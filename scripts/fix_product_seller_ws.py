import os
import paramiko

p = os.environ["ANYLANG_SSH_PASS"]
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect("87.192.230.208", 2222, "admin_root", p)
sftp = c.open_sftp()
sftp.put(r"E:\Anylang\backend\app\models\product.py", "/home/admin_root/anylang/backend/app/models/product.py")
sftp.close()

def sudo(cmd, timeout=600):
    _, o, e = c.exec_command(f"echo {p!r} | sudo -S bash -lc {cmd!r}", timeout=timeout)
    text = (o.read() + e.read()).decode(errors="replace")
    print(text[-2000:].encode("ascii", "replace").decode("ascii"))

# patch nginx: exact /ws as well
sudo(
    r"""python3 - <<'PY'
from pathlib import Path
p = Path('/etc/nginx/sites-available/anylang.uz')
t = p.read_text(encoding='utf-8')
needle = '    # WebSocket\n    location /ws/ {'
extra = '''    # WebSocket exact + prefix
    location = /ws {
        return 301 /ws/;
    }
    location /ws/ {'''
if 'location = /ws' not in t:
    t = t.replace(needle, extra)
    p.write_text(t, encoding='utf-8')
    print('nginx ws patched')
else:
    print('nginx already patched')
PY"""
)
sudo("nginx -t && systemctl reload nginx")
sudo("cd /home/admin_root/anylang/deploy && docker compose -f docker-compose.prod.yml --env-file .env up -d --build api", timeout=900)

# translate test via docker exec python -c
sudo(
    """docker exec anylang-api-1 python -c \"import asyncio; from app.integrations.translation import translate; print(asyncio.run(translate('Hello friend','uz','en')))\""""
)
c.close()
