# -*- coding: utf-8 -*-
"""Deploy USD catalog + CBU FX payment changes to production API."""
from __future__ import annotations

import os
import sys

import paramiko

PASS = os.environ.get("ANYLANG_SSH_PASS") or os.environ.get("SSH_PASS")
if not PASS:
    print("Set ANYLANG_SSH_PASS", file=sys.stderr)
    sys.exit(1)

HOST = "87.192.230.208"
PORT = 2222
USER = "admin_root"
REMOTE = "/home/admin_root/anylang"
ROOT = r"E:\Anylang"

FILES = [
    (r"backend\app\payments\fx.py", f"{REMOTE}/backend/app/payments/fx.py"),
    (r"backend\app\payments\service.py", f"{REMOTE}/backend/app/payments/service.py"),
    (r"backend\app\payments\schemas.py", f"{REMOTE}/backend/app/payments/schemas.py"),
    (
        r"backend\app\services\subscription.py",
        f"{REMOTE}/backend/app/services/subscription.py",
    ),
    (
        r"backend\app\schemas\subscription.py",
        f"{REMOTE}/backend/app/schemas/subscription.py",
    ),
    (
        r"backend\app\api\v1\subscription.py",
        f"{REMOTE}/backend/app/api/v1/subscription.py",
    ),
]


def main() -> int:
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, PORT, USER, PASS, timeout=30)
    sftp = c.open_sftp()
    for local_rel, remote in FILES:
        local = os.path.join(ROOT, local_rel)
        print("put", local_rel, "->", remote)
        sftp.put(local, remote)
    sftp.close()

    cmd = (
        f"echo {PASS!r} | sudo -S bash -lc "
        f"'cd {REMOTE}/deploy && docker compose -f docker-compose.prod.yml "
        f"--env-file .env up -d --build api worker'"
    )
    _, out, err = c.exec_command(cmd, timeout=300)
    text = (out.read() + err.read()).decode("utf-8", "replace")
    print(text[-3000:] if len(text) > 3000 else text)
    c.close()
    print("deploy done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
