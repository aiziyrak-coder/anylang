#!/usr/bin/env python3
"""Download language flags (flagcdn) and publish to https://anylang.uz/flags/."""
from __future__ import annotations

import os
import sys
import tempfile
import urllib.request
from pathlib import Path

import paramiko

ROOT = Path(r"E:\Anylang")
sys.path.insert(0, str(ROOT / "backend"))
from app.services.language_catalog import LANGUAGE_ROWS  # noqa: E402

PASS = os.environ["ANYLANG_SSH_PASS"]
HOST = os.environ.get("ANYLANG_SSH_HOST", "87.192.230.208")
REMOTE_DIR = "/var/www/anylang-flags"
NGINX_PATCH = """
    # Language / country flags (cached by clients)
    location /flags/ {
        alias /var/www/anylang-flags/;
        autoindex off;
        expires 30d;
        add_header Cache-Control "public, max-age=2592000" always;
        types { image/png png; }
        default_type image/png;
    }
"""


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 300) -> str:
    _, out, err = c.exec_command(
        f"echo {PASS!r} | sudo -S bash -lc {cmd!r}", timeout=timeout
    )
    text = (out.read() + err.read()).decode(errors="replace")
    print(text[-2000:] if len(text) > 2000 else text)
    return text


def main() -> int:
    countries = sorted({row[2].lower() for row in LANGUAGE_ROWS})
    tmp = Path(tempfile.mkdtemp(prefix="anylang-flags-"))
    print(f"Downloading {len(countries)} flags → {tmp}")
    for cc in countries:
        url = f"https://flagcdn.com/w160/{cc}.png"
        dest = tmp / f"{cc}.png"
        try:
            urllib.request.urlretrieve(url, dest)
            print(" OK", cc)
        except Exception as e:
            print(" FAIL", cc, e)

    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, 2222, "admin_root", PASS, timeout=30)
    sudo(c, f"mkdir -p {REMOTE_DIR}")

    sftp = c.open_sftp()
    for png in tmp.glob("*.png"):
        sftp.put(str(png), f"/tmp/anylang_flag_{png.name}")
    sftp.put(str(ROOT / "scripts" / "patch_flags_nginx.py"), "/tmp/patch_flags_nginx.py")
    sftp.close()

    sudo(
        c,
        f"mkdir -p {REMOTE_DIR} && "
        f"for f in /tmp/anylang_flag_*.png; do "
        f"bn=$(basename \"$f\"); cp \"$f\" {REMOTE_DIR}/${{bn#anylang_flag_}}; done && "
        f"chown -R www-data:www-data {REMOTE_DIR} && "
        f"chmod 644 {REMOTE_DIR}/*.png && "
        f"ls {REMOTE_DIR} | wc -l",
    )
    sudo(c, "python3 /tmp/patch_flags_nginx.py")
    sudo(c, "nginx -t && systemctl reload nginx")
    sudo(
        c,
        "curl -sS -o /dev/null -w 'uz:%{http_code} %{size_download}\\n' "
        "https://anylang.uz/flags/uz.png; "
        "curl -sS -o /dev/null -w 'gb:%{http_code} %{size_download}\\n' "
        "https://anylang.uz/flags/gb.png",
    )
    c.close()
    print("Published flags to https://anylang.uz/flags/")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
