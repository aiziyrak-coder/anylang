from __future__ import annotations

from datetime import UTC, datetime

from redis.asyncio import Redis
from sqlalchemy import func, nullslast, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.errors import AppError
from app.core.pagination import normalize_page
from app.integrations.translation import _normalize_lang, user_preferred_lang
from app.models.chat import Chat, ChatParticipant, Message, MessageHide, MessageRead
from app.models.user import User
from app.ws.hub import get_hub


def _pair_ids(user_a: int, user_b: int) -> tuple[int, int]:
    return (min(user_a, user_b), max(user_a, user_b))


def _is_group(chat: Chat) -> bool:
    return (chat.type or "direct") == "group"


def _other_user_id(chat: Chat, viewer_id: int) -> int:
    if _is_group(chat):
        raise AppError(
            message="Guruh chatida yakka suhbatdosh yo'q",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )
    if chat.user_low_id is None or chat.user_high_id is None:
        raise AppError(message="Chat topilmadi", error_code="CHAT_NOT_FOUND", status_code=404)
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


def _preview_text(message: Message, *, viewer_id: int, viewer_language: str) -> str | None:
    if message.type != "text":
        return None
    if message.sender_id == viewer_id:
        return message.text_original
    lang = _normalize_lang(viewer_language)
    for translation in message.translations or []:
        if _normalize_lang(translation.language) != lang:
            continue
        if (translation.status or "done") != "done":
            break
        if (translation.text or "").strip():
            return translation.text
        break
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
        "text": _preview_text(message, viewer_id=viewer.id, viewer_language=user_preferred_lang(viewer)),
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


async def _ensure_participant(db: AsyncSession, *, chat_id: int, user_id: int, role: str = "member") -> None:
    existing = await db.execute(
        select(ChatParticipant.id).where(
            ChatParticipant.chat_id == chat_id,
            ChatParticipant.user_id == user_id,
        )
    )
    if existing.scalar_one_or_none() is not None:
        return
    db.add(ChatParticipant(chat_id=chat_id, user_id=user_id, role=role))


async def _get_participant(db: AsyncSession, chat_id: int, user_id: int) -> ChatParticipant | None:
    result = await db.execute(
        select(ChatParticipant).where(
            ChatParticipant.chat_id == chat_id,
            ChatParticipant.user_id == user_id,
        )
    )
    return result.scalar_one_or_none()


async def _participant_ids(db: AsyncSession, chat_id: int) -> list[int]:
    result = await db.execute(
        select(ChatParticipant.user_id).where(ChatParticipant.chat_id == chat_id)
    )
    return list(result.scalars().all())


async def _get_chat_for_user(db: AsyncSession, chat_id: int, user_id: int) -> Chat:
    result = await db.execute(select(Chat).where(Chat.id == chat_id))
    chat = result.scalar_one_or_none()
    if chat is None:
        raise AppError(message="Chat topilmadi", error_code="CHAT_NOT_FOUND", status_code=404)

    # Prefer participants table; fall back to legacy pair for safety.
    part = await _get_participant(db, chat_id, user_id)
    if part is not None:
        return chat
    if user_id in {chat.user_low_id, chat.user_high_id}:
        await _ensure_participant(db, chat_id=chat.id, user_id=user_id)
        await db.flush()
        return chat
    raise AppError(message="Chat topilmadi", error_code="CHAT_NOT_FOUND", status_code=404)


