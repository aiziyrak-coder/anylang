from __future__ import annotations

from datetime import UTC, datetime, timedelta

from redis.asyncio import Redis
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.errors import AppError
from app.core.pagination import normalize_page
from app.models.chat import Friendship
from app.models.user import User

COOLDOWN_AFTER_DECLINE_HOURS = 24
EXTENDED_COOLDOWN_DAYS = 7
MAX_DECLINES_BEFORE_EXTENDED = 3
DAILY_REQUEST_LIMIT = 50


def _pair_ids(user_a: int, user_b: int) -> tuple[int, int]:
    return (min(user_a, user_b), max(user_a, user_b))


def _serialize_friend(user: User, *, friends_since: datetime | None = None) -> dict:
    is_business = bool(
        user.subscription and user.subscription.plan == "business" and user.subscription.is_active
    )
    return {
        "id": user.id,
        "full_name": user.full_name,
        "number": user.number,
        "avatar_url": user.avatar_url,
        "is_online": False,
        "last_seen_at": None,
        "native_language": user.native_language,
        "country": user.country,
        "is_business": is_business,
        "verified_badge": user.verified_badge,
        "friends_since": friends_since,
    }


async def _get_friendship(db: AsyncSession, user_a: int, user_b: int) -> Friendship | None:
    low, high = _pair_ids(user_a, user_b)
    result = await db.execute(
        select(Friendship).where(Friendship.user_low_id == low, Friendship.user_high_id == high)
    )
    return result.scalar_one_or_none()


async def _load_user(db: AsyncSession, user_id: int) -> User:
    result = await db.execute(
        select(User)
        .where(User.id == user_id, User.is_active.is_(True))
        .options(selectinload(User.subscription))
    )
    user = result.scalar_one_or_none()
    if user is None:
        raise AppError(
            message="Foydalanuvchi topilmadi",
            error_code="USER_NOT_FOUND",
            status_code=404,
        )
    return user


async def _other_user(db: AsyncSession, friendship: Friendship, current_user_id: int) -> User:
    other_id = (
        friendship.user_high_id
        if friendship.user_low_id == current_user_id
        else friendship.user_low_id
    )
    return await _load_user(db, other_id)


def _daily_request_key(user_id: int) -> str:
    day = datetime.now(UTC).strftime("%Y-%m-%d")
    return f"friend:requests:daily:{user_id}:{day}"


async def _enforce_daily_limit(redis: Redis, user_id: int) -> None:
    key = _daily_request_key(user_id)
    count = await redis.incr(key)
    if count == 1:
        await redis.expire(key, 86400)
    if count > DAILY_REQUEST_LIMIT:
        raise AppError(
            message="Kunlik do'stlik so'rovlari limiti oshdi",
            error_code="TOO_MANY_REQUESTS",
            status_code=429,
        )


async def _enforce_decline_cooldown(friendship: Friendship | None) -> None:
    if friendship is None or friendship.last_declined_at is None:
        return

    if friendship.decline_count >= MAX_DECLINES_BEFORE_EXTENDED:
        wait = timedelta(days=EXTENDED_COOLDOWN_DAYS)
    else:
        wait = timedelta(hours=COOLDOWN_AFTER_DECLINE_HOURS)
    retry_at = friendship.last_declined_at + wait
    now = datetime.now(UTC)
    if now < retry_at:
        remaining = int((retry_at - now).total_seconds())
        raise AppError(
            message="Qayta so'rov yuborish uchun biroz kuting",
            error_code="FRIEND_REQUEST_COOLDOWN",
            status_code=429,
            extra={"retry_after_seconds": remaining},
        )


