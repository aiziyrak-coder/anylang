"""ARQ worker — periodic maintenance (365d account anonymize purge)."""

from __future__ import annotations

import logging

from arq import cron
from arq.connections import RedisSettings

from app.core.config import get_settings
from app.workers.tasks import expire_subscriptions_job

logger = logging.getLogger(__name__)


async def purge_expired_accounts_job(_ctx: dict) -> int:
    from app.db.session import get_session_factory
    from app.services.admin_console import purge_expired_accounts

    factory = get_session_factory()
    async with factory() as db:
        count = await purge_expired_accounts(db)
        await db.commit()
    logger.info("Purged %s expired soft-deleted accounts", count)
    return count


class WorkerSettings:
    redis_settings = RedisSettings.from_dsn(get_settings().redis_url)
    functions = [purge_expired_accounts_job, expire_subscriptions_job]
    cron_jobs = [
        cron(purge_expired_accounts_job, hour=3, minute=0, run_at_startup=False),
        cron(expire_subscriptions_job, hour="*/1", minute=15, run_at_startup=False),
    ]
