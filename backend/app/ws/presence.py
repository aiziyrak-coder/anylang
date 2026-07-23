"""Presence helpers — notify friends and chat partners on online/offline."""

from __future__ import annotations

import logging

from sqlalchemy import or_, select

from app.db.session import get_session_factory
from app.models.chat import Chat, Friendship
from app.ws.hub import get_hub

logger = logging.getLogger(__name__)


async def friend_user_ids(user_id: int) -> set[int]:
    factory = get_session_factory()
    async with factory() as db:
        result = await db.execute(
            select(Friendship.user_low_id, Friendship.user_high_id).where(
                Friendship.status == "accepted",
                or_(
                    Friendship.user_low_id == user_id,
                    Friendship.user_high_id == user_id,
                ),
            )
        )
        ids: set[int] = set()
        for low, high in result.all():
            other = high if low == user_id else low
            ids.add(int(other))
        return ids


async def chat_partner_ids(user_id: int) -> set[int]:
    """Anyone who already has a 1:1 chat with this user (even if not friends)."""
    factory = get_session_factory()
    async with factory() as db:
        result = await db.execute(
            select(Chat.user_low_id, Chat.user_high_id).where(
                or_(Chat.user_low_id == user_id, Chat.user_high_id == user_id)
            )
        )
        ids: set[int] = set()
        for low, high in result.all():
            other = high if low == user_id else low
            ids.add(int(other))
        return ids


async def broadcast_presence(user_id: int, *, is_online: bool) -> None:
    try:
        friends = await friend_user_ids(user_id)
        partners = await chat_partner_ids(user_id)
        targets = friends | partners
        if not targets:
            return
        hub = get_hub()
        await hub.publish_many(
            targets,
            "presence",
            {"user_id": user_id, "is_online": is_online},
        )
    except Exception:
        logger.exception("Failed to broadcast presence for user %s", user_id)
