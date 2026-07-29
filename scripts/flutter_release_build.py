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


def read_maps_key() -> str:
    env_key = (os.environ.get("GOOGLE_MAPS_API_KEY") or "").strip()
    if env_key:
        return env_key
    props = APP / "android" / "local.properties"
    if props.exists():
        for line in props.read_text(encoding="utf-8").splitlines():
            s = line.strip()
            if s.startswith("GOOGLE_MAPS_API_KEY="):
                return s.split("=", 1)[1].strip()
    return ""


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
    return args
