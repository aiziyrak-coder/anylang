"""Group membership, invite links, ownership, super-group helpers."""

from __future__ import annotations

import secrets
from datetime import UTC, datetime

from redis.asyncio import Redis
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.errors import AppError
from app.models.chat import Chat, ChatParticipant, Message
from app.models.user import User
from app.services.chats import (
    _get_chat_for_user,
    _get_participant,
    _is_group,
    _load_user,
    _serialize_chat,
    _serialize_interlocutor,
)
from app.ws.hub import get_hub

DEFAULT_MEMBER_LIMIT = 100
INVITE_BASE = "https://anylang.uz/g"


def _invite_link(token: str | None) -> str | None:
    if not token:
        return None
    return f"{INVITE_BASE}/{token}"


def _new_invite_token() -> str:
    return secrets.token_urlsafe(24)


def member_cap(chat: Chat) -> int | None:
    if chat.is_super:
        return None
    return chat.member_limit if chat.member_limit is not None else DEFAULT_MEMBER_LIMIT


async def _count_members(db: AsyncSession, chat_id: int) -> int:
    result = await db.execute(
        select(func.count()).select_from(ChatParticipant).where(ChatParticipant.chat_id == chat_id)
    )
    return int(result.scalar() or 0)


async def _require_group_member(
    db: AsyncSession, chat_id: int, user_id: int
) -> tuple[Chat, ChatParticipant]:
    chat = await _get_chat_for_user(db, chat_id, user_id)
    if not _is_group(chat):
        raise AppError(message="Bu guruh emas", error_code="NOT_A_GROUP", status_code=400)
    part = await _get_participant(db, chat_id, user_id)
    if part is None:
        raise AppError(message="Ruxsat yo'q", error_code="FORBIDDEN", status_code=403)
    return chat, part


async def _require_group_admin(
    db: AsyncSession, chat_id: int, user_id: int, *, owner_only: bool = False
) -> tuple[Chat, ChatParticipant]:
    chat, part = await _require_group_member(db, chat_id, user_id)
    if owner_only and part.role != "owner":
        raise AppError(message="Faqat asosiy admin", error_code="FORBIDDEN", status_code=403)
    if not owner_only and part.role not in {"owner", "admin"}:
        raise AppError(message="Ruxsat yo'q", error_code="FORBIDDEN", status_code=403)
    return chat, part


async def enrich_chat_dict(db: AsyncSession, data: dict, *, viewer: User, chat: Chat) -> dict:
    part = await _get_participant(db, chat.id, viewer.id)
    data["my_role"] = part.role if part else None
    data["is_super"] = bool(chat.is_super)
    data["created_by"] = chat.created_by
    data["member_limit"] = member_cap(chat)
    # Har qanday a'zo invite linkni ko'ra/ulasha oladi
    if part and chat.invite_enabled and chat.invite_token:
        data["invite_link"] = _invite_link(chat.invite_token)
    else:
        data["invite_link"] = None
    return data


async def list_members(db: AsyncSession, *, user: User, chat_id: int, redis: Redis | None) -> dict:
    await _get_chat_for_user(db, chat_id, user.id)
    result = await db.execute(
        select(ChatParticipant, User)
        .join(User, User.id == ChatParticipant.user_id)
        .where(ChatParticipant.chat_id == chat_id)
        .options(selectinload(User.subscription), selectinload(User.business))
        .order_by(ChatParticipant.id.asc())
    )
    items = []
    for part, member in result.all():
        profile = await _serialize_interlocutor(member, redis=redis)
        items.append(
            {
                "user_id": member.id,
                "role": part.role,
                "full_name": profile["full_name"],
                "avatar_url": profile.get("avatar_url"),
                "is_online": profile.get("is_online", False),
                "number": profile.get("number"),
            }
        )
    return {"items": items, "total": len(items)}


async def add_members(
    db: AsyncSession,
    *,
    user: User,
    chat_id: int,
    user_ids: list[int],
    redis: Redis | None = None,
) -> dict:
    # Guruh a'zosining har biri do'stlarini qo'sha oladi
    chat, _ = await _require_group_member(db, chat_id, user.id)
    cap = member_cap(chat)
    current = await _count_members(db, chat_id)
    unique: list[int] = []
    seen: set[int] = set()
    for uid in user_ids:
        if uid == user.id or uid in seen:
            continue
        seen.add(uid)
        unique.append(uid)
    if not unique:
        raise AppError(message="A'zo tanlanmadi", error_code="VALIDATION_ERROR", status_code=400)
    if cap is not None and current + len(unique) > cap:
        raise AppError(
            message=f"Limit: {cap} a'zo. Super Group ga o'ting",
            error_code="MEMBER_LIMIT",
            status_code=400,
            extra={"limit": cap, "current": current, "is_super": chat.is_super},
        )
    added = 0
    for uid in unique:
        existing = await _get_participant(db, chat_id, uid)
        if existing is not None:
            continue
        await _load_user(db, uid)
        db.add(ChatParticipant(chat_id=chat_id, user_id=uid, role="member"))
        added += 1
    await db.flush()
    hub = get_hub()
    try:
        for uid in unique:
            await hub.publish(uid, "group_updated", {"chat_id": chat_id, "reason": "member_added"})
    except Exception:
        pass
    return await list_members(db, user=user, chat_id=chat_id, redis=redis) | {"added": added}


