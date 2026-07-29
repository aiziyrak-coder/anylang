"""Chat Shared Media — photos / videos / files / audio / links / voice."""

from __future__ import annotations

import re

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.chat import Message
from app.models.user import User
from app.services.chats import _get_chat_for_user

_URL_RE = re.compile(r"https?://[^\s<>\"']+", re.IGNORECASE)

_SECTION_TYPES: dict[str, list[str]] = {
    "photos": ["image"],
    "videos": ["video"],
    "files": ["file", "invoice"],
    "audio": ["audio"],
    "voice": ["voice"],
    "links": ["text"],
}


def _meta(msg: Message) -> dict:
    return msg.meta if isinstance(msg.meta, dict) else {}


def _sender_name(user: User | None) -> str | None:
    if user is None:
        return None
    if (
        user.subscription
        and user.subscription.plan == "business"
        and user.subscription.is_active
        and user.business
        and user.business.company_name
    ):
        return user.business.company_name
    return user.full_name


def _url_from_meta(meta: dict) -> str | None:
    for key in ("url", "file_url", "image_url", "video_url"):
        val = meta.get(key)
        if isinstance(val, str) and val.strip():
            return val.strip()
    return None


def _first_link(text: str | None) -> str | None:
    if not text:
        return None
    m = _URL_RE.search(text)
    return m.group(0) if m else None


def _item_title(msg: Message, section: str) -> str | None:
    meta = _meta(msg)
    if section == "photos":
        return None
    if section == "videos":
        if meta.get("is_round_note"):
            return "Round video"
        return meta.get("filename") or meta.get("name")
    if section in {"files", "audio"}:
        return meta.get("filename") or meta.get("name") or meta.get("title")
    if section == "voice":
        return None
    if section == "links":
        return _first_link(msg.text_original)
    return None


def _item_subtitle(msg: Message, section: str) -> str | None:
    meta = _meta(msg)
    if section == "files":
        size = meta.get("size")
        if isinstance(size, int) and size > 0:
            if size < 1024:
                return f"{size} B"
            if size < 1024 * 1024:
                return f"{size // 1024} KB"
            return f"{size / (1024 * 1024):.1f} MB"
    if section == "videos":
        ms = meta.get("duration_ms")
        if isinstance(ms, (int, float)) and ms > 0:
            sec = int(ms) // 1000
            return f"{sec // 60}:{sec % 60:02d}"
    if section == "voice":
        ms = meta.get("duration_ms")
        if isinstance(ms, (int, float)) and ms > 0:
            sec = int(ms) // 1000
            return f"{sec // 60}:{sec % 60:02d}"
    return None


async def _load_users_map(db: AsyncSession, user_ids: set[int]) -> dict[int, User]:
    if not user_ids:
        return {}
    result = await db.execute(
        select(User)
        .where(User.id.in_(user_ids))
        .options(selectinload(User.business), selectinload(User.subscription))
    )
    return {u.id: u for u in result.scalars().all()}


async def _count_section(db: AsyncSession, chat_id: int, section: str) -> int:
    types = _SECTION_TYPES.get(section) or []
    if not types:
        return 0
    if section == "links":
        result = await db.execute(
            select(func.count())
            .select_from(Message)
            .where(
                Message.chat_id == chat_id,
                Message.deleted_for_everyone.is_(False),
                Message.type == "text",
                Message.text_original.is_not(None),
                or_(
                    Message.text_original.ilike("%http://%"),
                    Message.text_original.ilike("%https://%"),
                ),
            )
        )
        return int(result.scalar() or 0)

    result = await db.execute(
        select(func.count())
        .select_from(Message)
        .where(
            Message.chat_id == chat_id,
            Message.deleted_for_everyone.is_(False),
            Message.type.in_(types),
        )
    )
    return int(result.scalar() or 0)


async def get_shared_media(
    db: AsyncSession,
    *,
    user: User,
    chat_id: int,
    section: str = "summary",
    before_id: int | None = None,
    limit: int = 40,
) -> dict:
    await _get_chat_for_user(db, chat_id, user.id)

    section = (section or "summary").strip().lower()
    if section not in {
        "summary",
        "photos",
        "videos",
        "files",
        "audio",
        "links",
        "voice",
    }:
        section = "summary"

    limit = max(1, min(int(limit or 40), 100))

    counts = {
        "photos": await _count_section(db, chat_id, "photos"),
        "videos": await _count_section(db, chat_id, "videos"),
        "files": await _count_section(db, chat_id, "files"),
        "audio": await _count_section(db, chat_id, "audio"),
        "links": await _count_section(db, chat_id, "links"),
        "voice": await _count_section(db, chat_id, "voice"),
    }
    total_msg = await db.execute(
        select(func.count())
        .select_from(Message)
        .where(
            Message.chat_id == chat_id,
            Message.deleted_for_everyone.is_(False),
        )
    )
    counts["total_messages"] = int(total_msg.scalar() or 0)

    if section == "summary":
        return {
            "counts": counts,
            "section": "summary",
            "items": [],
            "has_more": False,
        }

    types = _SECTION_TYPES[section]
    query = (
        select(Message)
        .where(
            Message.chat_id == chat_id,
            Message.deleted_for_everyone.is_(False),
            Message.type.in_(types),
        )
        .order_by(Message.id.desc())
        .limit(limit + 1)
    )
    if before_id is not None:
        query = query.where(Message.id < before_id)
    if section == "links":
        query = query.where(
            Message.text_original.is_not(None),
            or_(
                Message.text_original.ilike("%http://%"),
                Message.text_original.ilike("%https://%"),
            ),
        )

    result = await db.execute(query)
    rows = list(result.scalars().all())
    has_more = len(rows) > limit
    rows = rows[:limit]

    users = await _load_users_map(db, {m.sender_id for m in rows})
    items: list[dict] = []
    for msg in rows:
        meta = _meta(msg)
        url = _url_from_meta(meta)
        if section == "links" and not url:
            url = _first_link(msg.text_original)
        items.append(
            {
                "id": msg.id,
                "type": msg.type,
                "section": section,
                "created_at": msg.created_at,
                "sender_id": msg.sender_id,
                "sender_name": _sender_name(users.get(msg.sender_id)),
                "text": msg.text_original,
                "meta": meta or None,
                "url": url,
                "title": _item_title(msg, section),
                "subtitle": _item_subtitle(msg, section),
            }
        )

    return {
        "counts": counts,
        "section": section,
        "items": items,
        "has_more": has_more,
    }
