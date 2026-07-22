from __future__ import annotations

from datetime import UTC, datetime
from pathlib import Path
from uuid import uuid4

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.errors import AppError
from app.integrations.storage import get_storage
from app.integrations.stt import transcribe_audio
from app.integrations.translation import translate
from app.models.chat import LiveSession, LiveTurn
from app.models.user import User

MAX_AUDIO_BYTES = 10 * 1024 * 1024
MAX_AUDIO_SECONDS = 60
ALLOWED_AUDIO_EXTENSIONS = {".m4a", ".aac", ".wav", ".ogg", ".mp3"}
ALLOWED_AUDIO_CONTENT_TYPES = {
    "audio/mp4",
    "audio/aac",
    "audio/x-m4a",
    "audio/wav",
    "audio/x-wav",
    "audio/ogg",
    "audio/mpeg",
    "audio/mp3",
}

LIVE_LANGUAGES: list[dict] = [
    {"code": "uz", "stt": True, "tts": True, "tts_voices": ["female", "male"]},
    {"code": "en", "stt": True, "tts": True, "tts_voices": ["female", "male"]},
    {"code": "ru", "stt": True, "tts": True, "tts_voices": ["female"]},
    {"code": "de", "stt": True, "tts": True, "tts_voices": ["female"]},
    {"code": "ja", "stt": True, "tts": False, "tts_voices": []},
    {"code": "zh", "stt": True, "tts": True, "tts_voices": ["female"]},
    {"code": "tr", "stt": True, "tts": True, "tts_voices": ["female"]},
]

LANGUAGE_BY_CODE = {lang["code"]: lang for lang in LIVE_LANGUAGES}


def _has_live_access(user: User) -> bool:
    sub = user.subscription
    return bool(sub and sub.is_active and sub.plan in {"premium", "business"})


def _require_live_access(user: User) -> None:
    if not _has_live_access(user):
        raise AppError(
            message="Jonli muloqot uchun Premium tarif kerak",
            error_code="SUBSCRIPTION_REQUIRED",
            status_code=403,
            extra={"required_plan": "premium"},
        )


def _normalize_lang(code: str) -> str:
    return code.split("_")[0].lower()


def _validate_language_pair(my_language: str, other_language: str) -> tuple[str, str]:
    my_lang = _normalize_lang(my_language)
    other_lang = _normalize_lang(other_language)
    if my_lang not in LANGUAGE_BY_CODE:
        raise AppError(
            message="Tanlangan til qo'llab-quvvatlanmaydi",
            error_code="LANGUAGE_NOT_SUPPORTED",
            status_code=400,
        )
    if other_lang not in LANGUAGE_BY_CODE:
        raise AppError(
            message="Tanlangan til qo'llab-quvvatlanmaydi",
            error_code="LANGUAGE_NOT_SUPPORTED",
            status_code=400,
        )
    if not LANGUAGE_BY_CODE[my_lang]["stt"]:
        raise AppError(
            message="Tanlangan tilda STT mavjud emas",
            error_code="LANGUAGE_NOT_SUPPORTED",
            status_code=400,
        )
    return my_lang, other_lang


async def _get_owned_session(
    db: AsyncSession,
    *,
    session_id: int,
    user: User,
    allow_ended: bool = False,
) -> LiveSession:
    result = await db.execute(
        select(LiveSession)
        .where(LiveSession.id == session_id, LiveSession.user_id == user.id)
        .options(selectinload(LiveSession.turns))
    )
    session = result.scalar_one_or_none()
    if session is None:
        raise AppError(
            message="Sessiya topilmadi",
            error_code="SESSION_NOT_FOUND",
            status_code=404,
        )
    if session.ended_at is not None and not allow_ended:
        raise AppError(
            message="Sessiya yakunlangan",
            error_code="SESSION_ENDED",
            status_code=409,
        )
    return session


def _serialize_session(session: LiveSession) -> dict:
    return {
        "id": session.id,
        "my_language": session.my_language,
        "other_language": session.other_language,
        "started_at": session.started_at,
        "ended_at": session.ended_at,
    }


def _serialize_turn(turn: LiveTurn) -> dict:
    return {
        "id": turn.id,
        "client_turn_id": turn.client_turn_id,
        "session_id": turn.session_id,
        "speaker": turn.speaker,
        "source_language": turn.source_language,
        "target_language": turn.target_language,
        "text_original": turn.text_original,
        "text_translated": turn.text_translated,
        "audio_original_url": turn.audio_original_url,
        "audio_tts_url": turn.audio_tts_url,
        "audio_duration_seconds": turn.audio_duration_seconds,
        "tts_duration_seconds": turn.tts_duration_seconds,
        "status": turn.status,
        "created_at": turn.created_at,
    }


def list_languages() -> dict:
    return {"languages": LIVE_LANGUAGES}


