import os
import paramiko

p = os.environ["ANYLANG_SSH_PASS"]
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect("87.192.230.208", 2222, "admin_root", p)

def sudo(cmd):
    _, o, e = c.exec_command(f"echo {p!r} | sudo -S bash -lc {cmd!r}", timeout=60)
    text = (o.read() + e.read()).decode(errors="replace")
    print(text[-2000:].encode("ascii", "replace").decode("ascii"))

for cmd in [
    "ls -la /home/admin_root/anylang/landing /home/admin_root/anylang/landing/assets",
    "namei -l /home/admin_root/anylang/landing/index.html",
    "tail -n 30 /var/log/nginx/error.log",
    "grep -n location /etc/nginx/sites-available/anylang.uz | head -40",
]:
    print(f"\n=== {cmd} ===")
    sudo(cmd)
c.close()
