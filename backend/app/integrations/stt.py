"""Speech-to-text: Deepgram → OpenAI Whisper → mock (non-prod only)."""

from __future__ import annotations

import logging

import httpx

from app.core.config import get_settings
from app.core.errors import AppError

logger = logging.getLogger(__name__)

DEEPGRAM_URL = "https://api.deepgram.com/v1/listen"
OPENAI_WHISPER_URL = "https://api.openai.com/v1/audio/transcriptions"


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

    if settings.openai_api_key:
        return await _openai_whisper_transcribe(
            data,
            content_type=content_type,
            language=language,
            api_key=settings.openai_api_key,
        )

    if settings.is_production:
        raise AppError(
            message="STT sozlanmagan",
            error_code="STT_UNAVAILABLE",
            status_code=503,
        )

    logger.warning("No STT provider configured — using local mock (non-production only)")
    return "Hello"


async def _openai_whisper_transcribe(
    data: bytes,
    *,
    content_type: str,
    language: str | None,
    api_key: str,
) -> str:
    # Whisper expects a filename with extension for format detection.
    mime = (content_type or "audio/mpeg").split(";")[0].strip().lower()
    ext = {
        "audio/mpeg": "mp3",
        "audio/mp3": "mp3",
        "audio/mp4": "mp4",
        "audio/m4a": "m4a",
        "audio/wav": "wav",
        "audio/x-wav": "wav",
        "audio/webm": "webm",
        "audio/ogg": "ogg",
        "application/octet-stream": "mp3",
    }.get(mime, "mp3")

    form_file = (f"audio.{ext}", data, mime or f"audio/{ext}")
    data_fields: dict[str, str] = {
        "model": "whisper-1",
        "response_format": "json",
    }
    if language:
        data_fields["language"] = language.split("_")[0].lower()

    headers = {"Authorization": f"Bearer {api_key}"}
    try:
        async with httpx.AsyncClient(timeout=90.0) as client:
            response = await client.post(
                OPENAI_WHISPER_URL,
                headers=headers,
                files={"file": form_file},
                data=data_fields,
            )
            response.raise_for_status()
            payload = response.json()
    except httpx.HTTPError as exc:
        logger.exception("OpenAI Whisper STT failed")
        raise AppError(
            message="Nutqni aniqlab bo'lmadi",
            error_code="STT_FAILED",
            status_code=502,
        ) from exc

    text = str(payload.get("text") or "").strip()
    if not text:
        raise AppError(
            message="Audioda nutq topilmadi",
            error_code="NO_SPEECH_DETECTED",
            status_code=400,
        )
    return text


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
