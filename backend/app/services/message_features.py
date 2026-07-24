"""Message edit, forward, pin, reactions, clear history."""

from __future__ import annotations

from datetime import UTC, datetime
from uuid import uuid4

from redis.asyncio import Redis
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.errors import AppError
from app.models.chat import Chat, ChatParticipant, Message, MessageHide, MessagePin, MessageReaction
from app.models.user import User
from app.services.chats import _get_chat_for_user, _get_participant, _is_group
from app.services.messages import (
    _load_reply_to_payloads,
    _load_sender_public_map,
    _serialize_message,
    _sender_public_fields,
)
from app.ws.hub import get_hub

ALLOWED_REACTIONS = {
    "👍",
    "❤️",
    "😂",
    "🔥",
    "😢",
    "🎉",
    "🙏",
    "👏",
    "😍",
    "😮",
    "😡",
    "🤔",
    "💯",
    "👀",
    "🤝",
    "💪",
    "✨",
    "🥰",
}


async def _member_ids(db: AsyncSession, chat_id: int) -> list[int]:
    result = await db.execute(
        select(ChatParticipant.user_id).where(ChatParticipant.chat_id == chat_id)
    )
    return list(result.scalars().all())


async def _publish_to_chat(db: AsyncSession, chat_id: int, event: str, payload: dict) -> None:
    hub = get_hub()
    for uid in await _member_ids(db, chat_id):
        try:
            await hub.publish(uid, event, payload)
        except Exception:
            pass


async def edit_message(
    db: AsyncSession,
    redis: Redis,
    *,
    user: User,
    message_id: int,
    text: str,
) -> dict:
    result = await db.execute(
        select(Message)
        .where(Message.id == message_id)
        .options(selectinload(Message.translations))
    )
    message = result.scalar_one_or_none()
    if message is None or message.deleted_for_everyone:
        raise AppError(message="Xabar topilmadi", error_code="MESSAGE_NOT_FOUND", status_code=404)
    await _get_chat_for_user(db, message.chat_id, user.id)
    if message.sender_id != user.id:
        raise AppError(message="Faqat o'z xabaringizni tahrirlaysiz", error_code="FORBIDDEN", status_code=403)
    if message.type != "text":
        raise AppError(message="Faqat matn tahrirlanadi", error_code="VALIDATION_ERROR", status_code=400)
    cleaned = (text or "").strip()
    if not cleaned:
        raise AppError(message="Matn bo'sh", error_code="VALIDATION_ERROR", status_code=400)
    message.text_original = cleaned
    message.edited_at = datetime.now(UTC)
    message.translations = []
    await db.flush()
    s_name, s_avatar = _sender_public_fields(user)
    payload = _serialize_message(
        message,
        viewer_id=user.id,
        viewer_language=user.native_language,
        sender_name=s_name,
        sender_avatar_url=s_avatar,
    )
    await _publish_to_chat(db, message.chat_id, "message_edited", {"chat_id": message.chat_id, "message": payload})
    return payload


