"""Speech-to-text: OpenAI Whisper (preferred) → Deepgram → mock (non-prod only).

Whisper is preferred because Deepgram nova-2 poorly handles Uzbek and some
Turkic languages — empty transcripts were surfacing as NO_SPEECH_DETECTED.
"""

from __future__ import annotations

import logging
from pathlib import Path

import httpx

from app.core.config import get_settings
from app.core.errors import AppError

logger = logging.getLogger(__name__)

DEEPGRAM_URL = "https://api.deepgram.com/v1/listen"
OPENAI_WHISPER_URL = "https://api.openai.com/v1/audio/transcriptions"

# Deepgram nova-2 has weak / no support for these ISO codes.
_DEEPGRAM_WEAK_LANGS = frozenset({"uz", "kk", "ky", "tg", "tk"})


def _iso_lang(language: str | None) -> str | None:
    if not language:
        return None
    code = language.strip().lower().replace("-", "_").split("_")[0]
    return code or None


def _guess_ext(content_type: str | None, filename: str | None) -> str:
    name = (filename or "").lower()
    suffix = Path(name).suffix.lstrip(".")
    if suffix in {"m4a", "mp3", "mp4", "wav", "webm", "ogg", "aac", "flac", "mpeg"}:
        return "m4a" if suffix == "aac" else suffix

    mime = (content_type or "").split(";")[0].strip().lower()
    return {
        "audio/mpeg": "mp3",
        "audio/mp3": "mp3",
        "audio/mp4": "m4a",
        "audio/m4a": "m4a",
        "audio/x-m4a": "m4a",
        "audio/aac": "m4a",
        "audio/wav": "wav",
        "audio/x-wav": "wav",
        "audio/webm": "webm",
        "audio/ogg": "ogg",
        "application/octet-stream": "m4a",
    }.get(mime, "m4a")


async def transcribe_audio(
    data: bytes,
    *,
    content_type: str,
    language: str | None = None,
    filename: str | None = None,
) -> str:
    if not data:
        raise AppError(
            message="Audioda nutq topilmadi",
            error_code="NO_SPEECH_DETECTED",
            status_code=400,
        )

    settings = get_settings()
    lang = _iso_lang(language)
    ext = _guess_ext(content_type, filename)
    mime = (content_type or "").split(";")[0].strip().lower() or f"audio/{ext}"

    # Prefer Whisper (Uzbek / multilingual). Fall back to Deepgram, then retry
    # Whisper without a hard language lock if the first pass was empty.
    errors: list[str] = []

    if settings.openai_api_key:
        try:
            text = await _openai_whisper_transcribe(
                data,
                content_type=mime,
                language=lang,
                api_key=settings.openai_api_key,
                ext=ext,
            )
            if text:
                return text
        except AppError as exc:
            if exc.error_code != "NO_SPEECH_DETECTED":
                errors.append(str(exc.message))
                logger.warning("Whisper STT failed (%s); trying fallback", exc.error_code)
            else:
                # Retry auto-detect once — forced `uz` sometimes returns empty on short clips.
                if lang:
                    try:
                        text = await _openai_whisper_transcribe(
                            data,
                            content_type=mime,
                            language=None,
                            api_key=settings.openai_api_key,
                            ext=ext,
                        )
                        if text:
                            return text
                    except AppError:
                        pass

    use_deepgram = bool(settings.deepgram_api_key) and lang not in _DEEPGRAM_WEAK_LANGS
    if use_deepgram or (settings.deepgram_api_key and not settings.openai_api_key):
        try:
            text = await _deepgram_transcribe(
                data,
                content_type=mime,
                language=lang if lang not in _DEEPGRAM_WEAK_LANGS else None,
                api_key=settings.deepgram_api_key,
            )
            if text:
                return text
        except AppError as exc:
            if exc.error_code != "NO_SPEECH_DETECTED":
                errors.append(str(exc.message))
                logger.warning("Deepgram STT failed (%s)", exc.error_code)

    if settings.is_production:
        raise AppError(
            message="Audioda nutq topilmadi. Yaxshiroq eshitiladigan qilib qayta yozing",
            error_code="NO_SPEECH_DETECTED",
            status_code=400,
            extra={"detail": "; ".join(errors)} if errors else None,
        )

    logger.warning("No STT provider succeeded — using local mock (non-production only)")
    return "Hello"


async def _openai_whisper_transcribe(
    data: bytes,
    *,
    content_type: str,
    language: str | None,
    api_key: str,
    ext: str = "m4a",
) -> str:
    form_file = (f"audio.{ext}", data, content_type or f"audio/{ext}")
    data_fields: dict[str, str] = {
        "model": "whisper-1",
        "response_format": "json",
    }
    if language:
        data_fields["language"] = language

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
        params["language"] = language

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
