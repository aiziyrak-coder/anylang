from __future__ import annotations

import re

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.errors import AppError
from app.core.pagination import PageParams, paginate_items
from app.models.chat import Friendship
from app.models.product import Product
from app.models.user import BusinessProfile, Subscription, User


def _business_completeness(business: BusinessProfile, *, has_listing: bool) -> int:
    score = 0
    if business.logo_url:
        score += 10
    if business.company_name.strip():
        score += 10
    if business.country:
        score += 10
    if business.business_role:
        score += 10
    if business.website:
        score += 10
    if business.description and len(business.description) >= 20:
        score += 10
    if business.founded_year is not None:
        score += 10
    if business.certificates:
        score += 10
    if business.factory_images:
        score += 10
    if has_listing:
        score += 10
    return score


async def _business_stats(db: AsyncSession, user_id: int) -> dict:
    listings_result = await db.execute(
        select(func.count())
        .select_from(Product)
        .where(Product.seller_id == user_id, Product.status == "published")
    )
    listings_count = int(listings_result.scalar() or 0)

    views_result = await db.execute(
        select(func.coalesce(func.sum(Product.views_count), 0)).where(Product.seller_id == user_id)
    )
    total_views = int(views_result.scalar() or 0)

    return {
        "listings_count": listings_count,
        "total_views": total_views,
        "rating": None,
        "reviews_count": 0,
    }


def _serialize_subscription(subscription: Subscription) -> dict:
    return {
        "plan": subscription.plan,
        "billing_cycle": subscription.billing_cycle,
        "started_at": subscription.started_at,
        "expires_at": subscription.expires_at,
        "auto_renew": subscription.auto_renew,
        "is_active": subscription.is_active,
        "source": subscription.source,
    }


async def serialize_user(user: User, db: AsyncSession) -> dict:
    """Build a dict matching UserOut / TZ section 4.1."""
    loaded = await load_user_for_response(db, user.id)
    if loaded is not None:
        user = loaded

    subscription = user.subscription
    if subscription is None:
        subscription = await ensure_basic_subscription(user, db)
        loaded = await load_user_for_response(db, user.id)
        if loaded is not None:
            user = loaded
            subscription = user.subscription or subscription

    is_business = bool(subscription.plan == "business" and subscription.is_active)

    business_payload: dict | None = None
    if is_business and user.business is not None:
        stats = await _business_stats(db, user.id)
        has_listing = stats["listings_count"] > 0
        business_payload = {
            "company_name": user.business.company_name,
            "logo_url": user.business.logo_url,
            "country": user.business.country,
            "business_role": user.business.business_role,
            "website": user.business.website,
            "description": user.business.description,
            "founded_year": user.business.founded_year,
            "certificates": list(user.business.certificates or []),
            "factory_images": [
                {"id": img.id, "url": img.url} for img in (user.business.factory_images or [])
            ],
            "completeness": _business_completeness(user.business, has_listing=has_listing),
            "stats": stats,
        }

    return {
        "id": user.id,
        "full_name": user.full_name,
        "number": user.number,
        "email": user.email,
        "birth_date": user.birth_date,
        "gender": user.gender,
        "country": (user.country or "").strip().upper() or None,
        "avatar_url": user.avatar_url,
        "app_language": user.app_language,
        "native_language": user.native_language,
        "is_verified": user.is_verified,
        "verified_badge": user.verified_badge,
        "is_active": user.is_active,
        "profile_completed": user.profile_completed,
        "created_at": user.created_at,
        "last_number_change_at": user.last_number_change_at,
        "subscription": _serialize_subscription(subscription),
        "is_business": is_business,
        "business": business_payload,
    }


async def ensure_basic_subscription(user: User, db: AsyncSession) -> Subscription:
    result = await db.execute(select(Subscription).where(Subscription.user_id == user.id))
    existing = result.scalar_one_or_none()
    if existing is not None:
        return existing

    subscription = Subscription(
        user_id=user.id,
        plan="basic",
        billing_cycle=None,
        started_at=None,
        expires_at=None,
        auto_renew=False,
        is_active=True,
        source="purchase",
    )
    db.add(subscription)
    await db.flush()
    return subscription


async def load_user_for_response(db: AsyncSession, user_id: int) -> User | None:
    result = await db.execute(
        select(User)
        .where(User.id == user_id)
        .options(
            selectinload(User.subscription),
            selectinload(User.business).selectinload(BusinessProfile.factory_images),
        )
    )
    return result.scalar_one_or_none()


def _normalize_number_query(query: str) -> str:
    return re.sub(r"[\s\-]", "", query)


