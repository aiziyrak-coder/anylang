#!/usr/bin/env python3
"""Ensure /flags/ location exists on anylang.uz nginx."""
from __future__ import annotations

from pathlib import Path

PATH = Path("/etc/nginx/sites-available/anylang.uz")

BLOCK = """
    # Language / country flags (cached by clients)
    location /flags/ {
        alias /var/www/anylang-flags/;
        autoindex off;
        expires 30d;
        add_header Cache-Control "public, max-age=2592000" always;
        types { image/png png; }
        default_type image/png;
    }
"""


def main() -> int:
    text = PATH.read_text(encoding="utf-8")
    if "location /flags/" in text:
        print("flags location already present")
        return 0
    marker = "    # Android test APK"
    if marker not in text:
        marker = "    # Admin panel"
    if marker not in text:
        raise SystemExit("Cannot find insert point")
    PATH.write_text(text.replace(marker, BLOCK + "\n" + marker, 1), encoding="utf-8")
    print("patched nginx with /flags/")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
