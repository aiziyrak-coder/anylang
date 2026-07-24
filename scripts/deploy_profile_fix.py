#!/usr/bin/env python3
"""Deploy profile/avatar fixes."""
from __future__ import annotations

import os
import sys

import paramiko

PASS = os.environ.get("ANYLANG_SSH_PASS", "")
HOST = os.environ.get("ANYLANG_SSH_HOST", "87.192.230.208")
REMOTE = "/home/admin_root/anylang"
FILES = [
    "backend/app/services/business.py",
    "backend/app/services/users.py",
    "backend/app/schemas/user.py",
]


def main() -> int:
    if not PASS:
        print("Set ANYLANG_SSH_PASS", file=sys.stderr)
        return 1
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, 2222, "admin_root", PASS, timeout=25)
    sftp = c.open_sftp()
    for rel in FILES:
        local = rf"E:\Anylang\{rel.replace('/', os.sep)}"
        sftp.put(local, f"{REMOTE}/{rel}")
        print("put", rel)
    sftp.close()
    cmd = (
        "cd /home/admin_root/anylang/deploy && "
        "docker compose -f docker-compose.prod.yml --env-file .env up -d --build api"
    )
    _, o, e = c.exec_command(f"echo {PASS!r} | sudo -S bash -lc {cmd!r}", timeout=1200)
    print(o.read().decode(errors="replace")[-2000:])
    err = e.read().decode(errors="replace")
    print("\n".join(ln for ln in err.splitlines() if "password" not in ln.lower())[-800:])
    code = o.channel.recv_exit_status()
    _, o2, _ = c.exec_command(
        f"echo {PASS!r} | sudo -S bash -lc 'sleep 5; curl -sS -m 8 http://127.0.0.1:8105/health'",
        timeout=40,
    )
    print("health", o2.read().decode(errors="replace"))
    c.close()
    return code


if __name__ == "__main__":
    raise SystemExit(main())
