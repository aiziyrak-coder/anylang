#!/usr/bin/env python3
"""Generate UI i18n JSON for all locales via OpenAI (parallel batches)."""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

import httpx
import paramiko

ROOT = Path(r"E:\Anylang")
OUT = ROOT / "Anylang" / "assets" / "i18n"
DONE = ROOT / "scripts" / "_i18n_done"
sys.path.insert(0, str(ROOT / "scripts"))
from ui_locale_catalog import (  # noqa: E402
    EXTRA_LANG_NAME_EN,
    EXTRA_LANG_NAME_RU,
    EXTRA_LANG_NAME_UZ,
    OPENAI_LANG_NAME,
    UI_LOCALES,
)

BATCH = 90
MODEL = "gpt-4o-mini"
WORKERS = 6


def fetch_openai_key() -> str:
    env_key = os.environ.get("OPENAI_API_KEY", "").strip()
    if env_key:
        return env_key
    passwd = os.environ.get("ANYLANG_SSH_PASS", "")
    if not passwd:
        raise SystemExit("OPENAI_API_KEY or ANYLANG_SSH_PASS required")
    c = paramiko.SSHClient()
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect("87.192.230.208", 2222, "admin_root", passwd, timeout=25)
    cmd = (
        "grep -E '^OPENAI_API_KEY=' /home/admin_root/anylang/deploy/.env "
        "| head -1 | cut -d= -f2-"
    )
    _, out, err = c.exec_command(
        f"echo {passwd!r} | sudo -S bash -lc {cmd!r}",
        timeout=30,
    )
    stdout = out.read().decode(errors="replace")
    _ = err.read()  # sudo password noise
    c.close()
    key = ""
    for line in stdout.splitlines():
        line = line.strip().strip('"').strip("'")
        if line.startswith("sk-"):
            key = line
            break
    if not key:
        raise SystemExit("failed to read OPENAI_API_KEY from server")
    return key


def load_json(name: str) -> dict[str, str]:
    return json.loads((OUT / f"{name}.json").read_text(encoding="utf-8"))


