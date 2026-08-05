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


async def expire_stale_top_pins_job(_ctx: dict) -> int:
    from app.db.session import get_session_factory
    from app.services.products import expire_stale_top_pins

    factory = get_session_factory()
    async with factory() as db:
        count = await expire_stale_top_pins(db)
        await db.commit()
    logger.info("Expired/promoted %s product top pins", count)
    return count


async def expire_stale_promos_job(_ctx: dict) -> int:
    from app.db.session import get_session_factory
    from app.services.promo import expire_stale_promos

    factory = get_session_factory()
    async with factory() as db:
        count = await expire_stale_promos(db)
        await db.commit()
    logger.info("Auto-expired %s promo codes", count)
    return count


async def restore_sla_notify_job(_ctx: dict) -> int:
    from app.db.session import get_session_factory
    from app.services.restore_admin import notify_sla_breaches

    factory = get_session_factory()
    async with factory() as db:
        count = await notify_sla_breaches(db)
        await db.commit()
    logger.info("Restore SLA reminders sent: %s", count)
    return count


async def scan_audit_anomalies_job(_ctx: dict) -> int:
    from app.db.session import get_session_factory
    from app.services.audit_admin import scan_anomalous_activity

    factory = get_session_factory()
    async with factory() as db:
        count = await scan_anomalous_activity(db)
        await db.commit()
    logger.info("Audit anomaly alerts created: %s", count)
    return count


async def translate_catalog_job(
    _ctx: dict,
    kind: str,
    entity_id: int,
    source_lang: str = "uz",
) -> bool:
    """Fill product/business i18n maps from one source language."""
    from app.db.session import get_session_factory
    from app.services import catalog_i18n

    factory = get_session_factory()
    async with factory() as db:
        if kind == "product":
            ok = await catalog_i18n.apply_product_i18n(
                db, int(entity_id), source_lang=source_lang
            )
        elif kind == "business":
            ok = await catalog_i18n.apply_business_i18n(
                db, int(entity_id), source_lang=source_lang
            )
        else:
            logger.warning("unknown catalog translate kind=%s", kind)
            return False
    logger.info(
        "catalog translate kind=%s id=%s ok=%s lang=%s",
        kind,
        entity_id,
        ok,
        source_lang,
    )
    return bool(ok)
