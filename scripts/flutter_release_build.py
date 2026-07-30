"""Flutter release APK build flags (obfuscation + defines)."""
from __future__ import annotations

import os
from pathlib import Path

ROOT = Path(r"E:\Anylang")
APP = ROOT / "Anylang"
DEFAULT_FLUTTER = Path(
    r"C:\Users\alocomputers\AppData\Local\flutter\bin\flutter.bat"
)
DEBUG_INFO_DIR = APP / "build" / "debug-info"


def _read_dotenv_key(name: str) -> str:
    """Read KEY=value from Anylang/.env (optional local secrets)."""
    env_file = APP / ".env"
    if not env_file.exists():
        return ""
    for line in env_file.read_text(encoding="utf-8").splitlines():
        s = line.strip()
        if not s or s.startswith("#") or "=" not in s:
            continue
        k, v = s.split("=", 1)
        if k.strip() == name:
            return v.strip().strip('"').strip("'")
    return ""


def read_maps_key() -> str:
    env_key = (os.environ.get("GOOGLE_MAPS_API_KEY") or "").strip()
    if env_key:
        return env_key
    from_env = _read_dotenv_key("GOOGLE_MAPS_API_KEY")
    if from_env:
        return from_env
    props = APP / "android" / "local.properties"
    if props.exists():
        for line in props.read_text(encoding="utf-8").splitlines():
            s = line.strip()
            if s.startswith("GOOGLE_MAPS_API_KEY="):
                return s.split("=", 1)[1].strip()
    return ""


def read_google_server_client_id() -> str:
    """Web OAuth client ID for Google Sign-In idToken (serverClientId)."""
    env_key = (os.environ.get("GOOGLE_SERVER_CLIENT_ID") or "").strip()
    if env_key:
        return env_key
    return _read_dotenv_key("GOOGLE_SERVER_CLIENT_ID")


def flutter_release_apk_args(
    *,
    api_base: str = "https://anylang.uz/",
    flutter: Path | None = None,
    obfuscate: bool = True,
) -> list[str]:
    """Production APK: R8 (Gradle) + Dart --obfuscate + split-debug-info."""
    args = [
        str(flutter or DEFAULT_FLUTTER),
        "build",
        "apk",
        "--release",
        f"--dart-define=API_BASE_URL={api_base}",
    ]
    if obfuscate:
        DEBUG_INFO_DIR.mkdir(parents=True, exist_ok=True)
        args.extend(
            [
                "--obfuscate",
                f"--split-debug-info={DEBUG_INFO_DIR}",
            ]
        )
    maps_key = read_maps_key()
    if maps_key:
        args.append(f"--dart-define=GOOGLE_MAPS_API_KEY={maps_key}")
    google_client = read_google_server_client_id()
    if google_client:
        args.append(f"--dart-define=GOOGLE_SERVER_CLIENT_ID={google_client}")
    return args
