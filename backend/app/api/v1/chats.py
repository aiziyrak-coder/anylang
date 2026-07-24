from __future__ import annotations

import uuid

from fastapi import APIRouter, BackgroundTasks, File, Form, Query, UploadFile, status

from app.api.deps_auth import CurrentUser
from app.core.deps import DbSession, RedisClient
from app.core.uploads import read_upload_limited
from app.schemas.chat import (
    ChatCreateIn,
    ChatListOut,
    ChatMediaUploadOut,
    ChatOut,
    ChatSearchOut,
    ClearHistoryIn,
    GroupCreateIn,
    GroupMembersAddIn,
    GroupUpdateIn,
    InviteOut,
    MembersOut,
    MessageCreateIn,
    MessageDeletedOut,
    MessageEditIn,
    MessageForwardIn,
    MessageListOut,
    MessageOut,
    ReactionIn,
    ReadMessagesIn,
    ReadMessagesOut,
    TransferOwnershipIn,
)
from app.models.chat import Chat
from app.services import chats as chats_service
from app.services import group_admin as group_admin_service
from app.services import message_features as message_features_service
from app.services import messages as messages_service
from app.services.business import _upload_image

router = APIRouter()
messages_router = APIRouter()


@router.get("", response_model=ChatListOut)
async def list_chats(
    db: DbSession,
    redis: RedisClient,
    current_user: CurrentUser,
    page: int | None = Query(default=None, ge=1),
    limit: int | None = Query(default=None, ge=1, le=100),
    sort: str = Query(default="activity", pattern="^(activity|unread|name)$"),
    chat_type: str | None = Query(default=None, alias="type", pattern="^(direct|group)$"),
) -> ChatListOut:
    data = await chats_service.list_chats(
        db,
        user=current_user,
        redis=redis,
        page=page,
        limit=limit,
        sort=sort,
        chat_type=chat_type,
    )
    items = []
    for item in data["items"]:
        chat = await db.get(Chat, item["id"])
        if chat is not None and chats_service._is_group(chat):
            item = await group_admin_service.enrich_chat_dict(
                db, item, viewer=current_user, chat=chat
            )
        items.append(item)
    data = {**data, "items": items}
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


@router.post("/groups", response_model=ChatOut, status_code=status.HTTP_201_CREATED)
async def create_group(
    body: GroupCreateIn,
    db: DbSession,
    redis: RedisClient,
    current_user: CurrentUser,
) -> ChatOut:
    data = await chats_service.create_group_chat(
        db,
        user=current_user,
        title=body.title,
        user_ids=body.user_ids,
        redis=redis,
    )
    await db.commit()
    return ChatOut.model_validate(data)


@router.post("/join/{token}", response_model=ChatOut)
async def join_group_by_token(
    token: str,
    db: DbSession,
    redis: RedisClient,
    current_user: CurrentUser,
) -> ChatOut:
    data = await group_admin_service.join_by_token(
        db, user=current_user, token=token, redis=redis
    )
    await db.commit()
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


@router.patch("/{chat_id}", response_model=ChatOut)
async def update_group(
    chat_id: int,
    body: GroupUpdateIn,
    db: DbSession,
    redis: RedisClient,
    current_user: CurrentUser,
) -> ChatOut:
    data = await chats_service.update_group_chat(
        db,
        user=current_user,
        chat_id=chat_id,
        title=body.title,
        redis=redis,
    )
    await db.commit()
    return ChatOut.model_validate(data)


@router.delete("/{chat_id}", status_code=status.HTTP_200_OK)
async def delete_group(
    chat_id: int,
    db: DbSession,
    current_user: CurrentUser,
) -> dict:
    data = await group_admin_service.delete_group(db, user=current_user, chat_id=chat_id)
    await db.commit()
    return data


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


@router.post("/{chat_id}/pin", status_code=status.HTTP_200_OK)
async def pin_chat(
    chat_id: int,
    db: DbSession,
    current_user: CurrentUser,
) -> dict:
    data = await chats_service.set_chat_pinned(
        db,
        user=current_user,
        chat_id=chat_id,
        pinned=True,
    )
    await db.commit()
    return data


@router.delete("/{chat_id}/pin", status_code=status.HTTP_200_OK)
async def unpin_chat(
    chat_id: int,
    db: DbSession,
    current_user: CurrentUser,
) -> dict:
    data = await chats_service.set_chat_pinned(
        db,
        user=current_user,
        chat_id=chat_id,
        pinned=False,
    )
    await db.commit()
    return data


