from __future__ import annotations

import asyncio
import logging
from datetime import UTC, datetime, timedelta
from pathlib import Path
from uuid import uuid4

from fastapi.responses import Response
from sqlalchemy import func, or_, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.errors import AppError
from app.integrations.live_export import build_export_pdf, build_export_text
from app.integrations.ocr import extract_text_from_image
from app.integrations.storage import get_storage
from app.integrations.stt import transcribe_audio
from app.integrations.tts import synthesize_speech
from app.integrations.translation import translate
from app.models.chat import LiveSession, LiveTurn
from app.models.user import User

logger = logging.getLogger(__name__)

MAX_AUDIO_BYTES = 10 * 1024 * 1024
MAX_AUDIO_SECONDS = 60
ALLOWED_AUDIO_EXTENSIONS = {".m4a", ".aac", ".wav", ".ogg", ".mp3"}
ALLOWED_AUDIO_CONTENT_TYPES = {
    "audio/mp4",
    "audio/aac",
    "audio/x-m4a",
    "audio/m4a",
    "audio/wav",
    "audio/x-wav",
    "audio/ogg",
    "audio/mpeg",
    "audio/mp3",
    "application/octet-stream",
}

from app.services.language_catalog import live_language_dicts

LIVE_LANGUAGES: list[dict] = live_language_dicts()
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


def _serialize_session(
    session: LiveSession,
    *,
    turn_count: int = 0,
    preview: str | None = None,
) -> dict:
    return {
        "id": session.id,
        "my_language": session.my_language,
        "other_language": session.other_language,
        "started_at": session.started_at,
        "ended_at": session.ended_at,
        "turn_count": turn_count,
        "preview": preview,
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


def _normalize_tts_voice(voice: str | None, *, available: list[str] | None) -> str:
    v = (voice or "female").strip().lower()
    if v not in {"female", "male"}:
        v = "female"
    opts = list(available or [])
    if opts and v not in opts:
        v = opts[0]
    return v


def _normalize_tts_speed(speed: float | None) -> float:
    if speed is None:
        return 1.0
    try:
        return max(0.5, min(2.0, float(speed)))
    except (TypeError, ValueError):
        return 1.0


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
    tts_voice: str | None = None,
    tts_speed: float | None = None,
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
        filename=filename,
    )
    if not text_original.strip():
        raise AppError(
            message="Audioda nutq topilmadi",
            error_code="NO_SPEECH_DETECTED",
            status_code=400,
        )

    storage = get_storage()
    audio_key = f"live/{session.id}/{uuid4().hex}{ext}"

    async def _upload_original() -> str:
        return await storage.upload_bytes(
            audio_key,
            data,
            content_type or "application/octet-stream",
        )

    async def _fast_translate() -> str:
        return await translate(
            text_original,
            target_lang=target_language,
            source_lang=source_language,
            domain="general",
            fast=True,
        )

    # Parallel: translation + original audio upload (biggest latency win after STT).
    text_translated, audio_original_url = await asyncio.gather(
        _fast_translate(),
        _upload_original(),
    )

    target_meta = LANGUAGE_BY_CODE.get(target_language, {})
    audio_tts_url: str | None = None
    tts_duration_seconds: int | None = None
    if target_meta.get("tts") and (text_translated or "").strip():
        voice = _normalize_tts_voice(
            tts_voice,
            available=list(target_meta.get("tts_voices") or []),
        )
        speed = _normalize_tts_speed(tts_speed)
        try:
            synthesized = await synthesize_speech(
                text_translated,
                language=target_language,
                voice=voice,
                speed=speed,
                fast=True,
            )
            if synthesized is not None:
                tts_bytes, tts_ctype, tts_dur = synthesized
                tts_key = f"live/{session.id}/{uuid4().hex}.mp3"
                audio_tts_url = await storage.upload_bytes(
                    tts_key,
                    tts_bytes,
                    tts_ctype or "audio/mpeg",
                )
                tts_duration_seconds = max(1, int(round(tts_dur)))
        except Exception:
            # Partial success: keep STT + translation even if TTS fails.
            logger.exception("Live TTS failed session=%s", session.id)
            audio_tts_url = None
            tts_duration_seconds = None

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
        tts_duration_seconds=tts_duration_seconds,
        status="done",
    )
    db.add(turn)
    try:
        await db.flush()
    except IntegrityError:
        await db.rollback()
        # Concurrent retry with same client_turn_id — return existing row.
        raced = await db.execute(
            select(LiveTurn).where(
                LiveTurn.session_id == session.id,
                LiveTurn.client_turn_id == client_turn_id,
            )
        )
        existing_race = raced.scalar_one_or_none()
        if existing_race is None:
            raise
        return _serialize_turn(existing_race)
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

    # Newest page first (desc), then reverse for chronological UI order.
    # Asc+limit previously skipped the turns just before the cursor.
    result = await db.execute(query.order_by(LiveTurn.id.desc()).limit(safe_limit + 1))
    turns = list(result.scalars().all())
    has_more = len(turns) > safe_limit
    items = list(reversed(turns[:safe_limit]))

    return {
        "items": [_serialize_turn(turn) for turn in items],
        "has_more": has_more,
    }


