"""Push token CRUD + FCM send + ARQ enqueue helpers."""

from __future__ import annotations

import json
import logging
from datetime import UTC, datetime
from typing import Any

from arq import create_pool
from arq.connections import ArqRedis, RedisSettings
from redis.asyncio import Redis
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.errors import AppError
from app.integrations import fcm as fcm_client
from app.models.chat import ChatParticipant
from app.models.push_token import PushToken
from app.ws.hub import get_hub

logger = logging.getLogger(__name__)

_arq_pool: ArqRedis | None = None


async def _get_arq() -> ArqRedis:
    global _arq_pool
    if _arq_pool is None:
        _arq_pool = await create_pool(RedisSettings.from_dsn(get_settings().redis_url))
    return _arq_pool


async def register_push_token(
    db: AsyncSession,
    *,
    user_id: int,
    token: str,
    platform: str,
    device_id: str | None = None,
    app_version: str | None = None,
) -> dict[str, Any]:
    now = datetime.now(UTC)
    platform_norm = platform.strip().lower()
    if platform_norm not in {"android", "ios", "web"}:
        raise AppError(
            message="platform android|ios|web bo'lishi kerak",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )
    token = token.strip()
    if not token:
        raise AppError(
            message="token majburiy",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )

    # Same device → revoke other active tokens so only the latest FCM token remains.
    if device_id:
        await db.execute(
            update(PushToken)
            .where(
                PushToken.user_id == user_id,
                PushToken.device_id == device_id,
                PushToken.token != token,
                PushToken.revoked_at.is_(None),
            )
            .values(revoked_at=now)
        )

    result = await db.execute(select(PushToken).where(PushToken.token == token))
    row = result.scalar_one_or_none()
    if row is None:
        row = PushToken(
            user_id=user_id,
            token=token,
            device_id=device_id,
            platform=platform_norm,
            app_version=app_version,
            last_seen_at=now,
            revoked_at=None,
        )
        db.add(row)
    else:
        row.user_id = user_id
        row.device_id = device_id
        row.platform = platform_norm
        row.app_version = app_version
        row.last_seen_at = now
        row.revoked_at = None
    await db.flush()
    await db.refresh(row)
    return {
        "id": row.id,
        "platform": row.platform,
        "device_id": row.device_id,
        "app_version": row.app_version,
        "last_seen_at": row.last_seen_at,
        "message": "OK",
    }


async def unregister_push_token(
    db: AsyncSession,
    *,
    user_id: int,
    token: str | None = None,
    device_id: str | None = None,
) -> dict[str, str]:
    if not token and not device_id:
        raise AppError(
            message="token yoki device_id kerak",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )
    now = datetime.now(UTC)
    q = update(PushToken).where(
        PushToken.user_id == user_id,
        PushToken.revoked_at.is_(None),
    )
    if token:
        q = q.where(PushToken.token == token)
    if device_id:
        q = q.where(PushToken.device_id == device_id)
    await db.execute(q.values(revoked_at=now))
    return {"message": "OK"}


async def revoke_push_tokens_for_device(
    db: AsyncSession,
    *,
    user_id: int,
    device_id: str | None,
) -> int:
    if not device_id:
        return 0
    now = datetime.now(UTC)
    result = await db.execute(
        update(PushToken)
        .where(
            PushToken.user_id == user_id,
            PushToken.device_id == device_id,
            PushToken.revoked_at.is_(None),
        )
        .values(revoked_at=now)
    )
    return int(result.rowcount or 0)


async def revoke_push_tokens_for_devices(
    db: AsyncSession,
    *,
    user_id: int,
    device_ids: list[str],
) -> int:
    ids = [d for d in device_ids if d]
    if not ids:
        return 0
    now = datetime.now(UTC)
    result = await db.execute(
        update(PushToken)
        .where(
            PushToken.user_id == user_id,
            PushToken.device_id.in_(ids),
            PushToken.revoked_at.is_(None),
        )
        .values(revoked_at=now)
    )
    return int(result.rowcount or 0)


async def list_active_tokens(db: AsyncSession, user_id: int) -> list[PushToken]:
    result = await db.execute(
        select(PushToken).where(
            PushToken.user_id == user_id,
            PushToken.revoked_at.is_(None),
        )
    )
    return list(result.scalars().all())


