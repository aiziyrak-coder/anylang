#!/usr/bin/env python3
"""Deploy subscription polish (API + admin) and patch Stripe return URLs."""
from __future__ import annotations

import os
from pathlib import Path

import paramiko

ROOT = Path(r"E:\Anylang")
PASS = os.environ["ANYLANG_SSH_PASS"]
REMOTE = "/home/admin_root/anylang"
FILES = [
    "backend/app/api/v1/admin_console.py",
    "backend/app/core/config.py",
    "backend/app/main.py",
    "backend/app/schemas/subscription.py",
    "backend/app/schemas/user.py",
    "backend/app/services/admin_console.py",
    "backend/app/services/subscription.py",
    "backend/.env.example",
    "admin/src/app/dashboard/subscriptions/page.tsx",
    "admin/src/app/dashboard/users/page.tsx",
    "admin/src/lib/i18n/uz.ts",
]


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 1200) -> str:
    _, out, err = c.exec_command(
        f"echo {PASS!r} | sudo -S bash -lc {cmd!r}", timeout=timeout
    )
    text = (out.read() + err.read()).decode(errors="replace")
    print(text[-3500:])
    return text


def main() -> int:
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect("87.192.230.208", 2222, "admin_root", PASS, timeout=25)
    sftp = c.open_sftp()
    for rel in FILES:
        sftp.put(str(ROOT / rel.replace("/", os.sep)), f"{REMOTE}/{rel}")
        print("put", rel)
    sftp.close()

    patch = """
from pathlib import Path
p = Path('/home/admin_root/anylang/deploy/.env')
text = p.read_text(encoding='utf-8')
kv = {
  'STRIPE_SUCCESS_URL': 'https://anylang.uz/billing/success',
  'STRIPE_CANCEL_URL': 'https://anylang.uz/billing/cancel',
}
lines = text.splitlines()
out=[]; seen=set()
for line in lines:
    if not line or line.startswith('#') or '=' not in line:
        out.append(line); continue
    k=line.split('=',1)[0].strip()
    if k in kv:
        out.append(f'{k}={kv[k]}'); seen.add(k)
    else:
        out.append(line)
for k,v in kv.items():
    if k not in seen: out.append(f'{k}={v}')
p.write_text('\\n'.join(out)+'\\n', encoding='utf-8')
print('stripe urls patched')
"""
    sftp = c.open_sftp()
    with sftp.file("/tmp/patch_stripe_urls.py", "w") as f:
        f.write(patch)
    sftp.close()
    sudo(c, "python3 /tmp/patch_stripe_urls.py", timeout=60)
    sudo(
        c,
        "cd /home/admin_root/anylang/deploy && "
        "docker compose -f docker-compose.prod.yml --env-file .env "
        "up -d --build api worker admin",
        timeout=1200,
    )
    sudo(
        c,
        "sleep 6; curl -sS http://127.0.0.1:8105/health; echo; "
        "curl -sS -o /dev/null -w '%{http_code}\\n' http://127.0.0.1:8105/billing/success; "
        "curl -sS https://anylang.uz/api/v1/subscription/plans?language=uz_UZ | head -c 400; echo",
        timeout=60,
    )
    c.close()
    print("deploy done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