@router.get("/{chat_id}/members", response_model=MembersOut)
async def list_members(
    chat_id: int,
    db: DbSession,
    redis: RedisClient,
    current_user: CurrentUser,
) -> MembersOut:
    data = await group_admin_service.list_members(
        db, user=current_user, chat_id=chat_id, redis=redis
    )
    return MembersOut.model_validate(data)


@router.post("/{chat_id}/members", response_model=MembersOut)
async def add_members(
    chat_id: int,
    body: GroupMembersAddIn,
    db: DbSession,
    redis: RedisClient,
    current_user: CurrentUser,
) -> MembersOut:
    data = await group_admin_service.add_members(
        db,
        user=current_user,
        chat_id=chat_id,
        user_ids=body.user_ids,
        redis=redis,
    )
    await db.commit()
    return MembersOut.model_validate(data)


@router.delete("/{chat_id}/members/{user_id}", status_code=status.HTTP_200_OK)
async def remove_member(
    chat_id: int,
    user_id: int,
    db: DbSession,
    redis: RedisClient,
    current_user: CurrentUser,
) -> dict:
    data = await group_admin_service.remove_member(
        db,
        user=current_user,
        chat_id=chat_id,
        target_user_id=user_id,
        redis=redis,
    )
    await db.commit()
    return data


@router.post("/{chat_id}/leave", status_code=status.HTTP_200_OK)
async def leave_group(
    chat_id: int,
    db: DbSession,
    redis: RedisClient,
    current_user: CurrentUser,
) -> dict:
    data = await group_admin_service.leave_group(
        db, user=current_user, chat_id=chat_id, redis=redis
    )
    await db.commit()
    return data


@router.post("/{chat_id}/transfer-ownership", status_code=status.HTTP_200_OK)
async def transfer_ownership(
    chat_id: int,
    body: TransferOwnershipIn,
    db: DbSession,
    current_user: CurrentUser,
) -> dict:
    data = await group_admin_service.transfer_ownership(
        db, user=current_user, chat_id=chat_id, new_owner_id=body.user_id
    )
    await db.commit()
    return data


@router.post("/{chat_id}/admins/{user_id}", status_code=status.HTTP_200_OK)
async def promote_admin(
    chat_id: int,
    user_id: int,
    db: DbSession,
    current_user: CurrentUser,
) -> dict:
    data = await group_admin_service.promote_admin(
        db, user=current_user, chat_id=chat_id, target_user_id=user_id
    )
    await db.commit()
    return data


@router.delete("/{chat_id}/admins/{user_id}", status_code=status.HTTP_200_OK)
async def demote_admin(
    chat_id: int,
    user_id: int,
    db: DbSession,
    current_user: CurrentUser,
) -> dict:
    data = await group_admin_service.demote_admin(
        db, user=current_user, chat_id=chat_id, target_user_id=user_id
    )
    await db.commit()
    return data


@router.get("/{chat_id}/invite", response_model=InviteOut)
async def get_invite(
    chat_id: int,
    db: DbSession,
    current_user: CurrentUser,
) -> InviteOut:
    data = await group_admin_service.get_invite(db, user=current_user, chat_id=chat_id)
    return InviteOut.model_validate(data)


@router.post("/{chat_id}/invite", response_model=InviteOut)
async def regenerate_invite(
    chat_id: int,
    db: DbSession,
    current_user: CurrentUser,
) -> InviteOut:
    data = await group_admin_service.regenerate_invite(db, user=current_user, chat_id=chat_id)
    await db.commit()
    return InviteOut.model_validate(data)


@router.delete("/{chat_id}/invite", status_code=status.HTTP_200_OK)
async def disable_invite(
    chat_id: int,
    db: DbSession,
    current_user: CurrentUser,
) -> dict:
    data = await group_admin_service.disable_invite(db, user=current_user, chat_id=chat_id)
    await db.commit()
    return data


@router.post("/{chat_id}/avatar", response_model=ChatOut)
async def upload_group_avatar(
    chat_id: int,
    db: DbSession,
    redis: RedisClient,
    current_user: CurrentUser,
    file: UploadFile = File(...),
) -> ChatOut:
    key = f"group-avatars/{chat_id}/{uuid.uuid4().hex}.webp"
    url = await _upload_image(file, key)
    data = await group_admin_service.set_group_avatar(
        db, user=current_user, chat_id=chat_id, avatar_url=url, redis=redis
    )
    await db.commit()
    return ChatOut.model_validate(data)


