from __future__ import annotations

from fastapi import APIRouter

from app.api.deps_auth import CurrentUser
from app.core.deps import DbSession
from app.schemas.trade_assistant import TradeAssistantIn, TradeAssistantOut
from app.services import trade_assistant as trade_service

router = APIRouter()


@router.post("/chat", response_model=TradeAssistantOut)
async def trade_assistant_chat(
    body: TradeAssistantIn,
    db: DbSession,
    current_user: CurrentUser,
) -> TradeAssistantOut:
    _ = current_user
    data = await trade_service.reply_trade_assistant(
        db,
        message=body.message,
        history=body.history,
        locale=body.locale,
        seller_id=body.seller_id,
    )
    return TradeAssistantOut.model_validate(data)
