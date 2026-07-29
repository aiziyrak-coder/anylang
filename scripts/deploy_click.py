#!/usr/bin/env python3
"""Push Click SHOP API env to production and rebuild api/worker."""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import paramiko

PASS = os.environ["ANYLANG_SSH_PASS"]
HOST = os.environ.get("ANYLANG_SSH_HOST", "87.192.230.208")
REMOTE = "/home/admin_root/anylang"
ROOT = Path(r"E:\Anylang")

ENV_KEYS: dict[str, str] = {
    "PAYMENT_PROVIDER": "click",
    "CLICK_SERVICE_ID": "108598",
    "CLICK_PAY_BASE_URL": "https://my.click.uz/services/pay",
    "CLICK_MERCHANT_API_BASE": "https://api.click.uz/v2/merchant",
    "CLICK_OFD_UNITS": "1",
    "PAYMENT_TEST_AMOUNT_UZS": "1000",
    "PUBLIC_API_BASE_URL": "https://anylang.uz",
}


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 1800) -> int:
    full = f"echo {PASS!r} | sudo -S bash -lc {cmd!r}"
    _, out, err = c.exec_command(full, timeout=timeout)
    text = (out.read() + err.read()).decode("utf-8", errors="replace")
    code = out.channel.recv_exit_status()
    try:
        print(text[-5000:])
    except UnicodeEncodeError:
        print(text[-5000:].encode("ascii", "replace").decode("ascii"))
    print("exit", code)
    return code


def ensure_remote_dir(sftp: paramiko.SFTPClient, remote: str) -> None:
    parts = remote.strip("/").split("/")
    cur = ""
    for p in parts:
        cur += "/" + p
        try:
            sftp.stat(cur)
        except OSError:
            try:
                sftp.mkdir(cur)
            except OSError:
                pass


def main() -> int:
    for key in (
        "CLICK_MERCHANT_ID",
        "CLICK_SECRET_KEY",
        "CLICK_MERCHANT_USER_ID",
        "CLICK_OFD_SPIC",
        "CLICK_OFD_PACKAGE_CODE",
    ):
        val = (os.environ.get(key) or "").strip()
        if val:
            ENV_KEYS[key] = val

    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, 2222, "admin_root", PASS, timeout=30)
    sftp = c.open_sftp()

    with sftp.file("/tmp/click_env_keys.json", "w") as f:
        f.write(json.dumps(ENV_KEYS))

    patch_py = r"""
import json, pathlib
keys = json.loads(pathlib.Path('/tmp/click_env_keys.json').read_text(encoding='utf-8'))
p = pathlib.Path('/home/admin_root/anylang/deploy/.env')
text = p.read_text(encoding='utf-8') if p.exists() else ''
lines = text.splitlines()
seen = set()
out = []
for ln in lines:
    if not ln.strip() or ln.strip().startswith('#') or '=' not in ln:
        out.append(ln)
        continue
    k = ln.split('=', 1)[0].strip()
    if k in keys:
        out.append(f'{k}={keys[k]}')
        seen.add(k)
    else:
        out.append(ln)
for k, v in keys.items():
    if k not in seen:
        out.append(f'{k}={v}')
p.write_text('\n'.join(out) + '\n', encoding='utf-8')
print('env updated', sorted(keys))
"""
    with sftp.file("/tmp/patch_click_env.py", "w") as f:
        f.write(patch_py)

    files = [
        "core/config.py",
        "payments/click.py",
        "payments/fiscal.py",
        "payments/pricing.py",
        "payments/service.py",
        "payments/router.py",
        "services/payments.py",
        "services/subscription.py",
    ]
    for rel in files:
        local = ROOT / "backend" / "app" / rel
        remote = f"{REMOTE}/backend/app/{rel}"
        if not local.exists():
            print("missing", local)
            continue
        ensure_remote_dir(sftp, str(Path(remote).parent).replace("\\", "/"))
        sftp.put(str(local), remote)
        print("put", rel)
    sftp.close()

    sudo(c, "python3 /tmp/patch_click_env.py")
    code = sudo(
        c,
        f"cd {REMOTE}/deploy && "
        "docker compose -f docker-compose.prod.yml --env-file .env up -d --build --force-recreate "
        "api worker",
        timeout=2400,
    )
    if code != 0:
        c.close()
        return code

    sudo(
        c,
        "sleep 5; curl -sS http://127.0.0.1:8105/health; echo; "
        "docker exec anylang-api-1 printenv | grep -E 'PAYMENT_|CLICK_|PUBLIC_API' "
        "| sed -E 's/(SECRET|KEY)=.*/\\1=***/'; "
        "curl -sS -o /dev/null -w 'prepare:%{http_code}\\n' -X POST "
        "https://anylang.uz/api/v1/payments/click/prepare; "
        "curl -sS -o /dev/null -w 'complete:%{http_code}\\n' -X POST "
        "https://anylang.uz/api/v1/payments/click/complete; "
        "curl -sS ifconfig.me; echo; "
        "hostname -I | awk '{print $1}'",
    )
    c.close()
    print(
        "\nCALLBACK URLs for merchant.click.uz:\n"
        "  Prepare URL:  https://anylang.uz/api/v1/payments/click/prepare\n"
        "  Complete URL: https://anylang.uz/api/v1/payments/click/complete\n"
    )
    missing = [
        k
        for k in ("CLICK_MERCHANT_ID", "CLICK_SECRET_KEY", "CLICK_MERCHANT_USER_ID")
        if k not in ENV_KEYS
    ]
    if missing:
        print("WARNING: still missing credentials:", ", ".join(missing))
        print("Set them in merchant.click.uz / env then re-run with env vars.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
