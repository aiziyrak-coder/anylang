#!/usr/bin/env python3
"""Full production ship: sync trees, pull, rebuild, migrate, APK publish + install."""

from __future__ import annotations

import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

import paramiko

ROOT = Path(r"E:\Anylang")
PASS = os.environ["ANYLANG_SSH_PASS"]
HOST = os.environ.get("ANYLANG_SSH_HOST", "87.192.230.208")
REMOTE = "/home/admin_root/anylang"
ADB = Path(os.environ["LOCALAPPDATA"]) / "Android" / "Sdk" / "platform-tools" / "adb.exe"
FLUTTER = Path(r"C:\Users\alocomputers\AppData\Local\flutter\bin\flutter.bat")
APP = ROOT / "Anylang"
APK_REMOTE = "/var/www/anylang-apk"

SYNC_DIRS = [
    "backend/app",
    "backend/alembic",
    "admin/src",
    "admin/public",
    "landing",
    "deploy",
]
SYNC_FILES = [
    "backend/requirements.txt",
    "backend/Dockerfile",
    "backend/alembic.ini",
    "admin/package.json",
    "admin/Dockerfile",
    "admin/next.config.ts",
    "admin/next.config.js",
    "admin/tsconfig.json",
]


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 1800) -> tuple[int, str]:
    full = f"echo {PASS!r} | sudo -S bash -lc {cmd!r}"
    _, out, err = c.exec_command(full, timeout=timeout)
    text = (out.read() + err.read()).decode(errors="replace")
    code = out.channel.recv_exit_status()
    print(text[-5000:])
    print("exit", code)
    return code, text


def ensure_remote_dir(sftp: paramiko.SFTPClient, remote: str) -> None:
    parts = remote.strip("/").split("/")
    cur = ""
    for p in parts:
        cur += "/" + p
        try:
            sftp.stat(cur)
        except OSError:
            try:
                sftp.mkdir(cur)
            except OSError:
                pass


def put_file(sftp: paramiko.SFTPClient, local: Path, remote: str) -> None:
    ensure_remote_dir(sftp, str(Path(remote).parent).replace("\\", "/"))
    sftp.put(str(local), remote)


def sync_tree(sftp: paramiko.SFTPClient, rel: str) -> int:
    base = ROOT / rel
    n = 0
    if not base.exists():
        print("skip missing", rel)
        return 0
    if base.is_file():
        put_file(sftp, base, f"{REMOTE}/{rel.replace(chr(92), '/')}")
        return 1
    for item in base.rglob("*"):
        if not item.is_file():
            continue
        if item.suffix in {".pyc", ".pyo"} or "__pycache__" in item.parts:
            continue
        if item.name in {".env", ".env.local"}:
            continue
        if ".next" in item.parts or "node_modules" in item.parts:
            continue
        rel_path = item.relative_to(ROOT).as_posix()
        put_file(sftp, item, f"{REMOTE}/{rel_path}")
        n += 1
    return n


def read_version() -> tuple[str, int]:
    import re

    text = (APP / "pubspec.yaml").read_text(encoding="utf-8")
    m = re.search(r"^version:\s*([0-9.]+)\+(\d+)\s*$", text, re.M)
    if not m:
        raise SystemExit("Cannot parse version")
    return m.group(1), int(m.group(2))