async def send_to_user(
    db: AsyncSession,
    *,
    user_id: int,
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
    collapse_key: str | None = None,
) -> dict[str, int]:
    if not fcm_client.fcm_configured():
        logger.warning("FCM send_to_user no-op (not configured) user_id=%s", user_id)
        return {"sent": 0, "failed": 0, "revoked": 0}

    tokens = await list_active_tokens(db, user_id)
    if not tokens:
        return {"sent": 0, "failed": 0, "revoked": 0}

    str_data = {str(k): str(v) for k, v in (data or {}).items()}
    sent = failed = revoked = 0
    now = datetime.now(UTC)
    for row in tokens:
        result = await fcm_client.send_fcm_message(
            token=row.token,
            title=title,
            body=body,
            data=str_data,
            collapse_key=collapse_key,
        )
        if result.get("ok"):
            sent += 1
            row.last_seen_at = now
        else:
            failed += 1
            if result.get("invalid_token"):
                row.revoked_at = now
                revoked += 1
    await db.flush()
    logger.info(
        "FCM user=%s sent=%s failed=%s revoked=%s",
        user_id,
        sent,
        failed,
        revoked,
    )
    return {"sent": sent, "failed": failed, "revoked": revoked}


async def enqueue_push(
    user_id: int,
    *,
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
    collapse_key: str | None = None,
) -> None:
    payload = {
        "user_id": user_id,
        "title": title,
        "body": body,
        "data": data or {},
        "collapse_key": collapse_key,
    }
    try:
        pool = await _get_arq()
        await pool.enqueue_job(
            "send_push_job",
            user_id,
            title,
            body,
            data or {},
            collapse_key,
        )
    except Exception:
        logger.exception("Failed to enqueue send_push_job user_id=%s", user_id)
        return

    try:
        from app.db.redis import get_redis

        redis = await get_redis()
        await redis.publish("push:events", json.dumps(payload, default=str))
    except Exception:
        logger.debug("push:events publish failed", exc_info=True)


async def is_chat_muted_for_user(
    db: AsyncSession,
    redis: Redis | None,
    *,
    user_id: int,
    chat_id: int,
) -> bool:
    result = await db.execute(
        select(ChatParticipant).where(
            ChatParticipant.chat_id == chat_id,
            ChatParticipant.user_id == user_id,
        )
    )
    part = result.scalar_one_or_none()
    if part is None:
        return False
    if not part.muted:
        if redis is not None:
            if await redis.sismember(f"chat_muted:{user_id}", chat_id):
                return True
            if await redis.exists(f"chat_muted_until:{user_id}:{chat_id}"):
                return True
        return False
    until = part.muted_until
    if until is not None and until.tzinfo is None:
        until = until.replace(tzinfo=UTC)
    if until is not None and until <= datetime.now(UTC):
        return False
    return True


async def maybe_enqueue_chat_push(
    db: AsyncSession,
    redis: Redis,
    *,
    recipient_id: int,
    chat_id: int,
    sender_name: str,
    preview: str,
    message_id: int,
) -> None:
    hub = get_hub()
    try:
        if await hub.is_online(redis, recipient_id):
            return
    except Exception:
        logger.debug("presence check failed user=%s", recipient_id, exc_info=True)

    try:
        if await is_chat_muted_for_user(
            db, redis, user_id=recipient_id, chat_id=chat_id
        ):
            return
    except Exception:
        logger.debug("mute check failed chat=%s user=%s", chat_id, recipient_id, exc_info=True)

    title = (sender_name or "AnyLang").strip() or "AnyLang"
    body = (preview or "").strip() or "Yangi xabar"
    if len(body) > 180:
        body = body[:177] + "…"
    await enqueue_push(
        recipient_id,
        title=title,
        body=body,
        data={
            "type": "chat_message",
            "chat_id": str(chat_id),
            "message_id": str(message_id),
        },
        collapse_key=f"chat_{chat_id}",
    )


async def enqueue_friend_request_push(
    *,
    target_user_id: int,
    requester_name: str,
    friendship_id: int,
) -> None:
    name = (requester_name or "").strip() or "Someone"
    await enqueue_push(
        target_user_id,
        title="AnyLang",
        body=f"{name} do'stlik so'rovi yubordi",
        data={
            "type": "friend_request",
            "friendship_id": str(friendship_id),
        },
        collapse_key="friend_requests",
    )