async def forward_message(
    db: AsyncSession,
    redis: Redis,
    *,
    user: User,
    message_id: int,
    chat_ids: list[int],
    hide_sender: bool = False,
) -> dict:
    result = await db.execute(
        select(Message)
        .where(Message.id == message_id)
        .options(selectinload(Message.translations))
    )
    source = result.scalar_one_or_none()
    if source is None or source.deleted_for_everyone:
        raise AppError(message="Xabar topilmadi", error_code="MESSAGE_NOT_FOUND", status_code=404)
    await _get_chat_for_user(db, source.chat_id, user.id)
    sender_map = await _load_sender_public_map(db, {source.sender_id})
    src_name, _ = sender_map.get(source.sender_id, (None, None))
    base_meta = dict(source.meta or {})
    if hide_sender:
        # Telegram "Hide Sender Name" — o'zingiz yuborgandek ko'rinadi.
        forward_meta = {k: v for k, v in base_meta.items() if k != "forward_from"}
    else:
        forward_meta = {
            **base_meta,
            "forward_from": {
                "message_id": source.id,
                "chat_id": source.chat_id,
                "sender_id": source.sender_id,
                "sender_name": src_name or "",
            },
        }
    created: list[dict] = []
    for cid in chat_ids:
        await _get_chat_for_user(db, cid, user.id)
        msg = Message(
            chat_id=cid,
            sender_id=user.id,
            client_message_id=f"fwd_{uuid4().hex[:16]}",
            type=source.type,
            text_original=source.text_original,
            original_language=source.original_language,
            meta=forward_meta,
            status="sent",
            delivered_at=datetime.now(UTC),
        )
        msg.translations = []
        db.add(msg)
        await db.flush()
        chat = await db.get(Chat, cid)
        if chat is not None:
            chat.last_message_id = msg.id
            chat.last_message_at = msg.created_at
            chat.has_messages = True
        s_name, s_avatar = _sender_public_fields(user)
        payload = _serialize_message(
            msg,
            viewer_id=user.id,
            viewer_language=user.native_language,
            sender_name=s_name,
            sender_avatar_url=s_avatar,
        )
        await _publish_to_chat(db, cid, "new_message", {"chat_id": cid, "message": payload})
        created.append(payload)
    await db.flush()
    return {"items": created, "count": len(created)}


async def pin_message(
    db: AsyncSession, redis: Redis, *, user: User, chat_id: int, message_id: int
) -> dict:
    chat = await _get_chat_for_user(db, chat_id, user.id)
    if _is_group(chat):
        part = await _get_participant(db, chat_id, user.id)
        if part is None or part.role not in {"owner", "admin"}:
            raise AppError(message="Ruxsat yo'q", error_code="FORBIDDEN", status_code=403)
    msg = await db.get(Message, message_id)
    if msg is None or msg.chat_id != chat_id or msg.deleted_for_everyone:
        raise AppError(message="Xabar topilmadi", error_code="MESSAGE_NOT_FOUND", status_code=404)
    existing = await db.execute(
        select(MessagePin).where(MessagePin.chat_id == chat_id, MessagePin.message_id == message_id)
    )
    if existing.scalar_one_or_none() is None:
        max_pins = 20 if getattr(chat, "is_super", False) else 5
        count = await db.execute(
            select(MessagePin).where(MessagePin.chat_id == chat_id)
        )
        if len(list(count.scalars().all())) >= max_pins:
            raise AppError(
                message=f"Maksimal {max_pins} ta pin",
                error_code="PIN_LIMIT",
                status_code=400,
            )
        db.add(
            MessagePin(
                chat_id=chat_id,
                message_id=message_id,
                pinned_by=user.id,
                pinned_at=datetime.now(UTC),
            )
        )
        await db.flush()
    await _publish_to_chat(
        db, chat_id, "message_pinned", {"chat_id": chat_id, "message_id": message_id}
    )
    return {"ok": True, "chat_id": chat_id, "message_id": message_id, "pinned": True}


async def unpin_message(
    db: AsyncSession, redis: Redis, *, user: User, chat_id: int, message_id: int
) -> dict:
    chat = await _get_chat_for_user(db, chat_id, user.id)
    if _is_group(chat):
        part = await _get_participant(db, chat_id, user.id)
        if part is None or part.role not in {"owner", "admin"}:
            raise AppError(message="Ruxsat yo'q", error_code="FORBIDDEN", status_code=403)
    result = await db.execute(
        select(MessagePin).where(MessagePin.chat_id == chat_id, MessagePin.message_id == message_id)
    )
    pin = result.scalar_one_or_none()
    if pin is not None:
        await db.delete(pin)
        await db.flush()
    await _publish_to_chat(
        db, chat_id, "message_unpinned", {"chat_id": chat_id, "message_id": message_id}
    )
    return {"ok": True, "pinned": False}


