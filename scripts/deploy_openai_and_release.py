"""Deploy OpenAI translation + API, install release APK. Key via OPENAI_API_KEY env."""
from __future__ import annotations

import os
import subprocess
from pathlib import Path

import paramiko

ROOT = Path(r"E:\Anylang")
PASS = os.environ["ANYLANG_SSH_PASS"]
OPENAI = os.environ["OPENAI_API_KEY"]
REMOTE = "/home/admin_root/anylang"
ADB = Path(os.environ["LOCALAPPDATA"]) / "Android" / "Sdk" / "platform-tools" / "adb.exe"
FLUTTER = Path(r"C:\Users\alocomputers\AppData\Local\flutter\bin\flutter.bat")


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 900) -> str:
    _, out, err = c.exec_command(f"echo {PASS!r} | sudo -S bash -lc {cmd!r}", timeout=timeout)
    text = (out.read() + err.read()).decode(errors="replace")
    print(text[-3000:].encode("ascii", "replace").decode("ascii"))
    return text


def main() -> None:
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect("87.192.230.208", 2222, "admin_root", PASS)
    sftp = c.open_sftp()
    for rel in [
        "backend/app/integrations/translation.py",
        "backend/app/core/config.py",
        "backend/app/core/startup.py",
        "deploy/env.production.template",
    ]:
        sftp.put(str(ROOT / rel), f"{REMOTE}/{rel}")
        print("put", rel)
    sftp.close()

    # Upsert OpenAI settings into .env without printing the key
    py = f"""
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
print('env updated')
"""
    sftp = c.open_sftp()
    with sftp.file("/tmp/patch_openai_env.py", "w") as f:
        f.write(py)
    sftp.close()
    sudo(c, "python3 /tmp/patch_openai_env.py")
    sudo(
        c,
        "cd /home/admin_root/anylang/deploy && docker compose -f docker-compose.prod.yml --env-file .env up -d --build api worker",
        timeout=900,
    )
    # smoke translate path via register is heavy; hit health + ready
    sudo(c, "curl -sS https://anylang.uz/health; echo; curl -sS https://anylang.uz/ready || curl -sS http://127.0.0.1:8105/ready")
    c.close()

    phone = subprocess.check_output([str(ADB), "devices"], text=True)
    print(phone)
    serial = next((l.split()[0] for l in phone.splitlines() if "\tdevice" in l), None)
    if not serial:
        print("No phone — skipping APK install")
        return
    env = os.environ.copy()
    env["PATH"] = r"C:\Users\alocomputers\AppData\Local\flutter\bin;" + env.get("PATH", "")
    app = ROOT / "Anylang"
    subprocess.check_call(
        [str(FLUTTER), "build", "apk", "--release", "--dart-define=API_BASE_URL=https://anylang.uz/"],
        cwd=str(app),
        env=env,
    )
    apk = app / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"
    subprocess.check_call([str(ADB), "-s", serial, "install", "-r", str(apk)])
    subprocess.check_call(
        [str(ADB), "-s", serial, "shell", "am", "start", "-n", "com.izodev.anylang/.MainActivity"]
    )
    print("DONE")


if __name__ == "__main__":
    main()
