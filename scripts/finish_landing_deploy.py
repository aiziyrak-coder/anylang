import os
import paramiko

p = os.environ["ANYLANG_SSH_PASS"]
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect("87.192.230.208", 2222, "admin_root", p)

def sudo(cmd, timeout=900):
    _, o, e = c.exec_command(f"echo {p!r} | sudo -S bash -lc {cmd!r}", timeout=timeout)
    text = (o.read() + e.read()).decode(errors="replace")
    print(text[-3000:].encode("ascii", "replace").decode("ascii"))
    return text

print("=== admin rebuild ===")
sudo("cd /home/admin_root/anylang/deploy && docker compose -f docker-compose.prod.yml --env-file .env up -d --build admin")
print("=== status ===")
sudo("docker ps --filter name=anylang --format 'table {{.Names}}\t{{.Status}}'")
for cmd in [
    "curl -sS -o /dev/null -w '%{http_code}' https://anylang.uz/",
    "curl -sS -o /dev/null -w '%{http_code}' https://anylang.uz/assets/landing.css",
    "curl -sS -o /dev/null -w '%{http_code}' https://anylang.uz/admin/login",
    "curl -sS -o /dev/null -w '%{http_code}' https://anylang.uz/health",
    "curl -sS https://anylang.uz/ | head -c 180",
]:
    print(f"\n> {cmd}")
    sudo(cmd)
c.close()
