"""Text-to-speech for Jonli: ElevenLabs (preferred) → OpenAI TTS → none.

Natural multilingual voices with male/female + speed (0.5–2.0).
"""

from __future__ import annotations

import logging
from typing import Literal

import httpx

from app.core.config import get_settings

logger = logging.getLogger(__name__)

TtsVoice = Literal["female", "male"]

ELEVEN_TTS_URL = "https://api.elevenlabs.io/v1/text-to-speech/{voice_id}"
OPENAI_SPEECH_URL = "https://api.openai.com/v1/audio/speech"

# Public ElevenLabs default voices (multilingual-capable).
_ELEVEN_DEFAULT_VOICES: dict[str, str] = {
    "female": "21m00Tcm4TlvDq8ikWAM",  # Rachel
    "male": "pNInz6obpgDQGcFmaJgB",  # Adam
}

# OpenAI TTS-1-HD voices — natural, multilingual.
_OPENAI_VOICES: dict[str, str] = {
    "female": "nova",
    "male": "onyx",
}


def _clamp_speed(speed: float | None) -> float:
    if speed is None:
        return 1.0
    try:
        return max(0.5, min(2.0, float(speed)))
    except (TypeError, ValueError):
        return 1.0


def _normalize_voice(voice: str | None) -> TtsVoice:
    v = (voice or "female").strip().lower()
    return "male" if v == "male" else "female"


async def synthesize_speech(
    text: str,
    *,
    language: str | None = None,
    voice: str | None = "female",
    speed: float | None = 1.0,
    fast: bool = False,
) -> tuple[bytes, str, float] | None:
    """Return (audio_bytes, content_type, duration_hint_seconds) or None on failure."""
    cleaned = (text or "").strip()
    if not cleaned:
        return None

    gender = _normalize_voice(voice)
    rate = _clamp_speed(speed)
    settings = get_settings()

    if (settings.elevenlabs_api_key or "").strip():
        try:
            result = await _elevenlabs_tts(
                cleaned,
                voice=gender,
                speed=rate,
                api_key=settings.elevenlabs_api_key.strip(),
                female_voice_id=(settings.elevenlabs_voice_female or "").strip(),
                male_voice_id=(settings.elevenlabs_voice_male or "").strip(),
            )
            if result is not None:
                return result
        except Exception as exc:
            logger.warning("ElevenLabs TTS failed: %s", exc)

    if (settings.openai_api_key or "").strip():
        try:
            result = await _openai_tts(
                cleaned,
                voice=gender,
                speed=rate,
                api_key=settings.openai_api_key.strip(),
                language=language,
                # Live: tts-1 (~2x faster than tts-1-hd).
                model="tts-1" if fast else "tts-1-hd",
            )
            if result is not None:
                return result
        except Exception as exc:
            logger.warning("OpenAI TTS failed: %s", exc)

    return None


async def _elevenlabs_tts(
    text: str,
    *,
    voice: TtsVoice,
    speed: float,
    api_key: str,
    female_voice_id: str,
    male_voice_id: str,
) -> tuple[bytes, str, float] | None:
    voice_id = (
        (male_voice_id if voice == "male" else female_voice_id)
        or _ELEVEN_DEFAULT_VOICES[voice]
    )
    # ElevenLabs accepts ~0.7–1.2; clamp and let client handle extreme rates.
    eleven_speed = max(0.7, min(1.2, speed))
    url = ELEVEN_TTS_URL.format(voice_id=voice_id)
    payload = {
        "text": text[:2500],
        "model_id": "eleven_multilingual_v2",
        "speed": eleven_speed,
        "voice_settings": {
            "stability": 0.4,
            "similarity_boost": 0.8,
            "style": 0.35,
            "use_speaker_boost": True,
            "speed": eleven_speed,
        },
    }

    async with httpx.AsyncClient(timeout=25.0) as client:
        resp = await client.post(
            url,
            headers={
                "xi-api-key": api_key,
                "Accept": "audio/mpeg",
                "Content-Type": "application/json",
            },
            json=payload,
            params={"output_format": "mp3_44100_128"},
        )
        if resp.status_code >= 400:
            logger.warning(
                "ElevenLabs TTS HTTP %s: %s",
                resp.status_code,
                (resp.text or "")[:200],
            )
            return None
        data = resp.content
        if not data:
            return None
        # Rough duration hint from bitrate (~16KB/s for 128kbps mp3).
        duration = max(1.0, len(data) / 16000.0)
        return data, "audio/mpeg", duration


async def _openai_tts(
    text: str,
    *,
    voice: TtsVoice,
    speed: float,
    api_key: str,
    language: str | None,
    model: str = "tts-1-hd",
) -> tuple[bytes, str, float] | None:
    del language  # OpenAI TTS auto-detects; kept for API symmetry.
    payload = {
        "model": model or "tts-1-hd",
        "input": text[:4096],
        "voice": _OPENAI_VOICES[voice],
        "response_format": "mp3",
        "speed": max(0.5, min(2.0, speed)),
    }
    async with httpx.AsyncClient(timeout=20.0) as client:
        resp = await client.post(
            OPENAI_SPEECH_URL,
            headers={
                "Authorization": f"Bearer {api_key}",
                "Content-Type": "application/json",
            },
            json=payload,
        )
        if resp.status_code >= 400:
            logger.warning(
                "OpenAI TTS HTTP %s: %s",
                resp.status_code,
                (resp.text or "")[:200],
            )
            return None
        data = resp.content
        if not data:
            return None
        duration = max(1.0, len(data) / 16000.0)
        return data, "audio/mpeg", duration
