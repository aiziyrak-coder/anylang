#!/usr/bin/env python3
import os
import paramiko

PASS = os.environ["ANYLANG_SSH_PASS"]
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect("87.192.230.208", 2222, "admin_root", PASS, timeout=25)
cmd = (
    "docker logs --tail 120 anylang-api-1 2>&1 | "
    "grep -iE 'error|exception|traceback|500|create_message|translate' | tail -50"
)
_, o, e = c.exec_command(f"echo {PASS!r} | sudo -S bash -lc {cmd!r}", timeout=60)
print(o.read().decode(errors="replace")[-5000:])
err = e.read().decode(errors="replace")
print("---stderr---")
print("\n".join(ln for ln in err.splitlines() if "password" not in ln.lower())[-800:])
c.close()