async def _serialize_chat(
    db: AsyncSession,
    *,
    chat: Chat,
    viewer: User,
    redis: Redis | None,
    participant: ChatParticipant | None = None,
) -> dict:
    if participant is None:
        participant = await _get_participant(db, chat.id, viewer.id)

    muted = bool(participant.muted) if participant else False
    if redis is not None and not muted:
        muted = bool(await redis.sismember(f"chat_muted:{viewer.id}", chat.id))

    pinned = bool(participant and participant.pinned_at is not None)
    count_result = await db.execute(
        select(func.count()).select_from(ChatParticipant).where(ChatParticipant.chat_id == chat.id)
    )
    participant_count = int(count_result.scalar() or 0)

    last_message: dict | None = None
    if chat.last_message_id is not None:
        msg_result = await db.execute(
            select(Message)
            .where(Message.id == chat.last_message_id)
            .options(selectinload(Message.translations))
        )
        last_message = await _serialize_last_message(
            db, msg_result.scalar_one_or_none(), viewer=viewer
        )

    unread = await _unread_count(db, chat.id, viewer.id) if chat.has_messages else 0
    base = {
        "id": chat.id,
        "type": chat.type or "direct",
        "title": chat.title,
        "avatar_url": chat.avatar_url,
        "interlocutor": None,
        "participant_count": participant_count,
        "last_message": last_message,
        "unread_count": unread,
        "last_message_at": chat.last_message_at,
        "muted": muted,
        "pinned": pinned,
    }

    if not _is_group(chat):
        other_id = _other_user_id(chat, viewer.id)
        other = await _load_user(db, other_id)
        base["interlocutor"] = await _serialize_interlocutor(other, redis=redis)
        base["participant_count"] = max(participant_count, 2)
    return base


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
        select(Chat).where(
            Chat.type == "direct",
            Chat.user_low_id == low,
            Chat.user_high_id == high,
        )
    )
    chat = result.scalar_one_or_none()
    if chat is None:
        chat = Chat(
            type="direct",
            user_low_id=low,
            user_high_id=high,
            has_messages=False,
            created_by=user.id,
        )
        db.add(chat)
        await db.flush()
        await _ensure_participant(db, chat_id=chat.id, user_id=user.id, role="member")
        await _ensure_participant(db, chat_id=chat.id, user_id=target.id, role="member")
        await db.flush()
        await db.refresh(chat)
    else:
        await _ensure_participant(db, chat_id=chat.id, user_id=user.id)
        await _ensure_participant(db, chat_id=chat.id, user_id=target.id)
        await db.flush()

    return await _serialize_chat(db, chat=chat, viewer=user, redis=redis)


async def create_group_chat(
    db: AsyncSession,
    *,
    user: User,
    title: str,
    user_ids: list[int],
    redis: Redis | None = None,
) -> dict:
    cleaned_title = title.strip()
    if not cleaned_title:
        raise AppError(message="Guruh nomi majburiy", error_code="VALIDATION_ERROR", status_code=400)

    unique_ids = []
    seen: set[int] = set()
    for uid in user_ids:
        if uid == user.id or uid in seen:
            continue
        seen.add(uid)
        unique_ids.append(uid)
    if not unique_ids:
        raise AppError(
            message="Guruhga kamida 1 ta a'zo qo'shing",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )
    if len(unique_ids) > 99:
        raise AppError(
            message="Guruhda maksimal 100 ta a'zo (Super Group da cheksiz)",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )

    members = []
    for uid in unique_ids:
        members.append(await _load_user(db, uid))

    from app.services.group_admin import DEFAULT_MEMBER_LIMIT, _new_invite_token

    chat = Chat(
        type="group",
        title=cleaned_title[:120],
        user_low_id=None,
        user_high_id=None,
        created_by=user.id,
        has_messages=False,
        invite_token=_new_invite_token(),
        invite_enabled=True,
        is_super=False,
        member_limit=DEFAULT_MEMBER_LIMIT,
    )
    db.add(chat)
    await db.flush()

    db.add(ChatParticipant(chat_id=chat.id, user_id=user.id, role="owner"))
    for member in members:
        db.add(ChatParticipant(chat_id=chat.id, user_id=member.id, role="member"))
    await db.flush()
    await db.refresh(chat)

    data = await _serialize_chat(db, chat=chat, viewer=user, redis=redis)
    from app.services.group_admin import enrich_chat_dict

    return await enrich_chat_dict(db, data, viewer=user, chat=chat)


