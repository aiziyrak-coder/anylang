import os
import json
import ssl
import urllib.request
import paramiko

p = os.environ["ANYLANG_SSH_PASS"]
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect("87.192.230.208", 2222, "admin_root", p)

def sudo(cmd):
    _, o, e = c.exec_command(f"echo {p!r} | sudo -S bash -lc {cmd!r}", timeout=60)
    return (o.read() + e.read()).decode(errors="replace")

print("api status:", sudo("docker ps --filter name=anylang-api --format '{{.Status}}'").strip())
print("ready:", sudo("curl -sS http://127.0.0.1:8105/ready").strip())
print("env provider:", sudo("grep -E '^(TRANSLATION_PROVIDER|ALLOW_MOCK_TRANSLATION|OPENAI_MODEL|OPENAI_API_KEY)=' /home/admin_root/anylang/deploy/.env | sed 's/OPENAI_API_KEY=.*/OPENAI_API_KEY=***SET***/'").strip())
print("api log tail:", sudo("docker logs anylang-api-1 --tail 20 2>&1").encode("ascii","replace").decode()[-1500:])

# quick OpenAI path via python inside container
test = """
python - <<'PY'
import asyncio
from app.integrations.translation import translate
async def main():
    out = await translate('Hello, how are you?', 'uz', 'en')
    print('TRANSLATED=', out)
asyncio.run(main())
PY
"""
print("translate test:")
print(sudo(f"docker exec anylang-api-1 bash -lc {test!r}").encode("ascii","replace").decode()[-800:])
c.close()
