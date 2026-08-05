"""System health, feature flags, job queues, error spikes, controlled purge."""

from __future__ import annotations

import hashlib
import secrets
import time
from datetime import UTC, datetime, timedelta
from typing import Any

from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.db.redis import get_redis
from app.models.payment import Payment
from app.models.system_ops import SystemErrorEvent, SystemFeatureFlag
from app.models.user import AdminUser, User
from app.services.admin_ops import write_audit

FLAGS_CACHE_KEY = "anylang:feature_flags"
PURGE_TOKEN_PREFIX = "anylang:purge_confirm:"
DEFAULT_FLAGS: dict[str, Any] = {
    "maintenance_mode": False,
    "region_off": [],  # ISO country codes e.g. ["RU", "KZ"]
    "push_enabled": True,
    "translate_enabled": True,
    "payments_enabled": True,
}

KNOWN_FLAG_KEYS = set(DEFAULT_FLAGS.keys())


def _ms(started: float) -> float:
    return round((time.perf_counter() - started) * 1000, 2)


async def check_system_health() -> dict[str, Any]:
    """Latency for API (self), Redis, Postgres, MinIO/S3."""
    checks: dict[str, Any] = {}
    overall = "ok"

    # API self — process is up if we got here
    t0 = time.perf_counter()
    checks["api"] = {"status": "ok", "latency_ms": _ms(t0)}

    # Redis
    t0 = time.perf_counter()
    try:
        redis = await get_redis()
        pong = await redis.ping()
        checks["redis"] = {
            "status": "ok" if pong else "degraded",
            "latency_ms": _ms(t0),
        }
        if not pong:
            overall = "degraded"
    except Exception as exc:
        checks["redis"] = {
            "status": "fail",
            "latency_ms": _ms(t0),
            "error": str(exc)[:160],
        }
        overall = "fail"

    # Postgres
    t0 = time.perf_counter()
    try:
        from app.db.session import get_session_factory

        factory = get_session_factory()
        async with factory() as db:
            await db.execute(text("SELECT 1"))
        checks["postgres"] = {"status": "ok", "latency_ms": _ms(t0)}
    except Exception as exc:
        checks["postgres"] = {
            "status": "fail",
            "latency_ms": _ms(t0),
            "error": str(exc)[:160],
        }
        overall = "fail"

    # MinIO / S3
    t0 = time.perf_counter()
    try:
        from app.integrations.storage import get_storage

        await get_storage().head_bucket()
        checks["minio"] = {"status": "ok", "latency_ms": _ms(t0)}
    except Exception as exc:
        checks["minio"] = {
            "status": "fail",
            "latency_ms": _ms(t0),
            "error": str(exc)[:160],
        }
        if overall == "ok":
            overall = "degraded"

    return {
        "status": overall,
        "checked_at": datetime.now(UTC).isoformat(),
        "checks": checks,
    }


async def _flags_from_db(db: AsyncSession) -> dict[str, Any]:
    rows = (await db.execute(select(SystemFeatureFlag))).scalars().all()
    out = dict(DEFAULT_FLAGS)
    for row in rows:
        if row.key in KNOWN_FLAG_KEYS:
            val = row.value
            if isinstance(val, dict) and "v" in val:
                out[row.key] = val["v"]
            else:
                out[row.key] = val
    return out


async def get_feature_flags(db: AsyncSession, *, use_cache: bool = True) -> dict[str, Any]:
    if use_cache:
        try:
            redis = await get_redis()
            cached = await redis.get(FLAGS_CACHE_KEY)
            if cached:
                import json

                data = json.loads(cached)
                if isinstance(data, dict):
                    merged = dict(DEFAULT_FLAGS)
                    merged.update({k: data[k] for k in KNOWN_FLAG_KEYS if k in data})
                    return merged
        except Exception:
            pass
    flags = await _flags_from_db(db)
    try:
        import json

        redis = await get_redis()
        await redis.set(FLAGS_CACHE_KEY, json.dumps(flags), ex=60)
    except Exception:
        pass
    return flags


