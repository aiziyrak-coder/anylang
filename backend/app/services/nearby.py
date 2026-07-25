"""Nearby people — GPS asosida yaqin foydalanuvchilar (Premium)."""

from __future__ import annotations

import math
from datetime import UTC, datetime, timedelta
from decimal import Decimal

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.errors import AppError
from app.models.user import User


def has_nearby_access(user: User) -> bool:
    sub = user.subscription
    return bool(sub and sub.is_active and sub.plan in {"premium", "business"})


def _lang_code(raw: str | None) -> str:
    return str(raw or "").strip().lower().replace("-", "_").split("_", 1)[0]


def haversine_m(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    r = 6371000.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlmb = math.radians(lng2 - lng1)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlmb / 2) ** 2
    return 2 * r * math.asin(min(1.0, math.sqrt(a)))


async def update_my_location(
    db: AsyncSession,
    *,
    user: User,
    lat: float,
    lng: float,
    sharing_enabled: bool | None = None,
) -> dict:
    if not (-90.0 <= lat <= 90.0) or not (-180.0 <= lng <= 180.0):
        raise AppError(
            message="Noto‘g‘ri koordinata",
            error_code="INVALID_LOCATION",
            status_code=400,
        )
    user.location_lat = Decimal(f"{lat:.7f}")
    user.location_lng = Decimal(f"{lng:.7f}")
    user.location_updated_at = datetime.now(UTC)
    if sharing_enabled is not None:
        user.location_sharing_enabled = bool(sharing_enabled)
    await db.flush()
    return {
        "location_lat": float(user.location_lat),
        "location_lng": float(user.location_lng),
        "location_updated_at": user.location_updated_at,
        "location_sharing_enabled": user.location_sharing_enabled,
    }


async def set_location_sharing(
    db: AsyncSession,
    *,
    user: User,
    enabled: bool,
) -> dict:
    user.location_sharing_enabled = bool(enabled)
    if not enabled:
        # Maxfiylik: o‘chirishda oxirgi nuqtani saqlab qolamiz, lekin sharing false.
        pass
    await db.flush()
    return {"location_sharing_enabled": user.location_sharing_enabled}


async def list_nearby(
    db: AsyncSession,
    *,
    viewer: User,
    lat: float,
    lng: float,
    radius_m: int = 2000,
    language: str | None = None,
    limit: int = 40,
) -> dict:
    locked = not has_nearby_access(viewer)
    safe_radius = min(max(int(radius_m or 2000), 100), 20000)
    safe_limit = min(max(int(limit or 40), 1), 80)
    lang_filter = _lang_code(language) if language else ""

    if locked:
        return {
            "locked": True,
            "radius_m": safe_radius,
            "items": [],
            "total_count": 0,
        }

    if not (-90.0 <= lat <= 90.0) or not (-180.0 <= lng <= 180.0):
        raise AppError(
            message="Noto‘g‘ri koordinata",
            error_code="INVALID_LOCATION",
            status_code=400,
        )

    # Avtomatik o‘z joylashuvini yangilash (sharing yoqilgan bo‘lsa).
    viewer.location_lat = Decimal(f"{lat:.7f}")
    viewer.location_lng = Decimal(f"{lng:.7f}")
    viewer.location_updated_at = datetime.now(UTC)
    if not viewer.location_sharing_enabled:
        viewer.location_sharing_enabled = True
    await db.flush()

    # Bounding box (taxminiy) — keyin haversine.
    deg = safe_radius / 111_000.0
    lat_min, lat_max = lat - deg, lat + deg
    cos_lat = max(0.2, abs(math.cos(math.radians(lat))))
    lng_deg = deg / cos_lat
    lng_min, lng_max = lng - lng_deg, lng + lng_deg

    stale_before = datetime.now(UTC) - timedelta(hours=6)

    result = await db.execute(
        select(User)
        .options(selectinload(User.subscription), selectinload(User.business))
        .where(
            User.id != viewer.id,
            User.is_active.is_(True),
            User.deleted_at.is_(None),
            User.location_sharing_enabled.is_(True),
            User.location_lat.is_not(None),
            User.location_lng.is_not(None),
            User.location_updated_at.is_not(None),
            User.location_updated_at >= stale_before,
            User.location_lat >= Decimal(str(lat_min)),
            User.location_lat <= Decimal(str(lat_max)),
            User.location_lng >= Decimal(str(lng_min)),
            User.location_lng <= Decimal(str(lng_max)),
        )
        .limit(400)
    )
    rows = list(result.scalars().all())

    scored: list[tuple[float, User]] = []
    for u in rows:
        u_lat = float(u.location_lat or 0)
        u_lng = float(u.location_lng or 0)
        dist = haversine_m(lat, lng, u_lat, u_lng)
        if dist > safe_radius:
            continue
        if lang_filter:
            native = _lang_code(u.native_language)
            app = _lang_code(u.app_language)
            if lang_filter not in {native, app}:
                continue
        scored.append((dist, u))

    scored.sort(key=lambda t: t[0])
    items = []
    for dist, u in scored[:safe_limit]:
        is_business = bool(
            u.subscription
            and u.subscription.is_active
            and u.subscription.plan == "business"
        )
        company = None
        if is_business and u.business is not None:
            company = (u.business.company_name or "").strip() or None
        display = company or u.full_name or "User"
        lang = _lang_code(u.native_language) or _lang_code(u.app_language) or "en"
        items.append(
            {
                "id": u.id,
                "full_name": display,
                "avatar_url": (
                    (u.business.logo_url if is_business and u.business else None)
                    or u.avatar_url
                ),
                "number": u.number,
                "native_language": lang,
                "country": (u.country or "").strip().upper() or None,
                "verified_badge": bool(u.verified_badge),
                "is_business": is_business,
                "distance_m": int(round(dist)),
                "location_updated_at": u.location_updated_at,
            }
        )

    return {
        "locked": False,
        "radius_m": safe_radius,
        "items": items,
        "total_count": len(items),
    }
