"""Build release APK and publish to https://anylang.uz/download/anylang-latest.apk"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

import paramiko

ROOT = Path(r"E:\Anylang")
APP = ROOT / "Anylang"
FLUTTER = Path(r"C:\Users\alocomputers\AppData\Local\flutter\bin\flutter.bat")
PASS = os.environ["ANYLANG_SSH_PASS"]
HOST = os.environ.get("ANYLANG_SSH_HOST", "87.192.230.208")
REMOTE_DIR = "/var/www/anylang-apk"
API_BASE = "https://anylang.uz/"


def sudo(c: paramiko.SSHClient, cmd: str, timeout: int = 300) -> str:
    _, out, err = c.exec_command(
        f"echo {PASS!r} | sudo -S bash -lc {cmd!r}", timeout=timeout
    )
    text = (out.read() + err.read()).decode(errors="replace")
    print(text[-2000:])
    return text


def read_version() -> tuple[str, int]:
    text = (APP / "pubspec.yaml").read_text(encoding="utf-8")
    m = re.search(r"^version:\s*([0-9.]+)\+(\d+)\s*$", text, re.M)
    if not m:
        raise SystemExit("Cannot parse version from pubspec.yaml")
    return m.group(1), int(m.group(2))


def build_apk() -> Path:
    env = os.environ.copy()
    env["PUB_CACHE"] = str(Path.home() / "AppData" / "Local" / "Pub" / "Cache")
    subprocess.check_call(
        [
            str(FLUTTER),
            "build",
            "apk",
            "--release",
            f"--dart-define=API_BASE_URL={API_BASE}",
        ],
        cwd=str(APP),
        env=env,
    )
    apk = APP / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"
    if not apk.exists():
        raise SystemExit(f"APK missing: {apk}")
    return apk


def main() -> int:
    skip_build = "--skip-build" in sys.argv
    ver, build = read_version()
    if skip_build:
        apk = APP / "build" / "app" / "outputs" / "flutter-apk" / "app-release.apk"
        if not apk.exists():
            print("No existing APK; building...")
            apk = build_apk()
        else:
            print("Using existing", apk)
    else:
        print(f"Building APK {ver}+{build} ...")
        apk = build_apk()

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
        "notes": "Play Market chiqquncha test release",
    }
    meta_path = ROOT / "landing" / "download-meta.json"
    meta_path.write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")

    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(HOST, 2222, "admin_root", PASS, timeout=30)

    sudo(c, f"mkdir -p {REMOTE_DIR} && chown www-data:www-data {REMOTE_DIR}")

    sftp = c.open_sftp()
    tmp_apk = f"/tmp/{versioned}"
    tmp_json = "/tmp/anylang-latest.json"
    print("Uploading APK...", size, "bytes")
    sftp.put(str(apk), tmp_apk)
    with sftp.file(tmp_json, "w") as f:
        f.write(json.dumps(meta, ensure_ascii=False, indent=2))
    sftp.close()

    sudo(
        c,
        f"cp {tmp_apk} {REMOTE_DIR}/{versioned} && "
        f"cp {tmp_apk} {REMOTE_DIR}/anylang-latest.apk && "
        f"cp {tmp_json} {REMOTE_DIR}/latest.json && "
        f"chown -R www-data:www-data {REMOTE_DIR} && "
        f"chmod 644 {REMOTE_DIR}/* && "
        f"ls -lh {REMOTE_DIR}",
    )
    # Keep landing meta in sync if site root exists
    landing_meta = ROOT / "landing" / "download-meta.json"
    if landing_meta.exists():
        tmp_landing = "/tmp/anylang-landing-meta.json"
        sftp2 = c.open_sftp()
        sftp2.put(str(landing_meta), tmp_landing)
        sftp2.close()
        sudo(
            c,
            f"cp {tmp_landing} /var/www/anylang/download-meta.json 2>/dev/null || true; "
            f"cp {tmp_json} /var/www/anylang/download-meta.json 2>/dev/null || true",
        )
    sudo(
        c,
        "curl -sS -o /dev/null -w 'apk:%{http_code} size:%{size_download}\\n' "
        "https://anylang.uz/download/anylang-latest.apk; "
        "curl -sS https://anylang.uz/download/latest.json",
        timeout=60,
    )
    c.close()
    print("Published:", meta["download_url"], meta["version_full"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