def main() -> int:
    print("=== 1) SSH connect + sync ===")
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, 2222, "admin_root", PASS, timeout=30)
    sftp = c.open_sftp()
    total = 0
    for d in SYNC_DIRS:
        n = sync_tree(sftp, d)
        print(f"synced {d}: {n}")
        total += n
    for f in SYNC_FILES:
        local = ROOT / f
        if local.exists():
            put_file(sftp, local, f"{REMOTE}/{f}")
            total += 1
            print("put", f)
    sftp.close()
    print("uploaded", total)

    print("=== 2) git pull (best effort) + rebuild ===")
    sudo(
        c,
        f"cd {REMOTE} && "
        "(git rev-parse --is-inside-work-tree >/dev/null 2>&1 && "
        "git fetch origin && git reset --hard origin/main || echo GIT_SKIP) || echo NO_GIT",
    )
    code, _ = sudo(
        c,
        f"cd {REMOTE}/deploy && "
        "docker compose -f docker-compose.prod.yml --env-file .env up -d --build --force-recreate "
        "api worker admin",
        timeout=2400,
    )
    if code != 0:
        print("admin rebuild failed; retry api+worker")
        code, _ = sudo(
            c,
            f"cd {REMOTE}/deploy && "
            "docker compose -f docker-compose.prod.yml --env-file .env up -d --build --force-recreate "
            "api worker",
            timeout=2400,
        )
        if code != 0:
            c.close()
            return code

    print("=== 3) migrations + health ===")
    sudo(
        c,
        "docker exec anylang-api-1 alembic upgrade head || "
        "docker exec anylang-api-1 python -m alembic upgrade head || true",
        timeout=600,
    )
    sudo(
        c,
        "sleep 6; curl -sS http://127.0.0.1:8105/health; echo; "
        "curl -sS -o /dev/null -w 'public_health:%{http_code}\\n' https://anylang.uz/health; "
        "docker ps --filter name=anylang --format 'table {{.Names}}\\t{{.Status}}'",
    )

    print("=== 4) landing sync ===")
    sudo(
        c,
        "mkdir -p /var/www/anylang /var/www/anylang-apk && "
        f"rsync -a --delete {REMOTE}/landing/ /var/www/anylang/ && "
        "chown -R www-data:www-data /var/www/anylang /var/www/anylang-apk && "
        "chmod -R a+rX /var/www/anylang && chmod 755 /var/www/anylang-apk",
    )
    c.close()

    print("=== 5) Flutter release APK ===")
    ver, build = read_version()
    env = os.environ.copy()
    env["PATH"] = r"C:\Users\alocomputers\AppData\Local\flutter\bin;" + env.get("PATH", "")
    env["PUB_CACHE"] = str(Path.home() / "AppData" / "Local" / "Pub" / "Cache")
    subprocess.check_call(
        [
            str(FLUTTER),
            "build",
            "apk",
            "--release",
            "--dart-define=API_BASE_URL=https://anylang.uz/",
        ],
        cwd=str(APP),
        env=env,
    )
    apk = APP / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"
    if not apk.exists():
        print("APK missing", apk)
        return 1

    print("=== 6) Publish APK to download ===")
    size = apk.stat().st_size
    versioned = f"anylang-{ver}+{build}.apk"
    meta = {
        "version": ver,
        "build": build,
        "version_full": f"{ver}+{build}",
        "filename": "anylang-latest.apk",
        "versioned_filename": versioned,
        "size_bytes": size,
        "size_mb": round(size / (1024 * 1024), 2),
        "updated_at": datetime.now(timezone.utc).isoformat(),
        "download_url": "https://anylang.uz/download/anylang-latest.apk",
        "package": "com.izodev.anylang",
        "notes": f"Release {ver}+{build} — faster Live speech (Uzbek STT) + translation",
    }
    meta_path = ROOT / "landing" / "download-meta.json"
    meta_path.write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")

    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, 2222, "admin_root", PASS, timeout=30)
    sudo(c, f"mkdir -p {APK_REMOTE} && chown www-data:www-data {APK_REMOTE}")
    sftp = c.open_sftp()
    tmp_apk = f"/tmp/{versioned}"
    tmp_json = "/tmp/anylang-latest.json"
    print("Uploading APK", size, "bytes")
    sftp.put(str(apk), tmp_apk)
    with sftp.file(tmp_json, "w") as f:
        f.write(json.dumps(meta, ensure_ascii=False, indent=2))
    sftp.put(str(meta_path), "/tmp/anylang-landing-meta.json")
    sftp.close()
    sudo(
        c,
        f"cp {tmp_apk} {APK_REMOTE}/{versioned} && "
        f"cp {tmp_apk} {APK_REMOTE}/anylang-latest.apk && "
        f"cp {tmp_json} {APK_REMOTE}/latest.json && "
        "cp /tmp/anylang-landing-meta.json /var/www/anylang/download-meta.json && "
        f"chown -R www-data:www-data {APK_REMOTE} /var/www/anylang/download-meta.json && "
        f"chmod 644 {APK_REMOTE}/* && "
        f"ls -lh {APK_REMOTE}",
    )
    sudo(
        c,
        "curl -sS -o /dev/null -w 'apk:%{http_code} size:%{size_download}\\n' "
        "https://anylang.uz/download/anylang-latest.apk; "
        "curl -sS https://anylang.uz/download/latest.json; echo",
    )

    print("=== 7) Install on phone ===")
    phone = subprocess.check_output([str(ADB), "devices"], text=True)
    print(phone)
    serial = next((ln.split()[0] for ln in phone.splitlines() if "\tdevice" in ln), None)
    if serial:
        subprocess.check_call([str(ADB), "-s", serial, "install", "-r", str(apk)])
        subprocess.check_call(
            [
                str(ADB),
                "-s",
                serial,
                "shell",
                "am",
                "start",
                "-n",
                "com.izodev.anylang/.MainActivity",
            ]
        )
        print("installed on", serial)
    else:
        print("No phone connected — APK published only")

    c.close()
    print(f"DONE version={ver}+{build} url=https://anylang.uz/download/anylang-latest.apk")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
