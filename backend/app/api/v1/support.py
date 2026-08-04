from __future__ import annotations

import logging

from fastapi import APIRouter, Query, Request
from sqlalchemy.exc import SQLAlchemyError

from app.api.deps_auth import CurrentUser
from app.core.deps import DbSession, RedisClient
from app.core.errors import AppError
from app.core.rate_limit import client_ip, enforce_rate_limit
from app.schemas.support import (
    SupportChatIn,
    SupportChatOut,
    SupportRateIn,
    SupportSessionListOut,
    SupportSessionOut,
)
from app.services import support_chat as support_service
from app.services import support_sessions as support_sessions_service

router = APIRouter()
_log = logging.getLogger(__name__)


@router.get("/sessions/active", response_model=SupportSessionOut | None)
async def support_active_session(
    db: DbSession,
    current_user: CurrentUser,
) -> SupportSessionOut | None:
    data = await support_sessions_service.get_active_session(db, user=current_user)
    if data is None:
        return None
    return SupportSessionOut.model_validate(data)


@router.get("/sessions", response_model=SupportSessionListOut)
async def support_list_sessions(
    db: DbSession,
    current_user: CurrentUser,
    limit: int = Query(default=50, ge=1, le=100),
) -> SupportSessionListOut:
    data = await support_sessions_service.list_sessions(
        db, user=current_user, limit=limit
    )
    return SupportSessionListOut.model_validate(data)


@router.get("/sessions/{session_id}", response_model=SupportSessionOut)
async def support_get_session(
    session_id: int,
    db: DbSession,
    current_user: CurrentUser,
) -> SupportSessionOut:
    data = await support_sessions_service.get_session(
        db, user=current_user, session_id=session_id
    )
    return SupportSessionOut.model_validate(data)


@router.post("/sessions/{session_id}/rate", response_model=SupportSessionOut)
async def support_rate_session(
    session_id: int,
    body: SupportRateIn,
    db: DbSession,
    current_user: CurrentUser,
) -> SupportSessionOut:
    data = await support_sessions_service.rate_session(
        db,
        user=current_user,
        session_id=session_id,
        rating=body.rating,
    )
    return SupportSessionOut.model_validate(data)


@router.post("/chat", response_model=SupportChatOut)
async def support_chat(
    body: SupportChatIn,
    db: DbSession,
    current_user: CurrentUser,
) -> SupportChatOut:
    try:
        data = await support_sessions_service.chat_in_session(
            db,
            user=current_user,
            message=body.message,
            locale=body.locale,
            session_id=body.session_id,
        )
        return SupportChatOut.model_validate(data)
    except AppError:
        raise
    except SQLAlchemyError as exc:
        # Session persistence must not block Sofiya replies (MissingGreenlet / schema).
        _log.exception("support session chat failed; falling back to stateless: %s", exc)
        try:
            await db.rollback()
        except SQLAlchemyError:
            pass
        reply = await support_service.reply_support(
            message=body.message,
            history=body.history,
            locale=body.locale,
            source="app",
        )
        return SupportChatOut(
            reply=reply,
            agent_name=support_service.agent_name(),
            session_id=body.session_id or 0,
        )
    except Exception as exc:
        _log.exception("support session chat unexpected error: %s", exc)
        raise AppError(
            message="Qo'llab-quvvatlash vaqtincha mavjud emas",
            error_code="SERVICE_UNAVAILABLE",
            status_code=503,
        ) from exc


@router.post("/public", response_model=SupportChatOut)
async def support_chat_public(
    body: SupportChatIn,
    request: Request,
    redis: RedisClient,
) -> SupportChatOut:
    """Landing / sayt uchun ochiq qo'llab-quvvatlash (authsiz, rate-limit)."""
    ip = client_ip(request)
    await enforce_rate_limit(
        redis,
        f"support:public:ip:{ip}",
        limit=20,
        window_seconds=3600,
        message="Juda ko'p so'rov. Biroz kutib qayta yozing",
    )
    reply = await support_service.reply_support(
        message=body.message,
        history=body.history,
        locale=body.locale,
        source="landing",
    )
    return SupportChatOut(
        reply=reply,
        agent_name=support_service.agent_name(),
        session_id=0,
    )
