#!/usr/bin/env python3
"""Wipe production app data for a clean test start. Keeps admin panel accounts.

Preserved:
  - admin_users
  - alembic_version
  - languages (reference)
  - number_groups (admin catalog / pricing)

Everything else (users, products, payments, chats, promo usage, …) is truncated.
"""

from __future__ import annotations

import os
import sys

import paramiko

PASS = os.environ.get("ANYLANG_SSH_PASS", "")
HOST = os.environ.get("ANYLANG_SSH_HOST", "87.192.230.208")
PORT = 2222
USER = "admin_root"

KEEP = {
    "admin_users",
    "alembic_version",
    "languages",
    "number_groups",
}

WIPE_SQL = r"""
DO $$
DECLARE
  r RECORD;
BEGIN
  FOR r IN
    SELECT tablename
    FROM pg_tables
    WHERE schemaname = 'public'
      AND tablename NOT IN (
        'admin_users',
        'alembic_version',
        'languages',
        'number_groups'
      )
  LOOP
    EXECUTE format('TRUNCATE TABLE %I RESTART IDENTITY CASCADE', r.tablename);
    RAISE NOTICE 'truncated %', r.tablename;
  END LOOP;
END $$;

SELECT 'admin_users' AS kept, count(*)::text AS n FROM admin_users
UNION ALL SELECT 'users', count(*)::text FROM users
UNION ALL SELECT 'products', count(*)::text FROM products
UNION ALL SELECT 'payments', count(*)::text FROM payments
UNION ALL SELECT 'chats', count(*)::text FROM chats
UNION ALL SELECT 'number_groups', count(*)::text FROM number_groups
UNION ALL SELECT 'languages', count(*)::text FROM languages;
"""


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 300) -> tuple[int, str]:
    full = f"echo {PASS!r} | sudo -S bash -lc {cmd!r}"
    _, out, err = c.exec_command(full, timeout=timeout)
    text = (out.read() + err.read()).decode("utf-8", errors="replace")
    code = out.channel.recv_exit_status()
    print(text[-6000:] if len(text) > 6000 else text)
    print("exit", code)
    return code, text


def main() -> int:
    if not PASS:
        print("Set ANYLANG_SSH_PASS", file=sys.stderr)
        return 1

    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, PORT, USER, PASS, timeout=30)

    print("=== BEFORE ===")
    sudo(
        c,
        "docker exec anylang-postgres-1 psql -U anylang -d anylang -c "
        "\"SELECT id,email,role,is_active FROM admin_users; "
        "SELECT (SELECT count(*) FROM users) users, "
        "(SELECT count(*) FROM products) products, "
        "(SELECT count(*) FROM payments) payments;\"",
    )

    # Write SQL on remote, run via psql -f to avoid shell quoting hell.
    sftp = c.open_sftp()
    with sftp.file("/tmp/anylang_wipe_test_data.sql", "w") as f:
        f.write(WIPE_SQL)
    sftp.close()

    print("=== WIPE (keep admin_users / languages / number_groups) ===")
    code, _ = sudo(
        c,
        "docker cp /tmp/anylang_wipe_test_data.sql anylang-postgres-1:/tmp/wipe.sql && "
        "docker exec anylang-postgres-1 psql -U anylang -d anylang -v ON_ERROR_STOP=1 "
        "-f /tmp/wipe.sql",
        timeout=600,
    )
    if code != 0:
        c.close()
        return code

    # Flush redis caches if present.
    print("=== REDIS FLUSH (best-effort) ===")
    sudo(
        c,
        "docker ps --format '{{.Names}}' | grep -E 'redis|anylang-redis' | head -1 | "
        "xargs -r -I{} docker exec {} redis-cli FLUSHALL || true",
    )

    print("=== AFTER ===")
    sudo(
        c,
        "docker exec anylang-postgres-1 psql -U anylang -d anylang -c "
        "\"SELECT id,email,role,is_active FROM admin_users; "
        "SELECT (SELECT count(*) FROM users) users, "
        "(SELECT count(*) FROM products) products, "
        "(SELECT count(*) FROM payments) payments, "
        "(SELECT count(*) FROM chats) chats;\"",
    )
    c.close()
    print("DONE wipe — admin panel accounts preserved")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
