from __future__ import annotations

import asyncio
import json
import logging

import jwt
from fastapi import APIRouter, Query, WebSocket, WebSocketDisconnect
from sqlalchemy import select

from app.core.security import decode_token
from app.db.redis import get_redis
from app.db.session import get_session_factory
from app.models.user import User
from app.ws.hub import get_hub

logger = logging.getLogger(__name__)

router = APIRouter()


def _extract_token(websocket: WebSocket, query_token: str | None) -> str | None:
    """Prefer Authorization / Sec-WebSocket-Protocol; query string is legacy fallback."""
    auth = websocket.headers.get("authorization")
    if auth and auth.lower().startswith("bearer "):
        return auth[7:].strip()

    # Clients may pass: Sec-WebSocket-Protocol: bearer, <jwt>
    proto = websocket.headers.get("sec-websocket-protocol")
    if proto:
        parts = [p.strip() for p in proto.split(",")]
        if len(parts) >= 2 and parts[0].lower() == "bearer":
            return parts[1]
        if len(parts) == 1 and parts[0] not in {"graphql-ws", "graphql-transport-ws"}:
            # Single opaque token protocol value
            if parts[0].count(".") == 2:
                return parts[0]

    return query_token


async def _authenticate_ws(token: str | None) -> int | None:
    if not token:
        return None
    try:
        payload = decode_token(token)
    except jwt.PyJWTError:
        return None
    if payload.get("type") != "access":
        return None
    try:
        user_id = int(payload["sub"])
    except (KeyError, TypeError, ValueError):
        return None

    factory = get_session_factory()
    async with factory() as db:
        result = await db.execute(
            select(User.id).where(
                User.id == user_id,
                User.is_active.is_(True),
                User.is_verified.is_(True),
                User.deleted_at.is_(None),
            )
        )
        if result.scalar_one_or_none() is None:
            return None
    return user_id


@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket, token: str | None = Query(default=None)) -> None:
    from app.core.config import get_settings

    # Prefer Authorization / subprotocol. Query-string tokens leak via logs/proxies.
    if token and get_settings().is_production:
        await websocket.close(code=4401, reason="Query token not allowed")
        return
    access = _extract_token(websocket, None if get_settings().is_production else token)
    user_id = await _authenticate_ws(access)
    if user_id is None:
        await websocket.close(code=4401, reason="Authentication required")
        return

    # Echo selected subprotocol when client sent bearer,<token>
    proto = websocket.headers.get("sec-websocket-protocol")
    accept_kwargs: dict = {}
    if proto:
        first = proto.split(",")[0].strip()
        if first.lower() == "bearer":
            accept_kwargs["subprotocol"] = "bearer"

    await websocket.accept(**accept_kwargs)

    redis = await get_redis()
    hub = get_hub()
    await hub.set_online(redis, user_id)

    pubsub = await hub.subscribe(user_id)
    listen_task: asyncio.Task | None = None

    async def redis_listener() -> None:
        try:
            async for raw in pubsub.listen():
                if raw["type"] != "message":
                    continue
                data = raw.get("data")
                if isinstance(data, bytes):
                    data = data.decode()
                if isinstance(data, str):
                    await websocket.send_text(data)
        except asyncio.CancelledError:
            raise
        except Exception:
            logger.exception("WebSocket redis listener failed for user %s", user_id)

    listen_task = asyncio.create_task(redis_listener())

    try:
        while True:
            raw = await websocket.receive_text()
            try:
                msg = json.loads(raw)
            except json.JSONDecodeError:
                continue

            msg_type = msg.get("type")
            if msg_type == "ping":
                await hub.refresh_presence(redis, user_id)
                await websocket.send_json({"type": "pong", "data": {}})
    except WebSocketDisconnect:
        pass
    finally:
        if listen_task is not None:
            listen_task.cancel()
            try:
                await listen_task
            except asyncio.CancelledError:
                pass
        try:
            await pubsub.unsubscribe()
            await pubsub.aclose()
        except Exception:
            logger.exception("Failed to close pubsub for user %s", user_id)
        await hub.set_offline(redis, user_id)
