import os
import paramiko

p = os.environ["ANYLANG_SSH_PASS"]
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect("87.192.230.208", 2222, "admin_root", p)

cmds = [
    "curl -sS -o /dev/null -w '%{http_code}' http://127.0.0.1:8105/api/v1/docs",
    "curl -sS -o /dev/null -w '%{http_code}' http://127.0.0.1:8105/ready",
    "curl -sS -o /dev/null -w '%{http_code}' http://127.0.0.1:3105/api/auth/login",
    "cat /etc/nginx/sites-available/anylang.uz",
    "ls -la /etc/letsencrypt/live/anylang.uz/ 2>/dev/null || true",
]
for cmd in cmds:
    _, o, e = c.exec_command(f"echo '{p}' | sudo -S bash -lc {repr(cmd)}", timeout=60)
    print(f"\n=== {cmd[:80]} ===")
    print(o.read().decode(errors='replace')[:4000])
c.close()
