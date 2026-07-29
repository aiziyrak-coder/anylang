# -*- coding: utf-8 -*-
"""Final pass: translate remaining exact-EN leftovers (excl. intentional templates)."""
from __future__ import annotations

import json
import os
import re
import sys
import time
from pathlib import Path

import httpx

ROOT = Path(r"E:\Anylang")
sys.path.insert(0, str(ROOT / "scripts"))
from generate_ui_i18n import fetch_openai_key, load_json, save_json  # noqa: E402
from ui_locale_catalog import OPENAI_LANG_NAME, UI_LOCALES  # noqa: E402

# ASCII-only @tokens so Hangul/CJK after @n is not absorbed into the placeholder name.
PH = re.compile(r"@[A-Za-z_][A-Za-z0-9_]*|\{[a-zA-Z0-9_]+\}|%(?:s|d|f)")
ALLOW_EMPTY = {"terms_agree_before", "terms_agree_after"}
# Identical across locales by design (symbols + placeholders only).
SKIP_LEFTOVER_KEYS = {
    "subscription_promo_discount",
    "settings_app_version",
    # Placeholders / samples identical by design
    "chat_search_count",
    "jonli_voice_chip",
    "full_name_hint",
    "email_hint",
    "onb1_msg_out",  # demo bubble may stay bilingual sample
    "numbers_bonus_short",  # "Bonus: @plan" — international loanword
    "deal_mode_accept_meta",  # mostly placeholders
    # Identical cognates in FR/etc. (correct native spelling)
    "profile_settings_notifications",
    "settings_notifications",
    "translation_domain_construction",
}
SKIP_EQ_VALUES = {"AnyLang", "Business Match", "Moderator AI"}
LANG_NAME = {
    **OPENAI_LANG_NAME,
    "uz_UZ": "Uzbek (Latin)",
    "ru_RU": "Russian",
    "us_US": "English (US)",
}

MASTER_FIX = {
    "uz_UZ": {
        "nearby_speaker_distance": "@lang so‘zlovchi · @distance",
        "subscription_promo_discount": "@code: @before → @after (−@discount)",
        "networking_connections": "@n ta aloqa",
        "networking_countries": "@n ta mamlakat",
        "numbers_bonus_short": "Bonus: @plan",
    },
    "ru_RU": {
        "nearby_speaker_distance": "@lang говорящий · @distance",
        "onb1_msg_in": "Привет! Как дела?",
        "subscription_promo_discount": "@code: @before → @after (−@discount)",
        "business_match_title": "Business Match",
        "mod_ai_title": "Moderator AI",
        "networking_connections": "@n связей",
        "networking_countries": "@n стран",
    },
    "us_US": {
        "subscription_promo_discount": "@code: @before → @after (−@discount)",
    },
}


def ph_set(s: str) -> set[str]:
    return set(PH.findall(s or ""))