def _day_bounds_utc(now: datetime | None = None) -> tuple[datetime, datetime]:
    n = now or datetime.now(UTC)
    if n.tzinfo is None:
        n = n.replace(tzinfo=UTC)
    start = datetime(n.year, n.month, n.day, tzinfo=UTC)
    end = start + timedelta(days=1)
    return start, end


async def list_sessions(
    db: AsyncSession,
    *,
    user: User,
    today_only: bool = True,
    q: str | None = None,
    limit: int = 40,
) -> dict:
    _require_live_access(user)
    safe_limit = min(max(limit, 1), 100)
    query = select(LiveSession).where(LiveSession.user_id == user.id)
    if today_only:
        start, end = _day_bounds_utc()
        query = query.where(
            LiveSession.started_at >= start,
            LiveSession.started_at < end,
        )

    search = (q or "").strip()
    if search:
        pattern = f"%{search}%"
        turn_match = (
            select(LiveTurn.session_id)
            .where(
                or_(
                    LiveTurn.text_original.ilike(pattern),
                    LiveTurn.text_translated.ilike(pattern),
                )
            )
            .distinct()
        )
        query = query.where(
            or_(
                LiveSession.my_language.ilike(pattern),
                LiveSession.other_language.ilike(pattern),
                LiveSession.id.in_(turn_match),
            )
        )

    result = await db.execute(
        query.order_by(LiveSession.started_at.desc()).limit(safe_limit + 1)
    )
    sessions = list(result.scalars().all())
    has_more = len(sessions) > safe_limit
    sessions = sessions[:safe_limit]

    items: list[dict] = []
    for session in sessions:
        count_row = await db.execute(
            select(func.count())
            .select_from(LiveTurn)
            .where(LiveTurn.session_id == session.id)
        )
        turn_count = int(count_row.scalar_one() or 0)
        preview_row = await db.execute(
            select(LiveTurn)
            .where(
                LiveTurn.session_id == session.id,
                LiveTurn.text_original.is_not(None),
            )
            .order_by(LiveTurn.id.desc())
            .limit(1)
        )
        last_turn = preview_row.scalar_one_or_none()
        preview = None
        if last_turn is not None:
            preview = (last_turn.text_original or last_turn.text_translated or "").strip()
            if len(preview) > 120:
                preview = preview[:117] + "…"
        items.append(
            _serialize_session(session, turn_count=turn_count, preview=preview)
        )

    return {"items": items, "has_more": has_more}


async def _session_bundle(
    db: AsyncSession,
    *,
    user: User,
    session_id: int,
) -> dict:
    session = await _get_owned_session(
        db, session_id=session_id, user=user, allow_ended=True
    )
    turns_result = await db.execute(
        select(LiveTurn)
        .where(LiveTurn.session_id == session.id)
        .order_by(LiveTurn.id.asc())
    )
    turns = list(turns_result.scalars().all())
    return {
        **_serialize_session(session, turn_count=len(turns)),
        "turns": [_serialize_turn(t) for t in turns],
    }


async def export_history(
    db: AsyncSession,
    *,
    user: User,
    fmt: str = "txt",
    session_id: int | None = None,
    today_only: bool = True,
) -> Response:
    _require_live_access(user)
    fmt_n = (fmt or "txt").strip().lower()
    if fmt_n not in {"txt", "pdf"}:
        raise AppError(
            message="format txt yoki pdf bo'lishi kerak",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )

    bundles: list[dict] = []
    if session_id is not None:
        bundles.append(await _session_bundle(db, user=user, session_id=session_id))
    else:
        listed = await list_sessions(
            db, user=user, today_only=today_only, q=None, limit=100
        )
        for item in listed["items"]:
            bundles.append(await _session_bundle(db, user=user, session_id=item["id"]))

    title = "AnyLang · Jonli suhbatlar"
    if today_only and session_id is None:
        title = "AnyLang · Bugungi jonli suhbatlar"
    elif session_id is not None:
        title = f"AnyLang · Jonli sessiya #{session_id}"

    stamp = datetime.now(UTC).strftime("%Y%m%d_%H%M")
    if fmt_n == "pdf":
        data = build_export_pdf(title=title, sessions=bundles)
        filename = f"anylang_jonli_{stamp}.pdf"
        media = "application/pdf"
    else:
        text = build_export_text(title=title, sessions=bundles)
        data = text.encode("utf-8")
        filename = f"anylang_jonli_{stamp}.txt"
        media = "text/plain; charset=utf-8"

    return Response(
        content=data,
        media_type=media,
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"',
        },
    )


