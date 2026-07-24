#!/usr/bin/env python3
"""Set OpenAI on production and rebuild API. Key from OPENAI_API_KEY env only."""

from __future__ import annotations

import json
import os
import time
import urllib.request

import paramiko

PASS = os.environ["ANYLANG_SSH_PASS"]
OPENAI = os.environ["OPENAI_API_KEY"].strip()
HOST = "87.192.230.208"
REMOTE = "/home/admin_root/anylang"


def main() -> None:
    if not OPENAI.startswith("sk-"):
        raise SystemExit("OPENAI_API_KEY missing or invalid")

    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, 2222, "admin_root", PASS, timeout=25)
    sftp = c.open_sftp()
    for rel in [
        "backend/app/integrations/translation.py",
        "backend/app/integrations/stt.py",
        "backend/app/services/messages.py",
        "backend/app/core/config.py",
        "backend/app/core/startup.py",
        "deploy/env.production.template",
    ]:
        local = rf"E:\Anylang\{rel.replace('/', os.sep)}"
        remote = f"{REMOTE}/{rel}"
        try:
            sftp.put(local, remote)
            print("put", rel)
        except FileNotFoundError:
            print("skip missing", rel)
    sftp.close()

    patch = f"""
from pathlib import Path
p = Path('/home/admin_root/anylang/deploy/.env')
text = p.read_text(encoding='utf-8')
lines = text.splitlines()
kv = {{
  'TRANSLATION_PROVIDER': 'openai',
  'ALLOW_MOCK_TRANSLATION': 'false',
  'OPENAI_API_KEY': {OPENAI!r},
  'OPENAI_MODEL': 'gpt-4o-mini',
}}
out = []
seen = set()
for line in lines:
    if not line or line.startswith('#') or '=' not in line:
        out.append(line)
        continue
    k = line.split('=', 1)[0].strip()
    if k in kv:
        out.append(f'{{k}}={{kv[k]}}')
        seen.add(k)
    else:
        out.append(line)
for k, v in kv.items():
    if k not in seen:
        out.append(f'{{k}}={{v}}')
p.write_text('\\n'.join(out) + '\\n', encoding='utf-8')
# never print key
print('env updated keys=', sorted(kv))
"""
    sftp = c.open_sftp()
    with sftp.file("/tmp/patch_openai_env.py", "w") as f:
        f.write(patch)
    sftp.close()

    def sudo(cmd: str, timeout: int = 900) -> str:
        _, o, e = c.exec_command(
            f"echo {PASS!r} | sudo -S bash -lc {cmd!r}", timeout=timeout
        )
        out = (o.read() + e.read()).decode(errors="replace")
        print(out[-2500:])
        return out

    sudo("python3 /tmp/patch_openai_env.py; shred -u /tmp/patch_openai_env.py 2>/dev/null || rm -f /tmp/patch_openai_env.py")
    sudo(
        "cd /home/admin_root/anylang/deploy && "
        "docker compose -f docker-compose.prod.yml --env-file .env up -d --build api worker",
        timeout=900,
    )

    for _ in range(25):
        _, o, _ = c.exec_command(
            f"echo {PASS!r} | sudo -S docker inspect -f "
            "'{{.State.Health.Status}}' anylang-api-1",
            timeout=15,
        )
        status = o.read().decode().strip()
        print("health:", status)
        if status == "healthy":
            break
        time.sleep(2)

    # Confirm env inside container (masked)
    _, o, _ = c.exec_command(
        f"echo {PASS!r} | sudo -S docker exec anylang-api-1 "
        "printenv TRANSLATION_PROVIDER OPENAI_MODEL ALLOW_MOCK_TRANSLATION",
        timeout=20,
    )
    print("container env:\n", o.read().decode())
    _, o, _ = c.exec_command(
        f"echo {PASS!r} | sudo -S docker exec anylang-api-1 "
        "sh -c 'printenv OPENAI_API_KEY | wc -c'",
        timeout=20,
    )
    print("openai key length chars:", o.read().decode().strip())

    c.close()

    # Direct OpenAI smoke (local)
    body = json.dumps(
        {
            "model": "gpt-4o-mini",
            "temperature": 0,
            "messages": [
                {
                    "role": "system",
                    "content": "Return ONLY the translation, nothing else.",
                },
                {
                    "role": "user",
                    "content": "Translate to Uzbek:\nHello, how are you?",
                },
            ],
        }
    ).encode()
    req = urllib.request.Request(
        "https://api.openai.com/v1/chat/completions",
        data=body,
        headers={
            "Authorization": f"Bearer {OPENAI}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=45) as r:
        data = json.loads(r.read().decode())
        text = data["choices"][0]["message"]["content"]
        print("OpenAI smoke translation:", text)

    print("DONE")


if __name__ == "__main__":
    main()
