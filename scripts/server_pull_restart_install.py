#!/usr/bin/env python3
"""Server: git pull + full stack rebuild/restart. Local: release APK install."""

from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

import paramiko

ROOT = Path(r"E:\Anylang")
PASS = os.environ["ANYLANG_SSH_PASS"]
HOST = os.environ.get("ANYLANG_SSH_HOST", "87.192.230.208")
REMOTE = "/home/admin_root/anylang"
ADB = Path(os.environ["LOCALAPPDATA"]) / "Android" / "Sdk" / "platform-tools" / "adb.exe"
FLUTTER = Path(r"C:\Users\alocomputers\AppData\Local\flutter\bin\flutter.bat")


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 1800) -> int:
    full = f"echo {PASS!r} | sudo -S bash -lc {cmd!r}"
    _, out, err = c.exec_command(full, timeout=timeout)
    text = (out.read() + err.read()).decode(errors="replace")
    code = out.channel.recv_exit_status()
    print(text[-4500:])
    print("exit", code)
    return code


def main() -> int:
    print("=== SERVER: git pull + rebuild/restart ===")
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, 2222, "admin_root", PASS, timeout=30)

    # Prefer git pull; if dirty/unavailable, still rebuild from synced tree.
    code = sudo(
        c,
        f"cd {REMOTE} && "
        "(git rev-parse --is-inside-work-tree >/dev/null 2>&1 && "
        "git fetch origin && git reset --hard origin/main && git pull --ff-only origin main "
        "|| echo 'GIT_SKIP') && "
        "grep -q '^OPENAI_TRANSLATION_MODEL=' deploy/.env "
        "|| echo 'OPENAI_TRANSLATION_MODEL=gpt-4o' >> deploy/.env; "
        "sed -i 's/^OPENAI_TRANSLATION_MODEL=.*/OPENAI_TRANSLATION_MODEL=gpt-4o/' deploy/.env; "
        "sed -i 's/^TRANSLATION_PROVIDER=.*/TRANSLATION_PROVIDER=openai/' deploy/.env",
    )
    if code != 0:
        print("env/git step non-zero, continuing")

    code = sudo(
        c,
        f"cd {REMOTE}/deploy && "
        "docker compose -f docker-compose.prod.yml --env-file .env up -d --build --force-recreate "
        "api worker admin",
        timeout=1800,
    )
    if code != 0:
        c.close()
        return code

    sudo(
        c,
        "sleep 8; curl -sS http://127.0.0.1:8105/health; echo; "
        "docker ps --filter name=anylang --format 'table {{.Names}}\\t{{.Status}}'; "
        f"cd {REMOTE} && (git log -1 --oneline || true)",
    )
    c.close()

    print("=== PHONE: build + install APK ===")
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
    phone = subprocess.check_output([str(ADB), "devices"], text=True)
    print(phone)
    serial = next((ln.split()[0] for ln in phone.splitlines() if "\tdevice" in ln), None)
    if not serial:
        print("No phone", file=sys.stderr)
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
    print("DONE", apk)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
