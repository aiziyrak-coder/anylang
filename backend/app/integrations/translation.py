import logging
import re

import httpx

from app.core.config import get_settings
from app.core.errors import AppError

logger = logging.getLogger(__name__)

DEEPL_FREE_URL = "https://api-free.deepl.com/v2/translate"
DEEPL_PRO_URL = "https://api.deepl.com/v2/translate"
OPENAI_CHAT_URL = "https://api.openai.com/v1/chat/completions"

_LANG_NAMES = {
    "uz": "Uzbek (Latin script)",
    "ru": "Russian",
    "en": "English",
    "tr": "Turkish",
    "kk": "Kazakh",
    "ky": "Kyrgyz",
    "tg": "Tajik",
    "az": "Azerbaijani",
    "tk": "Turkmen",
    "de": "German",
    "fr": "French",
    "es": "Spanish",
    "pt": "Portuguese",
    "it": "Italian",
    "pl": "Polish",
    "uk": "Ukrainian",
    "nl": "Dutch",
    "sv": "Swedish",
    "no": "Norwegian",
    "da": "Danish",
    "fi": "Finnish",
    "el": "Greek",
    "cs": "Czech",
    "sk": "Slovak",
    "ro": "Romanian",
    "hu": "Hungarian",
    "bg": "Bulgarian",
    "sr": "Serbian",
    "hr": "Croatian",
    "bs": "Bosnian",
    "ar": "Arabic",
    "fa": "Persian (Farsi)",
    "he": "Hebrew",
    "ka": "Georgian",
    "hy": "Armenian",
    "zh": "Chinese (Simplified)",
    "ja": "Japanese",
    "ko": "Korean",
    "hi": "Hindi",
    "bn": "Bengali",
    "ur": "Urdu",
    "pa": "Punjabi",
    "ta": "Tamil",
    "te": "Telugu",
    "mr": "Marathi",
    "gu": "Gujarati",
    "kn": "Kannada",
    "ml": "Malayalam",
    "si": "Sinhala",
    "ne": "Nepali",
    "th": "Thai",
    "vi": "Vietnamese",
    "id": "Indonesian",
    "ms": "Malay",
    "tl": "Filipino (Tagalog)",
    "my": "Burmese",
    "km": "Khmer",
    "sw": "Swahili",
    "am": "Amharic",
    "ha": "Hausa",
    "yo": "Yoruba",
}

# UI / locale leftovers → ISO 639-1 used by translation + DB matching.
_LANG_ALIASES = {
    "us": "en",
    "gb": "en",
    "eng": "en",
    "ua": "uk",
}

_LANG_QUALITY = {
    "uz": (
        "Uzbek: use modern Latin orthography (o‘, g‘, sh, ch, ng). "
        "Correct case endings and verb agreement. No Russian word-order calques. "
        "Natural spoken Uzbek for chat; never leave misspellings."
    ),
    "ru": (
        "Russian: perfect cases, gender/number agreement, verb aspect, and punctuation. "
        "Natural chat Russian; no literal calques from other languages."
    ),
    "en": (
        "English: correct articles (a/an/the), verb tense/agreement, prepositions, "
        "and spelling (US or consistent). Natural chat English; no broken syntax."
    ),
    "tr": (
        "Turkish: correct agglutination and vowel harmony; natural chat Turkish."
    ),
}


def _normalize_lang(code: str | None) -> str:
    raw = (code or "").strip().split("_")[0].split("-")[0].lower()
    if not raw:
        return "uz"
    return _LANG_ALIASES.get(raw, raw)


def user_preferred_lang(user) -> str:
    """Tarjima maqsad tili: ona tili (native); yo'q bo'lsa app tili."""
    native = getattr(user, "native_language", None)
    app = getattr(user, "app_language", None)
    return _normalize_lang(native or app or "uz")


_URL_TOKEN_RE = re.compile(
    r"(https?://[^\s<>\"']+|anylang://[^\s<>\"']+)",
    re.IGNORECASE,
)


def _is_url_only_message(text: str) -> bool:
    stripped = (text or "").strip()
    if not stripped:
        return True
    parts = stripped.split()
    return bool(parts) and all(_URL_TOKEN_RE.fullmatch(p) for p in parts)


def _protect_urls(text: str) -> tuple[str, list[str]]:
    urls: list[str] = []

    def _stash(match: re.Match[str]) -> str:
        urls.append(match.group(0))
        return f"⟦URL{len(urls) - 1}⟧"

    return _URL_TOKEN_RE.sub(_stash, text), urls


def _restore_urls(text: str, urls: list[str]) -> str:
    out = text
    for i, url in enumerate(urls):
        out = out.replace(f"⟦URL{i}⟧", url)
        out = out.replace(f"[URL{i}]", url)
    return out