async def list_friends(
    db: AsyncSession,
    *,
    user: User,
    search: str | None,
    page: int | None,
    limit: int | None,
) -> dict:
    params = normalize_page(page, limit, default_size=50, max_size=100)

    friendships_query = select(Friendship).where(
        Friendship.status == "accepted",
        or_(Friendship.user_low_id == user.id, Friendship.user_high_id == user.id),
    )
    friendships_result = await db.execute(
        friendships_query.order_by(Friendship.accepted_at.desc())
    )
    friendships = list(friendships_result.scalars().all())

    other_ids = [
        f.user_high_id if f.user_low_id == user.id else f.user_low_id for f in friendships
    ]
    if not other_ids:
        pending_result = await db.execute(
            select(func.count())
            .select_from(Friendship)
            .where(
                Friendship.status == "pending",
                Friendship.requester_id != user.id,
                or_(Friendship.user_low_id == user.id, Friendship.user_high_id == user.id),
            )
        )
        return {
            "items": [],
            "page": params.page,
            "limit": params.page_size,
            "total": 0,
            "has_more": False,
            "online_count": 0,
            "pending_incoming_count": int(pending_result.scalar() or 0),
        }

    users_query = (
        select(User)
        .where(User.id.in_(other_ids))
        .options(selectinload(User.subscription))
    )
    if search:
        pattern = f"%{search.strip()}%"
        users_query = users_query.where(
            or_(User.full_name.ilike(pattern), User.number.ilike(pattern))
        )

    users_result = await db.execute(users_query.order_by(User.full_name.asc()))
    users_by_id = {u.id: u for u in users_result.scalars().all()}

    rows: list[tuple[Friendship, User]] = []
    for friendship in friendships:
        other_id = (
            friendship.user_high_id
            if friendship.user_low_id == user.id
            else friendship.user_low_id
        )
        friend_user = users_by_id.get(other_id)
        if friend_user is not None:
            rows.append((friendship, friend_user))

    total = len(rows)
    page_rows = rows[params.offset : params.offset + params.limit]

    pending_result = await db.execute(
        select(func.count())
        .select_from(Friendship)
        .where(
            Friendship.status == "pending",
            Friendship.requester_id != user.id,
            or_(Friendship.user_low_id == user.id, Friendship.user_high_id == user.id),
        )
    )
    pending_incoming_count = int(pending_result.scalar() or 0)

    items = [
        _serialize_friend(friend_user, friends_since=friendship.accepted_at)
        for friendship, friend_user in page_rows
    ]

    return {
        "items": items,
        "page": params.page,
        "limit": params.page_size,
        "total": total,
        "has_more": params.offset + len(items) < total,
        "online_count": 0,
        "pending_incoming_count": pending_incoming_count,
    }


async def send_friend_request(
    db: AsyncSession,
    redis: Redis,
    *,
    user: User,
    target_user_id: int,
) -> dict:
    if target_user_id == user.id:
        raise AppError(
            message="O'zingizga so'rov yuborib bo'lmaydi",
            error_code="CANNOT_FRIEND_SELF",
            status_code=400,
        )

    target = await _load_user(db, target_user_id)
    friendship = await _get_friendship(db, user.id, target.id)

    if friendship is not None and friendship.status == "accepted":
        raise AppError(
            message="Allaqachon do'ssiz",
            error_code="ALREADY_FRIENDS",
            status_code=409,
        )

    if friendship is not None and friendship.status == "pending":
        if friendship.requester_id == user.id:
            raise AppError(
                message="So'rov allaqachon yuborilgan",
                error_code="REQUEST_ALREADY_SENT",
                status_code=409,
            )
        friendship.status = "accepted"
        friendship.accepted_at = datetime.now(UTC)
        await db.flush()
        return {
            "id": friendship.id,
            "user_id": target.id,
            "status": "accepted",
            "auto_accepted": True,
            "created_at": friendship.created_at,
        }

    if friendship is not None and friendship.status == "declined":
        await _enforce_decline_cooldown(friendship)
        await _enforce_daily_limit(redis, user.id)
        friendship.requester_id = user.id
        friendship.status = "pending"
        friendship.accepted_at = None
        await db.flush()
        await db.refresh(friendship)
        return {
            "id": friendship.id,
            "user_id": target.id,
            "status": "pending",
            "auto_accepted": False,
            "created_at": friendship.created_at,
        }

    await _enforce_daily_limit(redis, user.id)

    low, high = _pair_ids(user.id, target.id)
    if friendship is None:
        friendship = Friendship(
            user_low_id=low,
            user_high_id=high,
            requester_id=user.id,
            status="pending",
        )
        db.add(friendship)
    else:
        friendship.requester_id = user.id
        friendship.status = "pending"
        friendship.accepted_at = None

    await db.flush()
    await db.refresh(friendship)
    return {
        "id": friendship.id,
        "user_id": target.id,
        "status": "pending",
        "auto_accepted": False,
        "created_at": friendship.created_at,
    }


async def _get_request_for_user(
    db: AsyncSession,
    *,
    request_id: int,
    user: User,
) -> Friendship:
    result = await db.execute(select(Friendship).where(Friendship.id == request_id))
    friendship = result.scalar_one_or_none()
    if friendship is None:
        raise AppError(message="So'rov topilmadi", error_code="NOT_FOUND", status_code=404)

    if user.id not in {friendship.user_low_id, friendship.user_high_id}:
        raise AppError(message="So'rov topilmadi", error_code="NOT_FOUND", status_code=404)

    if friendship.status != "pending":
        raise AppError(message="So'rov faol emas", error_code="NOT_FOUND", status_code=404)

    return friendship


