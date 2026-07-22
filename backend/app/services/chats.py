from __future__ import annotations

from datetime import datetime

from redis.asyncio import Redis
from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.errors import AppError
from app.core.pagination import normalize_page
from app.models.chat import Chat, Message, MessageHide, MessageRead
from app.models.user import User
from app.ws.hub import get_hub


def _pair_ids(user_a: int, user_b: int) -> tuple[int, int]:
    return (min(user_a, user_b), max(user_a, user_b))


def _other_user_id(chat: Chat, viewer_id: int) -> int:
    return chat.user_high_id if chat.user_low_id == viewer_id else chat.user_low_id


async def _load_user(db: AsyncSession, user_id: int) -> User:
    result = await db.execute(
        select(User)
        .where(User.id == user_id, User.is_active.is_(True))
        .options(selectinload(User.subscription), selectinload(User.business))
    )
    user = result.scalar_one_or_none()
    if user is None:
        raise AppError(
            message="Foydalanuvchi topilmadi",
            error_code="USER_NOT_FOUND",
            status_code=404,
        )
    return user


async def _serialize_interlocutor(
    user: User,
    *,
    redis: Redis | None = None,
) -> dict:
    is_business = bool(
        user.subscription and user.subscription.plan == "business" and user.subscription.is_active
    )
    is_online = False
    last_seen_at: datetime | None = None
    if redis is not None:
        hub = get_hub()
        is_online = await hub.is_online(redis, user.id)
        last_seen_at = await hub.get_last_seen(redis, user.id)

    display_name = user.full_name
    avatar_url = user.avatar_url
    if is_business and user.business is not None:
        if user.business.company_name:
            display_name = user.business.company_name
        if user.business.logo_url:
            avatar_url = user.business.logo_url

    return {
        "id": user.id,
        "full_name": display_name,
        "number": user.number,
        "avatar_url": avatar_url,
        "is_online": is_online,
        "last_seen_at": last_seen_at,
        "native_language": user.native_language,
        "country": user.business.country if is_business and user.business else user.country,
        "is_business": is_business,
        "verified_badge": user.verified_badge,
    }


def _normalize_lang(code: str) -> str:
    return (code or "").split("_")[0].split("-")[0].lower()


def _preview_text(message: Message, *, viewer_id: int, viewer_language: str) -> str | None:
    if message.type != "text":
        return None
    if message.sender_id == viewer_id:
        return message.text_original
    lang = _normalize_lang(viewer_language)
    for translation in message.translations or []:
        if _normalize_lang(translation.language) == lang:
            return translation.text
    return message.text_original


async def _serialize_last_message(
    db: AsyncSession,
    message: Message | None,
    *,
    viewer: User,
) -> dict | None:
    if message is None or message.deleted_for_everyone:
        return None

    hidden = await db.execute(
        select(MessageHide.id).where(
            MessageHide.message_id == message.id,
            MessageHide.user_id == viewer.id,
        )
    )
    if hidden.scalar_one_or_none() is not None:
        return None

    return {
        "id": message.id,
        "type": message.type,
        "text": _preview_text(message, viewer_id=viewer.id, viewer_language=viewer.native_language),
        "meta": message.meta,
        "sender_id": message.sender_id,
        "created_at": message.created_at,
    }


async def _unread_count(db: AsyncSession, chat_id: int, viewer_id: int) -> int:
    hidden_subq = (
        select(MessageHide.message_id)
        .where(MessageHide.user_id == viewer_id)
        .scalar_subquery()
    )
    read_subq = (
        select(MessageRead.message_id)
        .where(MessageRead.user_id == viewer_id)
        .scalar_subquery()
    )
    result = await db.execute(
        select(func.count())
        .select_from(Message)
        .where(
            Message.chat_id == chat_id,
            Message.sender_id != viewer_id,
            Message.deleted_for_everyone.is_(False),
            Message.id.notin_(hidden_subq),
            Message.id.notin_(read_subq),
        )
    )
    return int(result.scalar() or 0)


async def _get_chat_for_user(db: AsyncSession, chat_id: int, user_id: int) -> Chat:
    result = await db.execute(select(Chat).where(Chat.id == chat_id))
    chat = result.scalar_one_or_none()
    if chat is None or user_id not in {chat.user_low_id, chat.user_high_id}:
        raise AppError(message="Chat topilmadi", error_code="CHAT_NOT_FOUND", status_code=404)
    return chat


async def get_or_create_chat(
    db: AsyncSession,
    *,
    user: User,
    target_user_id: int,
    redis: Redis | None = None,
) -> dict:
    if target_user_id == user.id:
        raise AppError(
            message="O'zingiz bilan chat ochib bo'lmaydi",
            error_code="CANNOT_CHAT_SELF",
            status_code=400,
        )

    target = await _load_user(db, target_user_id)
    low, high = _pair_ids(user.id, target.id)

    result = await db.execute(
        select(Chat).where(Chat.user_low_id == low, Chat.user_high_id == high)
    )
    chat = result.scalar_one_or_none()
    if chat is None:
        chat = Chat(user_low_id=low, user_high_id=high, has_messages=False)
        db.add(chat)
        await db.flush()
        await db.refresh(chat)

    interlocutor = await _serialize_interlocutor(target, redis=redis)
    last_message: dict | None = None
    if chat.last_message_id is not None:
        msg_result = await db.execute(
            select(Message)
            .where(Message.id == chat.last_message_id)
            .options(selectinload(Message.translations))
        )
        last_message = await _serialize_last_message(
            db, msg_result.scalar_one_or_none(), viewer=user
        )

    unread = await _unread_count(db, chat.id, user.id) if chat.has_messages else 0

    return {
        "id": chat.id,
        "interlocutor": interlocutor,
        "last_message": last_message,
        "unread_count": unread,
        "last_message_at": chat.last_message_at,
    }


