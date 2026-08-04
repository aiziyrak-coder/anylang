#!/usr/bin/env python3
"""Purge seeded partner mock users/products from production."""
from __future__ import annotations

import os
from pathlib import Path

import paramiko

ROOT = Path(r"E:\Anylang")
PASS = os.environ["ANYLANG_SSH_PASS"]
HOST = os.environ.get("ANYLANG_SSH_HOST", "87.192.230.208")
PORT = int(os.environ.get("ANYLANG_SSH_PORT", "2222"))
USER = os.environ.get("ANYLANG_SSH_USER", "admin_root")
REMOTE = "/home/admin_root/anylang"


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 600) -> tuple[int, str]:
    _, out, err = c.exec_command(
        f"echo {PASS!r} | sudo -S bash -lc {cmd!r}", timeout=timeout
    )
    text = (out.read() + err.read()).decode(errors="replace")
    code = out.channel.recv_exit_status()
    print(text[-5000:])
    print("exit", code)
    return code, text


def main() -> int:
    verify = ROOT / "backend" / "scripts" / "_verify_after_purge.py"
    verify.write_text(
        "import asyncio\n"
        "from sqlalchemy import text\n"
        "from app.db.session import get_session_factory\n"
        "\n"
        "async def main():\n"
        "    f = get_session_factory()\n"
        "    async with f() as db:\n"
        "        u = (await db.execute(text('select count(1) from users'))).scalar()\n"
        "        p = (await db.execute(text('select count(1) from products'))).scalar()\n"
        "        e = (await db.execute(text(\"select count(1) from users where email like 'partner.m%'\"))).scalar()\n"
        "        print(f'AFTER users={u} products={p} partner_left={e}')\n"
        "\n"
        "asyncio.run(main())\n",
        encoding="utf-8",
    )

    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, PORT, USER, PASS, timeout=30)
    sftp = c.open_sftp()
    for rel in (
        "backend/scripts/purge_partner_seed.py",
        "backend/scripts/_verify_after_purge.py",
    ):
        sftp.put(str(ROOT / rel.replace("/", "\\")), f"{REMOTE}/{rel}")
        print("put", rel)
    sftp.close()

    code, _ = sudo(
        c,
        "set -e; "
        "docker exec anylang-api-1 mkdir -p /app/scripts; "
        "docker exec anylang-api-1 touch /app/scripts/__init__.py; "
        "docker cp /home/admin_root/anylang/backend/scripts/purge_partner_seed.py "
        "anylang-api-1:/app/scripts/purge_partner_seed.py; "
        "docker cp /home/admin_root/anylang/backend/scripts/_verify_after_purge.py "
        "anylang-api-1:/app/scripts/_verify_after_purge.py; "
        "docker exec -w /app anylang-api-1 python -m scripts.purge_partner_seed --dry-run; "
        "docker exec -w /app anylang-api-1 python -m scripts.purge_partner_seed; "
        "docker exec -w /app anylang-api-1 python /app/scripts/_verify_after_purge.py",
        timeout=600,
    )
    c.close()
    verify.unlink(missing_ok=True)
    return code


if __name__ == "__main__":
    raise SystemExit(main())
