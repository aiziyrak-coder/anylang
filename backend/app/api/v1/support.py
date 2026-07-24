from __future__ import annotations

from fastapi import APIRouter, Request

from app.api.deps_auth import CurrentUser
from app.core.deps import RedisClient
from app.core.rate_limit import client_ip, enforce_rate_limit
from app.schemas.support import SupportChatIn, SupportChatOut
from app.services import support_chat as support_service

router = APIRouter()


@router.post("/chat", response_model=SupportChatOut)
async def support_chat(
    body: SupportChatIn,
    current_user: CurrentUser,
) -> SupportChatOut:
    _ = current_user  # auth required; identity reserved for future logging
    reply = await support_service.reply_support(
        message=body.message,
        history=body.history,
        locale=body.locale,
        source="app",
    )
    return SupportChatOut(reply=reply, agent_name=support_service.agent_name())


@router.post("/public", response_model=SupportChatOut)
async def support_chat_public(
    body: SupportChatIn,
    request: Request,
    redis: RedisClient,
) -> SupportChatOut:
    """Landing / sayt uchun ochiq qo'llab-quvvatlash (authsiz, rate-limit)."""
    ip = client_ip(request)
    await enforce_rate_limit(
        redis,
        f"support:public:ip:{ip}",
        limit=20,
        window_seconds=3600,
        message="Juda ko'p so'rov. Biroz kutib qayta yozing",
    )
    reply = await support_service.reply_support(
        message=body.message,
        history=body.history,
        locale=body.locale,
        source="landing",
    )
    return SupportChatOut(reply=reply, agent_name=support_service.agent_name())
