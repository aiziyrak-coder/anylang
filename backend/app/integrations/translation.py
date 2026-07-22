import logging

import httpx

from app.core.config import get_settings
from app.core.errors import AppError

logger = logging.getLogger(__name__)

DEEPL_FREE_URL = "https://api-free.deepl.com/v2/translate"
DEEPL_PRO_URL = "https://api.deepl.com/v2/translate"
OPENAI_CHAT_URL = "https://api.openai.com/v1/chat/completions"


def _normalize_lang(code: str) -> str:
    return code.split("_")[0].lower()


def _deepl_lang(code: str) -> str:
    return code.split("_")[0].upper()


async def _translate_openai(text: str, target: str, source: str | None) -> str:
    settings = get_settings()
    src = source or "auto"
    system = (
        "You are a precise translation engine for a messaging/chat app. "
        "Translate the user message into the target language. "
        "Rules: "
        "1) Return ONLY the translated text — no quotes, labels, markdown, or commentary. "
        "2) Preserve personal names, usernames, @mentions, hashtags, URLs, and emails exactly. "
        "3) Keep all emojis and their positions; do not add or remove emojis. "
        "4) Keep the translation concise and natural for chat — match the source length when possible. "
        "5) Never invent, expand, summarize, or omit content that is not in the source. "
        "6) If the text is already in the target language (or is only names/emojis/symbols), return it unchanged. "
        "7) Preserve line breaks and basic punctuation intent."
    )
    user = (
        f"Source language: {src}\n"
        f"Target language: {target}\n\n"
        f"Text to translate:\n{text}"
    )
    headers = {
        "Authorization": f"Bearer {settings.openai_api_key}",
        "Content-Type": "application/json",
    }
    payload = {
        "model": settings.openai_model,
        "temperature": 0.2,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
    }
    async with httpx.AsyncClient(timeout=30.0) as client:
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
        return content


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
            return str(translations[0].get("text", text))
    return text


async def translate(text: str, target_lang: str, source_lang: str | None = None) -> str:
    """Translate text via OpenAI, DeepL, or mock (non-prod / allow_mock)."""
    settings = get_settings()
    target = _normalize_lang(target_lang)
    source = _normalize_lang(source_lang) if source_lang else None

    if not text.strip():
        return text
    if source and source == target:
        return text

    provider = (settings.translation_provider or "mock").strip().lower()

    if provider == "openai":
        if not settings.openai_api_key:
            raise AppError(
                message="OpenAI tarjima sozlanmagan",
                error_code="TRANSLATION_UNAVAILABLE",
                status_code=503,
            )
        try:
            return await _translate_openai(text, target, source)
        except AppError:
            raise
        except httpx.HTTPError as exc:
            logger.warning("OpenAI translation failed (%s)", exc)
            raise AppError(
                message="Tarjima xizmati vaqtincha ishlamayapti",
                error_code="TRANSLATION_FAILED",
                status_code=502,
            ) from exc

    if provider == "deepl":
        if not settings.deepl_api_key:
            raise AppError(
                message="DeepL tarjima sozlanmagan",
                error_code="TRANSLATION_UNAVAILABLE",
                status_code=503,
            )
        try:
            return await _translate_deepl(text, target, source)
        except httpx.HTTPError as exc:
            logger.warning("DeepL translation failed (%s)", exc)
            if settings.is_production:
                raise AppError(
                    message="Tarjima xizmati vaqtincha ishlamayapti",
                    error_code="TRANSLATION_FAILED",
                    status_code=502,
                ) from exc
            return f"[{target_lang}] {text}"

    # mock
    if settings.is_production and not settings.allow_mock_translation:
        raise AppError(
            message="Tarjima xizmati sozlanmagan",
            error_code="TRANSLATION_UNAVAILABLE",
            status_code=503,
        )
    return f"[{target_lang}] {text}"
