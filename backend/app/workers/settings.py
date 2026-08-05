"""ARQ worker — periodic maintenance (365d account anonymize purge)."""

from __future__ import annotations

import logging

from arq import cron
from arq.connections import RedisSettings

from app.core.config import get_settings
from app.workers.tasks import (
    expire_stale_promos_job,
    expire_stale_top_pins_job,
    expire_subscriptions_job,
    restore_sla_notify_job,
    scan_audit_anomalies_job,
    translate_catalog_job,
)
from app.workers.push import send_push_job

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
    functions = [
        purge_expired_accounts_job,
        expire_subscriptions_job,
        expire_stale_top_pins_job,
        expire_stale_promos_job,
        restore_sla_notify_job,
        scan_audit_anomalies_job,
        translate_catalog_job,
        send_push_job,
    ]
    cron_jobs = [
        cron(purge_expired_accounts_job, hour=3, minute=0, run_at_startup=False),
        cron(expire_subscriptions_job, minute=15, run_at_startup=False),
        cron(expire_stale_promos_job, minute=20, run_at_startup=False),
        cron(restore_sla_notify_job, minute=30, run_at_startup=False),
        cron(scan_audit_anomalies_job, minute={0, 15, 30, 45}, run_at_startup=False),
        cron(expire_stale_top_pins_job, minute={0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55}, run_at_startup=True),
    ]
