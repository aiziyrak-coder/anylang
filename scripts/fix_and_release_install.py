"""Deploy API email/OTP fix + install release APK on phone."""
from __future__ import annotations

import os
import subprocess
import tarfile
import tempfile
from pathlib import Path

import paramiko

ROOT = Path(r"E:\Anylang")
PASS = os.environ["ANYLANG_SSH_PASS"]
REMOTE = "/home/admin_root/anylang"
ADB = Path(os.environ["LOCALAPPDATA"]) / "Android" / "Sdk" / "platform-tools" / "adb.exe"
FLUTTER = Path(r"C:\Users\alocomputers\AppData\Local\flutter\bin\flutter.bat")


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 900) -> str:
    _, out, err = c.exec_command(f"echo {PASS!r} | sudo -S bash -lc {cmd!r}", timeout=timeout)
    text = (out.read() + err.read()).decode(errors="replace")
    print(text[-2500:].encode("ascii", "replace").decode("ascii"))
    return text


def deploy_api() -> None:
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect("87.192.230.208", 2222, "admin_root", PASS)

    files = [
        "backend/app/integrations/email.py",
        "backend/app/services/otp.py",
        "backend/app/services/auth.py",
        "backend/app/schemas/auth.py",
        "backend/app/core/config.py",
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
        "cd /home/admin_root/anylang/deploy && "
        "sed -i 's/^ALLOW_OTP_IN_RESPONSE=.*/ALLOW_OTP_IN_RESPONSE=false/' .env; "
        "sed -i 's/^SMTP_FAIL_OPEN=.*/SMTP_FAIL_OPEN=false/' .env; "
        "grep -q '^ALLOW_OTP_IN_RESPONSE=' .env || echo 'ALLOW_OTP_IN_RESPONSE=false' >> .env; "
        "grep -q '^SMTP_FAIL_OPEN=' .env || echo 'SMTP_FAIL_OPEN=false' >> .env; "
        "grep -q '^ADMIN_SECRET_KEY=' .env || "
        "echo \"ADMIN_SECRET_KEY=$(openssl rand -base64 48)\" >> .env",
    )
    sudo(
        c,
        "cd /home/admin_root/anylang/deploy && docker compose -f docker-compose.prod.yml --env-file .env up -d --build api",
        timeout=900,
    )
    c.close()


def install_release() -> None:
    phone = subprocess.check_output([str(ADB), "devices"], text=True)
    print(phone)
    serial = None
    for line in phone.splitlines():
        if "\tdevice" in line:
            serial = line.split()[0]
            break
    if not serial:
        raise SystemExit("No phone connected")

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
    subprocess.check_call([str(ADB), "-s", serial, "install", "-r", str(apk)])
    subprocess.check_call(
        [str(ADB), "-s", serial, "shell", "am", "start", "-n", "com.izodev.anylang/.MainActivity"]
    )
    print("RELEASE INSTALLED")


if __name__ == "__main__":
    print("=== deploy api ===")
    deploy_api()
    print("=== install release ===")
    install_release()
