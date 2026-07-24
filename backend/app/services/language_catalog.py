"""Language catalog — DB seed source. flag_url points to anylang.uz/flags/{cc}.png."""

from __future__ import annotations

# (code, native_name, flag_country, flag_emoji, stt, tts, tts_voices)
# flag_country = ISO 3166-1 alpha-2 for flag asset (lowercase file name).
LANGUAGE_ROWS: list[tuple[str, str, str, str, bool, bool, list[str]]] = [
    # Central Asia / core
    ("uz", "O‘zbek", "uz", "🇺🇿", True, True, ["female", "male"]),
    ("en", "English", "gb", "🇬🇧", True, True, ["female", "male"]),
    ("ru", "Русский", "ru", "🇷🇺", True, True, ["female"]),
    ("tr", "Türkçe", "tr", "🇹🇷", True, True, ["female"]),
    ("kk", "Қазақша", "kz", "🇰🇿", True, False, []),
    ("ky", "Кыргызча", "kg", "🇰🇬", True, False, []),
    ("tg", "Тоҷикӣ", "tj", "🇹🇯", True, False, []),
    ("az", "Azərbaycan", "az", "🇦🇿", True, False, []),
    ("tk", "Türkmen", "tm", "🇹🇲", True, False, []),
    # Europe
    ("de", "Deutsch", "de", "🇩🇪", True, True, ["female"]),
    ("fr", "Français", "fr", "🇫🇷", True, True, ["female"]),
    ("es", "Español", "es", "🇪🇸", True, True, ["female"]),
    ("pt", "Português", "pt", "🇵🇹", True, False, []),
    ("it", "Italiano", "it", "🇮🇹", True, False, []),
    ("pl", "Polski", "pl", "🇵🇱", True, False, []),
    ("uk", "Українська", "ua", "🇺🇦", True, False, []),
    ("nl", "Nederlands", "nl", "🇳🇱", True, False, []),
    ("sv", "Svenska", "se", "🇸🇪", True, False, []),
    ("no", "Norsk", "no", "🇳🇴", True, False, []),
    ("da", "Dansk", "dk", "🇩🇰", True, False, []),
    ("fi", "Suomi", "fi", "🇫🇮", True, False, []),
    ("el", "Ελληνικά", "gr", "🇬🇷", True, False, []),
    ("cs", "Čeština", "cz", "🇨🇿", True, False, []),
    ("sk", "Slovenčina", "sk", "🇸🇰", True, False, []),
    ("ro", "Română", "ro", "🇷🇴", True, False, []),
    ("hu", "Magyar", "hu", "🇭🇺", True, False, []),
    ("bg", "Български", "bg", "🇧🇬", True, False, []),
    ("sr", "Српски", "rs", "🇷🇸", True, False, []),
    ("hr", "Hrvatski", "hr", "🇭🇷", True, False, []),
    ("bs", "Bosanski", "ba", "🇧🇦", True, False, []),
    # Middle East / Caucasus
    ("ar", "العربية", "sa", "🇸🇦", True, False, []),
    ("fa", "فارسی", "ir", "🇮🇷", True, False, []),
    ("he", "עברית", "il", "🇮🇱", True, False, []),
    ("ka", "ქართული", "ge", "🇬🇪", True, False, []),
    ("hy", "Հայերեն", "am", "🇦🇲", True, False, []),
    # Asia
    ("zh", "中文", "cn", "🇨🇳", True, True, ["female"]),
    ("ja", "日本語", "jp", "🇯🇵", True, False, []),
    ("ko", "한국어", "kr", "🇰🇷", True, False, []),
    ("hi", "हिन्दी", "in", "🇮🇳", True, False, []),
    ("bn", "বাংলা", "bd", "🇧🇩", True, False, []),
    ("ur", "اردو", "pk", "🇵🇰", True, False, []),
    ("pa", "ਪੰਜਾਬੀ", "in", "🇮🇳", True, False, []),
    ("ta", "தமிழ்", "in", "🇮🇳", True, False, []),
    ("te", "తెలుగు", "in", "🇮🇳", True, False, []),
    ("mr", "मराठी", "in", "🇮🇳", True, False, []),
    ("gu", "ગુજરાતી", "in", "🇮🇳", True, False, []),
    ("kn", "ಕನ್ನಡ", "in", "🇮🇳", True, False, []),
    ("ml", "മലയാളം", "in", "🇮🇳", True, False, []),
    ("si", "සිංහල", "lk", "🇱🇰", True, False, []),
    ("ne", "नेपाली", "np", "🇳🇵", True, False, []),
    ("th", "ไทย", "th", "🇹🇭", True, False, []),
    ("vi", "Tiếng Việt", "vn", "🇻🇳", True, False, []),
    ("id", "Bahasa Indonesia", "id", "🇮🇩", True, False, []),
    ("ms", "Bahasa Melayu", "my", "🇲🇾", True, False, []),
    ("tl", "Filipino", "ph", "🇵🇭", True, False, []),
    ("my", "မြန်မာ", "mm", "🇲🇲", True, False, []),
    ("km", "ខ្មែរ", "kh", "🇰🇭", True, False, []),
    # Africa
    ("sw", "Kiswahili", "ke", "🇰🇪", True, False, []),
    ("am", "አማርኛ", "et", "🇪🇹", True, False, []),
    ("ha", "Hausa", "ng", "🇳🇬", True, False, []),
    ("yo", "Yorùbá", "ng", "🇳🇬", True, False, []),
]

LANGUAGES_VERSION = "2026-07-24.1"
FLAGS_BASE_URL = "https://anylang.uz/flags"


def flag_url_for_country(flag_country: str) -> str:
    return f"{FLAGS_BASE_URL}/{flag_country.lower()}.png"


def catalog_dicts() -> list[dict]:
    out: list[dict] = []
    for code, native, flag_cc, emoji, stt, tts, voices in LANGUAGE_ROWS:
        out.append(
            {
                "code": code,
                "native_name": native,
                "flag_country": flag_cc.lower(),
                "flag_emoji": emoji,
                "flag_url": flag_url_for_country(flag_cc),
                "stt": stt,
                "tts": tts,
                "tts_voices": list(voices),
            }
        )
    return out


def live_language_dicts() -> list[dict]:
    """Shape used by live API (includes flag fields)."""
    return [
        {
            "code": d["code"],
            "stt": d["stt"],
            "tts": d["tts"],
            "tts_voices": d["tts_voices"],
            "native_name": d["native_name"],
            "flag_emoji": d["flag_emoji"],
            "flag_url": d["flag_url"],
            "flag_country": d["flag_country"],
        }
        for d in catalog_dicts()
    ]
