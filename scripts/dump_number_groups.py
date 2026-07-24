#!/usr/bin/env python3
from __future__ import annotations

import os
import sys

import paramiko

PASS = os.environ.get("ANYLANG_SSH_PASS", "")


def main() -> int:
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect("87.192.230.208", 2222, "admin_root", PASS, timeout=25)
    sql = (
        "SELECT id, name, patterns::text, price, bonus_plan, is_active "
        "FROM number_groups ORDER BY id;"
    )
    cmd = (
        f"echo {PASS!r} | sudo -S docker compose "
        f"-f /home/admin_root/anylang/deploy/docker-compose.prod.yml "
        f"--env-file /home/admin_root/anylang/deploy/.env "
        f"exec -T postgres psql -U anylang -d anylang -c {sql!r}"
    )
    _, o, e = c.exec_command(cmd, timeout=60)
    print(o.read().decode(errors="replace"))
    print(e.read().decode(errors="replace")[-500:])
    c.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
