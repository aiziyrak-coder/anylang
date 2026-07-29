#!/usr/bin/env python3
"""Deploy Sofiya support session fix (MissingGreenlet) + ensure migration."""
from __future__ import annotations

import os
from pathlib import Path

import paramiko

ROOT = Path(r"E:\Anylang")
PASS = os.environ["ANYLANG_SSH_PASS"]
HOST = os.environ.get("ANYLANG_SSH_HOST", "87.192.230.208")
REMOTE = "/home/admin_root/anylang"

FILES = [
    "backend/app/services/support_sessions.py",
    "backend/app/services/support_chat.py",
    "backend/app/api/v1/support.py",
    "backend/app/schemas/support.py",
    "backend/app/models/support.py",
    "backend/app/models/__init__.py",
    "backend/alembic/versions/t7u8v9w0x1y2_support_sessions.py",
]


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 1200) -> tuple[int, str]:
    _, out, err = c.exec_command(
        f"echo {PASS!r} | sudo -S bash -lc {cmd!r}", timeout=timeout
    )
    text = (out.read() + err.read()).decode(errors="replace")
    code = out.channel.recv_exit_status()
    print(text[-4000:])
    print("exit", code)
    return code, text


def main() -> int:
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, 2222, "admin_root", PASS, timeout=30)
    sftp = c.open_sftp()
    for rel in FILES:
        local = ROOT / rel.replace("/", os.sep)
        remote = f"{REMOTE}/{rel}"
        sftp.put(str(local), remote)
        print("put", rel)
    sftp.close()

    code, _ = sudo(
        c,
        "cd /home/admin_root/anylang/deploy && "
        "docker compose -f docker-compose.prod.yml --env-file .env "
        "up -d --build --force-recreate api worker",
        timeout=1800,
    )
    if code != 0:
        c.close()
        return code

    sudo(
        c,
        "sleep 10; "
        "docker exec anylang-api-1 alembic upgrade head; "
        "docker exec anylang-api-1 alembic current; "
        "curl -sS http://127.0.0.1:8105/health; echo; "
        "curl -sS -o /dev/null -w 'support_chat:%{http_code}\\n' "
        "-X POST http://127.0.0.1:8105/api/v1/support/chat "
        "-H 'Content-Type: application/json' "
        "-d '{\"message\":\"ping\",\"history\":[],\"locale\":\"uz\"}'; "
        "curl -sS -o /dev/null -w 'support_public:%{http_code}\\n' "
        "-X POST http://127.0.0.1:8105/api/v1/support/public "
        "-H 'Content-Type: application/json' "
        "-d '{\"message\":\"salom\",\"history\":[],\"locale\":\"uz\"}'; "
        "docker logs anylang-api-1 --tail 40 2>&1 | tail -40",
        timeout=120,
    )
    c.close()
    print("support sessions fix deploy done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
