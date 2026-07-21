from collections.abc import AsyncGenerator
from typing import Annotated

from fastapi import Depends
from redis.asyncio import Redis
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.redis import get_redis
from app.db.session import get_db

DbSession = Annotated[AsyncSession, Depends(get_db)]
RedisClient = Annotated[Redis, Depends(get_redis)]


async def redis_dep() -> AsyncGenerator[Redis, None]:
    yield await get_redis()
