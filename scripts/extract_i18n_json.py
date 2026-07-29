#!/usr/bin/env python3
"""Extract uz/ru/en UI maps from language_localizations.dart → assets/i18n/*.json."""
from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(r"E:\Anylang")
DART = ROOT / "Anylang" / "lib" / "presentation" / "utils" / "language_localizations.dart"
OUT = ROOT / "Anylang" / "assets" / "i18n"


def extract_map(text: str, name: str) -> dict[str, str]:
    pat = rf"'{re.escape(name)}': \{{(.*?)\n    \}},"
    m = re.search(pat, text, re.S)
    if not m:
        raise SystemExit(f"map not found: {name}")
    body = m.group(1)
    out: dict[str, str] = {}
    for km in re.finditer(
        r"'((?:\\'|[^'])*)':\s*((?:'(?:\\'|[^'])*')|(?:\"(?:\\\"|[^\"])*\"))",
        body,
    ):
        key = km.group(1)
        raw = km.group(2)
        val = raw[1:-1]
        val = (
            val.replace("\\'", "'")
            .replace('\\"', '"')
            .replace("\\n", "\n")
            .replace("\\\\", "\\")
        )
        out[key] = val
    return out


def main() -> int:
    text = DART.read_text(encoding="utf-8")
    OUT.mkdir(parents=True, exist_ok=True)
    for name in ("uz_UZ", "ru_RU", "us_US"):
        data = extract_map(text, name)
        path = OUT / f"{name}.json"
        path.write_text(
            json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        print(name, len(data), "->", path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
