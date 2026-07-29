# -*- coding: utf-8 -*-
"""Force-translate stubborn leftover EN strings (esp. CJK / non-Latin)."""
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
from finish_i18n_leftovers import (  # noqa: E402
    ALLOW_EMPTY,
    LANG_NAME,
    PH,
    SKIP_EQ_VALUES,
    SKIP_LEFTOVER_KEYS,
    leftovers,
    ph_set,
)
from generate_ui_i18n import fetch_openai_key, load_json, save_json  # noqa: E402
from ui_locale_catalog import UI_LOCALES  # noqa: E402

# Locales where keeping English is almost never OK for UI body copy.
STRICT_NATIVE = {
    "ko_KR",
    "ja_JP",
    "zh_CN",
    "ar_SA",
    "fa_IR",
    "he_IL",
    "hy_AM",
    "ka_GE",
    "th_TH",
    "hi_IN",
    "bn_BD",
    "ur_PK",
    "pa_IN",
    "ta_IN",
    "te_IN",
    "mr_IN",
    "gu_IN",
    "kn_IN",
    "ml_IN",
    "si_LK",
    "ne_NP",
    "my_MM",
    "km_KH",
    "am_ET",
    "ps_AF",
    "el_GR",
    "bg_BG",
    "sr_RS",
    "mk_MK",
    "be_BY",
    "uk_UA",
    "ru_RU",
    "uz_UZ",
    "kk_KZ",
    "ky_KG",
    "tg_TJ",
    "mn_MN",
}

# Hand fixes for masters / common short labels
HAND = {
    "uz_UZ": {"numbers_bonus_short": "Bonus: @plan"},  # loanword OK
    "fr_FR": {
        "deal_mode_accept_meta": "@n confirmations · v@v",
        "profile_settings_notifications": "Notifications",
        "settings_notifications": "Notifications",
        "support_faq": "Support · FAQ",
        "translation_domain_construction": "Construction",
    },
}


def translate_one(
    client: httpx.Client,
    api_key: str,
    target: str,
    code: str,
    key: str,
    src: str,
) -> str:
    system = (
        f"You are a professional native {target} UI translator for the AnyLang app. "
        "Translate the English UI string into natural, correct native language. "
        "Return ONLY the translated string — no quotes, no JSON, no markdown. "
        "Preserve placeholders EXACTLY as separate tokens (@name @n @plan @date etc). "
        "Never glue placeholders to words. Keep AnyLang brand. "
        f"CRITICAL: the result MUST be in {target}, NOT English "
        "(unless the English word is also the correct native word, e.g. French Notifications)."
    )
    for attempt in range(6):
        try:
            model = "gpt-4o" if attempt >= 2 or code in STRICT_NATIVE else "gpt-4o-mini"
            r = client.post(
                "https://api.openai.com/v1/chat/completions",
                headers={"Authorization": f"Bearer {api_key}"},
                json={
                    "model": model,
                    "temperature": 0.1,
                    "messages": [
                        {"role": "system", "content": system},
                        {
                            "role": "user",
                            "content": f"key={key}\nEnglish:\n{src}",
                        },
                    ],
                },
            )
            r.raise_for_status()
            out = r.json()["choices"][0]["message"]["content"].strip()
            if out.startswith('"') and out.endswith('"'):
                out = out[1:-1]
            if ph_set(out) != ph_set(src):
                time.sleep(0.4)
                continue
            if code in STRICT_NATIVE and out == src and len(src) >= 16:
                # reject unchanged long English
                system = system + " Do NOT copy the English. Translate fully."
                time.sleep(0.5)
                continue
            return out
        except Exception as e:
            print(f"    err {key}: {e}")
            time.sleep(1.2 * (attempt + 1))
    return src


def main() -> int:
    # apply hand fixes
    for code, fixes in HAND.items():
        data = load_json(code)
        data.update(fixes)
        save_json(code, data)

    en = load_json("us_US")
    api_key = fetch_openai_key()
    os.environ["OPENAI_API_KEY"] = api_key

    total = 0
    with httpx.Client(timeout=120.0) as client:
        for _, code, *_ in UI_LOCALES:
            if code == "us_US":
                continue
            data = load_json(code)
            todo = leftovers(en, data)
            # also ph mismatches
            for k, ev in en.items():
                if k in todo or k in ALLOW_EMPTY:
                    continue
                if ph_set(str(ev)) != ph_set(str(data.get(k, ""))):
                    todo[k] = ev
            if not todo:
                continue
            # skip intentional cognates for Latin langs when short identical is correct
            if code not in STRICT_NATIVE and code not in {
                "tl_PH",
                "zu_ZA",
                "ig_NG",
                "ha_NG",
                "yo_NG",
                "sw_KE",
                "so_SO",
                "af_ZA",
                "id_ID",
                "ms_MY",
                "et_EE",
                "sq_AL",
                "mt_MT",
                "ca_ES",
                "ku_TR",
                "sl_SI",
                "no_NO",
                "da_DK",
                "sv_SE",
                "ro_RO",
                "nl_NL",
                "de_DE",
                "es_ES",
                "pt_PT",
                "it_IT",
                "pl_PL",
                "cs_CZ",
                "sk_SK",
                "hr_HR",
                "bs_BA",
                "fi_FI",
                "tr_TR",
                "az_AZ",
                "tk_TM",
                "is_IS",
                "ga_IE",
                "cy_GB",
                "lv_LV",
                "lt_LT",
            }:
                # only strict + listed need force; others already clean enough
                pass

            print(f"{code}: force {len(todo)}")
            for i, (k, src) in enumerate(todo.items(), 1):
                out = translate_one(
                    client, api_key, LANG_NAME[code], code, k, src
                )
                data[k] = out
                total += 1
                if i % 5 == 0 or i == len(todo):
                    print(f"  {code} {i}/{len(todo)}")
                    save_json(code, data)
            save_json(code, data)

    # final report
    print("\n=== REPORT ===")
    bad_ph = 0
    left_total = 0
    for _, code, *_ in UI_LOCALES:
        data = load_json(code)
        issues = []
        for k, ev in en.items():
            if k not in data:
                issues.append(f"missing:{k}")
            elif k not in ALLOW_EMPTY and not str(data[k]).strip():
                issues.append(f"empty:{k}")
            elif ph_set(str(ev)) != ph_set(str(data[k])):
                issues.append(f"ph:{k}")
        left = leftovers(en, data)
        # For French-like cognates, don't count identical short labels as failure
        if code not in STRICT_NATIVE | {"tl_PH", "zu_ZA", "ig_NG"}:
            left = {
                k: v
                for k, v in left.items()
                if len(v) >= 22 or (code in STRICT_NATIVE)
            }
        left_total += len(left)
        if issues:
            bad_ph += 1
            print(f"{code}: ISSUES {issues[:8]}")
        elif left:
            print(f"{code}: leftover {len(left)} -> {list(left)[:8]}")
        else:
            print(f"{code}: OK")
    print("done forced", total, "ph_bad_locales", bad_ph, "leftover_keys", left_total)
    return 0 if bad_ph == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