@router.post("/{chat_id}/clear", status_code=status.HTTP_200_OK)
async def clear_history(
    chat_id: int,
    body: ClearHistoryIn,
    db: DbSession,
    redis: RedisClient,
    current_user: CurrentUser,
) -> dict:
    data = await message_features_service.clear_chat_history(
        db,
        redis,
        user=current_user,
        chat_id=chat_id,
        for_everyone=body.for_everyone,
    )
    await db.commit()
    return data


@router.get("/{chat_id}/pinned-messages", response_model=MessageListOut)
async def list_pinned_messages(
    chat_id: int,
    db: DbSession,
    current_user: CurrentUser,
) -> MessageListOut:
    data = await message_features_service.list_pinned(db, user=current_user, chat_id=chat_id)
    return MessageListOut.model_validate({"items": data["items"], "has_more": False})


@router.post("/{chat_id}/messages/{message_id}/pin", status_code=status.HTTP_200_OK)
async def pin_message(
    chat_id: int,
    message_id: int,
    db: DbSession,
    redis: RedisClient,
    current_user: CurrentUser,
) -> dict:
    data = await message_features_service.pin_message(
        db, redis, user=current_user, chat_id=chat_id, message_id=message_id
    )
    await db.commit()
    return data


@router.delete("/{chat_id}/messages/{message_id}/pin", status_code=status.HTTP_200_OK)
async def unpin_message(
    chat_id: int,
    message_id: int,
    db: DbSession,
    redis: RedisClient,
    current_user: CurrentUser,
) -> dict:
    data = await message_features_service.unpin_message(
        db, redis, user=current_user, chat_id=chat_id, message_id=message_id
    )
    await db.commit()
    return data


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
    data = await message_features_service.enrich_messages(
        db, data, viewer_id=current_user.id, chat_id=chat_id
    )
    return MessageListOut.model_validate(data)


@router.post("/{chat_id}/messages", response_model=MessageOut, status_code=status.HTTP_201_CREATED)
async def send_message(
    chat_id: int,
    body: MessageCreateIn,
    background_tasks: BackgroundTasks,
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
    job = data.pop("_translation_job", None)
    await db.commit()
    if job:
        background_tasks.add_task(
            messages_service.finish_message_translation_job,
            message_id=job["message_id"],
            chat_id=job["chat_id"],
            text=job["text"],
            target_lang=job["target_lang"],
            source_lang=job["source_lang"],
            sender_id=job["sender_id"],
            sender_language=job["sender_language"],
            recipient_id=job["recipient_id"],
            recipient_language=job["recipient_language"],
        )
    return MessageOut.model_validate(data)


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


@messages_router.patch("/messages/{message_id}", response_model=MessageOut)
async def edit_message(
    message_id: int,
    body: MessageEditIn,
    db: DbSession,
    redis: RedisClient,
    current_user: CurrentUser,
) -> MessageOut:
    data = await message_features_service.edit_message(
        db, redis, user=current_user, message_id=message_id, text=body.text
    )
    await db.commit()
    return MessageOut.model_validate(data)


@messages_router.post("/messages/{message_id}/forward", status_code=status.HTTP_200_OK)
async def forward_message(
    message_id: int,
    body: MessageForwardIn,
    db: DbSession,
    redis: RedisClient,
    current_user: CurrentUser,
) -> dict:
    data = await message_features_service.forward_message(
        db,
        redis,
        user=current_user,
        message_id=message_id,
        chat_ids=body.chat_ids,
        hide_sender=body.hide_sender,
    )
    await db.commit()
    return data


@messages_router.post("/messages/{message_id}/reactions", status_code=status.HTTP_200_OK)
async def set_reaction(
    message_id: int,
    body: ReactionIn,
    db: DbSession,
    redis: RedisClient,
    current_user: CurrentUser,
) -> dict:
    data = await message_features_service.set_reaction(
        db, redis, user=current_user, message_id=message_id, emoji=body.emoji
    )
    await db.commit()
    return data


@messages_router.delete("/messages/{message_id}/reactions", status_code=status.HTTP_200_OK)
async def remove_reaction(
    message_id: int,
    db: DbSession,
    redis: RedisClient,
    current_user: CurrentUser,
) -> dict:
    data = await message_features_service.remove_reaction(
        db, redis, user=current_user, message_id=message_id
    )
    await db.commit()
    return data


@messages_router.get("/messages/{message_id}/reactions", status_code=status.HTTP_200_OK)
async def list_reactions(
    message_id: int,
    db: DbSession,
    current_user: CurrentUser,
) -> dict:
    return await message_features_service.list_reactions_detailed(
        db, user=current_user, message_id=message_id
    )


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
