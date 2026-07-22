"""Patch only anylang.uz nginx — no other sites touched."""
import os
import paramiko

HOST = "87.192.230.208"
PORT = 2222
USER = "admin_root"
LOCAL = r"E:\Anylang\deploy\nginx\anylang.uz.conf"
REMOTE = "/tmp/anylang.uz.conf.new"

p = os.environ["ANYLANG_SSH_PASS"]
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect(HOST, PORT, USER, p)

sftp = c.open_sftp()
sftp.put(LOCAL, REMOTE)
sftp.close()

steps = [
    f"cp /etc/nginx/sites-available/anylang.uz /etc/nginx/sites-available/anylang.uz.bak.$(date +%Y%m%d%H%M%S)",
    f"python3 - <<'PY'\n"
    "from pathlib import Path\n"
    "new = Path('/tmp/anylang.uz.conf.new').read_text(encoding='utf-8')\n"
    "cur = Path('/etc/nginx/sites-available/anylang.uz').read_text(encoding='utf-8')\n"
    "marker = '    # FastAPI backend'\n"
    "bff = '''    # Admin BFF routes (must be before /api/ backend block)\n"
    "    location /api/auth/ {\n"
    "        proxy_pass http://127.0.0.1:3105;\n"
    "        proxy_http_version 1.1;\n"
    "        proxy_set_header Host $host;\n"
    "        proxy_set_header X-Real-IP $remote_addr;\n"
    "        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n"
    "        proxy_set_header X-Forwarded-Proto $scheme;\n"
    "    }\n\n"
    "    location /api/proxy/ {\n"
    "        proxy_pass http://127.0.0.1:3105;\n"
    "        proxy_http_version 1.1;\n"
    "        proxy_set_header Host $host;\n"
    "        proxy_set_header X-Real-IP $remote_addr;\n"
    "        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n"
    "        proxy_set_header X-Forwarded-Proto $scheme;\n"
    "        proxy_read_timeout 120s;\n"
    "    }\n\n'''\n"
    "if '/api/auth/' not in cur:\n"
    "    cur = cur.replace(marker, bff + marker)\n"
    "    Path('/etc/nginx/sites-available/anylang.uz').write_text(cur, encoding='utf-8')\n"
    "    print('patched')\n"
    "else:\n"
    "    print('already patched')\n"
    "PY",
    "nginx -t",
    "systemctl reload nginx",
]

for step in steps:
    _, o, e = c.exec_command(f"echo '{p}' | sudo -S bash -lc {repr(step)}", timeout=120)
    out = o.read().decode(errors="replace")
    err = e.read().decode(errors="replace")
    print(f"\n=== {step[:60]}... ===")
    print(out or err)

# verify login
login_cmd = (
    "curl -sS -X POST http://127.0.0.1/api/auth/login "
    "-H 'Host: anylang.uz' -H 'Content-Type: application/json' "
    "-d '{\"email\":\"admin@anylang.com\",\"password\":\"AnyVY4cN6lV8at1wtWI!9\"}' "
    "-w '\\nHTTP:%{http_code}'"
)
_, o, _ = c.exec_command(f"echo '{p}' | sudo -S bash -lc {repr(login_cmd)}", timeout=60)
print("\n=== login test ===")
print(o.read().decode(errors="replace")[:500])

c.close()
