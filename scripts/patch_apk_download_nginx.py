#!/usr/bin/env python3
"""Ensure /download/ APK locations exist on anylang.uz nginx (preserve SSL)."""
from __future__ import annotations

from pathlib import Path

PATH = Path("/etc/nginx/sites-available/anylang.uz")

BLOCK = """
    # Android test APK (Play Market chiqquncha)
    location /download/ {
        alias /var/www/anylang-apk/;
        autoindex off;
        types {
            application/vnd.android.package-archive apk;
            application/json json;
        }
        default_type application/octet-stream;
        add_header Cache-Control "public, max-age=60" always;
    }

    location = /download/anylang-latest.apk {
        alias /var/www/anylang-apk/anylang-latest.apk;
        default_type application/vnd.android.package-archive;
        add_header Content-Disposition 'attachment; filename="AnyLang.apk"' always;
        add_header Cache-Control "no-cache" always;
    }

    location = /download/latest.json {
        alias /var/www/anylang-apk/latest.json;
        default_type application/json;
        add_header Cache-Control "no-cache" always;
    }
"""


def main() -> int:
    text = PATH.read_text(encoding="utf-8")
    if "location = /download/anylang-latest.apk" in text:
        print("download locations already present")
        return 0

    marker = "    # Admin panel"
    if marker not in text:
        # fallback: after landing location /
        marker = "    location /admin"
        insert = BLOCK + "\n" + marker
        if marker not in text:
            raise SystemExit("Cannot find insert point in nginx conf")
        text = text.replace(marker, insert, 1)
    else:
        text = text.replace(marker, BLOCK + "\n" + marker, 1)

    PATH.write_text(text, encoding="utf-8")
    print("patched nginx with /download/")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