async def remove_member(
    db: AsyncSession,
    *,
    user: User,
    chat_id: int,
    target_user_id: int,
    redis: Redis | None = None,
) -> dict:
    chat, actor = await _require_group_admin(db, chat_id, user.id)
    if target_user_id == user.id:
        raise AppError(message="O'zingizni chiqarib bo'lmaydi — leave ishlating", error_code="VALIDATION_ERROR", status_code=400)
    target = await _get_participant(db, chat_id, target_user_id)
    if target is None:
        raise AppError(message="A'zo topilmadi", error_code="NOT_FOUND", status_code=404)
    if target.role == "owner":
        raise AppError(message="Asosiy adminni chiqarib bo'lmaydi", error_code="FORBIDDEN", status_code=403)
    if actor.role == "admin" and target.role == "admin":
        raise AppError(message="Adminni faqat asosiy admin chiqara oladi", error_code="FORBIDDEN", status_code=403)
    await db.delete(target)
    await db.flush()
    try:
        await get_hub().publish(target_user_id, "group_member_removed", {"chat_id": chat_id})
    except Exception:
        pass
    return {"ok": True, "chat_id": chat_id, "removed_user_id": target_user_id}


async def leave_group(db: AsyncSession, *, user: User, chat_id: int, redis: Redis | None = None) -> dict:
    chat = await _get_chat_for_user(db, chat_id, user.id)
    if not _is_group(chat):
        raise AppError(message="Bu guruh emas", error_code="NOT_A_GROUP", status_code=400)
    part = await _get_participant(db, chat_id, user.id)
    if part is None:
        raise AppError(message="A'zo emassiz", error_code="NOT_FOUND", status_code=404)
    if part.role == "owner":
        raise AppError(
            message="Avval egalikni o'tkazing yoki guruhni o'chiring",
            error_code="TRANSFER_OR_DELETE_REQUIRED",
            status_code=400,
        )
    await db.delete(part)
    await db.flush()
    return {"ok": True, "chat_id": chat_id}


async def transfer_ownership(
    db: AsyncSession, *, user: User, chat_id: int, new_owner_id: int
) -> dict:
    chat, _ = await _require_group_admin(db, chat_id, user.id, owner_only=True)
    if new_owner_id == user.id:
        raise AppError(message="O'zingizga o'tkazib bo'lmaydi", error_code="VALIDATION_ERROR", status_code=400)
    new_part = await _get_participant(db, chat_id, new_owner_id)
    if new_part is None:
        raise AppError(message="Foydalanuvchi guruhda emas", error_code="NOT_FOUND", status_code=404)
    old = await _get_participant(db, chat_id, user.id)
    assert old is not None
    old.role = "admin"
    new_part.role = "owner"
    chat.created_by = new_owner_id
    await db.flush()
    return {"ok": True, "chat_id": chat_id, "owner_id": new_owner_id}


async def delete_group(db: AsyncSession, *, user: User, chat_id: int) -> dict:
    chat, _ = await _require_group_admin(db, chat_id, user.id, owner_only=True)
    member_ids = [
        r
        for (r,) in (
            await db.execute(select(ChatParticipant.user_id).where(ChatParticipant.chat_id == chat_id))
        ).all()
    ]
    await db.delete(chat)
    await db.flush()
    hub = get_hub()
    for uid in member_ids:
        try:
            await hub.publish(uid, "group_deleted", {"chat_id": chat_id})
        except Exception:
            pass
    return {"ok": True, "chat_id": chat_id}


async def promote_admin(db: AsyncSession, *, user: User, chat_id: int, target_user_id: int) -> dict:
    await _require_group_admin(db, chat_id, user.id, owner_only=True)
    target = await _get_participant(db, chat_id, target_user_id)
    if target is None:
        raise AppError(message="A'zo topilmadi", error_code="NOT_FOUND", status_code=404)
    if target.role == "owner":
        raise AppError(message="Allaqachon asosiy admin", error_code="VALIDATION_ERROR", status_code=400)
    target.role = "admin"
    await db.flush()
    return {"ok": True, "user_id": target_user_id, "role": "admin"}


