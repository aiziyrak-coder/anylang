import os
import paramiko
from pathlib import Path

PASS = os.environ["ANYLANG_SSH_PASS"]
ROOT = Path(r"E:\Anylang")
REMOTE = "/home/admin_root/anylang"
FILES = [
    "backend/app/services/users.py",
    "backend/app/schemas/business.py",
]

c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect("87.192.230.208", 2222, "admin_root", PASS, timeout=25)
sftp = c.open_sftp()
for f in FILES:
    sftp.put(str(ROOT / f), f"{REMOTE}/{f}")
    print("put", f)
sftp.close()
cmd = (
    "cd /home/admin_root/anylang/deploy && "
    "docker compose -f docker-compose.prod.yml --env-file .env up -d --build api"
)
_, o, e = c.exec_command(f"echo {PASS!r} | sudo -S bash -lc {cmd!r}", timeout=900)
print((o.read() + e.read()).decode(errors="replace")[-2500:])
print("exit", o.channel.recv_exit_status())
c.close()
