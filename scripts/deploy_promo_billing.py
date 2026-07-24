#!/usr/bin/env python3
"""Deploy multi-month plans + promo codes (API + admin) and run migration."""
from __future__ import annotations

import os
from pathlib import Path

import paramiko

ROOT = Path(r"E:\Anylang")
PASS = os.environ["ANYLANG_SSH_PASS"]
REMOTE = "/home/admin_root/anylang"

FILES = [
    "backend/app/models/__init__.py",
    "backend/app/models/promo.py",
    "backend/app/services/promo.py",
    "backend/app/services/subscription.py",
    "backend/app/services/payments.py",
    "backend/app/services/admin_console.py",
    "backend/app/schemas/promo.py",
    "backend/app/schemas/payment.py",
    "backend/app/schemas/subscription.py",
    "backend/app/schemas/user.py",
    "backend/app/api/v1/payments.py",
    "backend/app/api/v1/subscription.py",
    "backend/app/api/v1/admin_console.py",
    "backend/alembic/versions/a7b8c9d0e1f2_promo_codes.py",
    "admin/src/app/dashboard/layout.tsx",
    "admin/src/app/dashboard/promo-codes/page.tsx",
    "admin/src/app/dashboard/subscriptions/page.tsx",
    "admin/src/lib/i18n/uz.ts",
]


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 1200) -> str:
    _, out, err = c.exec_command(
        f"echo {PASS!r} | sudo -S bash -lc {cmd!r}", timeout=timeout
    )
    text = (out.read() + err.read()).decode(errors="replace")
    print(text[-4000:])
    return text


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
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect("87.192.230.208", 2222, "admin_root", PASS, timeout=25)
    sftp = c.open_sftp()
    for rel in FILES:
        local = ROOT / rel.replace("/", os.sep)
        remote = f"{REMOTE}/{rel}"
        ensure_remote_dir(sftp, str(Path(remote).parent).replace("\\", "/"))
        sftp.put(str(local), remote)
        print("put", rel)
    sftp.close()

    sudo(
        c,
        "cd /home/admin_root/anylang/deploy && "
        "docker compose -f docker-compose.prod.yml --env-file .env "
        "up -d --build api worker admin",
        timeout=1200,
    )
    sudo(
        c,
        "cd /home/admin_root/anylang/deploy && "
        "docker compose -f docker-compose.prod.yml --env-file .env "
        "exec -T api alembic upgrade head",
        timeout=180,
    )
    sudo(
        c,
        "sleep 4; "
        "curl -sS https://anylang.uz/api/v1/subscription/plans?language=uz_UZ | head -c 800; echo; "
        "curl -sS -o /dev/null -w 'plans:%{http_code}\\n' "
        "https://anylang.uz/api/v1/subscription/plans?language=uz_UZ",
        timeout=60,
    )
    c.close()
    print("deploy done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
