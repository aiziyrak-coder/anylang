import os
import time
import paramiko

p = os.environ["ANYLANG_SSH_PASS"]
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect("87.192.230.208", 2222, "admin_root", p)
time.sleep(5)
_, o, e = c.exec_command(
    f"echo {p!r} | sudo -S bash -lc \"docker ps --filter name=anylang-api --format '{{{{.Status}}}}'; curl -sS http://127.0.0.1:8105/ready\"",
    timeout=30,
)
print((o.read() + e.read()).decode(errors="replace")[-500:])
c.close()
