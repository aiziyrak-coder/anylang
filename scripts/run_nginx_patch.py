import os
import paramiko

p = os.environ["ANYLANG_SSH_PASS"]
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect("87.192.230.208", 2222, "admin_root", p)

sftp = c.open_sftp()
sftp.put(r"E:\Anylang\scripts\patch_anylang_nginx.py", "/tmp/patch_anylang_nginx.py")
sftp.close()

for cmd in [
    "cp /etc/nginx/sites-available/anylang.uz /etc/nginx/sites-available/anylang.uz.bak.bff",
    "python3 /tmp/patch_anylang_nginx.py",
    "nginx -t",
    "systemctl reload nginx",
    """curl -sS -X POST https://anylang.uz/api/auth/login -H 'Content-Type: application/json' -d '{"email":"admin@anylang.com","password":"AnyVY4cN6lV8at1wtWI!9"}' -w '\\nHTTP:%{http_code}'""",
]:
    _, o, e = c.exec_command(f"echo '{p}' | sudo -S bash -lc {repr(cmd)}", timeout=120)
    print(f"\n=== {cmd[:70]} ===")
    print(o.read().decode(errors="replace"))
    err = e.read().decode(errors="replace")
    if err.strip():
        print(err[-800:])

c.close()