async def list_pinned(db: AsyncSession, *, user: User, chat_id: int) -> dict:
    await _get_chat_for_user(db, chat_id, user.id)
    result = await db.execute(
        select(MessagePin, Message)
        .join(Message, Message.id == MessagePin.message_id)
        .where(MessagePin.chat_id == chat_id, Message.deleted_for_everyone.is_(False))
        .options(selectinload(Message.translations))
        .order_by(MessagePin.pinned_at.desc())
    )
    rows = list(result.all())
    sender_map = await _load_sender_public_map(db, {m.sender_id for _, m in rows})
    reply_map = await _load_reply_to_payloads(
        db, [m for _, m in rows], viewer_language=user.native_language
    )
    items = []
    for pin, msg in rows:
        s_name, s_avatar = sender_map.get(msg.sender_id, (None, None))
        payload = _serialize_message(
            msg,
            viewer_id=user.id,
            viewer_language=user.native_language,
            reply_to=reply_map.get(msg.reply_to_id) if msg.reply_to_id else None,
            sender_name=s_name,
            sender_avatar_url=s_avatar,
        )
        payload["pinned"] = True
        payload["pinned_at"] = pin.pinned_at
        items.append(payload)
    return {"items": items}


async def set_reaction(
    db: AsyncSession, redis: Redis, *, user: User, message_id: int, emoji: str
) -> dict:
    if emoji not in ALLOWED_REACTIONS:
        raise AppError(message="Noto'g'ri reaksiya", error_code="VALIDATION_ERROR", status_code=400)
    result = await db.execute(select(Message).where(Message.id == message_id))
    message = result.scalar_one_or_none()
    if message is None or message.deleted_for_everyone:
        raise AppError(message="Xabar topilmadi", error_code="MESSAGE_NOT_FOUND", status_code=404)
    await _get_chat_for_user(db, message.chat_id, user.id)
    existing = await db.execute(
        select(MessageReaction).where(
            MessageReaction.message_id == message_id,
            MessageReaction.user_id == user.id,
        )
    )
    row = existing.scalar_one_or_none()
    if row is None:
        db.add(
            MessageReaction(
                message_id=message_id,
                user_id=user.id,
                emoji=emoji,
                created_at=datetime.now(UTC),
            )
        )
    else:
        row.emoji = emoji
    await db.flush()
    summary = await reaction_summary(db, message_id=message_id, viewer_id=user.id)
    await _publish_to_chat(
        db,
        message.chat_id,
        "message_reaction",
        {"chat_id": message.chat_id, "message_id": message_id, "reactions": summary["reactions"]},
    )
    return summary


async def remove_reaction(
    db: AsyncSession, redis: Redis, *, user: User, message_id: int
) -> dict:
    result = await db.execute(select(Message).where(Message.id == message_id))
    message = result.scalar_one_or_none()
    if message is None:
        raise AppError(message="Xabar topilmadi", error_code="MESSAGE_NOT_FOUND", status_code=404)
    await _get_chat_for_user(db, message.chat_id, user.id)
    existing = await db.execute(
        select(MessageReaction).where(
            MessageReaction.message_id == message_id,
            MessageReaction.user_id == user.id,
        )
    )
    row = existing.scalar_one_or_none()
    if row is not None:
        await db.delete(row)
        await db.flush()
    summary = await reaction_summary(db, message_id=message_id, viewer_id=user.id)
    await _publish_to_chat(
        db,
        message.chat_id,
        "message_reaction",
        {"chat_id": message.chat_id, "message_id": message_id, "reactions": summary["reactions"]},
    )
    return summary


async def reaction_summary(db: AsyncSession, *, message_id: int, viewer_id: int) -> dict:
    result = await db.execute(
        select(MessageReaction).where(MessageReaction.message_id == message_id)
    )
    rows = list(result.scalars().all())
    counts: dict[str, dict] = {}
    for r in rows:
        bucket = counts.setdefault(r.emoji, {"emoji": r.emoji, "count": 0, "me": False, "users": []})
        bucket["count"] += 1
        if r.user_id == viewer_id:
            bucket["me"] = True
        bucket["users"].append({"user_id": r.user_id})
    return {"message_id": message_id, "reactions": list(counts.values())}