async def get_feature_flags_cached() -> dict[str, Any]:
    """Middleware-friendly: Redis first, else DB, else defaults."""
    try:
        redis = await get_redis()
        cached = await redis.get(FLAGS_CACHE_KEY)
        if cached:
            import json

            data = json.loads(cached)
            if isinstance(data, dict):
                merged = dict(DEFAULT_FLAGS)
                merged.update({k: data[k] for k in KNOWN_FLAG_KEYS if k in data})
                return merged
    except Exception:
        pass
    try:
        from app.db.session import get_session_factory

        factory = get_session_factory()
        async with factory() as db:
            return await get_feature_flags(db, use_cache=False)
    except Exception:
        return dict(DEFAULT_FLAGS)


async def update_feature_flags(
    db: AsyncSession,
    *,
    patch: dict[str, Any],
    admin: AdminUser,
    ip: str | None = None,
) -> dict[str, Any]:
    unknown = [k for k in patch if k not in KNOWN_FLAG_KEYS]
    if unknown:
        raise AppError(
            message=f"Noma’lum flag: {', '.join(unknown)}",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )
    now = datetime.now(UTC)
    for key, value in patch.items():
        if key == "region_off":
            if not isinstance(value, list):
                raise AppError(
                    message="region_off ro‘yxat bo‘lishi kerak",
                    error_code="VALIDATION_ERROR",
                    status_code=400,
                )
            value = [str(x).strip().upper()[:8] for x in value if str(x).strip()]
        elif key == "maintenance_mode":
            value = bool(value)
        elif key.endswith("_enabled"):
            value = bool(value)

        row = await db.get(SystemFeatureFlag, key)
        payload = {"v": value}
        if row is None:
            db.add(
                SystemFeatureFlag(
                    key=key,
                    value=payload,
                    updated_by=admin.id,
                )
            )
        else:
            row.value = payload
            row.updated_by = admin.id
            row.updated_at = now

    await db.flush()
    flags = await _flags_from_db(db)
    try:
        import json

        redis = await get_redis()
        await redis.set(FLAGS_CACHE_KEY, json.dumps(flags), ex=60)
    except Exception:
        pass

    await write_audit(
        db,
        admin=admin,
        action="maintenance.flags_update",
        target_type="system",
        target_id="feature_flags",
        meta={"patch": patch, "flags": flags},
        ip=ip,
    )
    return flags


async def job_queue_status(db: AsyncSession) -> dict[str, Any]:
    """ARQ queue depth + translate/push/payments monitoring."""
    queues: dict[str, Any] = {}

    # ARQ default queue
    arq_depth = None
    arq_error = None
    try:
        redis = await get_redis()
        # ARQ uses sorted set "arq:queue" by default
        arq_depth = int(await redis.zcard("arq:queue") or 0)
        # in-progress / result keys (best-effort)
        in_progress = 0
        async for _ in redis.scan_iter(match="arq:in-progress:*", count=100):
            in_progress += 1
            if in_progress >= 500:
                break
        queues["arq"] = {
            "queue_depth": arq_depth,
            "in_progress_approx": in_progress,
            "status": "ok" if arq_depth < 200 else "busy",
        }
    except Exception as exc:
        arq_error = str(exc)[:160]
        queues["arq"] = {"status": "fail", "error": arq_error}

    # Translate jobs — products missing i18n as soft backlog signal
    translate_pending = 0
    try:
        from app.models.product import Product
        from sqlalchemy import or_

        translate_pending = int(
            (
                await db.execute(
                    select(func.count())
                    .select_from(Product)
                    .where(
                        Product.status == "published",
                        or_(
                            Product.name_i18n == {},
                            Product.name_i18n.is_(None),
                        ),
                    )
                )
            ).scalar()
            or 0
        )
    except Exception:
        translate_pending = 0

    queues["translate"] = {
        "pending_catalog_approx": translate_pending,
        "arq_queue_depth": arq_depth,
        "enabled": (await get_feature_flags(db)).get("translate_enabled", True),
        "status": "ok",
    }

    # Push — ARQ function send_push_job; depth shared
    queues["push"] = {
        "arq_queue_depth": arq_depth,
        "enabled": (await get_feature_flags(db)).get("push_enabled", True),
        "status": "ok",
    }

    # Payments — DB pending / failed triage
    try:
        pending = int(
            (
                await db.execute(
                    select(func.count())
                    .select_from(Payment)
                    .where(Payment.status == "pending")
                )
            ).scalar()
            or 0
        )
        failed = int(
            (
                await db.execute(
                    select(func.count())
                    .select_from(Payment)
                    .where(Payment.status.in_(("failed", "needs_refund")))
                )
            ).scalar()
            or 0
        )
        queues["payments"] = {
            "pending": pending,
            "failed_or_refund": failed,
            "enabled": (await get_feature_flags(db)).get("payments_enabled", True),
            "status": "ok" if failed < 50 else "spike",
        }
    except Exception as exc:
        queues["payments"] = {"status": "fail", "error": str(exc)[:160]}

    return {
        "checked_at": datetime.now(UTC).isoformat(),
        "queues": queues,
    }


