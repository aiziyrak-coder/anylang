from __future__ import annotations

from fastapi import APIRouter, File, Form, Query, UploadFile, status
from fastapi.responses import Response

from app.api.deps_auth import CurrentUser
from app.core.deps import DbSession
from app.core.uploads import read_upload_limited
from app.schemas.live import (
    LiveLanguagesOut,
    LiveOcrTranslateOut,
    LiveSessionCreateIn,
    LiveSessionListOut,
    LiveSessionOut,
    LiveSessionUpdateIn,
    LiveTurnListOut,
    LiveTurnOut,
)
from app.services import live as live_service

router = APIRouter()


@router.get("/languages", response_model=LiveLanguagesOut)
async def list_languages() -> LiveLanguagesOut:
    return LiveLanguagesOut.model_validate(live_service.list_languages())


@router.post("/ocr-translate", response_model=LiveOcrTranslateOut)
async def ocr_translate(
    db: DbSession,
    current_user: CurrentUser,
    image: UploadFile = File(...),
    target_language: str = Form(...),
    source_language: str | None = Form(default=None),
    session_id: int | None = Form(default=None),
    client_turn_id: str | None = Form(default=None),
    tts_voice: str | None = Form(default="female"),
    tts_speed: float | None = Form(default=1.0),
) -> LiveOcrTranslateOut:
    content = await read_upload_limited(image, max_bytes=8 * 1024 * 1024)
    data = await live_service.ocr_translate(
        db,
        user=current_user,
        data=content,
        filename=image.filename or "photo.jpg",
        content_type=image.content_type or "image/jpeg",
        target_language=target_language,
        source_language=source_language,
        session_id=session_id,
        client_turn_id=client_turn_id,
        tts_voice=tts_voice,
        tts_speed=tts_speed,
    )
    return LiveOcrTranslateOut.model_validate(data)


@router.get("/sessions", response_model=LiveSessionListOut)
async def list_sessions(
    db: DbSession,
    current_user: CurrentUser,
    today: bool = Query(default=True),
    q: str | None = Query(default=None, max_length=120),
    limit: int = Query(default=40, ge=1, le=100),
) -> LiveSessionListOut:
    data = await live_service.list_sessions(
        db,
        user=current_user,
        today_only=today,
        q=q,
        limit=limit,
    )
    return LiveSessionListOut.model_validate(data)


@router.get("/sessions/export")
async def export_sessions(
    db: DbSession,
    current_user: CurrentUser,
    format: str = Query(default="txt", pattern="^(txt|pdf)$"),
    today: bool = Query(default=True),
    session_id: int | None = Query(default=None, ge=1),
) -> Response:
    return await live_service.export_history(
        db,
        user=current_user,
        fmt=format,
        session_id=session_id,
        today_only=today,
    )


@router.post("/sessions", response_model=LiveSessionOut, status_code=status.HTTP_201_CREATED)
async def create_session(
    body: LiveSessionCreateIn,
    db: DbSession,
    current_user: CurrentUser,
) -> LiveSessionOut:
    data = await live_service.create_session(
        db,
        user=current_user,
        my_language=body.my_language,
        other_language=body.other_language,
    )
    return LiveSessionOut.model_validate(data)


@router.patch("/sessions/{session_id}", response_model=LiveSessionOut)
async def update_session(
    session_id: int,
    body: LiveSessionUpdateIn,
    db: DbSession,
    current_user: CurrentUser,
) -> LiveSessionOut:
    data = await live_service.update_session(
        db,
        user=current_user,
        session_id=session_id,
        my_language=body.my_language,
        other_language=body.other_language,
    )
    return LiveSessionOut.model_validate(data)


@router.post("/sessions/{session_id}/end", response_model=LiveSessionOut)
async def end_session(
    session_id: int,
    db: DbSession,
    current_user: CurrentUser,
) -> LiveSessionOut:
    data = await live_service.end_session(db, user=current_user, session_id=session_id)
    return LiveSessionOut.model_validate(data)


@router.post(
    "/sessions/{session_id}/turns",
    response_model=LiveTurnOut,
    status_code=status.HTTP_201_CREATED,
)
async def create_turn(
    session_id: int,
    db: DbSession,
    current_user: CurrentUser,
    audio: UploadFile = File(...),
    speaker: str = Form(...),
    client_turn_id: str = Form(...),
    tts_voice: str | None = Form(default="female"),
    tts_speed: float | None = Form(default=1.0),
) -> LiveTurnOut:
    content = await read_upload_limited(audio, max_bytes=10 * 1024 * 1024)
    data = await live_service.create_turn(
        db,
        user=current_user,
        session_id=session_id,
        speaker=speaker,
        client_turn_id=client_turn_id,
        filename=audio.filename or "audio.m4a",
        content_type=audio.content_type or "application/octet-stream",
        data=content,
        tts_voice=tts_voice,
        tts_speed=tts_speed,
    )
    return LiveTurnOut.model_validate(data)


@router.get("/sessions/{session_id}/turns", response_model=LiveTurnListOut)
async def list_turns(
    session_id: int,
    db: DbSession,
    current_user: CurrentUser,
    limit: int = Query(default=50, ge=1, le=100),
    before_id: int | None = Query(default=None, ge=1),
) -> LiveTurnListOut:
    data = await live_service.list_turns(
        db,
        user=current_user,
        session_id=session_id,
        limit=limit,
        before_id=before_id,
    )
    return LiveTurnListOut.model_validate(data)
