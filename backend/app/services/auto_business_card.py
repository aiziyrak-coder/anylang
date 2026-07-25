"""Auto Business Card — noma'lum (do'st emas) yuboruvchi uchun xabar tepasidagi kartochka."""

from __future__ import annotations

from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.chat import Friendship
from app.models.user import User
from app.services.users import _business_stats


async def _accepted_friend_ids(
    db: AsyncSession,
    viewer_id: int,
    other_ids: set[int],
) -> set[int]:
    if not other_ids:
        return set()
    result = await db.execute(
        select(Friendship).where(
            Friendship.status == "accepted",
            or_(
                and_(
                    Friendship.user_low_id == viewer_id,
                    Friendship.user_high_id.in_(other_ids),
                ),
                and_(
                    Friendship.user_high_id == viewer_id,
                    Friendship.user_low_id.in_(other_ids),
                ),
            ),
        )
    )
    friends: set[int] = set()
    for f in result.scalars().all():
        other = f.user_high_id if f.user_low_id == viewer_id else f.user_low_id
        friends.add(other)
    return friends


def _serialize_card(
    user: User,
    *,
    products_count: int,
    rating: float | None,
) -> dict:
    biz = user.business
    is_business = bool(
        user.subscription
        and user.subscription.plan == "business"
        and user.subscription.is_active
    )
    company = ""
    country = (user.country or "").strip().upper() or None
    verified = bool(user.verified_badge)
    if biz is not None:
        company = (biz.company_name or "").strip()
        if biz.country:
            country = str(biz.country).strip().upper() or country
        if biz.documents_verified:
            verified = True
    if not company:
        company = (user.full_name or "").strip() or f"#{user.id}"
    avatar = None
    if biz is not None and biz.logo_url:
        avatar = biz.logo_url
    else:
        avatar = user.avatar_url
    return {
        "user_id": int(user.id),
        "company_name": company,
        "country": country,
        "verified": verified,
        "rating": rating,
        "products_count": int(products_count),
        "is_business": is_business,
        "avatar_url": avatar,
    }


async def build_auto_business_cards(
    db: AsyncSession,
    *,
    viewer_id: int,
    sender_ids: set[int],
) -> dict[int, dict]:
    """Noma'lum (do'st emas) yuboruvchilar uchun kartochka map'i."""
    targets = {int(sid) for sid in sender_ids if sid and sid != viewer_id}
    if not targets:
        return {}
    friends = await _accepted_friend_ids(db, viewer_id, targets)
    unknown = targets - friends
    if not unknown:
        return {}
    result = await db.execute(
        select(User)
        .where(User.id.in_(unknown), User.is_active.is_(True))
        .options(selectinload(User.subscription), selectinload(User.business))
    )
    out: dict[int, dict] = {}
    for user in result.scalars().all():
        stats = await _business_stats(db, user.id, user.business)
        products_count = int(stats.get("listings_count") or 0)
        rating = stats.get("rating")
        if rating is not None:
            rating = float(rating)
        out[int(user.id)] = _serialize_card(
            user,
            products_count=products_count,
            rating=rating,
        )
    return out
