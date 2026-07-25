from __future__ import annotations

from fastapi import APIRouter, Query, status

from app.api.deps_auth import CurrentUser
from app.core.deps import DbSession
from app.schemas.common import MessageResponse
from app.schemas.feed import FeedListOut, FeedPostCreateIn, FeedPostOut
from app.services import feed as feed_service

router = APIRouter()


@router.get("", response_model=FeedListOut)
async def list_feed(
    db: DbSession,
    current_user: CurrentUser,
    page: int | None = Query(default=1, ge=1),
    limit: int | None = Query(default=20, ge=1, le=50),
    post_type: str | None = Query(default=None),
    author_id: int | None = Query(default=None),
) -> FeedListOut:
    data = await feed_service.list_feed(
        db,
        viewer=current_user,
        page=page,
        limit=limit,
        post_type=post_type,
        author_id=author_id,
    )
    return FeedListOut.model_validate(data)


@router.post("", response_model=FeedPostOut, status_code=status.HTTP_201_CREATED)
async def create_feed_post(
    body: FeedPostCreateIn,
    db: DbSession,
    current_user: CurrentUser,
) -> FeedPostOut:
    data = await feed_service.create_post(db, user=current_user, payload=body)
    await db.commit()
    return FeedPostOut.model_validate(data)


@router.delete("/{post_id}", response_model=MessageResponse)
async def delete_feed_post(
    post_id: int,
    db: DbSession,
    current_user: CurrentUser,
) -> MessageResponse:
    await feed_service.delete_post(db, user=current_user, post_id=post_id)
    await db.commit()
    return MessageResponse(message="Post o‘chirildi")
