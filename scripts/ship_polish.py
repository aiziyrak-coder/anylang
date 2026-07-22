import os
import subprocess
from pathlib import Path

import paramiko

ROOT = Path(r"E:\Anylang")
PASS = os.environ["ANYLANG_SSH_PASS"]
ADB = Path(os.environ["LOCALAPPDATA"]) / "Android" / "Sdk" / "platform-tools" / "adb.exe"
FLUTTER = Path(r"C:\Users\alocomputers\AppData\Local\flutter\bin\flutter.bat")


def main() -> None:
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect("87.192.230.208", 2222, "admin_root", PASS)
    sftp = c.open_sftp()
    files = [
        "backend/app/services/messages.py",
        "backend/app/models/product.py",
        "backend/app/integrations/translation.py",
    ]
    for rel in files:
        local = ROOT / rel
        if local.exists():
            sftp.put(str(local), f"/home/admin_root/anylang/{rel}")
            print("put", rel)
    sftp.close()

    def sudo(cmd, timeout=900):
        _, o, e = c.exec_command(f"echo {PASS!r} | sudo -S bash -lc {cmd!r}", timeout=timeout)
        print((o.read() + e.read()).decode(errors="replace")[-2000:].encode("ascii", "replace").decode())

    sudo(
        "cd /home/admin_root/anylang/deploy && docker compose -f docker-compose.prod.yml --env-file .env up -d --build api",
        timeout=900,
    )
    sudo("curl -sS http://127.0.0.1:8105/ready")
    c.close()

    env = os.environ.copy()
    env["PATH"] = r"C:\Users\alocomputers\AppData\Local\flutter\bin;" + env.get("PATH", "")
    app = ROOT / "Anylang"
    subprocess.check_call(
        [str(FLUTTER), "build", "apk", "--release", "--dart-define=API_BASE_URL=https://anylang.uz/"],
        cwd=str(app),
        env=env,
    )
    out = subprocess.check_output([str(ADB), "devices"], text=True)
    print(out)
    serial = next((l.split()[0] for l in out.splitlines() if "\tdevice" in l), None)
    apk = app / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"
    if serial:
        subprocess.check_call([str(ADB), "-s", serial, "install", "-r", str(apk)])
        subprocess.check_call(
            [str(ADB), "-s", serial, "shell", "am", "start", "-n", "com.izodev.anylang/.MainActivity"]
        )
        print("INSTALLED")
    else:
        print("APK ready at", apk, "- phone not connected")


if __name__ == "__main__":
    main()