def app_locale_for_iso(iso: str) -> str:
    """ISO 639-1 → app_language locale (uz_UZ / ru_RU / us_US)."""
    code = _normalize_lang(iso)
    return {
        "uz": "uz_UZ",
        "ru": "ru_RU",
        "en": "us_US",
    }.get(code, f"{code}_{code.upper()}")


def _lang_name(code: str | None) -> str:
    if not code:
        return "auto-detected"
    n = _normalize_lang(code)
    return _LANG_NAMES.get(n, n)


def _deepl_lang(code: str) -> str:
    return _normalize_lang(code).upper()


def _translation_model(settings) -> str:
    dedicated = (getattr(settings, "openai_translation_model", None) or "").strip()
    if dedicated:
        return dedicated
    return (settings.openai_model or "gpt-4o-mini").strip()


def _strip_model_wrappers(text: str) -> str:
    out = (text or "").strip()
    if not out:
        return out
    # Remove accidental labels / code fences.
    out = re.sub(r"^```(?:\w+)?\s*", "", out)
    out = re.sub(r"\s*```$", "", out)
    out = out.strip()
    # Strip wrapping quotes only when the whole string is quoted once.
    if len(out) >= 2 and out[0] == out[-1] and out[0] in {'"', "'", "“", "”", "«", "»"}:
        out = out[1:-1].strip()
    for prefix in (
        "Translation:",
        "Translated:",
        "Corrected:",
        "Output:",
        "Tarjima:",
        "Перевод:",
    ):
        if out.lower().startswith(prefix.lower()):
            out = out[len(prefix) :].strip()
    return out.strip()


async def _openai_chat(
    *,
    api_key: str,
    model: str,
    system: str,
    user: str,
    temperature: float = 0.0,
    timeout: float = 35.0,
) -> str:
    headers = {
        "Authorization": f"Bearer {api_key}",
        "Content-Type": "application/json",
    }
    payload = {
        "model": model,
        "temperature": temperature,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
    }
    async with httpx.AsyncClient(timeout=timeout) as client:
        response = await client.post(OPENAI_CHAT_URL, headers=headers, json=payload)
        response.raise_for_status()
        data = response.json()
        content = (
            ((data.get("choices") or [{}])[0].get("message") or {}).get("content") or ""
        ).strip()
        if not content:
            raise AppError(
                message="Tarjima javobi bo'sh",
                error_code="TRANSLATION_FAILED",
                status_code=502,
            )
        return _strip_model_wrappers(content)


def _translate_system(tgt: str) -> str:
    quality = _LANG_QUALITY.get(tgt, "Use perfect native grammar, spelling, and syntax.")
    return (
        "You are a senior professional translator for AnyLang, a messaging app. "
        "Recipients must read every chat message in their native language with "
        "ZERO spelling, grammar, or syntax mistakes — native-speaker quality only.\n\n"
        "Hard rules:\n"
        "1) Output ONLY the translated message text. No quotes, labels, markdown, notes.\n"
        "2) Meaning must stay exact: do not invent, expand, summarize, or omit.\n"
        "3) Preserve names, @mentions, #hashtags, URLs, emails, phones, codes exactly.\n"
        "4) Keep emojis and relative positions; do not add/remove emojis.\n"
        "5) Match chat tone (casual/formal) and preserve line breaks.\n"
        "6) If already in the target language, or only names/emojis/symbols/numbers — return unchanged.\n"
        "7) Never produce broken word order, missing words, or misspellings.\n"
        "8) Prefer natural idiomatic phrasing over word-for-word calques.\n\n"
        f"Target-language quality bar:\n{quality}"
    )


def _proofread_system(tgt: str) -> str:
    quality = _LANG_QUALITY.get(tgt, "Fix every grammar, spelling, and syntax error.")
    return (
        "You are a native-speaker copy editor for chat translations in AnyLang. "
        "Your ONLY job is to eliminate spelling, grammar, syntax, and punctuation errors "
        "while keeping the meaning identical.\n\n"
        "Hard rules:\n"
        "1) Output ONLY the corrected text — no quotes, labels, or commentary.\n"
        "2) Fix: spelling, diacritics, grammar, agreement, word order, punctuation.\n"
        "3) Do NOT change meaning, add content, remove content, or rephrase style unless "
        "needed to fix an error.\n"
        "4) Preserve names, @mentions, #hashtags, URLs, emails, phones, codes, emojis exactly.\n"
        "5) Preserve line breaks.\n"
        "6) If the text is already perfect, return it unchanged.\n\n"
        f"Language focus:\n{quality}"
    )


