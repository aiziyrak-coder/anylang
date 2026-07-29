from __future__ import annotations

from fastapi import APIRouter, status

from app.api.deps_auth import CurrentUser
from app.core.deps import DbSession, RedisClient
from app.schemas.chat import ChatOut
from app.schemas.marketplace_groups import MarketplaceGroupListOut, MarketplaceGroupPreviewOut
from app.services import marketplace_groups as mpg_service

router = APIRouter()


@router.get("", response_model=MarketplaceGroupListOut)
async def list_marketplace_groups(
    db: DbSession,
    current_user: CurrentUser,
) -> MarketplaceGroupListOut:
    data = await mpg_service.list_marketplace_groups(db, viewer=current_user)
    return MarketplaceGroupListOut.model_validate(data)


@router.get("/{slug}/preview", response_model=MarketplaceGroupPreviewOut)
async def preview_marketplace_group(
    slug: str,
    db: DbSession,
    redis: RedisClient,
    current_user: CurrentUser,
) -> MarketplaceGroupPreviewOut:
    data = await mpg_service.preview_marketplace_group(
        db, viewer=current_user, slug=slug, redis=redis
    )
    return MarketplaceGroupPreviewOut.model_validate(data)


@router.post("/{slug}/join", response_model=ChatOut, status_code=status.HTTP_200_OK)
async def join_marketplace_group(
    slug: str,
    db: DbSession,
    redis: RedisClient,
    current_user: CurrentUser,
) -> ChatOut:
    data = await mpg_service.join_marketplace_group(
        db, viewer=current_user, slug=slug, redis=redis
    )
    await db.commit()
    return ChatOut.model_validate(data)
