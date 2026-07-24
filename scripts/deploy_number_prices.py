#!/usr/bin/env python3
"""Scale number-group prices so top tier is $2000."""
from __future__ import annotations

import os
import sys

import paramiko

PASS = os.environ.get("ANYLANG_SSH_PASS", "")
HOST = os.environ.get("ANYLANG_SSH_HOST", "87.192.230.208")
REMOTE = "/home/admin_root/anylang"
FILES = ["backend/app/services/numbers.py"]

# Proportional to old $499 max → $2000.
PRICE_SQL = """
UPDATE number_groups SET price = 2000.00 WHERE name = 'Platina';
UPDATE number_groups SET price = 1198.00 WHERE name = 'Brilliant';
UPDATE number_groups SET price = 597.00 WHERE name = 'Oltin';
UPDATE number_groups SET price = 517.00 WHERE name = 'Oltin — ketma-ket';
UPDATE number_groups SET price = 317.00 WHERE name = 'Kumush';
UPDATE number_groups SET price = 196.00 WHERE name = 'Kumush — juft';
UPDATE number_groups SET price = 76.00 WHERE name = 'Bronza';
UPDATE number_groups SET price = 36.00 WHERE name = 'Bronza — oson';
UPDATE number_groups SET price = 0.00 WHERE name = 'Standart';
SELECT name, price FROM number_groups ORDER BY price DESC, name;
"""


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

    # Escape single quotes for bash -c '...': double them for SQL inside single-quoted bash.
    sql_escaped = PRICE_SQL.replace("'", "'\"'\"'")
    fix_db = (
        f"echo {PASS!r} | sudo -S docker compose "
        f"-f /home/admin_root/anylang/deploy/docker-compose.prod.yml "
        f"--env-file /home/admin_root/anylang/deploy/.env "
        f"exec -T postgres psql -U anylang -d anylang -c {sql_escaped!r}"
    )
    # Better: pipe SQL via stdin
    pipe_sql = (
        f"echo {PASS!r} | sudo -S docker compose "
        f"-f /home/admin_root/anylang/deploy/docker-compose.prod.yml "
        f"--env-file /home/admin_root/anylang/deploy/.env "
        f"exec -T postgres psql -U anylang -d anylang"
    )
    stdin, o, e = c.exec_command(pipe_sql, timeout=60)
    stdin.write(PRICE_SQL)
    stdin.channel.shutdown_write()
    print("db:", o.read().decode(errors="replace")[-2000:])
    err = e.read().decode(errors="replace")
    print("\n".join(ln for ln in err.splitlines() if "password" not in ln.lower())[-500:])

    cmd = (
        "cd /home/admin_root/anylang/deploy && "
        "docker compose -f docker-compose.prod.yml --env-file .env up -d --build api"
    )
    _, o2, e2 = c.exec_command(f"echo {PASS!r} | sudo -S bash -lc {cmd!r}", timeout=1200)
    print(o2.read().decode(errors="replace")[-1200:])
    err2 = e2.read().decode(errors="replace")
    print("\n".join(ln for ln in err2.splitlines() if "password" not in ln.lower())[-600:])
    code = o2.channel.recv_exit_status()

    _, o3, _ = c.exec_command(
        "sleep 5; curl -sS -m 20 "
        "'http://127.0.0.1:8105/api/v1/numbers/groups' | python3 -c "
        "\"import sys,json; d=json.load(sys.stdin); "
        "items=d.get('items') or d if isinstance(d,list) else d.get('items',[]); "
        "[print(i.get('name'), i.get('price')) for i in (items if isinstance(items,list) else [])]\"",
        timeout=40,
    )
    print("groups:", o3.read().decode(errors="replace")[-1500:])
    c.close()
    return code


if __name__ == "__main__":
    raise SystemExit(main())