ALLOWED_IMAGE_CONTENT_TYPES = {
    "image/jpeg",
    "image/jpg",
    "image/png",
    "image/webp",
    "image/gif",
    "application/octet-stream",
}


async def ocr_translate(
    db: AsyncSession,
    *,
    user: User,
    data: bytes,
    filename: str,
    content_type: str,
    target_language: str,
    source_language: str | None = None,
    session_id: int | None = None,
    client_turn_id: str | None = None,
    tts_voice: str | None = "female",
    tts_speed: float | None = 1.0,
) -> dict:
    """Kamera/rasm → OCR → tarjima (+ ixtiyoriy TTS / sessiya turn)."""
    _require_live_access(user)

    mime = (content_type or "").split(";")[0].strip().lower()
    ext = Path(filename or "").suffix.lower()
    if mime not in ALLOWED_IMAGE_CONTENT_TYPES and ext not in {
        ".jpg",
        ".jpeg",
        ".png",
        ".webp",
        ".gif",
    }:
        raise AppError(
            message="Rasm formati qo'llab-quvvatlanmaydi",
            error_code="UNSUPPORTED_IMAGE_FORMAT",
            status_code=400,
        )

    target = _normalize_lang(target_language)
    if target not in LANGUAGE_BY_CODE:
        raise AppError(
            message="Tanlangan til qo'llab-quvvatlanmaydi",
            error_code="LANGUAGE_NOT_SUPPORTED",
            status_code=400,
        )

    source_hint = _normalize_lang(source_language) if source_language else None
    ocr = await extract_text_from_image(
        data,
        content_type=content_type,
        filename=filename,
        hint_lang=source_hint,
    )
    text_original = (ocr.get("text") or "").strip()
    if not text_original:
        raise AppError(
            message="Rasmdan matn topilmadi",
            error_code="NO_TEXT_DETECTED",
            status_code=400,
        )

    detected = ocr.get("detected_language")
    source = source_hint or (str(detected).strip().lower() if detected else None)
    if source == target:
        text_translated = text_original
    else:
        text_translated = await translate(
            text_original,
            target_lang=target,
            source_lang=source,
            domain=getattr(user, "translation_domain", None),
        )

    audio_tts_url: str | None = None
    target_meta = LANGUAGE_BY_CODE.get(target, {})
    if target_meta.get("tts") and text_translated.strip():
        voice = _normalize_tts_voice(
            tts_voice,
            available=list(target_meta.get("tts_voices") or []),
        )
        speed = _normalize_tts_speed(tts_speed)
        try:
            synthesized = await synthesize_speech(
                text_translated,
                language=target,
                voice=voice,
                speed=speed,
            )
            if synthesized is not None:
                tts_bytes, tts_ctype, _ = synthesized
                storage = get_storage()
                tts_key = f"live/ocr/{user.id}/{uuid4().hex}.mp3"
                audio_tts_url = await storage.upload_bytes(
                    tts_key,
                    tts_bytes,
                    tts_ctype or "audio/mpeg",
                )
        except Exception:
            audio_tts_url = None

    turn_id: int | None = None
    created_at: datetime | None = None
    resolved_client_id = (client_turn_id or "").strip() or f"ocr_{uuid4().hex[:16]}"
    resolved_session_id = session_id

    if session_id is not None:
        session = await _get_owned_session(
            db, session_id=session_id, user=user, allow_ended=False
        )
        # Kamera: tashqi matn → foydalanuvchi tiliga (my_language ga yaqin).
        turn = LiveTurn(
            session_id=session.id,
            client_turn_id=resolved_client_id,
            speaker="me",
            source_language=source or session.other_language,
            target_language=target,
            text_original=text_original,
            text_translated=text_translated,
            audio_original_url=None,
            audio_tts_url=audio_tts_url,
            audio_duration_seconds=None,
            tts_duration_seconds=None,
            status="done",
        )
        db.add(turn)
        try:
            await db.flush()
        except IntegrityError:
            await db.rollback()
            raced = await db.execute(
                select(LiveTurn).where(
                    LiveTurn.session_id == session.id,
                    LiveTurn.client_turn_id == resolved_client_id,
                )
            )
            existing_race = raced.scalar_one_or_none()
            if existing_race is None:
                raise
            turn = existing_race
        else:
            await db.refresh(turn)
        turn_id = turn.id
        created_at = turn.created_at
        resolved_session_id = session.id

        # Prefer persisted TTS/text from the winning row on race.
        text_original = turn.text_original or text_original
        text_translated = turn.text_translated or text_translated
        audio_tts_url = turn.audio_tts_url or audio_tts_url
        source = turn.source_language or source
        target = turn.target_language or target

    return {
        "text_original": text_original,
        "text_translated": text_translated,
        "source_language": source,
        "target_language": target,
        "audio_tts_url": audio_tts_url,
        "session_id": resolved_session_id,
        "turn_id": turn_id,
        "client_turn_id": resolved_client_id,
        "created_at": created_at or datetime.now(UTC),
    }
