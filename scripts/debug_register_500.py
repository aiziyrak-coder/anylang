import os
import paramiko

p = os.environ["ANYLANG_SSH_PASS"]
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect("87.192.230.208", 2222, "admin_root", p)

def sudo(cmd, timeout=60):
    _, o, e = c.exec_command(f"echo {p!r} | sudo -S bash -lc {cmd!r}", timeout=timeout)
    text = (o.read() + e.read()).decode(errors="replace")
    print(text[-3500:].encode("ascii", "replace").decode("ascii"))

print("=== api logs ===")
sudo("docker logs anylang-api-1 --tail 80 2>&1")
print("=== env mail/cors ===")
sudo("grep -E '^(CORS_|MAIL_|SMTP_|APP_|FRONTEND_|ALLOW_|TRUSTED)' /home/admin_root/anylang/deploy/.env | sed 's/=.*/=***/'")
c.close()
