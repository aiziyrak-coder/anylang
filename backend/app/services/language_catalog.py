"""Language catalog — DB seed source. flag_url points to anylang.uz/flags/{cc}.png."""

from __future__ import annotations

# (code, native_name, flag_country, flag_emoji, stt, tts, tts_voices)
# flag_country = ISO 3166-1 alpha-2 for flag asset (lowercase file name).
LANGUAGE_ROWS: list[tuple[str, str, str, str, bool, bool, list[str]]] = [
    # Central Asia / core
    ("uz", "O‘zbek", "uz", "🇺🇿", True, True, ["female", "male"]),
    ("en", "English", "gb", "🇬🇧", True, True, ["female", "male"]),
    ("ru", "Русский", "ru", "🇷🇺", True, True, ["female", "male"]),
    ("tr", "Türkçe", "tr", "🇹🇷", True, True, ["female", "male"]),
    ("kk", "Қазақша", "kz", "🇰🇿", True, True, ["female", "male"]),
    ("ky", "Кыргызча", "kg", "🇰🇬", True, True, ["female", "male"]),
    ("tg", "Тоҷикӣ", "tj", "🇹🇯", True, True, ["female", "male"]),
    ("az", "Azərbaycan", "az", "🇦🇿", True, True, ["female", "male"]),
    ("tk", "Türkmen", "tm", "🇹🇲", True, True, ["female", "male"]),
    # Europe
    ("de", "Deutsch", "de", "🇩🇪", True, True, ["female", "male"]),
    ("fr", "Français", "fr", "🇫🇷", True, True, ["female", "male"]),
    ("es", "Español", "es", "🇪🇸", True, True, ["female", "male"]),
    ("pt", "Português", "pt", "🇵🇹", True, True, ["female", "male"]),
    ("it", "Italiano", "it", "🇮🇹", True, True, ["female", "male"]),
    ("pl", "Polski", "pl", "🇵🇱", True, True, ["female", "male"]),
    ("uk", "Українська", "ua", "🇺🇦", True, True, ["female", "male"]),
    ("nl", "Nederlands", "nl", "🇳🇱", True, True, ["female", "male"]),
    ("sv", "Svenska", "se", "🇸🇪", True, True, ["female", "male"]),
    ("no", "Norsk", "no", "🇳🇴", True, True, ["female", "male"]),
    ("da", "Dansk", "dk", "🇩🇰", True, True, ["female", "male"]),
    ("fi", "Suomi", "fi", "🇫🇮", True, True, ["female", "male"]),
    ("el", "Ελληνικά", "gr", "🇬🇷", True, True, ["female", "male"]),
    ("cs", "Čeština", "cz", "🇨🇿", True, True, ["female", "male"]),
    ("sk", "Slovenčina", "sk", "🇸🇰", True, True, ["female", "male"]),
    ("ro", "Română", "ro", "🇷🇴", True, True, ["female", "male"]),
    ("hu", "Magyar", "hu", "🇭🇺", True, True, ["female", "male"]),
    ("bg", "Български", "bg", "🇧🇬", True, True, ["female", "male"]),
    ("sr", "Српски", "rs", "🇷🇸", True, True, ["female", "male"]),
    ("hr", "Hrvatski", "hr", "🇭🇷", True, True, ["female", "male"]),
    ("bs", "Bosanski", "ba", "🇧🇦", True, True, ["female", "male"]),
    # Middle East / Caucasus
    ("ar", "العربية", "sa", "🇸🇦", True, True, ["female", "male"]),
    ("fa", "فارسی", "ir", "🇮🇷", True, True, ["female", "male"]),
    ("he", "עברית", "il", "🇮🇱", True, True, ["female", "male"]),
    ("ka", "ქართული", "ge", "🇬🇪", True, True, ["female", "male"]),
    ("hy", "Հայերեն", "am", "🇦🇲", True, True, ["female", "male"]),
    # Asia
    ("zh", "中文", "cn", "🇨🇳", True, True, ["female", "male"]),
    ("ja", "日本語", "jp", "🇯🇵", True, True, ["female", "male"]),
    ("ko", "한국어", "kr", "🇰🇷", True, True, ["female", "male"]),
    ("hi", "हिन्दी", "in", "🇮🇳", True, True, ["female", "male"]),
    ("bn", "বাংলা", "bd", "🇧🇩", True, True, ["female", "male"]),
    ("ur", "اردو", "pk", "🇵🇰", True, True, ["female", "male"]),
    ("pa", "ਪੰਜਾਬੀ", "in", "🇮🇳", True, True, ["female", "male"]),
    ("ta", "தமிழ்", "in", "🇮🇳", True, True, ["female", "male"]),
    ("te", "తెలుగు", "in", "🇮🇳", True, True, ["female", "male"]),
    ("mr", "मराठी", "in", "🇮🇳", True, True, ["female", "male"]),
    ("gu", "ગુજરાતી", "in", "🇮🇳", True, True, ["female", "male"]),
    ("kn", "ಕನ್ನಡ", "in", "🇮🇳", True, True, ["female", "male"]),
    ("ml", "മലയാളം", "in", "🇮🇳", True, True, ["female", "male"]),
    ("si", "සිංහල", "lk", "🇱🇰", True, True, ["female", "male"]),
    ("ne", "नेपाली", "np", "🇳🇵", True, True, ["female", "male"]),
    ("th", "ไทย", "th", "🇹🇭", True, True, ["female", "male"]),
    ("vi", "Tiếng Việt", "vn", "🇻🇳", True, True, ["female", "male"]),
    ("id", "Bahasa Indonesia", "id", "🇮🇩", True, True, ["female", "male"]),
    ("ms", "Bahasa Melayu", "my", "🇲🇾", True, True, ["female", "male"]),
    ("tl", "Filipino", "ph", "🇵🇭", True, True, ["female", "male"]),
    ("my", "မြန်မာ", "mm", "🇲🇲", True, True, ["female", "male"]),
    ("km", "ខ្មែរ", "kh", "🇰🇭", True, True, ["female", "male"]),
    # Africa
    ("sw", "Kiswahili", "ke", "🇰🇪", True, True, ["female", "male"]),
    ("am", "አማርኛ", "et", "🇪🇹", True, True, ["female", "male"]),
    ("ha", "Hausa", "ng", "🇳🇬", True, True, ["female", "male"]),
    ("yo", "Yorùbá", "ng", "🇳🇬", True, True, ["female", "male"]),
]

LANGUAGES_VERSION = "2026-07-26.1"
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
