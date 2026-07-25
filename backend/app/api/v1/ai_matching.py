from __future__ import annotations

from fastapi import APIRouter, Query

from app.api.deps_auth import CurrentUser
from app.core.deps import DbSession
from app.schemas.ai_matching import AiMatchingOut, AiRecommendationsOut
from app.services import ai_matching as matching_service

router = APIRouter()


@router.get("/matches", response_model=AiMatchingOut)
async def ai_matching_matches(
    db: DbSession,
    current_user: CurrentUser,
    locale: str = Query(default="uz", max_length=16),
) -> AiMatchingOut:
    data = await matching_service.get_matches(
        db,
        user=current_user,
        locale=locale,
    )
    return AiMatchingOut.model_validate(data)


@router.get("/recommendations", response_model=AiRecommendationsOut)
async def ai_matching_recommendations(
    db: DbSession,
    current_user: CurrentUser,
    locale: str = Query(default="uz", max_length=16),
    limit: int = Query(default=12, ge=1, le=30),
) -> AiRecommendationsOut:
    data = await matching_service.get_recommendations(
        db,
        user=current_user,
        locale=locale,
        limit=limit,
    )
    return AiRecommendationsOut.model_validate(data)
