"""Deploy landing + admin basePath + nginx (anylang.uz only)."""
from __future__ import annotations

import os
import tarfile
import tempfile
from pathlib import Path

import paramiko

ROOT = Path(r"E:\Anylang")
HOST = "87.192.230.208"
PORT = 2222
USER = "admin_root"
REMOTE = "/home/admin_root/anylang"
PASS = os.environ["ANYLANG_SSH_PASS"]

UPLOAD_DIRS = [
    "landing",
    "admin",
    "deploy",
]

EXCLUDE_PARTS = {
    "node_modules",
    ".next",
    ".git",
    "__pycache__",
    ".venv",
    "venv",
    "dist",
    "coverage",
}


def tar_filter(tarinfo: tarfile.TarInfo) -> tarfile.TarInfo | None:
    parts = set(Path(tarinfo.name).parts)
    if parts & EXCLUDE_PARTS:
        return None
    return tarinfo


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 600) -> str:
    full = f"echo {PASS!r} | sudo -S bash -lc {cmd!r}"
    _, out, err = c.exec_command(full, timeout=timeout)
    o = out.read().decode(errors="replace")
    e = err.read().decode(errors="replace")
    text = (o + e).strip()
    safe = (text[-2500:] if len(text) > 2500 else text).encode("ascii", "replace").decode("ascii")
    print(safe)
    return text


def main() -> None:
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, PORT, USER, PASS)

    with tempfile.NamedTemporaryFile(suffix=".tar.gz", delete=False) as tmp:
        tar_path = tmp.name
    with tarfile.open(tar_path, "w:gz") as tar:
        for d in UPLOAD_DIRS:
            tar.add(ROOT / d, arcname=d, filter=tar_filter)

    print("Uploading bundle...")
    sftp = c.open_sftp()
    sftp.put(tar_path, "/tmp/anylang-landing-deploy.tgz")
    sftp.put(
        str(ROOT / "scripts" / "patch_landing_nginx.py"),
        "/tmp/patch_landing_nginx.py",
    )
    sftp.put(
        str(ROOT / "scripts" / "patch_apk_download_nginx.py"),
        "/tmp/patch_apk_download_nginx.py",
    )
    sftp.close()
    os.unlink(tar_path)

    sudo(c, f"mkdir -p {REMOTE} && tar -xzf /tmp/anylang-landing-deploy.tgz -C {REMOTE}")
    sudo(
        c,
        "mkdir -p /var/www/anylang /var/www/anylang-apk && "
        "rsync -a --delete /home/admin_root/anylang/landing/ /var/www/anylang/ "
        "&& chown -R www-data:www-data /var/www/anylang /var/www/anylang-apk "
        "&& chmod -R a+rX /var/www/anylang && chmod 755 /var/www/anylang-apk",
    )
    sudo(c, "python3 /tmp/patch_landing_nginx.py")
    sudo(c, "python3 /tmp/patch_apk_download_nginx.py")
    sudo(c, "nginx -t && systemctl reload nginx")
    print("\n=== Rebuild admin ===")
    sudo(
        c,
        f"cd {REMOTE}/deploy && docker compose -f docker-compose.prod.yml --env-file .env up -d --build admin",
        timeout=900,
    )
    print("\n=== Verify ===")
    for cmd in [
        "curl -sS -o /dev/null -w '%{http_code}' https://anylang.uz/",
        "curl -sS -o /dev/null -w '%{http_code}' https://anylang.uz/admin/login",
        "curl -sS -o /dev/null -w '%{http_code}' https://anylang.uz/health",
        "curl -sS https://anylang.uz/ | head -c 200",
    ]:
        print(f"\n> {cmd}")
        sudo(c, cmd)

    c.close()
    print("\nDONE")


if __name__ == "__main__":
    main()