async def demote_admin(db: AsyncSession, *, user: User, chat_id: int, target_user_id: int) -> dict:
    await _require_group_admin(db, chat_id, user.id, owner_only=True)
    target = await _get_participant(db, chat_id, target_user_id)
    if target is None:
        raise AppError(message="A'zo topilmadi", error_code="NOT_FOUND", status_code=404)
    if target.role != "admin":
        raise AppError(message="Bu foydalanuvchi admin emas", error_code="VALIDATION_ERROR", status_code=400)
    target.role = "member"
    await db.flush()
    return {"ok": True, "user_id": target_user_id, "role": "member"}


async def get_invite(db: AsyncSession, *, user: User, chat_id: int) -> dict:
    chat, part = await _require_group_member(db, chat_id, user.id)
    # Yangi token yaratish — faqat admin; oddiy a'zo mavjud linkni oladi
    if part.role in {"owner", "admin"} and not chat.invite_token:
        chat.invite_token = _new_invite_token()
        chat.invite_enabled = True
        await db.flush()
    return {
        "token": chat.invite_token if chat.invite_enabled else None,
        "link": _invite_link(chat.invite_token) if chat.invite_enabled and chat.invite_token else None,
        "enabled": bool(chat.invite_enabled and chat.invite_token),
    }


async def regenerate_invite(db: AsyncSession, *, user: User, chat_id: int) -> dict:
    chat, _ = await _require_group_admin(db, chat_id, user.id)
    chat.invite_token = _new_invite_token()
    chat.invite_enabled = True
    await db.flush()
    return {
        "token": chat.invite_token,
        "link": _invite_link(chat.invite_token),
        "enabled": True,
    }


async def disable_invite(db: AsyncSession, *, user: User, chat_id: int) -> dict:
    chat, _ = await _require_group_admin(db, chat_id, user.id)
    chat.invite_enabled = False
    await db.flush()
    return {"ok": True, "enabled": False}


async def preview_by_token(
    db: AsyncSession, *, user: User, token: str
) -> dict:
    result = await db.execute(
        select(Chat).where(Chat.invite_token == token, Chat.type == "group")
    )
    chat = result.scalar_one_or_none()
    if chat is None or not chat.invite_enabled:
        raise AppError(
            message="Invite yaroqsiz",
            error_code="INVITE_INVALID",
            status_code=404,
        )
    existing = await _get_participant(db, chat.id, user.id)
    title = (chat.title or "").strip() or "Guruh"
    return {
        "token": token,
        "title": title,
        "avatar_url": chat.avatar_url,
        "member_count": await _count_members(db, chat.id),
        "is_member": existing is not None,
        "is_super": bool(chat.is_super),
        "chat_id": chat.id if existing is not None else None,
        "invite_link": _invite_link(chat.invite_token),
    }


async def join_by_token(
    db: AsyncSession, *, user: User, token: str, redis: Redis | None = None
) -> dict:
    result = await db.execute(select(Chat).where(Chat.invite_token == token, Chat.type == "group"))
    chat = result.scalar_one_or_none()
    if chat is None or not chat.invite_enabled:
        raise AppError(message="Invite yaroqsiz", error_code="INVITE_INVALID", status_code=404)
    existing = await _get_participant(db, chat.id, user.id)
    if existing is not None:
        return await enrich_chat_dict(
            db,
            await _serialize_chat(db, chat=chat, viewer=user, redis=redis, participant=existing),
            viewer=user,
            chat=chat,
        )
    cap = member_cap(chat)
    current = await _count_members(db, chat.id)
    if cap is not None and current >= cap:
        raise AppError(
            message="Guruh to'ldi",
            error_code="MEMBER_LIMIT",
            status_code=400,
        )
    part = ChatParticipant(chat_id=chat.id, user_id=user.id, role="member")
    db.add(part)
    await db.flush()
    return await enrich_chat_dict(
        db,
        await _serialize_chat(db, chat=chat, viewer=user, redis=redis, participant=part),
        viewer=user,
        chat=chat,
    )


async def set_group_avatar(
    db: AsyncSession, *, user: User, chat_id: int, avatar_url: str, redis: Redis | None = None
) -> dict:
    chat, part = await _require_group_admin(db, chat_id, user.id)
    chat.avatar_url = avatar_url
    await db.flush()
    data = await _serialize_chat(db, chat=chat, viewer=user, redis=redis, participant=part)
    return await enrich_chat_dict(db, data, viewer=user, chat=chat)


async def mark_chat_super(db: AsyncSession, *, chat_id: int, payment_id: int) -> None:
    chat = await db.get(Chat, chat_id)
    if chat is None or not _is_group(chat):
        raise AppError(message="Guruh topilmadi", error_code="NOT_FOUND", status_code=404)
    chat.is_super = True
    chat.member_limit = None
    chat.super_payment_id = payment_id
    await db.flush()