def translate_batch(api_key: str, target_name: str, batch: dict[str, str]) -> dict[str, str]:
    system = (
        "Professional mobile UI localization for AnyLang (B2B trade + chat app). "
        "Return ONLY a JSON object with the SAME keys. "
        "Native, natural, production-quality translation — no awkward calques. "
        "Preserve EVERY placeholder EXACTLY as a separate token "
        "(@n @name @code @before @after @discount @voice @speed @day @month @year "
        "@current @total @plan @percent @base @tax @months @days @pos @time @date "
        "@lang @distance @count @email @members @rfq @v). "
        "Never glue placeholders to words (wrong: @n日前; correct: @n 日前). "
        "Keep brand names AnyLang, emojis, and newlines. No markdown."
    )
    user = {"target_language": target_name, "strings": batch}
    with httpx.Client(timeout=180.0) as client:
        for attempt in range(8):
            try:
                r = client.post(
                    "https://api.openai.com/v1/chat/completions",
                    headers={"Authorization": f"Bearer {api_key}"},
                    json={
                        "model": "gpt-4o-mini",
                        "temperature": 0.15,
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
                r.raise_for_status()
                content = r.json()["choices"][0]["message"]["content"]
                out = json.loads(content)
                if not isinstance(out, dict):
                    raise ValueError("not dict")
                # unwrap if model nested
                if "strings" in out and isinstance(out["strings"], dict):
                    out = out["strings"]
                fixed: dict[str, str] = {}
                for k, src in batch.items():
                    val = out.get(k, src)
                    if not isinstance(val, str) or not val.strip():
                        val = src
                    if ph_set(val) != ph_set(src):
                        # keep source if placeholders broken — retry later
                        continue
                    fixed[k] = val
                if len(fixed) == len(batch):
                    return fixed
                # partial — merge and retry missing once more with smaller set
                if attempt >= 3 and fixed:
                    missing = {k: batch[k] for k in batch if k not in fixed}
                    if not missing:
                        return fixed
                    batch = missing
                    # continue with remaining
                time.sleep(1.2 * (attempt + 1))
            except Exception as e:
                print(f"    retry {attempt}: {e}")
                time.sleep(1.5 * (attempt + 1))
    return batch


def leftovers(en: dict, data: dict) -> dict[str, str]:
    todo: dict[str, str] = {}
    for k, ev in en.items():
        if k in SKIP_LEFTOVER_KEYS or k in ALLOW_EMPTY or k.startswith("lang_name"):
            continue
        if not isinstance(ev, str) or len(ev) < 12:
            continue
        if ev.strip() in SKIP_EQ_VALUES:
            continue
        # Skip strings that are only placeholders / punctuation / digits
        bare = PH.sub("", ev)
        bare = re.sub(r"[\s·/\-–—:.,|()+\d]+", "", bare)
        if not re.search(r"[A-Za-z]{3,}", bare):
            continue
        cur = data.get(k, "")
        if cur == ev and re.search(r"[A-Za-z]{4}", ev):
            todo[k] = ev
    return todo


def audit(en: dict) -> int:
    bad = 0
    print("\n=== FINAL AUDIT ===")
    for _, code, *_ in UI_LOCALES:
        data = load_json(code)
        issues: list[str] = []
        left = 0
        for k, ev in en.items():
            if k not in data:
                issues.append(f"missing:{k}")
                continue
            v = str(data[k])
            if k not in ALLOW_EMPTY and not v.strip():
                issues.append(f"empty:{k}")
            if ph_set(str(ev)) != ph_set(v):
                issues.append(f"ph:{k}")
            if (
                code != "us_US"
                and k not in SKIP_LEFTOVER_KEYS
                and not k.startswith("lang_name")
                and v == ev
                and len(ev) >= 12
                and ev.strip() not in SKIP_EQ_VALUES
                and re.search(r"[A-Za-z]{4}", ev)
            ):
                bare = PH.sub("", ev)
                bare = re.sub(r"[\s·/\-–—:.,|()+\d]+", "", bare)
                if re.search(r"[A-Za-z]{3,}", bare):
                    left += 1
        print(f"{code}: keys={len(data)} issues={len(issues)} leftover_en={left}")
        if issues:
            bad += 1
            print(" ", issues[:15])
        if left and code != "us_US":
            # show keys
            data_left = leftovers(en, data)
            print("  leftover:", list(data_left)[:12])
    return bad


def main() -> int:
    for code, fixes in MASTER_FIX.items():
        data = load_json(code)
        data.update(fixes)
        save_json(code, data)
        print("fixed master", code)

    en = load_json("us_US")
    api_key = fetch_openai_key()
    os.environ["OPENAI_API_KEY"] = api_key

    total = 0
    # include uz/ru for remaining leftovers
    for _, code, *_ in UI_LOCALES:
        if code == "us_US":
            continue
        data = load_json(code)
        todo = leftovers(en, data)
        # also any placeholder mismatches vs EN
        for k, ev in en.items():
            if k in todo or k in ALLOW_EMPTY:
                continue
            cur = str(data.get(k, ""))
            if ph_set(str(ev)) != ph_set(cur):
                todo[k] = ev
        if not todo:
            print(f"{code}: clean")
            continue
        print(f"{code}: leftover {len(todo)}")
        keys = list(todo)
        for i in range(0, len(keys), 35):
            chunk = {k: todo[k] for k in keys[i : i + 35]}
            translated = translate_batch(api_key, LANG_NAME[code], chunk)
            data.update(translated)
            print(f"  {code} {min(i + 35, len(keys))}/{len(keys)}")
            save_json(code, data)
        total += len(todo)
        save_json(code, data)

    bad = audit(en)
    print("done fixed_keys≈", total, "locales_with_issues", bad)
    return 0 if bad == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
