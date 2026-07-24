#!/usr/bin/env python3
"""Deploy landing site + nginx /download/ for Android APK (no admin rebuild)."""
from __future__ import annotations

import os
import tarfile
import tempfile
from pathlib import Path

import paramiko

ROOT = Path(r"E:\Anylang")
HOST = os.environ.get("ANYLANG_SSH_HOST", "87.192.230.208")
PORT = 2222
USER = "admin_root"
PASS = os.environ["ANYLANG_SSH_PASS"]
REMOTE = "/home/admin_root/anylang"


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 300) -> str:
    _, out, err = c.exec_command(
        f"echo {PASS!r} | sudo -S bash -lc {cmd!r}", timeout=timeout
    )
    text = (out.read() + err.read()).decode(errors="replace")
    print(text[-2500:] if len(text) > 2500 else text)
    return text


def main() -> int:
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, PORT, USER, PASS, timeout=30)

    with tempfile.NamedTemporaryFile(suffix=".tar.gz", delete=False) as tmp:
        tar_path = tmp.name
    with tarfile.open(tar_path, "w:gz") as tar:
        tar.add(ROOT / "landing", arcname="landing")

    sftp = c.open_sftp()
    print("Uploading landing...")
    sftp.put(tar_path, "/tmp/anylang-landing-apk.tgz")
    sftp.put(
        str(ROOT / "scripts" / "patch_apk_download_nginx.py"),
        "/tmp/patch_apk_download_nginx.py",
    )
    sftp.close()
    os.unlink(tar_path)

    sudo(c, f"mkdir -p {REMOTE} && tar -xzf /tmp/anylang-landing-apk.tgz -C {REMOTE}")
    sudo(
        c,
        "mkdir -p /var/www/anylang /var/www/anylang-apk && "
        "rsync -a --delete /home/admin_root/anylang/landing/ /var/www/anylang/ && "
        "chown -R www-data:www-data /var/www/anylang /var/www/anylang-apk && "
        "chmod -R a+rX /var/www/anylang && chmod 755 /var/www/anylang-apk",
    )
    sudo(c, "python3 /tmp/patch_apk_download_nginx.py")
    sudo(c, "nginx -t && systemctl reload nginx")

    print("\n=== Verify landing ===")
    for cmd in [
        "curl -sS -o /dev/null -w 'home:%{http_code}\\n' https://anylang.uz/",
        "curl -sS https://anylang.uz/ | grep -o 'anylang-latest.apk' | head -1",
        "curl -sS -o /dev/null -w 'apk:%{http_code}\\n' https://anylang.uz/download/anylang-latest.apk",
        "curl -sS -o /dev/null -w 'json:%{http_code}\\n' https://anylang.uz/download/latest.json",
    ]:
        print(f"> {cmd}")
        sudo(c, cmd)

    c.close()
    print("DONE landing + /download/ nginx")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
