#!/usr/bin/env python3
"""Deploy voice STT failed UX fix (messages.py)."""
from __future__ import annotations

import os
from pathlib import Path

import paramiko

ROOT = Path(r"E:\Anylang")
PASS = os.environ["ANYLANG_SSH_PASS"]
HOST = os.environ.get("ANYLANG_SSH_HOST", "87.192.230.208")
REMOTE = "/home/admin_root/anylang"

FILES = [
    "backend/app/services/messages.py",
]


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 1200) -> int:
    _, out, err = c.exec_command(
        f"echo {PASS!r} | sudo -S bash -lc {cmd!r}", timeout=timeout
    )
    text = (out.read() + err.read()).decode(errors="replace")
    print(text[-3500:])
    return out.channel.recv_exit_status()


def main() -> int:
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, 2222, "admin_root", PASS, timeout=30)
    sftp = c.open_sftp()
    for rel in FILES:
        sftp.put(str(ROOT / rel.replace("/", os.sep)), f"{REMOTE}/{rel}")
        print("put", rel)
    sftp.close()
    code = sudo(
        c,
        "cd /home/admin_root/anylang/deploy && "
        "docker compose -f docker-compose.prod.yml --env-file .env "
        "up -d --build --force-recreate api worker",
        timeout=1800,
    )
    if code == 0:
        sudo(
            c,
            "sleep 8; curl -sS http://127.0.0.1:8105/health; echo; "
            "docker exec anylang-api-1 grep -n '_mark_voice_transcription_failed\\|_set_transcription_status' "
            "/app/app/services/messages.py | head -10",
            timeout=60,
        )
    c.close()
    return code


if __name__ == "__main__":
    raise SystemExit(main())