async def create_session(
    db: AsyncSession,
    *,
    user: User,
    my_language: str,
    other_language: str,
) -> dict:
    _require_live_access(user)
    my_lang, other_lang = _validate_language_pair(my_language, other_language)

    session = LiveSession(
        user_id=user.id,
        my_language=my_lang,
        other_language=other_lang,
        started_at=datetime.now(UTC),
    )
    db.add(session)
    await db.flush()
    await db.refresh(session)
    return _serialize_session(session)


async def update_session(
    db: AsyncSession,
    *,
    user: User,
    session_id: int,
    my_language: str,
    other_language: str,
) -> dict:
    _require_live_access(user)
    my_lang, other_lang = _validate_language_pair(my_language, other_language)
    session = await _get_owned_session(db, session_id=session_id, user=user)
    session.my_language = my_lang
    session.other_language = other_lang
    await db.flush()
    return _serialize_session(session)


async def end_session(db: AsyncSession, *, user: User, session_id: int) -> dict:
    session = await _get_owned_session(db, session_id=session_id, user=user, allow_ended=True)
    if session.ended_at is None:
        session.ended_at = datetime.now(UTC)
        await db.flush()
    return _serialize_session(session)


def _validate_audio(filename: str, content_type: str, data: bytes) -> str:
    ext = Path(filename or "").suffix.lower()
    if ext not in ALLOWED_AUDIO_EXTENSIONS and content_type not in ALLOWED_AUDIO_CONTENT_TYPES:
        raise AppError(
            message="Audio format qo'llab-quvvatlanmaydi",
            error_code="UNSUPPORTED_AUDIO_FORMAT",
            status_code=400,
        )
    if len(data) > MAX_AUDIO_BYTES:
        raise AppError(
            message="Audio fayl juda katta",
            error_code="FILE_TOO_LARGE",
            status_code=413,
        )
    if not data:
        raise AppError(
            message="Audioda nutq topilmadi",
            error_code="NO_SPEECH_DETECTED",
            status_code=400,
        )
    return ext or ".m4a"


async def create_turn(
    db: AsyncSession,
    *,
    user: User,
    session_id: int,
    speaker: str,
    client_turn_id: str,
    filename: str,
    content_type: str,
    data: bytes,
) -> dict:
    _require_live_access(user)

    if speaker not in {"me", "other"}:
        raise AppError(
            message="Spiker 'me' yoki 'other' bo'lishi kerak",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )

    session = await _get_owned_session(db, session_id=session_id, user=user)

    existing = await db.execute(
        select(LiveTurn).where(
            LiveTurn.session_id == session.id,
            LiveTurn.client_turn_id == client_turn_id,
        )
    )
    existing_turn = existing.scalar_one_or_none()
    if existing_turn is not None:
        return _serialize_turn(existing_turn)

    ext = _validate_audio(filename, content_type, data)

    if speaker == "me":
        source_language = session.my_language
        target_language = session.other_language
    else:
        source_language = session.other_language
        target_language = session.my_language

    text_original = await transcribe_audio(
        data,
        content_type=content_type or "application/octet-stream",
        language=source_language,
    )
    if not text_original.strip():
        raise AppError(
            message="Audioda nutq topilmadi",
            error_code="NO_SPEECH_DETECTED",
            status_code=400,
        )

    text_translated = await translate(
        text_original,
        target_lang=target_language,
        source_lang=source_language,
    )

    storage = get_storage()
    audio_key = f"live/{session.id}/{uuid4().hex}{ext}"
    audio_original_url = await storage.upload_bytes(
        audio_key,
        data,
        content_type or "application/octet-stream",
    )

    target_meta = LANGUAGE_BY_CODE.get(target_language, {})
    audio_tts_url: str | None = None
    if target_meta.get("tts"):
        audio_tts_url = None

    turn = LiveTurn(
        session_id=session.id,
        client_turn_id=client_turn_id,
        speaker=speaker,
        source_language=source_language,
        target_language=target_language,
        text_original=text_original,
        text_translated=text_translated,
        audio_original_url=audio_original_url,
        audio_tts_url=audio_tts_url,
        audio_duration_seconds=min(MAX_AUDIO_SECONDS, max(1, len(data) // 8000)),
        tts_duration_seconds=None,
        status="done",
    )
    db.add(turn)
    await db.flush()
    await db.refresh(turn)
    return _serialize_turn(turn)


async def list_turns(
    db: AsyncSession,
    *,
    user: User,
    session_id: int,
    limit: int,
    before_id: int | None,
) -> dict:
    await _get_owned_session(db, session_id=session_id, user=user, allow_ended=True)

    safe_limit = min(max(limit, 1), 100)
    query = select(LiveTurn).where(LiveTurn.session_id == session_id)
    if before_id is not None:
        query = query.where(LiveTurn.id < before_id)

    result = await db.execute(query.order_by(LiveTurn.id.asc()).limit(safe_limit + 1))
    turns = list(result.scalars().all())
    has_more = len(turns) > safe_limit
    items = turns[:safe_limit]

    return {
        "items": [_serialize_turn(turn) for turn in items],
        "has_more": has_more,
    }
