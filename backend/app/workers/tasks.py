"""ARQ background worker tasks."""

from __future__ import annotations

import logging

logger = logging.getLogger(__name__)


async def expire_subscriptions_job(_ctx: dict) -> int:
    from app.db.session import get_session_factory
    from app.services.subscription import expire_subscriptions

    factory = get_session_factory()
    async with factory() as db:
        count = await expire_subscriptions(db)
        await db.commit()
    logger.info("Expired %s subscriptions", count)
    return count
