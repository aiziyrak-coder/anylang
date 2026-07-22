import os
import paramiko

p = os.environ["ANYLANG_SSH_PASS"]
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect("87.192.230.208", 2222, "admin_root", p)
sftp = c.open_sftp()
sftp.put(r"E:\Anylang\admin\Dockerfile", "/home/admin_root/anylang/admin/Dockerfile")
sftp.mkdir("/home/admin_root/anylang/admin/public")
sftp.put(r"E:\Anylang\admin\public\.gitkeep", "/home/admin_root/anylang/admin/public/.gitkeep")
sftp.close()
cmd = f"cd /home/admin_root/anylang/deploy && echo '{p}' | sudo -S docker compose -f docker-compose.prod.yml --env-file .env up -d --build 2>&1"
_, stdout, _ = c.exec_command(cmd, timeout=2400)
import sys
sys.stdout.buffer.write(stdout.read())
c.close()