async def _friendship_context(
    db: AsyncSession, viewer_id: int, target_id: int
) -> tuple[str, int | None, bool]:
    low_id, high_id = sorted((viewer_id, target_id))
    result = await db.execute(
        select(Friendship).where(
            Friendship.user_low_id == low_id,
            Friendship.user_high_id == high_id,
        )
    )
    friendship = result.scalar_one_or_none()
    if friendship is None or friendship.status not in {"pending", "accepted"}:
        return "none", None, False
    if friendship.status == "accepted":
        return "accepted", friendship.id, False
    is_incoming = friendship.requester_id != viewer_id
    return "pending", friendship.id, is_incoming


async def get_public_profile(
    db: AsyncSession,
    user_id: int,
    viewer: User | None = None,
) -> dict:
    user = await load_user_for_response(db, user_id)
    if user is None or not user.is_active or user.deleted_at is not None:
        raise AppError(message="Foydalanuvchi topilmadi", error_code="USER_NOT_FOUND", status_code=404)

    is_business = user.is_business
    name = user.full_name
    avatar_url = user.avatar_url
    subtitle_role = user.native_language
    business_payload: dict | None = None

    if is_business and user.business is not None:
        business = user.business
        name = business.company_name or user.full_name
        avatar_url = business.logo_url or user.avatar_url
        subtitle_role = business.business_role or user.native_language
        stats = await _business_stats(db, user.id)
        has_listing = stats["listings_count"] > 0
        business_payload = {
            "business_role": business.business_role,
            "founded_year": business.founded_year,
            "website": business.website,
            "completeness": _business_completeness(business, has_listing=has_listing),
            "certificates": list(business.certificates or []),
            "factory_images": [
                {"id": img.id, "url": img.url} for img in (business.factory_images or [])
            ],
            "stats": {
                "listings_count": stats["listings_count"],
                "total_views": stats["total_views"],
                "rating": stats["rating"],
            },
        }

    payload = {
        "id": user.id,
        "is_business": is_business,
        "name": name,
        "verified_badge": user.verified_badge,
        "country": (user.business.country if user.business and user.business.country else user.country)
        if is_business
        else user.country,
        "subtitle_role": subtitle_role or user.native_language,
        "number": user.number,
        "avatar_url": avatar_url,
        "business": business_payload,
        "friendship_status": "none",
        "friendship_request_id": None,
        "is_request_incoming": False,
    }
    if viewer is not None and viewer.id != user.id:
        status, request_id, is_incoming = await _friendship_context(db, viewer.id, user.id)
        payload["friendship_status"] = status
        payload["friendship_request_id"] = request_id
        payload["is_request_incoming"] = is_incoming
    return payload


async def search_users(
    db: AsyncSession,
    viewer: User,
    query: str,
    params: PageParams,
) -> dict:
    digits = _normalize_number_query(query)
    if not digits.isdigit():
        raise AppError(
            message="Foydalanuvchini raqami orqali qidiring",
            error_code="NUMBER_QUERY_REQUIRED",
            status_code=400,
        )
    if len(digits) < 3:
        raise AppError(
            message="Kamida 3 ta raqam kiriting",
            error_code="NUMBER_QUERY_TOO_SHORT",
            status_code=400,
        )

    result = await db.execute(
        select(User)
        .where(
            User.is_active.is_(True),
            User.deleted_at.is_(None),
            User.id != viewer.id,
            User.number.like(f"{digits}%"),
        )
        .options(
            selectinload(User.subscription),
            selectinload(User.business),
        )
        .order_by(User.number)
    )
    candidates = list(result.scalars().all())
    items: list[dict] = []
    for user in candidates:
        status, request_id, is_incoming = await _friendship_context(db, viewer.id, user.id)
        is_business = user.is_business
        items.append(
            {
                "id": user.id,
                "full_name": user.business.company_name if is_business and user.business else user.full_name,
                "number": user.number,
                "avatar_url": (user.business.logo_url if is_business and user.business else user.avatar_url),
                "is_online": False,
                "last_seen_at": None,
                "native_language": user.native_language,
                "country": user.country,
                "is_business": is_business,
                "verified_badge": user.verified_badge,
                "friendship_status": status,
                "friendship_request_id": request_id,
                "is_request_incoming": is_incoming,
            }
        )

    page_items, total = paginate_items(items, params)
    return {
        "items": page_items,
        "page": params.page,
        "limit": params.page_size,
        "total": total,
        "has_more": params.offset + len(page_items) < total,
    }
