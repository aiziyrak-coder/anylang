"""ARQ job: deliver FCM push to a user's registered devices."""

from __future__ import annotations

import logging
from typing import Any

logger = logging.getLogger(__name__)


async def send_push_job(
    _ctx: dict,
    user_id: int,
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
    collapse_key: str | None = None,
) -> dict[str, int]:
    from app.db.session import get_session_factory
    from app.services import push as push_service

    factory = get_session_factory()
    async with factory() as db:
        result = await push_service.send_to_user(
            db,
            user_id=int(user_id),
            title=title,
            body=body,
            data=data,
            collapse_key=collapse_key,
        )
        await db.commit()
    return result
