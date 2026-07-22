import os
import sys
import paramiko

p = os.environ["ANYLANG_SSH_PASS"]
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect("87.192.230.208", 2222, "admin_root", p, timeout=20)

cmd = (
    f"cd /home/admin_root/anylang/deploy && "
    f"echo '{p}' | sudo -S docker compose -f docker-compose.prod.yml --env-file .env up -d --build 2>&1"
)
_, stdout, stderr = c.exec_command(cmd, timeout=2400)
out = stdout.read().decode(errors="replace")
err = stderr.read().decode(errors="replace")
sys.stdout.buffer.write(out.encode("utf-8", errors="replace"))
sys.stdout.buffer.write(err.encode("utf-8", errors="replace"))
code = stdout.channel.recv_exit_status()
print(f"\nEXIT={code}")
c.close()
