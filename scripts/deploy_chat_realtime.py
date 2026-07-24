"""Deploy chat realtime WS fix (nginx + API) and verify /ws."""
from __future__ import annotations

import os
from pathlib import Path

import paramiko

ROOT = Path(r"E:\Anylang")
PASS = os.environ["ANYLANG_SSH_PASS"]
REMOTE = "/home/admin_root/anylang"
HOST = "87.192.230.208"
PORT = 2222
USER = "admin_root"


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 900) -> str:
    _, out, err = c.exec_command(
        f"echo {PASS!r} | sudo -S bash -lc {cmd!r}", timeout=timeout
    )
    text = (out.read() + err.read()).decode(errors="replace")
    print(text[-3000:].encode("ascii", "replace").decode("ascii"))
    return text


def main() -> None:
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, PORT, USER, PASS)

    files = [
        "backend/app/ws/endpoint.py",
        "backend/app/ws/presence.py",
        "backend/app/services/messages.py",
        "deploy/nginx/anylang.uz.conf",
    ]
    sftp = c.open_sftp()
    for rel in files:
        local = ROOT / rel
        remote = f"{REMOTE}/{rel.replace(chr(92), '/')}"
        print("put", rel)
        sftp.put(str(local), remote)
    sftp.close()

    sudo(
        c,
        "cp /home/admin_root/anylang/deploy/nginx/anylang.uz.conf "
        "/etc/nginx/sites-available/anylang.uz && "
        "nginx -t && systemctl reload nginx",
        timeout=60,
    )
    sudo(
        c,
        "cd /home/admin_root/anylang/deploy && "
        "docker compose -f docker-compose.prod.yml --env-file .env up -d --build api",
        timeout=900,
    )
    sudo(
        c,
        "sleep 2; "
        "curl -sS -o /dev/null -w 'local_ws:%{http_code}\\n' "
        "-H 'Connection: Upgrade' -H 'Upgrade: websocket' "
        "-H 'Sec-WebSocket-Version: 13' -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' "
        "http://127.0.0.1:8105/ws; "
        "curl -sS -o /dev/null -w 'public_ws_slash:%{http_code}\\n' "
        "-H 'Connection: Upgrade' -H 'Upgrade: websocket' "
        "-H 'Sec-WebSocket-Version: 13' -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' "
        "https://anylang.uz/ws/; "
        "curl -sS http://127.0.0.1:8105/health",
        timeout=60,
    )
    c.close()
    print("DONE")


if __name__ == "__main__":
    main()
