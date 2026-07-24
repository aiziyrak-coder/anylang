#!/usr/bin/env python3
"""Full production sync (backend) + release APK install on connected phone."""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

import paramiko

ROOT = Path(r"E:\Anylang")
PASS = os.environ.get("ANYLANG_SSH_PASS", "")
HOST = os.environ.get("ANYLANG_SSH_HOST", "87.192.230.208")
REMOTE = "/home/admin_root/anylang"
ADB = Path(os.environ["LOCALAPPDATA"]) / "Android" / "Sdk" / "platform-tools" / "adb.exe"
FLUTTER = Path(r"C:\Users\alocomputers\AppData\Local\flutter\bin\flutter.bat")

# Sync these trees fully (preserves remote .env / secrets).
SYNC_DIRS = [
    "backend/app",
    "backend/alembic",
    "deploy",
]

SYNC_FILES = [
    "backend/requirements.txt",
    "backend/Dockerfile",
    "backend/alembic.ini",
    "admin/package.json",
    "admin/src/app/dashboard/products/page.tsx",
    "admin/src/lib/i18n/uz.ts",
]


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 1200) -> tuple[int, str]:
    full = f"echo {PASS!r} | sudo -S bash -lc {cmd!r}"
    _, out, err = c.exec_command(full, timeout=timeout)
    text = (out.read() + err.read()).decode(errors="replace")
    code = out.channel.recv_exit_status()
    print(text[-4000:])
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
        rel_path = item.relative_to(ROOT).as_posix()
        put_file(sftp, item, f"{REMOTE}/{rel_path}")
        n += 1
    return n


def bump_version() -> str:
    pubspec = ROOT / "Anylang" / "pubspec.yaml"
    text = pubspec.read_text(encoding="utf-8")
    # 1.0.21+22 -> 1.0.22+23
    import re

    m = re.search(r"^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)", text, re.M)
    if not m:
        raise SystemExit("version not found in pubspec.yaml")
    major, minor, patch, build = map(int, m.groups())
    patch += 1
    build += 1
    new = f"{major}.{minor}.{patch}+{build}"
    text = re.sub(r"^version:\s*.*$", f"version: {new}", text, count=1, flags=re.M)
    pubspec.write_text(text, encoding="utf-8")
    print("version ->", new)
    return new


def main() -> int:
    if not PASS:
        print("Set ANYLANG_SSH_PASS", file=sys.stderr)
        return 1
    if not ADB.exists():
        print("adb missing:", ADB, file=sys.stderr)
        return 1
    if not FLUTTER.exists():
        print("flutter missing:", FLUTTER, file=sys.stderr)
        return 1

    print("=== 1) Sync backend to server ===")
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, 2222, "admin_root", PASS, timeout=30)
    sftp = c.open_sftp()
    total = 0
    for d in SYNC_DIRS:
        n = sync_tree(sftp, d)
        print(f"synced {d}: {n} files")
        total += n
    for f in SYNC_FILES:
        local = ROOT / f
        if local.exists():
            put_file(sftp, local, f"{REMOTE}/{f}")
            total += 1
            print("put", f)
    sftp.close()
    print("total uploaded", total)

    print("=== 2) Ensure translation env + language sync + rebuild ===")
    sudo(
        c,
        "grep -q '^OPENAI_TRANSLATION_MODEL=' /home/admin_root/anylang/deploy/.env "
        "|| echo 'OPENAI_TRANSLATION_MODEL=gpt-4o' >> /home/admin_root/anylang/deploy/.env; "
        "sed -i 's/^OPENAI_TRANSLATION_MODEL=.*/OPENAI_TRANSLATION_MODEL=gpt-4o/' "
        "/home/admin_root/anylang/deploy/.env; "
        "grep -q '^TRANSLATION_PROVIDER=' /home/admin_root/anylang/deploy/.env "
        "|| echo 'TRANSLATION_PROVIDER=openai' >> /home/admin_root/anylang/deploy/.env; "
        "sed -i 's/^TRANSLATION_PROVIDER=.*/TRANSLATION_PROVIDER=openai/' "
        "/home/admin_root/anylang/deploy/.env",
    )
    # app_language = native_language sync (us/gb → en)
    sudo(
        c,
        "docker exec anylang-postgres-1 psql -U anylang -d anylang -v ON_ERROR_STOP=1 "
        "-c \"UPDATE users SET native_language = CASE "
        "WHEN lower(split_part(COALESCE(app_language, native_language), '_', 1)) IN ('us','gb','eng') THEN 'en' "
        "ELSE lower(split_part(COALESCE(app_language, native_language), '_', 1)) END "
        "WHERE app_language IS NOT NULL AND btrim(app_language) <> '';\"",
    )
    code, _ = sudo(
        c,
        "cd /home/admin_root/anylang/deploy && "
        "docker compose -f docker-compose.prod.yml --env-file .env up -d --build api worker admin",
        timeout=1800,
    )
    if code != 0:
        # admin optional
        print("full stack build failed; retrying api+worker only")
        code, _ = sudo(
            c,
            "cd /home/admin_root/anylang/deploy && "
            "docker compose -f docker-compose.prod.yml --env-file .env up -d --build api worker",
            timeout=1800,
        )
        if code != 0:
            c.close()
            return code

    print("=== 3) Health checks ===")
    sudo(
        c,
        "sleep 8; curl -sS http://127.0.0.1:8105/health; echo; "
        "docker ps --filter name=anylang --format 'table {{.Names}}\t{{.Status}}'",
    )
    c.close()

    print("=== 4) Bump version + build APK ===")
    ver = bump_version()
    env = os.environ.copy()
    env["PATH"] = r"C:\Users\alocomputers\AppData\Local\flutter\bin;" + env.get("PATH", "")
    app = ROOT / "Anylang"
    subprocess.check_call(
        [
            str(FLUTTER),
            "build",
            "apk",
            "--release",
            "--dart-define=API_BASE_URL=https://anylang.uz/",
        ],
        cwd=str(app),
        env=env,
    )
    apk = app / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"
    if not apk.exists():
        print("APK missing", apk, file=sys.stderr)
        return 1

    print("=== 5) Install on phone ===")
    phone = subprocess.check_output([str(ADB), "devices"], text=True)
    print(phone)
    serial = next((ln.split()[0] for ln in phone.splitlines() if "\tdevice" in ln), None)
    if not serial:
        print("No phone connected", file=sys.stderr)
        return 1
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
    print(f"DONE version={ver} apk={apk}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