async def list_reactions_detailed(db: AsyncSession, *, user: User, message_id: int) -> dict:
    result = await db.execute(select(Message).where(Message.id == message_id))
    message = result.scalar_one_or_none()
    if message is None:
        raise AppError(message="Xabar topilmadi", error_code="MESSAGE_NOT_FOUND", status_code=404)
    await _get_chat_for_user(db, message.chat_id, user.id)
    rows = await db.execute(
        select(MessageReaction, User)
        .join(User, User.id == MessageReaction.user_id)
        .where(MessageReaction.message_id == message_id)
    )
    items = [
        {
            "emoji": react.emoji,
            "user_id": member.id,
            "full_name": member.full_name,
            "avatar_url": member.avatar_url,
        }
        for react, member in rows.all()
    ]
    return {"items": items, **(await reaction_summary(db, message_id=message_id, viewer_id=user.id))}


async def enrich_messages(
    db: AsyncSession,
    data: dict,
    *,
    viewer_id: int,
    chat_id: int,
) -> dict:
    """Attach reaction summaries + pinned flags to list_messages payload."""
    items = list(data.get("items") or [])
    if not items:
        return data
    ids = [int(m["id"]) for m in items if m.get("id") is not None]
    react_rows = await db.execute(
        select(MessageReaction).where(MessageReaction.message_id.in_(ids))
    )
    by_msg: dict[int, list[MessageReaction]] = {}
    for row in react_rows.scalars().all():
        by_msg.setdefault(row.message_id, []).append(row)

    pin_rows = await db.execute(
        select(MessagePin.message_id).where(
            MessagePin.chat_id == chat_id, MessagePin.message_id.in_(ids)
        )
    )
    pinned_ids = set(pin_rows.scalars().all())

    for item in items:
        mid = int(item["id"])
        rows = by_msg.get(mid, [])
        counts: dict[str, int] = {}
        mine: str | None = None
        for r in rows:
            counts[r.emoji] = counts.get(r.emoji, 0) + 1
            if r.user_id == viewer_id:
                mine = r.emoji
        item["reactions"] = [
            {"emoji": e, "count": c, "me": e == mine} for e, c in counts.items()
        ]
        item["pinned"] = mid in pinned_ids
    data["items"] = items
    return data


async def clear_chat_history(
    db: AsyncSession,
    redis: Redis,
    *,
    user: User,
    chat_id: int,
    for_everyone: bool = False,
) -> dict:
    chat = await _get_chat_for_user(db, chat_id, user.id)
    if for_everyone:
        if _is_group(chat):
            part = await _get_participant(db, chat_id, user.id)
            if part is None or part.role not in {"owner", "admin"}:
                raise AppError(message="Ruxsat yo'q", error_code="FORBIDDEN", status_code=403)
        result = await db.execute(
            select(Message).where(Message.chat_id == chat_id, Message.deleted_for_everyone.is_(False))
        )
        msgs = list(result.scalars().all())
        for m in msgs:
            m.deleted_for_everyone = True
            m.is_deleted = True
            m.text_original = None
            m.meta = None
        await db.flush()
        await _publish_to_chat(db, chat_id, "history_cleared", {"chat_id": chat_id, "for_everyone": True})
        return {"cleared": len(msgs), "for_everyone": True}

    result = await db.execute(
        select(Message.id).where(Message.chat_id == chat_id, Message.deleted_for_everyone.is_(False))
    )
    ids = list(result.scalars().all())
    existing = await db.execute(
        select(MessageHide.message_id).where(
            MessageHide.user_id == user.id, MessageHide.message_id.in_(ids or [0])
        )
    )
    already = set(existing.scalars().all())
    added = 0
    for mid in ids:
        if mid in already:
            continue
        db.add(MessageHide(message_id=mid, user_id=user.id))
        added += 1
    await db.flush()
    return {"cleared": added, "for_everyone": False}
