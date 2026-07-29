#!/usr/bin/env python3
"""Create release keystore + android/key.properties (gitignored). Never commit these."""
from __future__ import annotations

import os
import secrets
import string
import subprocess
import sys
from pathlib import Path

ANDROID = Path(r"E:\Anylang\Anylang\android")
KEYSTORE_DIR = ANDROID / "keystore"
STORE_FILE = KEYSTORE_DIR / "anylang-release.jks"
PROPS = ANDROID / "key.properties"
ALIAS = "anylang"


def _keytool() -> str:
    candidates = [
        Path(r"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe"),
        Path(os.environ.get("JAVA_HOME", "")) / "bin" / "keytool.exe",
    ]
    for p in candidates:
        if p.is_file():
            return str(p)
    which = subprocess.run(["where", "keytool"], capture_output=True, text=True)
    if which.returncode == 0 and which.stdout.strip():
        return which.stdout.strip().splitlines()[0]
    raise SystemExit("keytool not found — install JDK / Android Studio JBR")


def _password(n: int = 32) -> str:
    alphabet = string.ascii_letters + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(n))


def main() -> int:
    if STORE_FILE.exists() and PROPS.exists():
        print("Release keystore already exists:", STORE_FILE)
        print("key.properties:", PROPS)
        return 0

    KEYSTORE_DIR.mkdir(parents=True, exist_ok=True)
    store_pass = _password()
    key_pass = store_pass

    cmd = [
        _keytool(),
        "-genkeypair",
        "-v",
        "-keystore",
        str(STORE_FILE),
        "-storetype",
        "JKS",
        "-keyalg",
        "RSA",
        "-keysize",
        "2048",
        "-validity",
        "10000",
        "-alias",
        ALIAS,
        "-storepass",
        store_pass,
        "-keypass",
        key_pass,
        "-dname",
        "CN=AnyLang, OU=Mobile, O=IzoDev, L=Tashkent, ST=Tashkent, C=UZ",
    ]
    subprocess.check_call(cmd)

    # storeFile relative to android/app module (Gradle file()).
    PROPS.write_text(
        "\n".join(
            [
                f"storePassword={store_pass}",
                f"keyPassword={key_pass}",
                f"keyAlias={ALIAS}",
                "storeFile=../keystore/anylang-release.jks",
                "",
            ]
        ),
        encoding="utf-8",
    )
    print("Created", STORE_FILE)
    print("Created", PROPS)
    print(
        "IMPORTANT: backup keystore + key.properties offline. "
        "Lost key = cannot update same package."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
