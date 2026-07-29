# -*- coding: utf-8 -*-
"""Repair i18n: fix masters, placeholder false-positives, leftover EN, broken @tokens."""
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
from generate_ui_i18n import OUT, fetch_openai_key, load_json, save_json  # noqa: E402
from ui_locale_catalog import OPENAI_LANG_NAME, UI_LOCALES  # noqa: E402

# Only real UI placeholders — NOT percent amounts like %30.
PH = re.compile(r"@[A-Za-z_][A-Za-z0-9_]*|\{[a-zA-Z0-9_]+\}|%(?:s|d|f)")
ALLOW_EMPTY = {"terms_agree_before", "terms_agree_after"}

MASTER_FIX = {
    "us_US": {
        "subscription_promo_discount": "@code: @before → @after (−@discount)",
        "settings_app_version": "AnyLang",
    },
    "uz_UZ": {
        "subscription_promo_discount": "@code: @before → @after (−@discount)",
        "settings_app_version": "AnyLang",
        "auto_biz_card_label": "AVTO BIZNES KARTA",
        "business_ai_title": "AI kompaniya profili",
        "business_card_qr_title": "Biznes karta QR",
        "business_match_title": "Biznes Match",
        "chat_overflow_group_catalog": "Guruh katalogi",
        "factory_audit_report": "Audit hisoboti",
        "factory_inspection_passed": "Tekshiruvdan o‘tdi",
        "factory_verification_title": "Zavod tasdiqlangan",
        "factory_verified": "Zavod tasdiqlangan",
        "feed_title": "Biznes lenta",
        "group_catalog_title": "Guruh katalogi",
        "market_analytics_title": "AI bozor tahlili",
        "marketplace_group_title_agriculture": "Qishloq xo‘jaligi guruhi",
        "marketplace_group_title_chemicals": "Kimyo guruhi",
        "marketplace_group_title_construction": "Qurilish guruhi",
        "marketplace_group_title_electronics": "Elektronika guruhi",
        "marketplace_group_title_food-exporters": "Oziq-ovqat eksportchilari",
        "marketplace_group_title_furniture": "Mebel guruhi",
        "marketplace_group_title_medical-suppliers": "Tibbiy yetkazib beruvchilar",
        "marketplace_group_title_textile": "To‘qimachilik guruhi",
        "marketplace_group_title_textile-manufacturers": "To‘qimachilik ishlab chiqaruvchilari",
        "marketplace_groups_title": "Marketplace guruh",
        "marketplace_section_verified": "Tasdiqlangan guruh",
        "marketplace_verified_info_title": "Tasdiqlangan guruh",
        "mod_ai_title": "Moderator AI",
        "nearby_premium_title": "Yaqin-atrof — Premium",
        "product_trust_trade_assurance": "Savdo kafolati",
        "products_tezkor_free_shipping": "Bepul yetkazib berish",
        "products_tezkor_premium": "Premium sotuvchi",
        "scam_detection_title": "Firibgarlik aniqlash",
        "settings_smart_translation": "Smart tarjima",
        "translation_domain_construction": "Qurilish",
        "onb1_msg_in": "Salom! Qalaysiz?",
    },
    "ru_RU": {
        "subscription_promo_discount": "@code: @before → @after (−@discount)",
        "settings_app_version": "AnyLang",
        "auto_biz_card_label": "АВТО БИЗНЕС-КАРТА",
        "business_ai_title": "AI-профиль компании",
        "business_card_qr_title": "QR визитки",
        "business_match_title": "Business Match",
        "chat_overflow_group_catalog": "Каталог группы",
        "factory_audit_report": "Отчёт аудита",
        "factory_inspection_passed": "Инспекция пройдена",
        "factory_verification_title": "Завод подтверждён",
        "factory_verified": "Завод подтверждён",
        "feed_title": "Бизнес-лента",
        "group_catalog_title": "Каталог группы",
        "market_analytics_title": "AI-аналитика рынка",
        "marketplace_group_title_agriculture": "Группа сельского хозяйства",
        "marketplace_group_title_chemicals": "Химическая группа",
        "marketplace_group_title_construction": "Строительная группа",
        "marketplace_group_title_electronics": "Электронная группа",
        "marketplace_group_title_food-exporters": "Экспортёры еды",
        "marketplace_group_title_furniture": "Мебельная группа",
        "marketplace_group_title_medical-suppliers": "Медицинские поставщики",
        "marketplace_group_title_textile": "Текстильная группа",
        "marketplace_group_title_textile-manufacturers": "Производители текстиля",
        "marketplace_groups_title": "Marketplace-группа",
        "marketplace_section_verified": "Проверенная группа",
        "marketplace_verified_info_title": "Проверенная группа",
        "mod_ai_title": "Moderator AI",
        "nearby_premium_title": "Рядом — Premium",
        "product_trust_trade_assurance": "Гарантия сделки",
        "products_tezkor_free_shipping": "Бесплатная доставка",
        "products_tezkor_premium": "Премиум-продавец",
        "scam_detection_title": "Антискам",
        "settings_smart_translation": "Умный перевод",
        "translation_domain_construction": "Строительство",
    },
}


def ph_set(s: str) -> set[str]:
    return set(PH.findall(s or ""))