def save_json(name: str, data: dict[str, str]) -> None:
    path = OUT / f"{name}.json"
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def write_index() -> None:
    locales = []
    for lang, code, language, country, aliases in UI_LOCALES:
        locales.append(
            {
                "lang": lang,
                "code": code,
                "language": language,
                "country": country,
                "aliases": aliases,
            }
        )
    (OUT / "index.json").write_text(
        json.dumps({"locales": locales}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )


def patch_base_lang_names() -> dict[str, str]:
    uz = load_json("uz_UZ")
    ru = load_json("ru_RU")
    en = load_json("us_US")
    uz.update(EXTRA_LANG_NAME_UZ)
    ru.update(EXTRA_LANG_NAME_RU)
    en.update(EXTRA_LANG_NAME_EN)
    save_json("uz_UZ", uz)
    save_json("ru_RU", ru)
    save_json("us_US", en)
    return en


def translate_batch(
    api_key: str,
    target_name: str,
    batch: dict[str, str],
) -> dict[str, str]:
    system = (
        "You translate mobile app UI strings. Return ONLY a JSON object "
        "mapping the same keys to translated values. Preserve placeholders "
        "exactly (@n, @count, @name, @amount, @percent, @base, @tax, @total, "
        "@plan, @months, @days, {name}, %s, etc). "
        "Keep brand name AnyLang unchanged. Keep emoji unchanged. "
        "Do not add extra keys. Do not wrap in markdown."
    )
    user = {"target_language": target_name, "strings": batch}
    with httpx.Client(timeout=180.0) as client:
        for attempt in range(6):
            try:
                r = client.post(
                    "https://api.openai.com/v1/chat/completions",
                    headers={"Authorization": f"Bearer {api_key}"},
                    json={
                        "model": MODEL,
                        "temperature": 0.1,
                        "response_format": {"type": "json_object"},
                        "messages": [
                            {"role": "system", "content": system},
                            {
                                "role": "user",
                                "content": json.dumps(user, ensure_ascii=False),
                            },
                        ],
                    },
                )
                if r.status_code == 429:
                    time.sleep(6 + attempt * 4)
                    continue
                r.raise_for_status()
                content = r.json()["choices"][0]["message"]["content"]
                parsed = json.loads(content)
                if "strings" in parsed and isinstance(parsed["strings"], dict):
                    parsed = parsed["strings"]
                out: dict[str, str] = {}
                for k, v in batch.items():
                    tv = parsed.get(k)
                    out[k] = tv.strip() if isinstance(tv, str) and tv.strip() else v
                return out
            except Exception as e:
                print(f"    retry {attempt+1}: {type(e).__name__}: {e}")
                time.sleep(2 + attempt * 2)
    return dict(batch)


def seed_english_placeholders(source: dict[str, str]) -> None:
    """So app can ship before full MT finishes."""
    for _, code, *_ in UI_LOCALES:
        if code in ("uz_UZ", "ru_RU", "us_US"):
            continue
        path = OUT / f"{code}.json"
        if path.exists():
            continue
        save_json(code, dict(source))
        print("seed", code)


def generate_locale(
    api_key: str,
    code: str,
    source: dict[str, str],
    force: bool = False,
) -> None:
    path = OUT / f"{code}.json"
    existing: dict[str, str] = {}
    if path.exists():
        existing = load_json(code)

    same_as_en = sum(1 for k, v in source.items() if existing.get(k) == v)
    # Brand names / shared tokens remain English — allow up to ~8% identical.
    if not force and existing and same_as_en <= max(80, len(source) // 12):
        DONE.mkdir(parents=True, exist_ok=True)
        (DONE / code).write_text("ok\n", encoding="utf-8")
        print(f"skip {code} (translated, same_as_en={same_as_en})")
        return

    target_name = OPENAI_LANG_NAME[code]
    todo_keys = [
        k
        for k in source
        if force or existing.get(k) == source[k] or k not in existing
    ]
    if not todo_keys:
        DONE.mkdir(parents=True, exist_ok=True)
        (DONE / code).write_text("ok\n", encoding="utf-8")
        print(f"skip {code} (nothing to do)")
        return

    print(f"generate {code} ({target_name}) todo={len(todo_keys)}")
    chunks: list[dict[str, str]] = []
    for i in range(0, len(todo_keys), BATCH):
        part = todo_keys[i : i + BATCH]
        chunks.append({k: source[k] for k in part})

    result = dict(existing) if existing else {}
    done = 0

    def work(chunk: dict[str, str]) -> dict[str, str]:
        return translate_batch(api_key, target_name, chunk)

    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        futs = {pool.submit(work, ch): ch for ch in chunks}
        for fut in as_completed(futs):
            translated = fut.result()
            result.update(translated)
            done += len(translated)
            print(f"  {code} {done}/{len(todo_keys)}", flush=True)

    for k, v in source.items():
        result.setdefault(k, v)
    save_json(code, result)
    DONE.mkdir(parents=True, exist_ok=True)
    (DONE / code).write_text("ok\n", encoding="utf-8")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--only", default="")
    ap.add_argument("--seed-only", action="store_true")
    args = ap.parse_args()

    OUT.mkdir(parents=True, exist_ok=True)
    if not (OUT / "us_US.json").exists():
        raise SystemExit("missing us_US.json — extract first")

    source = patch_base_lang_names()
    write_index()
    seed_english_placeholders(source)
    write_index()

    if args.seed_only:
        print("seed-only done")
        return 0

    api_key = fetch_openai_key()
    print("OpenAI key: OK")

    targets = [
        code
        for _, code, *_ in UI_LOCALES
        if code not in ("uz_UZ", "ru_RU", "us_US")
    ]
    if args.only:
        targets = [t for t in targets if t == args.only or t.startswith(args.only)]

    for code in targets:
        generate_locale(api_key, code, source, force=args.force)

    write_index()
    print("done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
