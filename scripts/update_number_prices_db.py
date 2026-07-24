#!/usr/bin/env python3
"""Force-update number group prices by id (top = $2000)."""
from __future__ import annotations

import os
import sys

import paramiko

PASS = os.environ.get("ANYLANG_SSH_PASS", "")

# Scaled from old max $499 → $2000 (ids from prod dump).
UPDATES = [
    (1, "2000.00"),  # Platina
    (2, "1198.00"),  # Brilliant
    (3, "597.00"),  # Oltin
    (4, "517.00"),  # Oltin — ketma-ket
    (5, "317.00"),  # Kumush
    (6, "196.00"),  # Kumush — juft
    (7, "76.00"),  # Bronza
    (8, "36.00"),  # Bronza — oson
    (9, "0.00"),  # Standart
]


def main() -> int:
    if not PASS:
        print("Set ANYLANG_SSH_PASS", file=sys.stderr)
        return 1

    stmts = "; ".join(f"UPDATE number_groups SET price = {price} WHERE id = {gid}" for gid, price in UPDATES)
    sql = stmts + "; SELECT id, name, price FROM number_groups WHERE id <= 9 ORDER BY price DESC;"

    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect("87.192.230.208", 2222, "admin_root", PASS, timeout=25)
    cmd = (
        f"echo {PASS!r} | sudo -S docker compose "
        f"-f /home/admin_root/anylang/deploy/docker-compose.prod.yml "
        f"--env-file /home/admin_root/anylang/deploy/.env "
        f"exec -T postgres psql -U anylang -d anylang -v ON_ERROR_STOP=1 -c {sql!r}"
    )
    _, o, e = c.exec_command(cmd, timeout=60)
    print(o.read().decode(errors="replace"))
    err = e.read().decode(errors="replace")
    print("\n".join(ln for ln in err.splitlines() if "password" not in ln.lower())[-800:])
    c.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
