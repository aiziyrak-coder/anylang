import os
import paramiko

p = os.environ["ANYLANG_SSH_PASS"]
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect("87.192.230.208", 2222, "admin_root", p)

cmds = [
    f"cp /home/admin_root/anylang/deploy/nginx/anylang.uz.conf /etc/nginx/sites-available/anylang.uz && "
    f"ln -sf /etc/nginx/sites-available/anylang.uz /etc/nginx/sites-enabled/anylang.uz && "
    f"nginx -t && systemctl reload nginx",
    "certbot --nginx -d anylang.uz -d www.anylang.uz --non-interactive --agree-tos -m admin@anylang.uz --redirect",
    "curl -s http://127.0.0.1:8105/health",
    "curl -sI http://127.0.0.1:3105 | head -5",
    "curl -sI http://anylang.uz | head -10",
    "curl -sI https://anylang.uz | head -10",
]
for cmd in cmds:
    full = f"echo '{p}' | sudo -S bash -lc {repr(cmd)}" if "nginx" in cmd or "certbot" in cmd else cmd
    _, o, e = c.exec_command(full, timeout=300)
    print("===", cmd[:60], "===")
    print(o.read().decode(errors="replace"))
    err = e.read().decode(errors="replace")
    if err.strip():
        print("ERR:", err[:300])
c.close()