def translate_batch(api_key: str, target_name: str, batch: dict[str, str]) -> dict[str, str]:
    system = (
        "Professional mobile UI localization. Return ONLY JSON with the SAME keys. "
        "PERFECT native grammar. Preserve placeholders EXACTLY as separate tokens "
        "(@n @name @code @before @after @discount @voice @speed @day @month @year "
        "@current @total @plan @percent @base @tax @months @days @pos @time @date @lang @distance @count). "
        "NEVER merge placeholders with words (wrong: @n日前 ; correct: @n 日前). "
        "Keep AnyLang and emojis. No markdown."
    )
    user = {"target_language": target_name, "strings": batch}
    with httpx.Client(timeout=180.0) as client:
        for attempt in range(6):
            try:
                r = client.post(
                    "https://api.openai.com/v1/chat/completions",
                    headers={"Authorization": f"Bearer {api_key}"},
                    json={
                        "model": "gpt-4o-mini",
                        "temperature": 0.0,
                        "response_format": {"type": "json_object"},
                        "messages": [
                            {"role": "system", "content": system},
                            {"role": "user", "content": json.dumps(user, ensure_ascii=False)},
                        ],
                    },
                )
                if r.status_code == 429:
                    time.sleep(5 + attempt * 3)
                    continue
                r.raise_for_status()
                parsed = json.loads(r.json()["choices"][0]["message"]["content"])
                if isinstance(parsed.get("strings"), dict):
                    parsed = parsed["strings"]
                out = {}
                for k, v in batch.items():
                    tv = parsed.get(k)
                    if isinstance(tv, str) and tv.strip() and ph_set(v) == ph_set(tv):
                        out[k] = tv.strip()
                    else:
                        out[k] = v  # keep EN if still broken
                return out
            except Exception as e:
                print(f"  retry {attempt+1}: {type(e).__name__}: {e}")
                time.sleep(2 + attempt)
    return dict(batch)


def broken_keys(en: dict[str, str], data: dict[str, str]) -> dict[str, str]:
    todo = {}
    for k, ev in en.items():
        if k in ALLOW_EMPTY:
            continue
        cur = data.get(k)
        if cur is None or (not str(cur).strip() and k not in ALLOW_EMPTY):
            todo[k] = ev
            continue
        if ph_set(ev) != ph_set(str(cur)):
            todo[k] = ev
            continue
        # fused placeholder like @n日前
        if re.search(r"@[a-zA-Z]+\S", str(cur)) and re.search(
            r"@[a-zA-Z]+[^\s@a-zA-Z0-9_{}]", str(cur)
        ):
            # if EN placeholder exists and target glued non-latin after it
            todo[k] = ev
    return todo


def main() -> int:
    for code, patch in MASTER_FIX.items():
        data = load_json(code)
        data.update(patch)
        save_json(code, data)
        print("fixed master", code)

    en = load_json("us_US")
    api_key = fetch_openai_key()
    os.environ["OPENAI_API_KEY"] = api_key

    total_fixed = 0
    for _, code, *_ in UI_LOCALES:
        if code in ("uz_UZ", "ru_RU", "us_US"):
            continue
        data = load_json(code)
        # sync promo template from EN if still wrong shape
        if ph_set(data.get("subscription_promo_discount", "")) != ph_set(
            en["subscription_promo_discount"]
        ):
            data["subscription_promo_discount"] = en["subscription_promo_discount"]
        todo = broken_keys(en, data)
        # also leftover EN for long UI lines (exclude short brands)
        for k, ev in en.items():
            if k in todo or k in ALLOW_EMPTY:
                continue
            cur = data.get(k, "")
            if cur == ev and len(ev) >= 18 and not k.startswith("lang_name"):
                if ev.strip() in {"AnyLang", "Business Match", "Moderator AI"}:
                    continue
                todo[k] = ev
        if not todo:
            print(f"{code}: clean")
            continue
        print(f"{code}: repair {len(todo)}")
        keys = list(todo)
        for i in range(0, len(keys), 40):
            chunk = {k: todo[k] for k in keys[i : i + 40]}
            data.update(translate_batch(api_key, OPENAI_LANG_NAME[code], chunk))
            print(f"  {code} {min(i+40, len(keys))}/{len(keys)}")
            save_json(code, data)
        total_fixed += len(todo)
        save_json(code, data)

    # final audit with fixed regex
    print("\n=== FINAL AUDIT ===")
    bad = 0
    for _, code, *_ in UI_LOCALES:
        data = load_json(code)
        issues = []
        leftover = 0
        for k, ev in en.items():
            if k not in data:
                issues.append(f"missing:{k}")
                continue
            v = data[k]
            if k not in ALLOW_EMPTY and not str(v).strip():
                issues.append(f"empty:{k}")
            if ph_set(ev) != ph_set(str(v)):
                issues.append(f"ph:{k}")
            if code != "us_US" and v == ev and len(ev) >= 18 and not k.startswith("lang_name"):
                leftover += 1
        print(f"{code}: issues={len(issues)} leftover_en>18={leftover}")
        if issues:
            bad += 1
            print(" ", issues[:12])
    print("done total_repair_batches_keys≈", total_fixed, "locales_with_issues", bad)
    return 0 if bad == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
