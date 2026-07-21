import logging

import httpx

from app.core.config import get_settings
from app.core.errors import AppError

logger = logging.getLogger(__name__)

DEEPL_FREE_URL = "https://api-free.deepl.com/v2/translate"
DEEPL_PRO_URL = "https://api.deepl.com/v2/translate"


def _normalize_lang(code: str) -> str:
    return code.split("_")[0].upper()


async def translate(text: str, target_lang: str, source_lang: str | None = None) -> str:
    """Translate text. Uses DeepL when configured; otherwise mock prefix."""
    settings = get_settings()
    target = _normalize_lang(target_lang)
    source = _normalize_lang(source_lang) if source_lang else None

    if source and source == target:
        return text

    use_mock = (
        settings.translation_provider == "mock"
        or not settings.deepl_api_key
    )
    if use_mock:
        if settings.is_production:
            raise AppError(
                message="Tarjima xizmati sozlanmagan",
                error_code="TRANSLATION_UNAVAILABLE",
                status_code=503,
            )
        if source and source == target:
            return text
        return f"[{target_lang}] {text}"

    api_url = DEEPL_FREE_URL if settings.deepl_api_key.endswith(":fx") else DEEPL_PRO_URL
    payload: dict[str, str | list[str]] = {
        "auth_key": settings.deepl_api_key,
        "text": [text],
        "target_lang": target,
    }
    if source:
        payload["source_lang"] = source

    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.post(api_url, data=payload)
            response.raise_for_status()
            data = response.json()
            translations = data.get("translations") or []
            if translations:
                return str(translations[0].get("text", text))
    except httpx.HTTPError as exc:
        logger.warning("DeepL translation failed (%s)", exc)
        if settings.is_production:
            raise AppError(
                message="Tarjima xizmati vaqtincha ishlamayapti",
                error_code="TRANSLATION_FAILED",
                status_code=502,
            ) from exc
        return f"[{target_lang}] {text}"

    return text
