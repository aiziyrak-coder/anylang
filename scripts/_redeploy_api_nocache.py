#!/usr/bin/env python3
from __future__ import annotations

import os
from pathlib import Path

import paramiko

PASS = os.environ["ANYLANG_SSH_PASS"]
ROOT = Path(r"E:\Anylang")
REMOTE = "/home/admin_root/anylang"


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 900) -> str:
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
    for rel in (
        "backend/app/api/v1/admin_console.py",
        "backend/app/api/v1/payments.py",
        "backend/app/services/promo.py",
        "backend/app/services/payments.py",
    ):
        sftp.put(str(ROOT / rel.replace("/", os.sep)), f"{REMOTE}/{rel}")
        print("put", rel)
    sftp.close()

    # Bust COPY cache
    sudo(c, "touch /home/admin_root/anylang/backend/app/api/v1/admin_console.py")
    sudo(
        c,
        "cd /home/admin_root/anylang/deploy && "
        "docker compose -f docker-compose.prod.yml --env-file .env "
        "build --no-cache api && "
        "docker compose -f docker-compose.prod.yml --env-file .env up -d api",
        timeout=1200,
    )
    sudo(
        c,
        "sleep 5; curl -sS https://anylang.uz/api/v1/subscription/plans?language=uz_UZ "
        "| python3 -c \"import sys,json; d=json.load(sys.stdin); "
        "print('periods', d['plans'][1]['periods']); print('opts', d.get('period_options'))\"",
    )
    c.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
