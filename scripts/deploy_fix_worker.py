import os
import paramiko

p = os.environ["ANYLANG_SSH_PASS"]
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect("87.192.230.208", 2222, "admin_root", p)
sftp = c.open_sftp()
sftp.put(
    r"E:\Anylang\backend\app\workers\settings.py",
    "/home/admin_root/anylang/backend/app/workers/settings.py",
)
sftp.close()
cmd = (
    f"cd /home/admin_root/anylang/deploy && "
    f"docker compose -f docker-compose.prod.yml --env-file .env up -d --build worker"
)
_, o, e = c.exec_command(f"echo '{p}' | sudo -S bash -lc {repr(cmd)}", timeout=600)
print(o.read().decode()[-2500:])
print(e.read().decode()[-500:])
_, o, _ = c.exec_command(f"echo '{p}' | sudo -S docker ps --filter name=anylang-worker --format '{{{{.Status}}}}'")
print("Worker:", o.read().decode())
c.close()
