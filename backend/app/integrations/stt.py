"""Speech-to-text for Live / chat voice.

Order (ideal for Uzbek + multilingual):
  1) OpenAI gpt-4o-mini-transcribe (fast, strong multilingual) → whisper-1
  2) Auto-detect language if forced-lang returned empty
  3) Deepgram nova-2 (skip for known-weak Turkic codes unless nothing else worked)
  4) Production: NO_SPEECH_DETECTED; local: mock
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

# Deepgram nova-2 is unreliable for these ISO codes — Whisper first, Deepgram last.
_DEEPGRAM_WEAK_LANGS = frozenset({"uz", "kk", "ky", "tg", "tk", "az"})

_LANG_PROMPTS: dict[str, str] = {
    "uz": "O'zbek tili. Oddiy suhbat. To'g'ri o'zbekcha so'zlar.",
    "kk": "Қазақ тілі. Қарапайым сөйлесу.",
    "ky": "Кыргыз тили. Жөнөкөй сүйлөшүү.",
    "tg": "Забони тоҷикӣ. Сӯҳбати оддӣ.",
    "tr": "Türkçe konuşma. Günlük sohbet.",
    "ru": "Русская речь. Обычный разговор.",
    "en": "English speech. Everyday conversation.",
    "ar": "كلام عربي فصيح أو عامي. محادثة عادية.",
    "zh": "中文口语。日常对话。",
    "ja": "日本語の会話。日常の話し言葉。",
    "ko": "한국어 대화. 일상 회화.",
    "de": "Deutsche Sprache. Alltagsgespräch.",
    "fr": "Français parlé. Conversation quotidienne.",
    "es": "Español hablado. Conversación cotidiana.",
}


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
        "video/mp4": "mp4",
        "video/webm": "webm",
        "video/quicktime": "mp4",
    }.get(mime, "m4a")


def _stt_models(settings) -> list[str]:
    primary = (getattr(settings, "openai_stt_model", None) or "").strip()
    models: list[str] = []
    if primary:
        models.append(primary)
    for m in ("gpt-4o-mini-transcribe", "whisper-1"):
        if m not in models:
            models.append(m)
    return models


async def transcribe_audio(
    data: bytes,
    *,
    content_type: str,
    language: str | None = None,
    filename: str | None = None,
) -> str:
    if not data or len(data) < 256:
        raise AppError(
            message="Audioda nutq topilmadi. Yaxshiroq eshitiladigan qilib qayta yozing",
            error_code="NO_SPEECH_DETECTED",
            status_code=400,
        )

    settings = get_settings()
    lang = _iso_lang(language)
    ext = _guess_ext(content_type, filename)
    mime = (content_type or "").split(";")[0].strip().lower() or f"audio/{ext}"
    errors: list[str] = []

    if settings.openai_api_key:
        # 1) Forced language (best when caller knows the speaker language).
        # 2) Auto-detect (helps when forced code mismatches accent / short clips).
        attempts: list[str | None] = [lang, None] if lang else [None]
        # Prefer auto-detect first for weak Deepgram langs — Whisper lock often empties.
        if lang in _DEEPGRAM_WEAK_LANGS:
            attempts = [None, lang]

        for model in _stt_models(settings):
            for attempt_lang in attempts:
                try:
                    text = await _openai_transcribe(
                        data,
                        content_type=mime,
                        language=attempt_lang,
                        api_key=settings.openai_api_key,
                        ext=ext,
                        model=model,
                        prompt=_LANG_PROMPTS.get(lang or "") or None,
                    )
                    if text:
                        return text
                except AppError as exc:
                    if exc.error_code == "NO_SPEECH_DETECTED":
                        continue
                    if exc.error_code == "STT_MODEL_UNSUPPORTED":
                        logger.info("STT model %s unsupported — trying next", model)
                        break
                    errors.append(str(exc.message))
                    logger.warning(
                        "OpenAI STT failed model=%s lang=%s: %s",
                        model,
                        attempt_lang,
                        exc.error_code,
                    )

    # Deepgram: primary for strong langs; last resort even for weak langs.
    if settings.deepgram_api_key:
        dg_lang = None if lang in _DEEPGRAM_WEAK_LANGS else lang
        try:
            text = await _deepgram_transcribe(
                data,
                content_type=mime,
                language=dg_lang,
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


async def _openai_transcribe(
    data: bytes,
    *,
    content_type: str,
    language: str | None,
    api_key: str,
    ext: str = "m4a",
    model: str = "whisper-1",
    prompt: str | None = None,
) -> str:
    form_file = (f"audio.{ext}", data, content_type or f"audio/{ext}")
    data_fields: dict[str, str] = {
        "model": model,
        "response_format": "json",
        "temperature": "0",
    }
    if language:
        data_fields["language"] = language
    if prompt and model.startswith("whisper"):
        # prompt is supported on whisper-1; newer models may ignore it safely.
        data_fields["prompt"] = prompt[:200]

    headers = {"Authorization": f"Bearer {api_key}"}
    try:
        async with httpx.AsyncClient(timeout=45.0) as client:
            response = await client.post(
                OPENAI_WHISPER_URL,
                headers=headers,
                files={"file": form_file},
                data=data_fields,
            )
            if response.status_code in {400, 404}:
                body = (response.text or "")[:300].lower()
                if "model" in body or "invalid" in body or response.status_code == 404:
                    raise AppError(
                        message="STT model unsupported",
                        error_code="STT_MODEL_UNSUPPORTED",
                        status_code=400,
                    )
            response.raise_for_status()
            payload = response.json()
    except AppError:
        raise
    except httpx.HTTPError as exc:
        logger.exception("OpenAI STT failed model=%s", model)
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
    params: dict[str, str] = {
        "model": "nova-2",
        "smart_format": "true",
        "punctuate": "true",
    }
    if language:
        params["language"] = language
    else:
        params["detect_language"] = "true"

    headers = {
        "Authorization": f"Token {api_key}",
        "Content-Type": content_type or "application/octet-stream",
    }
    try:
        async with httpx.AsyncClient(timeout=35.0) as client:
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
