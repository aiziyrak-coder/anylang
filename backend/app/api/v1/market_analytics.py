from __future__ import annotations

from fastapi import APIRouter, Query

from app.api.deps_auth import CurrentUser
from app.core.deps import DbSession
from app.schemas.market_analytics import MarketAnalyticsOut
from app.services import market_analytics as analytics_service

router = APIRouter()


@router.get("/insights", response_model=MarketAnalyticsOut)
async def market_analytics_insights(
    db: DbSession,
    current_user: CurrentUser,
    locale: str = Query(default="uz", max_length=16),
) -> MarketAnalyticsOut:
    data = await analytics_service.get_market_analytics(
        db,
        user=current_user,
        locale=locale,
    )
    return MarketAnalyticsOut.model_validate(data)