async def _translate_openai(text: str, target: str, source: str | None) -> str:
    settings = get_settings()
    src_name = _lang_name(source)
    tgt_name = _lang_name(target)
    model = _translation_model(settings)
    tgt = _normalize_lang(target)

    draft = await _openai_chat(
        api_key=settings.openai_api_key,
        model=model,
        system=_translate_system(tgt),
        user=(
            f"Source language: {src_name}\n"
            f"Target language: {tgt_name}\n\n"
            f"Text to translate:\n{text}"
        ),
        temperature=0.0,
        timeout=35.0,
    )

    # Short / emoji-only: skip second pass.
    meaningful = re.sub(r"[\W_]+", "", draft, flags=re.UNICODE)
    if len(meaningful) < 3:
        return draft

    try:
        polished = await _openai_chat(
            api_key=settings.openai_api_key,
            model=model,
            system=_proofread_system(tgt),
            user=(
                f"Language: {tgt_name}\n"
                f"Original source ({src_name}):\n{text}\n\n"
                f"Draft translation to proofread:\n{draft}"
            ),
            temperature=0.0,
            timeout=35.0,
        )
        if (polished or "").strip():
            return polished
    except Exception as exc:  # noqa: BLE001
        logger.warning("Translation proofread skipped (%s); using draft", exc)

    return draft


async def _translate_deepl(text: str, target: str, source: str | None) -> str:
    settings = get_settings()
    api_url = DEEPL_FREE_URL if settings.deepl_api_key.endswith(":fx") else DEEPL_PRO_URL
    payload: dict[str, str | list[str]] = {
        "auth_key": settings.deepl_api_key,
        "text": [text],
        "target_lang": _deepl_lang(target),
    }
    if source:
        payload["source_lang"] = _deepl_lang(source)

    async with httpx.AsyncClient(timeout=20.0) as client:
        response = await client.post(api_url, data=payload)
        response.raise_for_status()
        data = response.json()
        translations = data.get("translations") or []
        if translations:
            out = str(translations[0].get("text") or "").strip()
            if out:
                return out
            raise AppError(
                message="Tarjima javobi bo'sh",
                error_code="TRANSLATION_FAILED",
                status_code=502,
            )
    raise AppError(
        message="Tarjima javobi bo'sh",
        error_code="TRANSLATION_FAILED",
        status_code=502,
    )


async def translate(text: str, target_lang: str, source_lang: str | None = None) -> str:
    """Translate text via OpenAI, DeepL, or mock (non-prod / allow_mock)."""
    settings = get_settings()
    target = _normalize_lang(target_lang)
    source = _normalize_lang(source_lang) if source_lang else None

    if not text.strip():
        return text
    if source and source == target:
        return text
    # Faqat URL / invite link — tarjima qilinmasin
    if _is_url_only_message(text):
        return text

    protected, urls = _protect_urls(text)
    out = await _translate_provider(protected, target, source, settings)
    return _restore_urls(out, urls)


async def _translate_provider(
    text: str, target: str, source: str | None, settings
) -> str:
    provider = (settings.translation_provider or "mock").strip().lower()

    if provider == "openai":
        if not settings.openai_api_key:
            raise AppError(
                message="OpenAI tarjima sozlanmagan",
                error_code="TRANSLATION_UNAVAILABLE",
                status_code=503,
            )
        try:
            out = await _translate_openai(text, target, source)
        except AppError:
            raise
        except httpx.HTTPError as exc:
            logger.warning("OpenAI translation failed (%s)", exc)
            raise AppError(
                message="Tarjima xizmati vaqtincha ishlamayapti",
                error_code="TRANSLATION_FAILED",
                status_code=502,
            ) from exc
        if not (out or "").strip():
            raise AppError(
                message="Tarjima javobi bo'sh",
                error_code="TRANSLATION_FAILED",
                status_code=502,
            )
        return out.strip()

    if provider == "deepl":
        if not settings.deepl_api_key:
            raise AppError(
                message="DeepL tarjima sozlanmagan",
                error_code="TRANSLATION_UNAVAILABLE",
                status_code=503,
            )
        try:
            out = await _translate_deepl(text, target, source)
        except AppError:
            raise
        except httpx.HTTPError as exc:
            logger.warning("DeepL translation failed (%s)", exc)
            if settings.is_production:
                raise AppError(
                    message="Tarjima xizmati vaqtincha ishlamayapti",
                    error_code="TRANSLATION_FAILED",
                    status_code=502,
                ) from exc
            return f"[{target}] {text}"
        if not (out or "").strip():
            raise AppError(
                message="Tarjima javobi bo'sh",
                error_code="TRANSLATION_FAILED",
                status_code=502,
            )
        return out.strip()

    # mock
    if settings.is_production and not settings.allow_mock_translation:
        raise AppError(
            message="Tarjima xizmati sozlanmagan",
            error_code="TRANSLATION_UNAVAILABLE",
            status_code=503,
        )
    return f"[{target}] {text}"
