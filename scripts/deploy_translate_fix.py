#!/usr/bin/env python3
"""Upload chat translation fixes and rebuild API containers."""

from __future__ import annotations

import os
import sys

import paramiko

PASS = os.environ.get("ANYLANG_SSH_PASS", "")
HOST = os.environ.get("ANYLANG_SSH_HOST", "87.192.230.208")
REMOTE = "/home/admin_root/anylang"

FILES = [
    "backend/app/integrations/translation.py",
    "backend/app/services/messages.py",
    "backend/app/services/chats.py",
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
        remote = f"{REMOTE}/{rel}"
        sftp.put(local, remote)
        print("put", rel)
    sftp.close()

    cmds = [
        (
            "cd /home/admin_root/anylang/deploy && "
            "docker compose -f docker-compose.prod.yml --env-file .env up -d --build api worker"
        ),
        (
            "docker exec anylang-postgres-1 psql -U anylang -d anylang -c "
            "\"UPDATE message_translations mt SET text = m.text_original, status = 'failed' "
            "FROM messages m WHERE m.id = mt.message_id AND "
            "(mt.text IS NULL OR btrim(mt.text) = '') AND m.text_original IS NOT NULL "
            "AND btrim(m.text_original) <> '';\""
        ),
        (
            "docker exec anylang-postgres-1 psql -U anylang -d anylang -c "
            "\"UPDATE users SET native_language = 'en' "
            "WHERE lower(split_part(native_language, '_', 1)) IN ('us','gb','eng');\""
        ),
        "curl -sS http://127.0.0.1:8105/health",
        "grep -E '^TRANSLATION_PROVIDER=|^OPENAI_API_KEY=' /home/admin_root/anylang/deploy/.env | sed 's/=.*/=***/'",
    ]
    for cmd in cmds:
        full = f"echo '{PASS}' | sudo -S bash -lc {repr(cmd)}"
        _, o, e = c.exec_command(full, timeout=1200)
        out = o.read().decode(errors="replace")
        err = e.read().decode(errors="replace")
        code = o.channel.recv_exit_status()
        print("===", cmd[:90], "===")
        print(out[-3000:])
        if err.strip():
            # hide sudo password prompts noise
            cleaned = "\n".join(
                ln for ln in err.splitlines() if "password" not in ln.lower()
            )
            if cleaned.strip():
                print(cleaned[-1500:])
        print("exit", code)
        if code != 0 and "psql" not in cmd and "grep" not in cmd:
            c.close()
            return code
    c.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
