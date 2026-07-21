from __future__ import annotations

import json
import logging
from datetime import UTC, datetime
from typing import Any

from redis.asyncio import Redis
from redis.asyncio.client import PubSub

from app.db.redis import get_redis

logger = logging.getLogger(__name__)

PRESENCE_TTL_SECONDS = 60
USER_CHANNEL_PREFIX = "user:"
PRESENCE_KEY_PREFIX = "presence:"
LAST_SEEN_KEY_PREFIX = "last_seen:"


def user_channel(user_id: int) -> str:
    return f"{USER_CHANNEL_PREFIX}{user_id}"


def presence_key(user_id: int) -> str:
    return f"{PRESENCE_KEY_PREFIX}{user_id}"


def last_seen_key(user_id: int) -> str:
    return f"{LAST_SEEN_KEY_PREFIX}{user_id}"


class RedisHub:
    """Redis pub/sub manager for per-user WebSocket events."""

    async def publish(self, user_id: int, event_type: str, data: dict[str, Any]) -> None:
        redis = await get_redis()
        payload = json.dumps({"type": event_type, "data": data}, default=str)
        await redis.publish(user_channel(user_id), payload)

    async def publish_many(self, user_ids: set[int], event_type: str, data: dict[str, Any]) -> None:
        for uid in user_ids:
            await self.publish(uid, event_type, data)

    async def subscribe(self, user_id: int) -> PubSub:
        redis = await get_redis()
        pubsub = redis.pubsub()
        await pubsub.subscribe(user_channel(user_id))
        return pubsub

    async def set_online(self, redis: Redis, user_id: int) -> None:
        now = datetime.now(UTC).isoformat()
        pipe = redis.pipeline()
        pipe.set(presence_key(user_id), now, ex=PRESENCE_TTL_SECONDS)
        pipe.set(last_seen_key(user_id), now)
        await pipe.execute()

    async def refresh_presence(self, redis: Redis, user_id: int) -> None:
        now = datetime.now(UTC).isoformat()
        pipe = redis.pipeline()
        pipe.set(presence_key(user_id), now, ex=PRESENCE_TTL_SECONDS)
        pipe.set(last_seen_key(user_id), now)
        await pipe.execute()

    async def set_offline(self, redis: Redis, user_id: int) -> None:
        now = datetime.now(UTC).isoformat()
        pipe = redis.pipeline()
        pipe.delete(presence_key(user_id))
        pipe.set(last_seen_key(user_id), now)
        await pipe.execute()

    async def is_online(self, redis: Redis, user_id: int) -> bool:
        return bool(await redis.exists(presence_key(user_id)))

    async def get_last_seen(self, redis: Redis, user_id: int) -> datetime | None:
        raw = await redis.get(last_seen_key(user_id))
        if not raw:
            return None
        try:
            return datetime.fromisoformat(raw)
        except ValueError:
            logger.warning("Invalid last_seen value for user %s: %s", user_id, raw)
            return None


_hub: RedisHub | None = None


def get_hub() -> RedisHub:
    global _hub
    if _hub is None:
        _hub = RedisHub()
    return _hub
