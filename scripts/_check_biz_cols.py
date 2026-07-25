#!/usr/bin/env python3
import os
import paramiko

PASS = os.environ["ANYLANG_SSH_PASS"]
HOST = os.environ.get("ANYLANG_SSH_HOST", "87.192.230.208")
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect(HOST, 2222, "admin_root", PASS, timeout=30)

def run(cmd: str) -> None:
    _, out, err = c.exec_command(f"echo {PASS!r} | sudo -S bash -lc {cmd!r}", timeout=180)
    print((out.read() + err.read()).decode(errors="replace")[-2000:])
    print("---")

run("cd /home/admin_root/anylang/deploy && docker compose -f docker-compose.prod.yml --env-file .env exec -T api alembic current")
run("cd /home/admin_root/anylang/deploy && docker compose -f docker-compose.prod.yml --env-file .env exec -T api alembic upgrade head")
run("cd /home/admin_root/anylang/deploy && docker compose -f docker-compose.prod.yml --env-file .env exec -T postgres psql -U anylang -d anylang -c '\\\\d business_profiles'")
c.close()
