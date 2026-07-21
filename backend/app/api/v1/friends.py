from __future__ import annotations

from fastapi import APIRouter, Query, status

from app.api.deps_auth import CurrentUser
from app.core.deps import DbSession, RedisClient
from app.schemas.friends import (
    FriendListOut,
    FriendRemovedOut,
    FriendRequestAcceptOut,
    FriendRequestCreateIn,
    FriendRequestListOut,
    FriendRequestOut,
    FriendRequestStatusOut,
)
from app.services import friends as friends_service

router = APIRouter()


@router.get("", response_model=FriendListOut)
async def list_friends(
    db: DbSession,
    current_user: CurrentUser,
    search: str | None = None,
    page: int | None = Query(default=None, ge=1),
    limit: int | None = Query(default=None, ge=1, le=100),
) -> FriendListOut:
    data = await friends_service.list_friends(
        db,
        user=current_user,
        search=search,
        page=page,
        limit=limit,
    )
    return FriendListOut.model_validate(data)


@router.post("/requests", response_model=FriendRequestOut, status_code=status.HTTP_201_CREATED)
async def send_friend_request(
    body: FriendRequestCreateIn,
    db: DbSession,
    redis: RedisClient,
    current_user: CurrentUser,
) -> FriendRequestOut:
    data = await friends_service.send_friend_request(
        db,
        redis,
        user=current_user,
        target_user_id=body.user_id,
    )
    return FriendRequestOut.model_validate(data)


@router.post("/requests/{request_id}/accept", response_model=FriendRequestAcceptOut)
async def accept_friend_request(
    request_id: int,
    db: DbSession,
    current_user: CurrentUser,
) -> FriendRequestAcceptOut:
    data = await friends_service.accept_friend_request(
        db,
        user=current_user,
        request_id=request_id,
    )
    return FriendRequestAcceptOut.model_validate(data)


@router.post("/requests/{request_id}/decline", response_model=FriendRequestStatusOut)
async def decline_friend_request(
    request_id: int,
    db: DbSession,
    current_user: CurrentUser,
) -> FriendRequestStatusOut:
    data = await friends_service.decline_friend_request(
        db,
        user=current_user,
        request_id=request_id,
    )
    return FriendRequestStatusOut.model_validate(data)


@router.delete("/requests/{request_id}", response_model=FriendRequestStatusOut)
async def cancel_friend_request(
    request_id: int,
    db: DbSession,
    current_user: CurrentUser,
) -> FriendRequestStatusOut:
    data = await friends_service.cancel_friend_request(
        db,
        user=current_user,
        request_id=request_id,
    )
    return FriendRequestStatusOut.model_validate(data)


@router.get("/requests", response_model=FriendRequestListOut)
async def list_friend_requests(
    db: DbSession,
    current_user: CurrentUser,
    type: str = Query(default="incoming", pattern="^(incoming|outgoing)$"),
    page: int | None = Query(default=None, ge=1),
    limit: int | None = Query(default=None, ge=1, le=100),
) -> FriendRequestListOut:
    data = await friends_service.list_friend_requests(
        db,
        user=current_user,
        request_type=type,
        page=page,
        limit=limit,
    )
    return FriendRequestListOut.model_validate(data)


@router.delete("/{user_id}", response_model=FriendRemovedOut)
async def remove_friend(
    user_id: int,
    db: DbSession,
    current_user: CurrentUser,
) -> FriendRemovedOut:
    data = await friends_service.remove_friend(
        db,
        user=current_user,
        friend_user_id=user_id,
    )
    return FriendRemovedOut.model_validate(data)