def _fingerprint(*, error_code: str, path: str, message: str) -> str:
    raw = f"{error_code}|{path}|{(message or '')[:120]}"
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()[:32]


async def record_error_event(
    *,
    error_code: str,
    message: str,
    path: str,
    method: str = "",
    status_code: int | None = None,
    level: str = "error",
    meta: dict[str, Any] | None = None,
) -> None:
    """Best-effort insert — never raise to callers."""
    try:
        from app.db.session import get_session_factory

        factory = get_session_factory()
        async with factory() as db:
            db.add(
                SystemErrorEvent(
                    fingerprint=_fingerprint(
                        error_code=error_code, path=path, message=message
                    ),
                    level=level,
                    error_code=(error_code or "")[:64],
                    message=(message or "")[:500],
                    path=(path or "")[:255],
                    method=(method or "")[:16],
                    status_code=status_code,
                    meta=meta or {},
                    created_at=datetime.now(UTC),
                )
            )
            await db.commit()
    except Exception:
        pass


async def error_spike_dashboard(
    db: AsyncSession,
    *,
    hours: int = 24,
) -> dict[str, Any]:
    hours = max(1, min(int(hours), 168))
    since = datetime.now(UTC) - timedelta(hours=hours)

    total = int(
        (
            await db.execute(
                select(func.count())
                .select_from(SystemErrorEvent)
                .where(SystemErrorEvent.created_at >= since)
            )
        ).scalar()
        or 0
    )

    # Hourly buckets
    hour_expr = func.date_trunc("hour", SystemErrorEvent.created_at)
    hourly_rows = (
        await db.execute(
            select(hour_expr.label("hour"), func.count())
            .where(SystemErrorEvent.created_at >= since)
            .group_by(hour_expr)
            .order_by(hour_expr.asc())
        )
    ).all()
    timeline = [
        {"hour": (h.isoformat() if h else None), "count": int(c or 0)}
        for h, c in hourly_rows
    ]

    # Top fingerprints
    top_rows = (
        await db.execute(
            select(
                SystemErrorEvent.fingerprint,
                SystemErrorEvent.error_code,
                SystemErrorEvent.message,
                SystemErrorEvent.path,
                func.count().label("cnt"),
                func.max(SystemErrorEvent.created_at).label("last_seen"),
            )
            .where(SystemErrorEvent.created_at >= since)
            .group_by(
                SystemErrorEvent.fingerprint,
                SystemErrorEvent.error_code,
                SystemErrorEvent.message,
                SystemErrorEvent.path,
            )
            .order_by(func.count().desc())
            .limit(25)
        )
    ).all()

    top = [
        {
            "fingerprint": fp,
            "error_code": code,
            "message": msg,
            "path": path,
            "count": int(cnt or 0),
            "last_seen": last.isoformat() if last else None,
        }
        for fp, code, msg, path, cnt, last in top_rows
    ]

    # Spike heuristic: last hour vs previous hour
    now = datetime.now(UTC)
    h1 = now - timedelta(hours=1)
    h2 = now - timedelta(hours=2)
    last_hour = int(
        (
            await db.execute(
                select(func.count())
                .select_from(SystemErrorEvent)
                .where(SystemErrorEvent.created_at >= h1)
            )
        ).scalar()
        or 0
    )
    prev_hour = int(
        (
            await db.execute(
                select(func.count())
                .select_from(SystemErrorEvent)
                .where(
                    SystemErrorEvent.created_at >= h2,
                    SystemErrorEvent.created_at < h1,
                )
            )
        ).scalar()
        or 0
    )
    spike = last_hour >= 20 and last_hour >= max(10, prev_hour * 2)

    return {
        "hours": hours,
        "total": total,
        "last_hour": last_hour,
        "prev_hour": prev_hour,
        "spike": spike,
        "timeline": timeline,
        "top": top,
    }


