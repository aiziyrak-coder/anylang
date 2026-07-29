from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy import inspect as sa_inspect, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.errors import AppError
from app.models.support import SupportMessage, SupportSession
from app.models.user import User
from app.schemas.support import SupportHistoryItem
from app.services import support_chat as support_chat_service


def _loaded_messages(session: SupportSession) -> list[SupportMessage]:
    """Return messages without triggering async lazy-load (MissingGreenlet)."""
    insp = sa_inspect(session)
    if "messages" in insp.unloaded:
        return []
    return list(session.messages)


def _session_to_dict(session: SupportSession, *, include_messages: bool) -> dict:
    data: dict = {
        "id": session.id,
        "status": session.status,
        "locale": session.locale,
        "rating": session.rating,
        "preview": session.preview,
        "created_at": session.created_at,
        "updated_at": session.updated_at,
        "closed_at": session.closed_at,
        "messages": [],
    }
    if include_messages:
        data["messages"] = [
            {
                "id": m.id,
                "role": m.role,
                "content": m.content,
                "created_at": m.created_at,
            }
            for m in _loaded_messages(session)
        ]
    return data


async def get_active_session(db: AsyncSession, *, user: User) -> dict | None:
    result = await db.execute(
        select(SupportSession)
        .where(
            SupportSession.user_id == user.id,
            SupportSession.status == "active",
        )
        .options(selectinload(SupportSession.messages))
        .order_by(SupportSession.id.desc())
        .limit(1)
    )
    session = result.scalar_one_or_none()
    if session is None:
        return None
    return _session_to_dict(session, include_messages=True)


async def list_sessions(
    db: AsyncSession,
    *,
    user: User,
    limit: int = 50,
) -> dict:
    result = await db.execute(
        select(SupportSession)
        .where(SupportSession.user_id == user.id)
        .order_by(SupportSession.updated_at.desc())
        .limit(limit)
    )
    sessions = result.scalars().all()
    return {
        "items": [_session_to_dict(s, include_messages=False) for s in sessions],
    }


async def get_session(
    db: AsyncSession,
    *,
    user: User,
    session_id: int,
) -> dict:
    result = await db.execute(
        select(SupportSession)
        .where(
            SupportSession.id == session_id,
            SupportSession.user_id == user.id,
        )
        .options(selectinload(SupportSession.messages))
    )
    session = result.scalar_one_or_none()
    if session is None:
        raise AppError(
            message="Yozishma topilmadi",
            error_code="SUPPORT_SESSION_NOT_FOUND",
            status_code=404,
        )
    return _session_to_dict(session, include_messages=True)


async def _get_or_create_active_session(
    db: AsyncSession,
    *,
    user: User,
    locale: str,
    session_id: int | None,
) -> SupportSession:
    if session_id is not None:
        result = await db.execute(
            select(SupportSession)
            .where(
                SupportSession.id == session_id,
                SupportSession.user_id == user.id,
            )
            .options(selectinload(SupportSession.messages))
        )
        session = result.scalar_one_or_none()
        if session is None:
            raise AppError(
                message="Yozishma topilmadi",
                error_code="SUPPORT_SESSION_NOT_FOUND",
                status_code=404,
            )
        if session.status != "active":
            raise AppError(
                message="Yozishma yakunlangan",
                error_code="SUPPORT_SESSION_CLOSED",
                status_code=400,
            )
        return session

    result = await db.execute(
        select(SupportSession)
        .where(
            SupportSession.user_id == user.id,
            SupportSession.status == "active",
        )
        .options(selectinload(SupportSession.messages))
        .order_by(SupportSession.id.desc())
        .limit(1)
    )
    existing = result.scalar_one_or_none()
    if existing is not None:
        return existing

    session = SupportSession(
        user_id=user.id,
        status="active",
        locale=(locale or "uz")[:16],
    )
    # Init empty collection while pending — after flush, lazy-load would 500.
    session.messages = []
    db.add(session)
    await db.flush()
    return session


def _history_from_session(session: SupportSession) -> list[SupportHistoryItem]:
    items: list[SupportHistoryItem] = []
    for m in _loaded_messages(session):
        role = m.role if m.role in {"user", "assistant"} else "user"
        content = (m.content or "").strip()
        if not content:
            continue
        items.append(SupportHistoryItem(role=role, content=content))
    return items


async def chat_in_session(
    db: AsyncSession,
    *,
    user: User,
    message: str,
    locale: str,
    session_id: int | None,
) -> dict:
    text = message.strip()
    if not text:
        raise AppError(
            message="Xabar bo'sh",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )

    session = await _get_or_create_active_session(
        db,
        user=user,
        locale=locale,
        session_id=session_id,
    )

    history = _history_from_session(session)
    reply = await support_chat_service.reply_support(
        message=text,
        history=history,
        locale=locale,
        source="app",
    )

    user_msg = SupportMessage(role="user", content=text[:2000])
    assistant_msg = SupportMessage(role="assistant", content=reply[:4000])
    # Append via relationship — keeps collection loaded, no lazy-load later.
    session.messages.append(user_msg)
    session.messages.append(assistant_msg)

    if not session.preview:
        session.preview = text[:240]
    session.locale = (locale or session.locale or "uz")[:16]
    session.updated_at = datetime.now(UTC)

    await db.flush()

    return {
        "reply": reply,
        "agent_name": support_chat_service.agent_name(),
        "session_id": session.id,
    }


async def rate_session(
    db: AsyncSession,
    *,
    user: User,
    session_id: int,
    rating: int,
) -> dict:
    result = await db.execute(
        select(SupportSession)
        .where(
            SupportSession.id == session_id,
            SupportSession.user_id == user.id,
        )
        .options(selectinload(SupportSession.messages))
    )
    session = result.scalar_one_or_none()
    if session is None:
        raise AppError(
            message="Yozishma topilmadi",
            error_code="SUPPORT_SESSION_NOT_FOUND",
            status_code=404,
        )
    if session.status == "completed":
        return _session_to_dict(session, include_messages=True)

    session.rating = rating
    session.status = "completed"
    session.closed_at = datetime.now(UTC)
    session.updated_at = datetime.now(UTC)
    await db.flush()
    return _session_to_dict(session, include_messages=True)
