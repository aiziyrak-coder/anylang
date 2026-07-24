#!/usr/bin/env python3
import os
import paramiko

PASS = os.environ["ANYLANG_SSH_PASS"]
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect("87.192.230.208", 2222, "admin_root", PASS, timeout=25)
cmd = (
    "docker logs --tail 250 anylang-api-1 2>&1 | "
    "grep -iE 'error|traceback|exception|500|Validation|create_message|Internal' | tail -80"
)
_, o, e = c.exec_command(f"echo {PASS!r} | sudo -S bash -lc {cmd!r}", timeout=60)
print(o.read().decode(errors="replace")[-9000:])
print("---")
_, o2, _ = c.exec_command(
    f"echo {PASS!r} | sudo -S bash -lc "
    "'docker logs --tail 80 anylang-api-1 2>&1 | tail -50'",
    timeout=60,
)
print(o2.read().decode(errors="replace")[-5000:])
c.close()