async def update_group_chat(
    db: AsyncSession,
    *,
    user: User,
    chat_id: int,
    title: str | None,
    redis: Redis | None = None,
) -> dict:
    chat = await _get_chat_for_user(db, chat_id, user.id)
    if not _is_group(chat):
        raise AppError(message="Bu guruh emas", error_code="NOT_A_GROUP", status_code=400)
    part = await _get_participant(db, chat_id, user.id)
    if part is None or part.role not in {"owner", "admin"}:
        raise AppError(message="Ruxsat yo'q", error_code="FORBIDDEN", status_code=403)
    if title is not None:
        cleaned = title.strip()
        if not cleaned:
            raise AppError(message="Guruh nomi majburiy", error_code="VALIDATION_ERROR", status_code=400)
        chat.title = cleaned[:120]
    await db.flush()
    data = await _serialize_chat(db, chat=chat, viewer=user, redis=redis, participant=part)
    from app.services.group_admin import enrich_chat_dict

    return await enrich_chat_dict(db, data, viewer=user, chat=chat)


async def list_chats(
    db: AsyncSession,
    *,
    user: User,
    redis: Redis,
    page: int | None,
    limit: int | None,
    sort: str = "activity",
    chat_type: str | None = None,
) -> dict:
    params = normalize_page(page, limit, default_size=50, max_size=100)

    query = (
        select(Chat, ChatParticipant)
        .join(ChatParticipant, ChatParticipant.chat_id == Chat.id)
        .where(ChatParticipant.user_id == user.id)
        .where(
            or_(
                Chat.type == "group",
                Chat.has_messages.is_(True),
            )
        )
    )
    if chat_type in {"direct", "group"}:
        query = query.where(Chat.type == chat_type)

    if sort == "unread":
        # Approximate: activity first; unread re-ranked in Python after counts.
        query = query.order_by(
            nullslast(ChatParticipant.pinned_at.desc()),
            nullslast(Chat.last_message_at.desc()),
            Chat.id.desc(),
        )
    elif sort == "name":
        query = query.order_by(
            nullslast(ChatParticipant.pinned_at.desc()),
            func.lower(func.coalesce(Chat.title, "")).asc(),
            Chat.id.desc(),
        )
    else:
        # activity (default): pin first, then last message
        query = query.order_by(
            nullslast(ChatParticipant.pinned_at.desc()),
            nullslast(Chat.last_message_at.desc()),
            Chat.id.desc(),
        )

    result = await db.execute(query)
    rows = list(result.all())

    hidden_raw = await redis.smembers(f"chat_hidden:{user.id}")
    hidden_ids: set[int] = set()
    for x in hidden_raw or []:
        try:
            hidden_ids.add(int(x if not isinstance(x, bytes) else x.decode()))
        except (TypeError, ValueError):
            continue
    if hidden_ids:
        rows = [(c, p) for c, p in rows if c.id not in hidden_ids]

    items_full: list[dict] = []
    for chat, participant in rows:
        items_full.append(
            await _serialize_chat(
                db, chat=chat, viewer=user, redis=redis, participant=participant
            )
        )

    if sort == "unread":
        items_full.sort(
            key=lambda x: (
                0 if x.get("pinned") else 1,
                0 if (x.get("unread_count") or 0) > 0 else 1,
                -(
                    datetime.fromisoformat(x["last_message_at"]).timestamp()
                    if isinstance(x.get("last_message_at"), str)
                    else (x["last_message_at"].timestamp() if x.get("last_message_at") else 0)
                ),
            )
        )
    elif sort == "name":
        items_full.sort(
            key=lambda x: (
                0 if x.get("pinned") else 1,
                (
                    (x.get("title") or (x.get("interlocutor") or {}).get("full_name") or "")
                    .lower()
                ),
            )
        )

    total = len(items_full)
    page_items = items_full[params.offset : params.offset + params.limit]
    return {
        "items": page_items,
        "page": params.page,
        "limit": params.page_size,
        "total": total,
        "has_more": params.offset + len(page_items) < total,
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
    result = await db.execute(
        select(Chat, ChatParticipant)
        .join(ChatParticipant, ChatParticipant.chat_id == Chat.id)
        .where(ChatParticipant.user_id == user.id)
        .where(or_(Chat.type == "group", Chat.has_messages.is_(True)))
        .order_by(nullslast(Chat.last_message_at.desc()))
    )
    rows = list(result.all())
    hidden_raw = await redis.smembers(f"chat_hidden:{user.id}")
    hidden_ids: set[int] = set()
    for x in hidden_raw or []:
        try:
            hidden_ids.add(int(x if not isinstance(x, bytes) else x.decode()))
        except (TypeError, ValueError):
            continue

    items: list[dict] = []
    for chat, _part in rows:
        if chat.id in hidden_ids:
            continue
        if _is_group(chat):
            if chat.title and q.lower() in chat.title.lower():
                items.append(
                    {
                        "id": chat.id,
                        "type": "group",
                        "title": chat.title,
                        "interlocutor": None,
                        "last_message_at": chat.last_message_at,
                    }
                )
            continue
        try:
            other_id = _other_user_id(chat, user.id)
        except AppError:
            continue
        other = await db.execute(
            select(User)
            .where(
                User.id == other_id,
                or_(User.full_name.ilike(pattern), User.number.ilike(pattern)),
            )
            .options(selectinload(User.subscription), selectinload(User.business))
        )
        interlocutor_user = other.scalar_one_or_none()
        if interlocutor_user is None:
            continue
        items.append(
            {
                "id": chat.id,
                "type": "direct",
                "title": None,
                "interlocutor": await _serialize_interlocutor(interlocutor_user, redis=redis),
                "last_message_at": chat.last_message_at,
            }
        )

    return {"items": items}


async def set_chat_pinned(
    db: AsyncSession,
    *,
    user: User,
    chat_id: int,
    pinned: bool,
) -> dict:
    chat = await _get_chat_for_user(db, chat_id, user.id)
    part = await _get_participant(db, chat_id, user.id)
    if part is None:
        part = ChatParticipant(chat_id=chat.id, user_id=user.id, role="member")
        db.add(part)
    part.pinned_at = datetime.now(UTC) if pinned else None
    await db.flush()
    return {"id": chat_id, "pinned": pinned}


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


async def set_chat_muted(
    db: AsyncSession,
    *,
    user: User,
    chat_id: int,
    muted: bool,
    redis: Redis,
) -> dict:
    await _get_chat_for_user(db, chat_id, user.id)
    part = await _get_participant(db, chat_id, user.id)
    if part is not None:
        part.muted = muted
    key = f"chat_muted:{user.id}"
    if muted:
        await redis.sadd(key, chat_id)
    else:
        await redis.srem(key, chat_id)
    await db.flush()
    return {"id": chat_id, "muted": muted}


async def is_chat_muted(redis: Redis, *, user_id: int, chat_id: int) -> bool:
    return bool(await redis.sismember(f"chat_muted:{user_id}", chat_id))


async def block_user(redis: Redis, *, user_id: int, peer_id: int) -> dict:
    if peer_id <= 0 or peer_id == user_id:
        raise AppError(message="Noto'g'ri foydalanuvchi", error_code="VALIDATION_ERROR", status_code=400)
    await redis.sadd(f"blocked:{user_id}", peer_id)
    return {"user_id": peer_id, "blocked": True}


async def unblock_user(redis: Redis, *, user_id: int, peer_id: int) -> dict:
    await redis.srem(f"blocked:{user_id}", peer_id)
    return {"user_id": peer_id, "blocked": False}


async def list_blocked_user_ids(redis: Redis, *, user_id: int) -> list[int]:
    raw = await redis.smembers(f"blocked:{user_id}")
    out: list[int] = []
    for x in raw or []:
        try:
            out.append(int(x if not isinstance(x, bytes) else x.decode()))
        except (TypeError, ValueError):
            continue
    return out


async def require_chat_access(db: AsyncSession, chat_id: int, user_id: int) -> Chat:
    return await _get_chat_for_user(db, chat_id, user_id)


async def list_chat_member_ids(db: AsyncSession, chat_id: int) -> list[int]:
    return await _participant_ids(db, chat_id)
