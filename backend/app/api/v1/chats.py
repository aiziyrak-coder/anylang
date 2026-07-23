from __future__ import annotations

from fastapi import APIRouter, File, Form, Query, UploadFile, status

from app.api.deps_auth import CurrentUser
from app.core.deps import DbSession, RedisClient
from app.core.uploads import read_upload_limited
from app.schemas.chat import (
    ChatCreateIn,
    ChatListOut,
    ChatMediaUploadOut,
    ChatOut,
    ChatSearchOut,
    MessageCreateIn,
    MessageDeletedOut,
    MessageListOut,
    MessageOut,
    ReadMessagesIn,
    ReadMessagesOut,
)
from app.services import chats as chats_service
from app.services import messages as messages_service

router = APIRouter()
messages_router = APIRouter()


@router.get("", response_model=ChatListOut)
async def list_chats(
    db: DbSession,
    redis: RedisClient,
    current_user: CurrentUser,
    page: int | None = Query(default=None, ge=1),
    limit: int | None = Query(default=None, ge=1, le=100),
) -> ChatListOut:
    data = await chats_service.list_chats(
        db,
        user=current_user,
        redis=redis,
        page=page,
        limit=limit,
    )
    return ChatListOut.model_validate(data)


@router.post("", response_model=ChatOut, status_code=status.HTTP_200_OK)
async def get_or_create_chat(
    body: ChatCreateIn,
    db: DbSession,
    redis: RedisClient,
    current_user: CurrentUser,
) -> ChatOut:
    data = await chats_service.get_or_create_chat(
        db,
        user=current_user,
        target_user_id=body.user_id,
        redis=redis,
    )
    return ChatOut.model_validate(data)


@router.get("/search", response_model=ChatSearchOut)
async def search_chats(
    db: DbSession,
    redis: RedisClient,
    current_user: CurrentUser,
    query: str = Query(min_length=1),
) -> ChatSearchOut:
    data = await chats_service.search_chats(
        db,
        user=current_user,
        query=query,
        redis=redis,
    )
    return ChatSearchOut.model_validate(data)


@router.post("/{chat_id}/hide", status_code=status.HTTP_200_OK)
async def hide_chat(
    chat_id: int,
    db: DbSession,
    redis: RedisClient,
    current_user: CurrentUser,
) -> dict:
    return await chats_service.hide_chat(
        db,
        user=current_user,
        chat_id=chat_id,
        redis=redis,
    )


@router.post("/{chat_id}/mute", status_code=status.HTTP_200_OK)
async def mute_chat(
    chat_id: int,
    db: DbSession,
    redis: RedisClient,
    current_user: CurrentUser,
) -> dict:
    return await chats_service.set_chat_muted(
        db,
        user=current_user,
        chat_id=chat_id,
        muted=True,
        redis=redis,
    )


@router.delete("/{chat_id}/mute", status_code=status.HTTP_200_OK)
async def unmute_chat(
    chat_id: int,
    db: DbSession,
    redis: RedisClient,
    current_user: CurrentUser,
) -> dict:
    return await chats_service.set_chat_muted(
        db,
        user=current_user,
        chat_id=chat_id,
        muted=False,
        redis=redis,
    )


@router.get("/{chat_id}/messages", response_model=MessageListOut)
async def list_chat_messages(
    chat_id: int,
    db: DbSession,
    current_user: CurrentUser,
    limit: int | None = Query(default=None, ge=1, le=100),
    before_id: int | None = Query(default=None),
    after_id: int | None = Query(default=None),
) -> MessageListOut:
    data = await messages_service.list_messages(
        db,
        user=current_user,
        chat_id=chat_id,
        limit=limit,
        before_id=before_id,
        after_id=after_id,
    )
    return MessageListOut.model_validate(data)


@router.post("/{chat_id}/messages", response_model=MessageOut, status_code=status.HTTP_201_CREATED)
async def send_message(
    chat_id: int,
    body: MessageCreateIn,
    db: DbSession,
    redis: RedisClient,
    current_user: CurrentUser,
) -> MessageOut:
    data = await messages_service.create_message(
        db,
        redis,
        user=current_user,
        chat_id=chat_id,
        client_message_id=body.client_message_id,
        msg_type=body.type,
        text=body.text,
        meta=body.meta,
        reply_to_id=body.reply_to_id,
        media_id=body.media_id,
    )
    return MessageOut.model_validate(data)


@router.post("/media", response_model=ChatMediaUploadOut, status_code=status.HTTP_201_CREATED)
async def upload_chat_media(
    db: DbSession,
    current_user: CurrentUser,
    file: UploadFile = File(...),
    media_type: str = Form(...),
) -> ChatMediaUploadOut:
    data = await messages_service.upload_chat_media(
        db,
        user=current_user,
        media_type=media_type,
        filename=file.filename or "upload",
        content_type=file.content_type or "application/octet-stream",
        data=await read_upload_limited(file, max_bytes=50 * 1024 * 1024),
    )
    return ChatMediaUploadOut.model_validate(data)


@router.post("/{chat_id}/read", response_model=ReadMessagesOut)
async def mark_chat_read(
    chat_id: int,
    body: ReadMessagesIn,
    db: DbSession,
    redis: RedisClient,
    current_user: CurrentUser,
) -> ReadMessagesOut:
    data = await messages_service.mark_messages_read(
        db,
        redis,
        user=current_user,
        chat_id=chat_id,
        message_ids=body.message_ids,
    )
    return ReadMessagesOut.model_validate(data)


@messages_router.delete("/messages/{message_id}", response_model=MessageDeletedOut)
async def delete_message(
    message_id: int,
    db: DbSession,
    redis: RedisClient,
    current_user: CurrentUser,
    for_everyone: bool = Query(default=False),
) -> MessageDeletedOut:
    data = await messages_service.delete_message(
        db,
        redis,
        user=current_user,
        message_id=message_id,
        for_everyone=for_everyone,
    )
    return MessageDeletedOut.model_validate(data)
