"""Networking Score — connections, countries, trust (LinkedIn-style)."""

from __future__ import annotations

from sqlalchemy import or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.chat import Friendship
from app.models.user import User
from app.services import trust_score as trust_score_service


def _country_of(user: User) -> str | None:
    biz = user.business
    if biz is not None and (biz.country or "").strip():
        cc = biz.country.strip().upper()
        return cc if len(cc) == 2 else None
    raw = (user.country or "").strip().upper()
    return raw if len(raw) == 2 else None


async def _load_friend_users(db: AsyncSession, user_id: int) -> list[User]:
    friendships = await db.execute(
        select(Friendship).where(
            Friendship.status == "accepted",
            or_(Friendship.user_low_id == user_id, Friendship.user_high_id == user_id),
        )
    )
    other_ids: list[int] = []
    for f in friendships.scalars().all():
        other = f.user_high_id if f.user_low_id == user_id else f.user_low_id
        other_ids.append(int(other))
    if not other_ids:
        return []
    result = await db.execute(
        select(User)
        .where(User.id.in_(other_ids), User.is_active.is_(True), User.deleted_at.is_(None))
        .options(selectinload(User.business), selectinload(User.subscription))
    )
    return list(result.scalars().all())


async def build_networking_score(
    db: AsyncSession,
    user: User,
    *,
    friend_users: list[User] | None = None,
) -> dict:
    friends = friend_users if friend_users is not None else await _load_friend_users(db, user.id)
    countries: set[str] = set()
    for f in friends:
        cc = _country_of(f)
        if cc:
            countries.add(cc)

    trust: int | None = None
    if user.is_business and user.business is not None:
        try:
            payload = await trust_score_service.compute_trust_score(
                db, user, user.business
            )
            trust = int(payload.get("score") or 0)
        except Exception:
            trust = None

    return {
        "connections": len(friends),
        "countries": len(countries),
        "trust": trust,
    }
