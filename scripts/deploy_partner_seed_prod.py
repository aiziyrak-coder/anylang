#!/usr/bin/env python3
"""Upload partner seed artifacts and run seed against production API DB."""
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

FILES = [
    "backend/scripts/seed_partner_marketplace.py",
    "backend/scripts/_verify_prod_seed.py",
    "docs/outreach/partner_credentials.csv",
]


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 1200) -> tuple[int, str]:
    _, out, err = c.exec_command(
        f"echo {PASS!r} | sudo -S bash -lc {cmd!r}", timeout=timeout
    )
    text = (out.read() + err.read()).decode(errors="replace")
    code = out.channel.recv_exit_status()
    print(text[-8000:])
    print("exit", code)
    return code, text


def main() -> int:
    verify = ROOT / "backend" / "scripts" / "_verify_prod_seed.py"
    verify.write_text(
        "import asyncio\n"
        "from sqlalchemy import text\n"
        "from app.db.session import get_session_factory\n"
        "\n"
        "async def main():\n"
        "    f = get_session_factory()\n"
        "    async with f() as db:\n"
        "        u = (await db.execute(text('select count(1) from users'))).scalar()\n"
        "        p = (await db.execute(text(\"select count(1) from products where status='published'\"))).scalar()\n"
        "        b = (await db.execute(text(\"select count(1) from subscriptions where plan='business'\"))).scalar()\n"
        "        e = (await db.execute(text(\"select count(1) from users where email like 'partner.m%'\"))).scalar()\n"
        "        print(f'PROD users={u} partner_users={e} business={b} published_products={p}')\n"
        "\n"
        "asyncio.run(main())\n",
        encoding="utf-8",
    )

    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, PORT, USER, PASS, timeout=30)
    sftp = c.open_sftp()
    sudo(
        c,
        f"mkdir -p {REMOTE}/backend/scripts {REMOTE}/docs/outreach && "
        f"chown -R {USER}:{USER} {REMOTE}/docs {REMOTE}/backend/scripts",
        timeout=60,
    )
    for rel in FILES:
        local = ROOT / rel.replace("/", os.sep)
        remote = f"{REMOTE}/{rel}"
        sftp.put(str(local), remote)
        print("put", rel, local.stat().st_size)
    sftp.close()

    code, _ = sudo(
        c,
        "set -e; "
        "docker exec anylang-api-1 mkdir -p /app/scripts; "
        "docker exec anylang-api-1 touch /app/scripts/__init__.py; "
        "docker cp /home/admin_root/anylang/backend/scripts/seed_partner_marketplace.py "
        "anylang-api-1:/app/scripts/seed_partner_marketplace.py; "
        "docker cp /home/admin_root/anylang/backend/scripts/_verify_prod_seed.py "
        "anylang-api-1:/app/scripts/_verify_prod_seed.py; "
        "docker cp /home/admin_root/anylang/docs/outreach/partner_credentials.csv "
        "anylang-api-1:/tmp/partner_credentials.csv; "
        "docker exec -e PARTNER_CREDS_CSV=/tmp/partner_credentials.csv -w /app anylang-api-1 "
        "python -m scripts.seed_partner_marketplace --dry-run; "
        "docker exec -e PARTNER_CREDS_CSV=/tmp/partner_credentials.csv -w /app anylang-api-1 "
        "python -m scripts.seed_partner_marketplace --per-company 20; "
        "docker exec -w /app anylang-api-1 python /app/scripts/_verify_prod_seed.py",
        timeout=1800,
    )
    c.close()
    verify.unlink(missing_ok=True)
    Path(ROOT / "scripts" / "_probe_api_container.py").unlink(missing_ok=True)
    return code


if __name__ == "__main__":
    raise SystemExit(main())
