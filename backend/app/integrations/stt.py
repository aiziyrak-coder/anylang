"""Speech-to-text: Deepgram when configured; mock only outside production."""

from __future__ import annotations

import logging

import httpx

from app.core.config import get_settings
from app.core.errors import AppError

logger = logging.getLogger(__name__)

DEEPGRAM_URL = "https://api.deepgram.com/v1/listen"


async def transcribe_audio(
    data: bytes,
    *,
    content_type: str,
    language: str | None = None,
) -> str:
    settings = get_settings()

    if settings.deepgram_api_key:
        return await _deepgram_transcribe(
            data,
            content_type=content_type,
            language=language,
            api_key=settings.deepgram_api_key,
        )

    if settings.is_production:
        raise AppError(
            message="STT sozlanmagan",
            error_code="STT_UNAVAILABLE",
            status_code=503,
        )

    logger.warning("Deepgram not configured — using local mock STT (non-production only)")
    return "Hello"


async def _deepgram_transcribe(
    data: bytes,
    *,
    content_type: str,
    language: str | None,
    api_key: str,
) -> str:
    params: dict[str, str] = {"model": "nova-2", "smart_format": "true"}
    if language:
        params["language"] = language.split("_")[0].lower()

    headers = {
        "Authorization": f"Token {api_key}",
        "Content-Type": content_type or "application/octet-stream",
    }
    try:
        async with httpx.AsyncClient(timeout=60.0) as client:
            response = await client.post(
                DEEPGRAM_URL,
                params=params,
                headers=headers,
                content=data,
            )
            response.raise_for_status()
            payload = response.json()
    except httpx.HTTPError as exc:
        logger.exception("Deepgram STT failed")
        raise AppError(
            message="Nutqni aniqlab bo'lmadi",
            error_code="STT_FAILED",
            status_code=502,
        ) from exc

    try:
        transcript = (
            payload["results"]["channels"][0]["alternatives"][0].get("transcript") or ""
        )
    except (KeyError, IndexError, TypeError):
        transcript = ""

    text = str(transcript).strip()
    if not text:
        raise AppError(
            message="Audioda nutq topilmadi",
            error_code="NO_SPEECH_DETECTED",
            status_code=400,
        )
    return text
