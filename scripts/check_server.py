import os
import paramiko

p = os.environ["ANYLANG_SSH_PASS"]
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect("87.192.230.208", 2222, "admin_root", p, timeout=20)

cmds = [
    f"echo '{p}' | sudo -S docker ps -a --format 'table {{{{.Names}}}}\t{{{{.Status}}}}\t{{{{.Ports}}}}' | grep -i anylang || true",
    f"echo '{p}' | sudo -S docker compose -f /home/admin_root/anylang/deploy/docker-compose.prod.yml ps 2>&1",
    "curl -s http://127.0.0.1:8105/health 2>/dev/null || echo NO_API",
    "curl -sI http://127.0.0.1:3105 2>/dev/null | head -3 || echo NO_ADMIN",
    "ls -la /etc/nginx/sites-enabled/anylang.uz 2>/dev/null || echo NO_NGINX",
]
for cmd in cmds:
    _, o, e = c.exec_command(cmd, timeout=120)
    print("=== CMD ===")
    print(o.read().decode(errors="replace"))
    err = e.read().decode(errors="replace")
    if err.strip():
        print("ERR:", err[:500])
c.close()
