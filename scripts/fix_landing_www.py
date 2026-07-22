import os
import paramiko

p = os.environ["ANYLANG_SSH_PASS"]
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect("87.192.230.208", 2222, "admin_root", p)

def sudo(cmd, timeout=120):
    _, o, e = c.exec_command(f"echo {p!r} | sudo -S bash -lc {cmd!r}", timeout=timeout)
    text = (o.read() + e.read()).decode(errors="replace")
    print(text[-2000:].encode("ascii", "replace").decode("ascii"))

cmds = [
    "mkdir -p /var/www/anylang && rsync -a --delete /home/admin_root/anylang/landing/ /var/www/anylang/ && chown -R www-data:www-data /var/www/anylang && chmod -R a+rX /var/www/anylang",
    "sed -i 's#root /home/admin_root/anylang/landing;#root /var/www/anylang;#' /etc/nginx/sites-available/anylang.uz",
    "nginx -t && systemctl reload nginx",
    "curl -sS -o /dev/null -w '%{http_code}' https://anylang.uz/",
    "curl -sS -o /dev/null -w '%{http_code}' https://anylang.uz/assets/landing.css",
    "curl -sS -o /dev/null -w '%{http_code}' https://anylang.uz/admin/login",
    "curl -sS https://anylang.uz/ | head -c 220",
]
for cmd in cmds:
    print(f"\n=== {cmd[:90]} ===")
    sudo(cmd)
c.close()