async def purge_candidates(
    db: AsyncSession,
    *,
    limit_sample: int = 20,
) -> dict[str, Any]:
    now = datetime.now(UTC)
    base = select(User).where(
        User.deleted_at.is_not(None),
        User.scheduled_purge_at.is_not(None),
        User.scheduled_purge_at <= now,
        User.deletion_reason.is_distinct_from("purged"),
    )
    total = int(
        (
            await db.execute(select(func.count()).select_from(base.subquery()))
        ).scalar()
        or 0
    )
    rows = list(
        (
            await db.execute(
                base.order_by(User.scheduled_purge_at.asc()).limit(limit_sample)
            )
        )
        .scalars()
        .all()
    )
    sample = [
        {
            "id": u.id,
            "email": u.email,
            "number": u.number,
            "deleted_at": u.deleted_at.isoformat() if u.deleted_at else None,
            "scheduled_purge_at": (
                u.scheduled_purge_at.isoformat() if u.scheduled_purge_at else None
            ),
        }
        for u in rows
    ]
    return {"eligible": total, "sample": sample, "checked_at": now.isoformat()}


async def purge_dry_run(
    db: AsyncSession,
    *,
    admin: AdminUser,
    ip: str | None = None,
) -> dict[str, Any]:
    preview = await purge_candidates(db)
    token = secrets.token_urlsafe(24)
    payload = {
        "token": token,
        "admin_id": admin.id,
        "eligible": preview["eligible"],
        "created_at": datetime.now(UTC).isoformat(),
    }
    try:
        import json

        redis = await get_redis()
        await redis.set(
            f"{PURGE_TOKEN_PREFIX}{token}",
            json.dumps(payload),
            ex=600,
        )
    except Exception as exc:
        raise AppError(
            message=f"Redis token saqlanmadi: {exc}",
            error_code="REDIS_UNAVAILABLE",
            status_code=503,
        ) from exc

    await write_audit(
        db,
        admin=admin,
        action="maintenance.purge_dry_run",
        target_type="system",
        target_id="purge",
        meta={"eligible": preview["eligible"]},
        ip=ip,
    )
    return {
        **preview,
        "confirm_token": token,
        "expires_in_seconds": 600,
        "message": "Dry-run OK. Confirm token bilan tasdiqlang.",
    }


async def purge_confirm(
    db: AsyncSession,
    *,
    confirm_token: str,
    admin: AdminUser,
    ip: str | None = None,
) -> dict[str, Any]:
    token = (confirm_token or "").strip()
    if len(token) < 10:
        raise AppError(
            message="confirm_token majburiy",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )
    import json

    redis = await get_redis()
    key = f"{PURGE_TOKEN_PREFIX}{token}"
    raw = await redis.get(key)
    if not raw:
        raise AppError(
            message="Token muddati o‘tgan yoki noto‘g‘ri — qayta dry-run qiling",
            error_code="PURGE_TOKEN_INVALID",
            status_code=400,
        )
    try:
        payload = json.loads(raw)
    except Exception as exc:
        raise AppError(
            message="Token buzilgan",
            error_code="PURGE_TOKEN_INVALID",
            status_code=400,
        ) from exc

    if int(payload.get("admin_id") or 0) != admin.id:
        raise AppError(
            message="Token boshqa admin uchun",
            error_code="PURGE_TOKEN_MISMATCH",
            status_code=403,
        )

    from app.services.admin_console import purge_expired_accounts

    count = await purge_expired_accounts(db)
    await redis.delete(key)

    await write_audit(
        db,
        admin=admin,
        action="maintenance.purge",
        target_type="system",
        target_id="purge",
        meta={
            "purged": count,
            "dry_run_eligible": payload.get("eligible"),
            "confirm_token_prefix": token[:8],
        },
        ip=ip,
    )
    return {"purged": count, "dry_run_eligible": payload.get("eligible")}
