#!/usr/bin/env python3
"""Push Multicard env to production deploy/.env and rebuild api."""
from __future__ import annotations

import os
import sys

import paramiko

PASS = os.environ["ANYLANG_SSH_PASS"]
HOST = os.environ.get("ANYLANG_SSH_HOST", "87.192.230.208")
REMOTE = "/home/admin_root/anylang"

ENV_LINES = {
    "PAYMENT_PROVIDER": "multicard",
    "MULTICARD_BASE_URL": "https://dev-mesh.multicard.uz",
    "MULTICARD_APPLICATION_ID": "rhmt_test",
    "MULTICARD_SECRET": "Pw18axeBFo8V7NamKHXX",
    "MULTICARD_STORE_ID": "6",
    "PUBLIC_API_BASE_URL": "https://anylang.uz",
}


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 1800) -> int:
    full = f"echo {PASS!r} | sudo -S bash -lc {cmd!r}"
    _, out, err = c.exec_command(full, timeout=timeout)
    text = (out.read() + err.read()).decode(errors="replace")
    code = out.channel.recv_exit_status()
    print(text[-4000:])
    print("exit", code)
    return code


def main() -> int:
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, 2222, "admin_root", PASS, timeout=30)

    # Upsert env keys
    py = r"""
import pathlib
p = pathlib.Path('/home/admin_root/anylang/deploy/.env')
text = p.read_text(encoding='utf-8') if p.exists() else ''
lines = text.splitlines()
keys = {
  'PAYMENT_PROVIDER': 'multicard',
  'MULTICARD_BASE_URL': 'https://dev-mesh.multicard.uz',
  'MULTICARD_APPLICATION_ID': 'rhmt_test',
  'MULTICARD_SECRET': 'Pw18axeBFo8V7NamKHXX',
  'MULTICARD_STORE_ID': '6',
  'PUBLIC_API_BASE_URL': 'https://anylang.uz',
}
seen=set()
out=[]
for ln in lines:
  if not ln.strip() or ln.strip().startswith('#') or '=' not in ln:
    out.append(ln); continue
  k=ln.split('=',1)[0].strip()
  if k in keys:
    out.append(f'{k}={keys[k]}'); seen.add(k)
  else:
    out.append(ln)
for k,v in keys.items():
  if k not in seen:
    out.append(f'{k}={v}')
p.write_text('\n'.join(out)+'\n', encoding='utf-8')
print('env updated', sorted(keys))
"""
    sftp = c.open_sftp()
    with sftp.file("/tmp/patch_multicard_env.py", "w") as f:
        f.write(py)
    sftp.close()
    sudo(c, "python3 /tmp/patch_multicard_env.py")

    # Sync payment modules
    local_root = r"E:\Anylang\backend\app"
    rem_root = f"{REMOTE}/backend/app"
    files = [
        "core/config.py",
        "payments/multicard.py",
        "payments/service.py",
        "payments/tax.py",
        "payments/router.py",
        "payments/schemas.py",
        "payments/__init__.py",
        "schemas/payment.py",
        "schemas/subscription.py",
        "services/payments.py",
        "services/subscription.py",
        "api/v1/payments.py",
        "api/v1/subscription.py",
    ]
    sftp = c.open_sftp()
    for rel in files:
        local = f"{local_root}\\{rel.replace('/', chr(92))}"
        remote = f"{rem_root}/{rel}"
        try:
            sftp.put(local, remote)
            print("put", rel)
        except Exception as e:
            print("skip", rel, e)
    sftp.close()

    code = sudo(
        c,
        f"cd {REMOTE}/deploy && "
        "docker compose -f docker-compose.prod.yml --env-file .env up -d --build --force-recreate api worker",
        timeout=2400,
    )
    if code != 0:
        c.close()
        return code
    sudo(
        c,
        "sleep 8; curl -sS http://127.0.0.1:8105/health; echo; "
        "docker exec anylang-api-1 printenv | grep -E 'PAYMENT_PROVIDER|MULTICARD_' | sed 's/SECRET=.*/SECRET=***/'",
    )
    c.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
