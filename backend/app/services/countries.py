from __future__ import annotations

# Ro'yxat o'zgaganda VERSION ni oshiring — klient cache ni yangilaydi.
COUNTRIES_VERSION = "2026-07-22.1"

# (code, name_uz, name_ru, name_en, flag_emoji)
_COUNTRY_ROWS: list[tuple[str, str, str, str, str]] = [
    ("UZ", "Oʻzbekiston", "Узбекистан", "Uzbekistan", "🇺🇿"),
    ("KZ", "Qozogʻiston", "Казахстан", "Kazakhstan", "🇰🇿"),
    ("KG", "Qirgʻiziston", "Кыргызстан", "Kyrgyzstan", "🇰🇬"),
    ("TJ", "Tojikiston", "Таджикистан", "Tajikistan", "🇹🇯"),
    ("TM", "Turkmaniston", "Туркменистан", "Turkmenistan", "🇹🇲"),
    ("RU", "Rossiya", "Россия", "Russia", "🇷🇺"),
    ("TR", "Turkiya", "Турция", "Turkey", "🇹🇷"),
    ("AZ", "Ozarbayjon", "Азербайджан", "Azerbaijan", "🇦🇿"),
    ("US", "AQSH", "США", "United States", "🇺🇸"),
    ("GB", "Buyuk Britaniya", "Великобритания", "United Kingdom", "🇬🇧"),
    ("DE", "Germaniya", "Германия", "Germany", "🇩🇪"),
    ("FR", "Fransiya", "Франция", "France", "🇫🇷"),
    ("IT", "Italiya", "Италия", "Italy", "🇮🇹"),
    ("ES", "Ispaniya", "Испания", "Spain", "🇪🇸"),
    ("CN", "Xitoy", "Китай", "China", "🇨🇳"),
    ("JP", "Yaponiya", "Япония", "Japan", "🇯🇵"),
    ("KR", "Janubiy Koreya", "Южная Корея", "South Korea", "🇰🇷"),
    ("IN", "Hindiston", "Индия", "India", "🇮🇳"),
    ("AE", "BAA", "ОАЭ", "United Arab Emirates", "🇦🇪"),
    ("SA", "Saudiya Arabistoni", "Саудовская Аравия", "Saudi Arabia", "🇸🇦"),
    ("CA", "Kanada", "Канада", "Canada", "🇨🇦"),
    ("AU", "Avstraliya", "Австралия", "Australia", "🇦🇺"),
    ("PL", "Polsha", "Польша", "Poland", "🇵🇱"),
    ("UA", "Ukraina", "Украина", "Ukraine", "🇺🇦"),
    ("BY", "Belarus", "Беларусь", "Belarus", "🇧🇾"),
    ("NL", "Niderlandiya", "Нидерланды", "Netherlands", "🇳🇱"),
    ("SE", "Shvetsiya", "Швеция", "Sweden", "🇸🇪"),
    ("CH", "Shveysariya", "Швейцария", "Switzerland", "🇨🇭"),
    ("MY", "Malayziya", "Малайзия", "Malaysia", "🇲🇾"),
    ("ID", "Indoneziya", "Индонезия", "Indonesia", "🇮🇩"),
]


def list_countries() -> dict:
    seen: set[str] = set()
    items: list[dict] = []
    for code, name_uz, name_ru, name_en, flag in _COUNTRY_ROWS:
        code_u = code.upper()
        if code_u in seen:
            continue
        seen.add(code_u)
        items.append(
            {
                "code": code_u,
                "name_uz": name_uz,
                "name_ru": name_ru,
                "name_en": name_en,
                "flag_emoji": flag,
            }
        )
    # Asosiy auditoriya uchun UZ birinchi, qolganlari EN nomi bo'yicha
    items.sort(key=lambda x: (0 if x["code"] == "UZ" else 1, x["name_en"].lower()))
    return {"version": COUNTRIES_VERSION, "items": items}
