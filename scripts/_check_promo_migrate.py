#!/usr/bin/env python3
from __future__ import annotations

import os
from pathlib import Path

import paramiko

PASS = os.environ["ANYLANG_SSH_PASS"]
ROOT = Path(r"E:\Anylang")
REMOTE = "/home/admin_root/anylang"


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 300) -> str:
    _, out, err = c.exec_command(
        f"echo {PASS!r} | sudo -S bash -lc {cmd!r}", timeout=timeout
    )
    text = (out.read() + err.read()).decode(errors="replace")
    print(text[-3000:])
    return text


def main() -> int:
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect("87.192.230.208", 2222, "admin_root", PASS, timeout=25)

    sftp = c.open_sftp()
    rel = "backend/app/api/v1/admin_console.py"
    sftp.put(str(ROOT / rel.replace("/", os.sep)), f"{REMOTE}/{rel}")
    print("put", rel)
    sftp.close()

    sudo(
        c,
        "cd /home/admin_root/anylang/deploy && "
        "docker compose -f docker-compose.prod.yml --env-file .env up -d --build api",
        timeout=900,
    )
    sudo(
        c,
        "cd /home/admin_root/anylang/deploy && "
        "docker compose -f docker-compose.prod.yml --env-file .env "
        "exec -T api alembic current",
    )
    sudo(
        c,
        "cd /home/admin_root/anylang/deploy && "
        "docker compose -f docker-compose.prod.yml --env-file .env "
        "exec -T api alembic upgrade head",
    )
    sudo(
        c,
        "cd /home/admin_root/anylang/deploy && "
        "docker compose -f docker-compose.prod.yml --env-file .env "
        "exec -T postgres psql -U anylang -d anylang -c "
        "\"SELECT code, discount_type, discount_value, is_active FROM promo_codes LIMIT 5;\"",
    )
    c.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
