#!/usr/bin/env python3
import os
import paramiko

PASS = os.environ["ANYLANG_SSH_PASS"]
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect("87.192.230.208", 2222, "admin_root", PASS, timeout=20)

# List and delete auth keys inside redis container
cmd = (
    f"echo '{PASS}' | sudo -S docker exec anylang-redis-1 "
    "redis-cli --scan --pattern 'auth:*'"
)
_, o, e = c.exec_command(cmd, timeout=30)
keys = [k.strip() for k in o.read().decode().splitlines() if k.strip()]
print("keys before:", keys)
for k in keys:
    _, o2, _ = c.exec_command(
        f"echo '{PASS}' | sudo -S docker exec anylang-redis-1 redis-cli DEL '{k}'",
        timeout=20,
    )
    print("DEL", k, o2.read().decode().strip())

_, o, _ = c.exec_command(
    f"echo '{PASS}' | sudo -S docker exec anylang-redis-1 redis-cli --scan --pattern 'auth:*'",
    timeout=20,
)
print("keys after:", o.read().decode())

# Show SMTP_HOST specifically
_, o, _ = c.exec_command(
    "grep -n SMTP /home/admin_root/anylang/deploy/.env; "
    "grep -n ALLOW /home/admin_root/anylang/deploy/.env"
)
print("SMTP lines:\n", o.read().decode())
c.close()
