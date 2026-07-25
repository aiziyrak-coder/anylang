from __future__ import annotations

from datetime import UTC, datetime

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.user import BusinessProfile, ProfileView, Subscription, User


def has_profile_viewers_access(user: User) -> bool:
    sub = user.subscription
    return bool(sub and sub.is_active and sub.plan in {"premium", "business"})


async def record_profile_view(
    db: AsyncSession,
    *,
    profile_user_id: int,
    viewer_user_id: int,
) -> None:
    if profile_user_id <= 0 or viewer_user_id <= 0:
        return
    if profile_user_id == viewer_user_id:
        return
    now = datetime.now(UTC)
    result = await db.execute(
        select(ProfileView).where(
            ProfileView.profile_user_id == profile_user_id,
            ProfileView.viewer_user_id == viewer_user_id,
        )
    )
    row = result.scalar_one_or_none()
    if row is not None:
        row.view_count = int(row.view_count or 0) + 1
        row.last_viewed_at = now
        return
    db.add(
        ProfileView(
            profile_user_id=profile_user_id,
            viewer_user_id=viewer_user_id,
            view_count=1,
            last_viewed_at=now,
        )
    )


async def list_profile_viewers(
    db: AsyncSession,
    *,
    user: User,
    limit: int = 20,
) -> dict:
    safe_limit = min(max(int(limit or 20), 1), 50)
    total = int(
        (
            await db.execute(
                select(func.count(ProfileView.id)).where(
                    ProfileView.profile_user_id == user.id
                )
            )
        ).scalar()
        or 0
    )
    locked = not has_profile_viewers_access(user)
    if locked or total <= 0:
        return {
            "locked": locked,
            "total_count": total,
            "items": [],
        }

    result = await db.execute(
        select(ProfileView, User, BusinessProfile, Subscription)
        .join(User, User.id == ProfileView.viewer_user_id)
        .outerjoin(BusinessProfile, BusinessProfile.user_id == User.id)
        .outerjoin(Subscription, Subscription.user_id == User.id)
        .where(
            ProfileView.profile_user_id == user.id,
            User.is_active.is_(True),
            User.deleted_at.is_(None),
        )
        .order_by(ProfileView.last_viewed_at.desc())
        .limit(safe_limit)
    )

    items: list[dict] = []
    for view, viewer, biz, sub in result.all():
        is_biz = bool(sub and sub.is_active and sub.plan == "business" and biz is not None)
        if is_biz and biz is not None:
            name = (biz.company_name or viewer.full_name or "").strip() or f"User #{viewer.id}"
            country = (biz.country or viewer.country or "").strip().upper() or None
            logo = biz.logo_url or viewer.avatar_url
            role = biz.business_role
        else:
            name = (viewer.full_name or "").strip() or f"User #{viewer.id}"
            country = (viewer.country or "").strip().upper() or None
            logo = viewer.avatar_url
            role = None
        if country and len(country) != 2:
            country = None
        items.append(
            {
                "user_id": int(viewer.id),
                "name": name[:200],
                "country": country,
                "business_role": role,
                "avatar_url": logo,
                "is_business": is_biz,
                "view_count": int(view.view_count or 1),
                "last_viewed_at": view.last_viewed_at.isoformat()
                if view.last_viewed_at
                else None,
            }
        )

    return {
        "locked": False,
        "total_count": total,
        "items": items,
    }