async def accept_friend_request(
    db: AsyncSession,
    *,
    user: User,
    request_id: int,
) -> dict:
    friendship = await _get_request_for_user(db, request_id=request_id, user=user)
    if friendship.requester_id == user.id:
        raise AppError(
            message="O'z so'rovingizni qabul qilib bo'lmaydi",
            error_code="FORBIDDEN",
            status_code=403,
        )

    friendship.status = "accepted"
    friendship.accepted_at = datetime.now(UTC)
    friend_user = await _other_user(db, friendship, user.id)
    await db.flush()

    return {
        "id": friendship.id,
        "status": "accepted",
        "friend": _serialize_friend(friend_user, friends_since=friendship.accepted_at),
    }


async def decline_friend_request(
    db: AsyncSession,
    *,
    user: User,
    request_id: int,
) -> dict:
    friendship = await _get_request_for_user(db, request_id=request_id, user=user)
    if friendship.requester_id == user.id:
        raise AppError(
            message="O'z so'rovingizni rad etib bo'lmaydi",
            error_code="FORBIDDEN",
            status_code=403,
        )

    friendship.decline_count += 1
    friendship.last_declined_at = datetime.now(UTC)
    friendship.status = "declined"
    friendship.accepted_at = None
    await db.flush()

    return {"id": friendship.id, "status": "none"}


async def cancel_friend_request(
    db: AsyncSession,
    *,
    user: User,
    request_id: int,
) -> dict:
    friendship = await _get_request_for_user(db, request_id=request_id, user=user)
    if friendship.requester_id != user.id:
        raise AppError(
            message="Faqat o'z so'rovingizni bekor qilishingiz mumkin",
            error_code="NOT_REQUEST_OWNER",
            status_code=403,
        )

    await db.delete(friendship)
    await db.flush()
    return {"id": request_id, "status": "none"}


async def list_friend_requests(
    db: AsyncSession,
    *,
    user: User,
    request_type: str,
    include_declined: bool = False,
    page: int | None,
    limit: int | None,
) -> dict:
    params = normalize_page(page, limit, default_size=50, max_size=100)

    pair_filter = or_(Friendship.user_low_id == user.id, Friendship.user_high_id == user.id)

    if request_type == "incoming":
        query = select(Friendship).where(
            pair_filter,
            Friendship.status == "pending",
            Friendship.requester_id != user.id,
        )
    elif include_declined:
        # Yuborilgan + hali qabul qilinmagan: pending yoki rad etilgan (qayta so'rov)
        query = select(Friendship).where(
            pair_filter,
            Friendship.requester_id == user.id,
            Friendship.status.in_(("pending", "declined")),
        )
    else:
        query = select(Friendship).where(
            pair_filter,
            Friendship.status == "pending",
            Friendship.requester_id == user.id,
        )

    count_query = select(func.count()).select_from(query.subquery())
    total = int((await db.execute(count_query)).scalar() or 0)

    result = await db.execute(
        query.order_by(Friendship.created_at.desc()).offset(params.offset).limit(params.limit)
    )
    friendships = list(result.scalars().all())

    items = []
    for friendship in friendships:
        other = await _other_user(db, friendship, user.id)
        # API da declined → none (TZ 9.0); UI "Qo'shish" ko'rsatadi
        public_status = "none" if friendship.status == "declined" else friendship.status
        items.append(
            {
                "id": friendship.id,
                "user": _serialize_friend(other),
                "created_at": friendship.created_at,
                "status": public_status,
            }
        )

    return {
        "items": items,
        "total": total,
        "has_more": params.offset + len(items) < total,
    }


async def remove_friend(
    db: AsyncSession,
    *,
    user: User,
    friend_user_id: int,
) -> dict:
    friendship = await _get_friendship(db, user.id, friend_user_id)
    if friendship is None or friendship.status != "accepted":
        raise AppError(message="Do'st topilmadi", error_code="NOT_FOUND", status_code=404)

    await db.delete(friendship)
    await db.flush()
    return {"user_id": friend_user_id, "status": "none"}


def map_friendship_status(friendship: Friendship | None, *, current_user_id: int) -> str:
    if friendship is None or friendship.status == "declined":
        return "none"
    if friendship.status == "accepted":
        return "accepted"
    if friendship.status == "pending":
        return "pending"
    return "none"
