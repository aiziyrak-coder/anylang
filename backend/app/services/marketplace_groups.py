"""Marketplace Groups — open industry rooms + Verified Groups."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.errors import AppError
from app.models.chat import Chat, ChatParticipant, Message
from app.models.user import User
from app.services.chats import _ensure_participant, _get_participant, _serialize_chat
from app.services.group_admin import _new_invite_token, enrich_chat_dict

# Seed catalog — title English brand-style; blurb short EN (UI i18n by slug).
MARKETPLACE_SEEDS: list[dict[str, str | bool]] = [
    {
        "slug": "textile",
        "emoji": "👕",
        "title": "Textile Group",
        "blurb": "Daily RFQs for fabric, apparel and garments. Manufacturers reply with offers.",
        "verified_only": False,
    },
    {
        "slug": "electronics",
        "emoji": "🔌",
        "title": "Electronics Group",
        "blurb": "Components, devices and OEM electronics buy requests.",
        "verified_only": False,
    },
    {
        "slug": "agriculture",
        "emoji": "🌾",
        "title": "Agriculture Group",
        "blurb": "Produce, seeds, fertilizers and agri machinery RFQs.",
        "verified_only": False,
    },
    {
        "slug": "construction",
        "emoji": "🧱",
        "title": "Construction Group",
        "blurb": "Cement, steel, finishes and building materials.",
        "verified_only": False,
    },
    {
        "slug": "chemicals",
        "emoji": "🧪",
        "title": "Chemicals Group",
        "blurb": "Industrial chemicals, polymers and raw materials.",
        "verified_only": False,
    },
    {
        "slug": "furniture",
        "emoji": "🪑",
        "title": "Furniture Group",
        "blurb": "Home and office furniture wholesale requests.",
        "verified_only": False,
    },
    # Verified Groups — faqat tasdiqlangan bizneslar
    {
        "slug": "textile-manufacturers",
        "emoji": "🏭",
        "title": "Textile Manufacturers",
        "blurb": "Verified textile factories and manufacturers only.",
        "verified_only": True,
    },
    {
        "slug": "food-exporters",
        "emoji": "🥗",
        "title": "Food Exporters",
        "blurb": "Verified food exporters and processors only.",
        "verified_only": True,
    },
    {
        "slug": "medical-suppliers",
        "emoji": "🩺",
        "title": "Medical Suppliers",
        "blurb": "Verified medical and pharma suppliers only.",
        "verified_only": True,
    },
]

MARKETPLACE_MEMBER_LIMIT = 50_000


def user_is_verified_business(user: User) -> bool:
    """Admin verified badge yoki hujjatlar tasdiqlangan biznes."""
    if bool(getattr(user, "verified_badge", False)):
        return True
    biz = getattr(user, "business", None)
    if biz is not None and bool(getattr(biz, "documents_verified", False)):
        return True
    return False


async def assert_verified_join_allowed(db: AsyncSession, *, chat: Chat, user: User) -> None:
    if not bool(getattr(chat, "verified_only", False)):
        return
    # business relation lazy bo'lishi mumkin
    if getattr(user, "business", None) is None:
        result = await db.execute(
            select(User)
            .where(User.id == user.id)
            .options(selectinload(User.business))
        )
        loaded = result.scalar_one_or_none()
        if loaded is not None:
            user = loaded
    if user_is_verified_business(user):
        return
    raise AppError(
        message="Bu Verified Group — faqat tasdiqlangan bizneslar qo‘shila oladi",
        error_code="VERIFIED_ONLY",
        status_code=403,
    )


async def ensure_marketplace_groups(db: AsyncSession) -> None:
    for seed in MARKETPLACE_SEEDS:
        slug = str(seed["slug"])
        existing = await db.execute(
            select(Chat).where(Chat.marketplace_slug == slug).limit(1)
        )
        chat = existing.scalar_one_or_none()
        if chat is not None:
            # Keep verified_only / blurb in sync for existing seeds
            chat.verified_only = bool(seed["verified_only"])
            if seed.get("blurb") and not chat.marketplace_blurb:
                chat.marketplace_blurb = str(seed["blurb"])[:240]
            if seed.get("emoji") and not chat.marketplace_emoji:
                chat.marketplace_emoji = str(seed["emoji"])[:16]
            continue
        chat = Chat(
            type="group",
            title=str(seed["title"])[:120],
            user_low_id=None,
            user_high_id=None,
            created_by=None,
            has_messages=False,
            invite_token=_new_invite_token(),
            invite_enabled=True,
            is_super=True,
            member_limit=MARKETPLACE_MEMBER_LIMIT,
            marketplace_slug=slug,
            marketplace_emoji=str(seed["emoji"]),
            marketplace_blurb=str(seed["blurb"])[:240],
            verified_only=bool(seed["verified_only"]),
        )
        db.add(chat)
    await db.flush()


async def list_marketplace_groups(db: AsyncSession, *, viewer: User) -> dict:
    await ensure_marketplace_groups(db)
    # Ensure business loaded for viewer_verified
    if getattr(viewer, "business", None) is None:
        result = await db.execute(
            select(User)
            .where(User.id == viewer.id)
            .options(selectinload(User.business))
        )
        loaded = result.scalar_one_or_none()
        if loaded is not None:
            viewer = loaded
    viewer_verified = user_is_verified_business(viewer)

    result = await db.execute(
        select(Chat)
        .where(Chat.marketplace_slug.is_not(None), Chat.type == "group")
        .order_by(Chat.verified_only.asc(), Chat.id.asc())
    )
    chats = list(result.scalars().all())
    items = []
    for chat in chats:
        count_result = await db.execute(
            select(func.count())
            .select_from(ChatParticipant)
            .where(ChatParticipant.chat_id == chat.id)
        )
        member_count = int(count_result.scalar() or 0)
        part = await _get_participant(db, chat.id, viewer.id)
        since = datetime.now(UTC) - timedelta(hours=24)
        rfq_result = await db.execute(
            select(func.count())
            .select_from(Message)
            .where(
                Message.chat_id == chat.id,
                Message.type == "rfq",
                Message.deleted_for_everyone.is_(False),
                Message.created_at >= since,
            )
        )
        rfq_today = int(rfq_result.scalar() or 0)
        verified_only = bool(getattr(chat, "verified_only", False))
        items.append(
            {
                "id": chat.id,
                "slug": chat.marketplace_slug,
                "emoji": chat.marketplace_emoji or "🏪",
                "title": chat.title or chat.marketplace_slug,
                "blurb": chat.marketplace_blurb or "",
                "member_count": member_count,
                "joined": part is not None,
                "rfq_today": rfq_today,
                "my_role": part.role if part else None,
                "verified_only": verified_only,
                "can_join": (not verified_only) or viewer_verified or part is not None,
            }
        )
    return {"items": items, "viewer_verified": viewer_verified}


async def join_marketplace_group(
    db: AsyncSession,
    *,
    viewer: User,
    slug: str,
    redis=None,
) -> dict:
    await ensure_marketplace_groups(db)
    cleaned = (slug or "").strip().lower()
    result = await db.execute(
        select(Chat).where(Chat.marketplace_slug == cleaned, Chat.type == "group")
    )
    chat = result.scalar_one_or_none()
    if chat is None:
        raise AppError(
            message="Marketplace guruh topilmadi",
            error_code="NOT_FOUND",
            status_code=404,
        )
    existing = await _get_participant(db, chat.id, viewer.id)
    if existing is None:
        await assert_verified_join_allowed(db, chat=chat, user=viewer)
    await _ensure_participant(db, chat_id=chat.id, user_id=viewer.id)
    part = await _get_participant(db, chat.id, viewer.id)
    if part is not None and not part.role:
        part.role = "member"
    await db.flush()
    data = await _serialize_chat(db, chat=chat, viewer=viewer, redis=redis, participant=part)
    data["marketplace_slug"] = chat.marketplace_slug
    data["marketplace_emoji"] = chat.marketplace_emoji
    data["is_marketplace"] = True
    data["verified_only"] = bool(getattr(chat, "verified_only", False))
    return await enrich_chat_dict(db, data, viewer=viewer, chat=chat)


async def preview_marketplace_group(
    db: AsyncSession,
    *,
    viewer: User,
    slug: str,
    redis=None,
    members_limit: int = 12,
) -> dict:
    """Verified Group preview — a'zo bo‘lmasdan info + sample members + trust %."""
    from app.services import trust_score as trust_score_service
    from app.services.chats import _serialize_interlocutor

    await ensure_marketplace_groups(db)
    cleaned = (slug or "").strip().lower()
    result = await db.execute(
        select(Chat).where(Chat.marketplace_slug == cleaned, Chat.type == "group")
    )
    chat = result.scalar_one_or_none()
    if chat is None:
        raise AppError(
            message="Marketplace guruh topilmadi",
            error_code="NOT_FOUND",
            status_code=404,
        )

    if getattr(viewer, "business", None) is None:
        loaded = await db.execute(
            select(User)
            .where(User.id == viewer.id)
            .options(selectinload(User.business))
        )
        u = loaded.scalar_one_or_none()
        if u is not None:
            viewer = u

    viewer_verified = user_is_verified_business(viewer)
    part = await _get_participant(db, chat.id, viewer.id)
    joined = part is not None
    verified_only = bool(getattr(chat, "verified_only", False))
    can_join = (not verified_only) or viewer_verified or joined

    count_result = await db.execute(
        select(func.count())
        .select_from(ChatParticipant)
        .where(ChatParticipant.chat_id == chat.id)
    )
    member_count = int(count_result.scalar() or 0)

    since = datetime.now(UTC) - timedelta(hours=24)
    rfq_result = await db.execute(
        select(func.count())
        .select_from(Message)
        .where(
            Message.chat_id == chat.id,
            Message.type == "rfq",
            Message.deleted_for_everyone.is_(False),
            Message.created_at >= since,
        )
    )
    rfq_today = int(rfq_result.scalar() or 0)

    members_result = await db.execute(
        select(ChatParticipant, User)
        .join(User, User.id == ChatParticipant.user_id)
        .where(ChatParticipant.chat_id == chat.id)
        .options(selectinload(User.business), selectinload(User.subscription))
        .order_by(ChatParticipant.id.asc())
        .limit(max(1, min(members_limit, 30)))
    )
    members = []
    for p, member in members_result.all():
        profile = await _serialize_interlocutor(member, redis=redis)
        members.append(
            {
                "user_id": member.id,
                "full_name": profile.get("full_name") or "User",
                "avatar_url": profile.get("avatar_url"),
                "is_online": bool(profile.get("is_online")),
                "verified_badge": bool(getattr(member, "verified_badge", False)),
                "role": p.role,
            }
        )

    trust = await trust_score_service.compute_trust_score(
        db, viewer, getattr(viewer, "business", None)
    )
    biz = getattr(viewer, "business", None)
    docs_ok = bool(
        getattr(viewer, "verified_badge", False)
        or (biz is not None and getattr(biz, "documents_verified", False))
    )

    return {
        "id": chat.id,
        "slug": chat.marketplace_slug,
        "emoji": chat.marketplace_emoji or "🏪",
        "title": chat.title or chat.marketplace_slug,
        "blurb": chat.marketplace_blurb or "",
        "member_count": member_count,
        "rfq_today": rfq_today,
        "verified_only": verified_only,
        "joined": joined,
        "can_join": can_join,
        "viewer_verified": viewer_verified,
        "trust_score": int(trust.get("score") or 0),
        "trust_level": str(trust.get("level") or "low"),
        "documents_verified": docs_ok,
        "members": members,
        "members_shown": len(members),
    }


async def get_marketplace_group(
    db: AsyncSession,
    *,
    viewer: User,
    slug: str,
    redis=None,
) -> dict:
    await ensure_marketplace_groups(db)
    cleaned = (slug or "").strip().lower()
    result = await db.execute(
        select(Chat).where(Chat.marketplace_slug == cleaned, Chat.type == "group")
    )
    chat = result.scalar_one_or_none()
    if chat is None:
        raise AppError(
            message="Marketplace guruh topilmadi",
            error_code="NOT_FOUND",
            status_code=404,
        )
    part = await _get_participant(db, chat.id, viewer.id)
    if part is None:
        raise AppError(
            message="Avval guruhga qo‘shiling",
            error_code="NOT_A_MEMBER",
            status_code=403,
        )
    data = await _serialize_chat(db, chat=chat, viewer=viewer, redis=redis, participant=part)
    data["marketplace_slug"] = chat.marketplace_slug
    data["marketplace_emoji"] = chat.marketplace_emoji
    data["is_marketplace"] = True
    data["verified_only"] = bool(getattr(chat, "verified_only", False))
    return await enrich_chat_dict(db, data, viewer=viewer, chat=chat)