async def list_chats(
    db: AsyncSession,
    *,
    user: User,
    redis: Redis,
    page: int | None,
    limit: int | None,
) -> dict:
    params = normalize_page(page, limit, default_size=50, max_size=100)

    query = (
        select(Chat)
        .where(
            Chat.has_messages.is_(True),
            or_(Chat.user_low_id == user.id, Chat.user_high_id == user.id),
        )
        .order_by(Chat.last_message_at.desc().nullslast(), Chat.id.desc())
    )
    result = await db.execute(query)
    chats = list(result.scalars().all())
    hidden_raw = await redis.smembers(f"chat_hidden:{user.id}")
    hidden_ids: set[int] = set()
    for x in hidden_raw or []:
        try:
            hidden_ids.add(int(x if not isinstance(x, bytes) else x.decode()))
        except (TypeError, ValueError):
            continue
    if hidden_ids:
        chats = [c for c in chats if c.id not in hidden_ids]
    total = len(chats)
    page_chats = chats[params.offset : params.offset + params.limit]

    other_ids = [_other_user_id(c, user.id) for c in page_chats]
    users_by_id: dict[int, User] = {}
    if other_ids:
        users_result = await db.execute(
            select(User)
            .where(User.id.in_(other_ids))
            .options(selectinload(User.subscription), selectinload(User.business))
        )
        users_by_id = {u.id: u for u in users_result.scalars().all()}

    items: list[dict] = []
    for chat in page_chats:
        other_id = _other_user_id(chat, user.id)
        interlocutor_user = users_by_id.get(other_id)
        if interlocutor_user is None:
            continue

        last_message: dict | None = None
        if chat.last_message_id is not None:
            msg_result = await db.execute(
                select(Message)
                .where(Message.id == chat.last_message_id)
                .options(selectinload(Message.translations))
            )
            last_message = await _serialize_last_message(
                db, msg_result.scalar_one_or_none(), viewer=user
            )

        items.append(
            {
                "id": chat.id,
                "interlocutor": await _serialize_interlocutor(interlocutor_user, redis=redis),
                "last_message": last_message,
                "unread_count": await _unread_count(db, chat.id, user.id),
                "last_message_at": chat.last_message_at,
            }
        )

    return {
        "items": items,
        "page": params.page,
        "limit": params.page_size,
        "total": total,
        "has_more": params.offset + len(items) < total,
    }


async def search_chats(
    db: AsyncSession,
    *,
    user: User,
    query: str,
    redis: Redis,
) -> dict:
    q = query.strip()
    if not q:
        return {"items": []}

    pattern = f"%{q}%"
    chats_result = await db.execute(
        select(Chat)
        .where(
            Chat.has_messages.is_(True),
            or_(Chat.user_low_id == user.id, Chat.user_high_id == user.id),
        )
        .order_by(Chat.last_message_at.desc().nullslast())
    )
    chats = list(chats_result.scalars().all())
    hidden_raw = await redis.smembers(f"chat_hidden:{user.id}")
    hidden_ids: set[int] = set()
    for x in hidden_raw or []:
        try:
            hidden_ids.add(int(x if not isinstance(x, bytes) else x.decode()))
        except (TypeError, ValueError):
            continue
    if hidden_ids:
        chats = [c for c in chats if c.id not in hidden_ids]
    if not chats:
        return {"items": []}

    other_ids = [_other_user_id(c, user.id) for c in chats]
    users_result = await db.execute(
        select(User)
        .where(
            User.id.in_(other_ids),
            or_(User.full_name.ilike(pattern), User.number.ilike(pattern)),
        )
        .options(selectinload(User.subscription), selectinload(User.business))
    )
    matching_users = {u.id: u for u in users_result.scalars().all()}

    items: list[dict] = []
    for chat in chats:
        other_id = _other_user_id(chat, user.id)
        interlocutor_user = matching_users.get(other_id)
        if interlocutor_user is None:
            continue
        items.append(
            {
                "id": chat.id,
                "interlocutor": await _serialize_interlocutor(interlocutor_user, redis=redis),
                "last_message_at": chat.last_message_at,
            }
        )

    return {"items": items}


async def hide_chat(
    db: AsyncSession,
    *,
    user: User,
    chat_id: int,
    redis: Redis,
) -> dict:
    await _get_chat_for_user(db, chat_id, user.id)
    await redis.sadd(f"chat_hidden:{user.id}", chat_id)
    return {"id": chat_id, "hidden": True}


async def require_chat_access(db: AsyncSession, chat_id: int, user_id: int) -> Chat:
    return await _get_chat_for_user(db, chat_id, user_id)
