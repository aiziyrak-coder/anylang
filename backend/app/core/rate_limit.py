"""Redis-backed rate limiting helpers for auth and abuse protection."""

from __future__ import annotations

import logging

from fastapi import Request
from redis.asyncio import Redis

from app.core.errors import AppError

logger = logging.getLogger(__name__)


def client_ip(request: Request) -> str:
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()[:64] or "unknown"
    if request.client and request.client.host:
        return request.client.host[:64]
    return "unknown"


async def enforce_rate_limit(
    redis: Redis,
    key: str,
    *,
    limit: int,
    window_seconds: int,
    message: str = "Juda ko'p urinish — keyinroq qayta urinib ko'ring",
) -> int:
    """Increment counter; raise 429 when over limit. Returns current count."""
    count = await redis.incr(key)
    if count == 1:
        await redis.expire(key, window_seconds)
    if count > limit:
        ttl = await redis.ttl(key)
        logger.warning(
            "rate_limit_exceeded key=%s count=%s limit=%s",
            key,
            count,
            limit,
        )
        raise AppError(
            message=message,
            error_code="TOO_MANY_ATTEMPTS",
            status_code=429,
            extra={"retry_after_seconds": max(int(ttl), 1)},
        )
    return int(count)
