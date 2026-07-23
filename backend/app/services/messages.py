from __future__ import annotations

from datetime import UTC, datetime
from io import BytesIO
from uuid import uuid4

from PIL import Image
from redis.asyncio import Redis
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.errors import AppError
from app.integrations.storage import get_storage
from app.integrations.translation import _normalize_lang, translate
from app.models.chat import Chat, ChatMedia, Message, MessageHide, MessageRead, MessageTranslation
from app.models.user import User
from app.services.chats import _get_chat_for_user, _other_user_id
from app.ws.hub import get_hub

DEFAULT_MESSAGE_LIMIT = 50
MAX_MESSAGE_LIMIT = 100

MAX_IMAGE_BYTES = 10 * 1024 * 1024
MAX_VIDEO_BYTES = 50 * 1024 * 1024
MAX_AUDIO_BYTES = 10 * 1024 * 1024
MAX_FILE_BYTES = 20 * 1024 * 1024

ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp", "image/gif"}
ALLOWED_VIDEO_TYPES = {"video/mp4", "video/webm", "video/quicktime"}
ALLOWED_AUDIO_TYPES = {
    "audio/mp4",
    "audio/aac",
    "audio/x-m4a",
    "audio/wav",
    "audio/x-wav",
    "audio/ogg",
    "audio/mpeg",
    "audio/mp3",
}
ALLOWED_FILE_TYPES = {
    "application/pdf",
    "application/msword",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "text/plain",
}

MEDIA_RULES: dict[str, dict] = {
    "image": {"types": ALLOWED_IMAGE_TYPES, "max_bytes": MAX_IMAGE_BYTES, "verify_image": True},
    "video": {"types": ALLOWED_VIDEO_TYPES, "max_bytes": MAX_VIDEO_BYTES, "verify_image": False},
    "audio": {"types": ALLOWED_AUDIO_TYPES, "max_bytes": MAX_AUDIO_BYTES, "verify_image": False},
    "voice": {"types": ALLOWED_AUDIO_TYPES, "max_bytes": MAX_AUDIO_BYTES, "verify_image": False},
    "file": {
        "types": ALLOWED_FILE_TYPES | ALLOWED_IMAGE_TYPES,
        "max_bytes": MAX_FILE_BYTES,
        "verify_image": False,
    },
}


def _pick_translation_text(message: Message, viewer_language: str) -> str | None:
    """Viewer tilidagi tarjimani qaytaradi; bo'sh qatorni e'tiborsiz qoldiradi."""
    lang = _normalize_lang(viewer_language)
    for tr in message.translations or []:
        if _normalize_lang(tr.language) != lang:
            continue
        if (tr.text or "").strip():
            return tr.text
    return None


async def _load_recipient(db: AsyncSession, chat: Chat, sender_id: int) -> User:
    recipient_id = _other_user_id(chat, sender_id)
    result = await db.execute(select(User).where(User.id == recipient_id))
    user = result.scalar_one_or_none()
    if user is None:
        raise AppError(message="Foydalanuvchi topilmadi", error_code="USER_NOT_FOUND", status_code=404)
    return user


def _reply_preview_text(message: Message, viewer_language: str) -> str | None:
    if message.is_deleted or message.deleted_for_everyone:
        return None
    if message.type != "text":
        return None
    translated = _pick_translation_text(message, viewer_language)
    return translated if translated is not None else message.text_original


def _serialize_reply_to(
    reply: Message,
    *,
    sender_name: str,
    viewer_language: str,
) -> dict:
    deleted = bool(reply.is_deleted or reply.deleted_for_everyone)
    return {
        "id": reply.id,
        "sender_id": reply.sender_id,
        "sender_name": sender_name,
        "type": reply.type,
        "preview_text": None if deleted else _reply_preview_text(reply, viewer_language),
        "is_deleted": deleted,
    }


async def _load_reply_to_payloads(
    db: AsyncSession,
    messages: list[Message],
    *,
    viewer_language: str,
) -> dict[int, dict]:
    reply_ids = {m.reply_to_id for m in messages if m.reply_to_id is not None}
    if not reply_ids:
        return {}

    result = await db.execute(
        select(Message)
        .where(Message.id.in_(reply_ids))
        .options(selectinload(Message.translations))
    )
    replies = list(result.scalars().all())
    if not replies:
        return {}

    sender_ids = {r.sender_id for r in replies}
    users_result = await db.execute(select(User).where(User.id.in_(sender_ids)))
    names = {u.id: u.full_name for u in users_result.scalars().all()}

    return {
        r.id: _serialize_reply_to(
            r,
            sender_name=names.get(r.sender_id, ""),
            viewer_language=viewer_language,
        )
        for r in replies
    }


def _serialize_message(
    message: Message,
    *,
    viewer_id: int,
    viewer_language: str,
    read_message_ids: set[int] | None = None,
    reply_to: dict | None = None,
) -> dict:
    if message.deleted_for_everyone:
        text_original = None
        text = None
        meta = None
    else:
        text_original = message.text_original
        text = message.text_original
        if message.type == "text" and message.sender_id != viewer_id:
            translated = _pick_translation_text(message, viewer_language)
            if translated is not None:
                text = translated
        meta = message.meta

    read_by_recipient = False
    if read_message_ids is not None:
        read_by_recipient = message.id in read_message_ids

    return {
        "id": message.id,
        "chat_id": message.chat_id,
        "sender_id": message.sender_id,
        "client_message_id": message.client_message_id,
        "type": message.type,
        "text": text,
        "text_original": text_original,
        "original_language": message.original_language,
        "meta": meta,
        "reply_to_id": message.reply_to_id,
        "reply_to": reply_to,
        "status": message.status,
        "delivered_at": message.delivered_at,
        "is_deleted": message.is_deleted,
        "deleted_for_everyone": message.deleted_for_everyone,
        "translations": [
            {"language": t.language, "text": t.text, "status": t.status}
            for t in (message.translations or [])
        ],
        "read_by_recipient": read_by_recipient,
        "created_at": message.created_at,
    }


async def _hidden_message_ids(db: AsyncSession, viewer_id: int, message_ids: list[int]) -> set[int]:
    if not message_ids:
        return set()
    result = await db.execute(
        select(MessageHide.message_id).where(
            MessageHide.user_id == viewer_id,
            MessageHide.message_id.in_(message_ids),
        )
    )
    return set(result.scalars().all())


async def list_messages(
    db: AsyncSession,
    *,
    user: User,
    chat_id: int,
    limit: int | None,
    before_id: int | None,
    after_id: int | None,
) -> dict:
    await _get_chat_for_user(db, chat_id, user.id)

    safe_limit = min(max(limit or DEFAULT_MESSAGE_LIMIT, 1), MAX_MESSAGE_LIMIT)

    query = (
        select(Message)
        .where(Message.chat_id == chat_id, Message.deleted_for_everyone.is_(False))
        .options(selectinload(Message.translations))
    )

    if before_id is not None:
        anchor = await db.get(Message, before_id)
        if anchor is None or anchor.chat_id != chat_id:
            raise AppError(message="Xabar topilmadi", error_code="MESSAGE_NOT_FOUND", status_code=404)
        query = query.where(Message.id < before_id).order_by(Message.id.desc()).limit(safe_limit + 1)
    elif after_id is not None:
        anchor = await db.get(Message, after_id)
        if anchor is None or anchor.chat_id != chat_id:
            raise AppError(message="Xabar topilmadi", error_code="MESSAGE_NOT_FOUND", status_code=404)
        query = query.where(Message.id > after_id).order_by(Message.id.asc()).limit(safe_limit + 1)
    else:
        query = query.order_by(Message.id.desc()).limit(safe_limit + 1)

    result = await db.execute(query)
    rows = list(result.scalars().all())

    has_more = len(rows) > safe_limit
    if has_more:
        rows = rows[:safe_limit]

    if before_id is not None or after_id is None:
        rows.reverse()

    hidden = await _hidden_message_ids(db, user.id, [m.id for m in rows])
    visible = [m for m in rows if m.id not in hidden]

    read_ids: set[int] = set()
    if visible:
        read_result = await db.execute(
            select(MessageRead.message_id).where(
                MessageRead.message_id.in_([m.id for m in visible]),
                MessageRead.user_id != user.id,
            )
        )
        read_ids = set(read_result.scalars().all())

    reply_map = await _load_reply_to_payloads(
        db, visible, viewer_language=user.native_language
    )

    items = [
        _serialize_message(
            m,
            viewer_id=user.id,
            viewer_language=user.native_language,
            read_message_ids=read_ids if m.sender_id == user.id else None,
            reply_to=reply_map.get(m.reply_to_id) if m.reply_to_id else None,
        )
        for m in visible
    ]

    return {"items": items, "has_more": has_more}


async def create_message(
    db: AsyncSession,
    redis: Redis,
    *,
    user: User,
    chat_id: int,
    client_message_id: str,
    msg_type: str,
    text: str | None,
    meta: dict | None,
    reply_to_id: int | None,
    media_id: int | None,
) -> dict:
    chat = await _get_chat_for_user(db, chat_id, user.id)
    recipient = await _load_recipient(db, chat, user.id)

    blocked = await redis.sismember(f"blocked:{user.id}", recipient.id) or await redis.sismember(
        f"blocked:{recipient.id}", user.id
    )
    if blocked:
        raise AppError(
            message="Bu foydalanuvchi bilan yozishish mumkin emas",
            error_code="USER_BLOCKED",
            status_code=403,
        )

    if msg_type == "text":
        if not text or not text.strip():
            raise AppError(
                message="Matn xabari uchun matn majburiy",
                error_code="VALIDATION_ERROR",
                status_code=400,
            )
        text = text.strip()
        original_language = _normalize_lang(user.native_language)
        meta_payload = meta
    elif msg_type in {"product", "location", "contact"}:
        if not meta or not isinstance(meta, dict):
            raise AppError(
                message="Meta majburiy",
                error_code="VALIDATION_ERROR",
                status_code=400,
            )
        meta_payload = dict(meta)
        text = text.strip() if text else None
        original_language = _normalize_lang(user.native_language) if text else None
    else:
        if media_id is not None:
            media_result = await db.execute(
                select(ChatMedia).where(
                    ChatMedia.id == media_id,
                    ChatMedia.uploader_id == user.id,
                )
            )
            media = media_result.scalar_one_or_none()
            if media is None:
                raise AppError(
                    message="Media topilmadi",
                    error_code="MEDIA_NOT_FOUND",
                    status_code=404,
                )
            if media.type != msg_type:
                raise AppError(
                    message="Media turi mos kelmaydi",
                    error_code="VALIDATION_ERROR",
                    status_code=400,
                )
            meta_payload = dict(meta or {})
            meta_payload.setdefault("url", media.url)
            if media.meta:
                meta_payload = {**media.meta, **meta_payload}
            media.attached = True
        else:
            raise AppError(
                message="Media xabari uchun media identifikatori talab qilinadi",
                error_code="VALIDATION_ERROR",
                status_code=400,
            )
        text = text.strip() if text else None
        original_language = _normalize_lang(user.native_language) if text else None

    if reply_to_id is not None:
        reply = await db.get(Message, reply_to_id)
        if reply is None or reply.chat_id != chat_id:
            raise AppError(message="Javob xabari topilmadi", error_code="MESSAGE_NOT_FOUND", status_code=404)

    existing = await db.execute(
        select(Message)
        .where(
            Message.chat_id == chat_id,
            Message.client_message_id == client_message_id,
        )
        .options(selectinload(Message.translations))
    )
    duplicate = existing.scalar_one_or_none()
    if duplicate is not None:
        reply_map = await _load_reply_to_payloads(
            db, [duplicate], viewer_language=user.native_language
        )
        return _serialize_message(
            duplicate,
            viewer_id=user.id,
            viewer_language=user.native_language,
            reply_to=reply_map.get(duplicate.reply_to_id) if duplicate.reply_to_id else None,
        )

    now = datetime.now(UTC)
    message = Message(
        chat_id=chat_id,
        sender_id=user.id,
        client_message_id=client_message_id,
        type=msg_type,
        text_original=text,
        original_language=original_language,
        meta=meta_payload,
        reply_to_id=reply_to_id,
        status="sent",
        delivered_at=now,
    )
    db.add(message)
    await db.flush()

    translations: list[MessageTranslation] = []
    if msg_type == "text" and text:
        target_lang = _normalize_lang(recipient.native_language)
        source_lang = _normalize_lang(original_language) if original_language else None
        try:
            translated = await translate(text, target_lang, source_lang=source_lang)
            status = "done"
        except Exception as exc:  # noqa: BLE001 — keep message even if AI is down
            logger = __import__("logging").getLogger(__name__)
            logger.warning("Message translation failed (%s); keeping original", exc)
            translated = text
            status = "failed"
        # Hech qachon bo'sh tarjimani saqlamang — UI bo'sh bubble chiqaradi.
        if not (translated or "").strip():
            translated = text
            status = "failed"
        if translated != text or target_lang != (source_lang or ""):
            tr = MessageTranslation(
                message_id=message.id,
                language=target_lang,
                text=translated,
                status=status,
            )
            db.add(tr)
            translations.append(tr)
        elif status == "failed":
            tr = MessageTranslation(
                message_id=message.id,
                language=target_lang,
                text=text,
                status=status,
            )
            db.add(tr)
            translations.append(tr)

    chat.last_message_id = message.id
    chat.last_message_at = message.created_at
    chat.has_messages = True
    await db.flush()

    await db.refresh(message, attribute_names=["translations"])
    if translations:
        message.translations = translations

    reply_map = await _load_reply_to_payloads(
        db, [message], viewer_language=user.native_language
    )
    reply_payload = reply_map.get(message.reply_to_id) if message.reply_to_id else None
    if _normalize_lang(recipient.native_language) == _normalize_lang(user.native_language):
        reply_payload_recipient = reply_payload
    else:
        reply_map_recipient = await _load_reply_to_payloads(
            db, [message], viewer_language=recipient.native_language
        )
        reply_payload_recipient = (
            reply_map_recipient.get(message.reply_to_id) if message.reply_to_id else None
        )

    payload = _serialize_message(
        message,
        viewer_id=user.id,
        viewer_language=user.native_language,
        reply_to=reply_payload,
    )

    hub = get_hub()
    sender_payload = _serialize_message(
        message,
        viewer_id=user.id,
        viewer_language=user.native_language,
        reply_to=reply_payload,
    )
    recipient_payload = _serialize_message(
        message,
        viewer_id=recipient.id,
        viewer_language=recipient.native_language,
        reply_to=reply_payload_recipient,
    )
    event_data = {
        "chat_id": chat_id,
        "message": payload,
    }
    await hub.publish(user.id, "new_message", {**event_data, "message": sender_payload})
    await hub.publish(recipient.id, "new_message", {**event_data, "message": recipient_payload})

    return payload


async def mark_messages_read(
    db: AsyncSession,
    redis: Redis,
    *,
    user: User,
    chat_id: int,
    message_ids: list[int],
) -> dict:
    chat = await _get_chat_for_user(db, chat_id, user.id)
    other_id = _other_user_id(chat, user.id)

    result = await db.execute(
        select(Message).where(
            Message.chat_id == chat_id,
            Message.id.in_(message_ids),
            Message.sender_id != user.id,
            Message.deleted_for_everyone.is_(False),
        )
    )
    messages = list(result.scalars().all())
    if not messages:
        return {"read_count": 0, "message_ids": []}

    existing_reads = await db.execute(
        select(MessageRead.message_id).where(
            MessageRead.user_id == user.id,
            MessageRead.message_id.in_([m.id for m in messages]),
        )
    )
    already_read = set(existing_reads.scalars().all())

    now = datetime.now(UTC)
    read_ids: list[int] = []
    for message in messages:
        if message.id in already_read:
            continue
        db.add(MessageRead(message_id=message.id, user_id=user.id, read_at=now))
        read_ids.append(message.id)

    await db.flush()

    if read_ids:
        hub = get_hub()
        event = {
            "chat_id": chat_id,
            "reader_id": user.id,
            "message_ids": read_ids,
            "read_at": now.isoformat(),
        }
        await hub.publish(other_id, "messages_read", event)
        await hub.publish(user.id, "messages_read", event)

    return {"read_count": len(read_ids), "message_ids": read_ids}


async def delete_message(
    db: AsyncSession,
    redis: Redis,
    *,
    user: User,
    message_id: int,
    for_everyone: bool = False,
) -> dict:
    result = await db.execute(
        select(Message)
        .where(Message.id == message_id)
        .options(selectinload(Message.chat))
    )
    message = result.scalar_one_or_none()
    if message is None:
        raise AppError(message="Xabar topilmadi", error_code="MESSAGE_NOT_FOUND", status_code=404)

    chat = message.chat
    await _get_chat_for_user(db, chat.id, user.id)

    if for_everyone:
        if message.sender_id != user.id:
            raise AppError(
                message="Faqat yuboruvchi hammaga o'chira oladi",
                error_code="FORBIDDEN",
                status_code=403,
            )
        message.is_deleted = True
        message.deleted_for_everyone = True
        deleted_for_everyone = True
    else:
        hide_result = await db.execute(
            select(MessageHide).where(
                MessageHide.message_id == message.id,
                MessageHide.user_id == user.id,
            )
        )
        if hide_result.scalar_one_or_none() is None:
            db.add(MessageHide(message_id=message.id, user_id=user.id))
        if message.sender_id == user.id:
            message.is_deleted = True
        deleted_for_everyone = False

    if chat.last_message_id == message.id and message.deleted_for_everyone:
        prev_result = await db.execute(
            select(Message)
            .where(Message.chat_id == chat.id, Message.deleted_for_everyone.is_(False))
            .order_by(Message.id.desc())
            .limit(1)
        )
        prev = prev_result.scalar_one_or_none()
        chat.last_message_id = prev.id if prev else None
        chat.last_message_at = prev.created_at if prev else None
        chat.has_messages = prev is not None

    await db.flush()

    other_id = _other_user_id(chat, user.id)
    hub = get_hub()
    event = {
        "chat_id": chat.id,
        "message_id": message.id,
        "deleted_for_everyone": deleted_for_everyone,
        "deleted_by": user.id,
    }
    await hub.publish(user.id, "message_deleted", event)
    await hub.publish(other_id, "message_deleted", event)

    return {"id": message.id, "deleted_for_everyone": deleted_for_everyone}


async def upload_chat_media(
    db: AsyncSession,
    *,
    user: User,
    media_type: str,
    filename: str,
    content_type: str,
    data: bytes,
) -> dict:
    rules = MEDIA_RULES.get(media_type)
    if rules is None:
        raise AppError(
            message="Noto'g'ri media turi",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )
    if content_type not in rules["types"]:
        raise AppError(
            message="Fayl turi ruxsat etilmagan",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )
    if len(data) > rules["max_bytes"]:
        raise AppError(
            message="Fayl hajmi juda katta",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )

    if rules.get("verify_image"):
        try:
            Image.open(BytesIO(data)).verify()
        except Exception as exc:
            raise AppError(
                message="Rasm fayli noto'g'ri",
                error_code="VALIDATION_ERROR",
                status_code=400,
            ) from exc

    ext_map = {
        "image/jpeg": "jpg",
        "image/png": "png",
        "image/webp": "webp",
        "image/gif": "gif",
        "video/mp4": "mp4",
        "video/webm": "webm",
        "video/quicktime": "mov",
        "audio/mpeg": "mp3",
        "audio/mp3": "mp3",
        "audio/mp4": "m4a",
        "audio/aac": "aac",
        "audio/x-m4a": "m4a",
        "audio/wav": "wav",
        "audio/x-wav": "wav",
        "audio/ogg": "ogg",
        "application/pdf": "pdf",
        "application/msword": "doc",
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document": "docx",
        "text/plain": "txt",
    }
    raw_ext = filename.rsplit(".", 1)[-1].lower() if "." in filename else ""
    safe_ext = "".join(ch for ch in raw_ext if ch.isalnum())[:8]
    ext = ext_map.get(content_type) or (safe_ext if safe_ext else "bin")
    # Never trust path-like filenames in object keys
    safe_name = "".join(ch for ch in filename if ch.isalnum() or ch in "._-")[:80] or "file"
    key = f"chat/uploads/{user.id}/{uuid4().hex}.{ext}"
    url = await get_storage().upload_bytes(key, data, content_type)

    meta: dict = {"filename": safe_name, "content_type": content_type, "size": len(data)}
    media = ChatMedia(uploader_id=user.id, type=media_type, url=url, meta=meta, attached=False)
    db.add(media)
    await db.flush()
    await db.refresh(media)
    return {"id": media.id, "url": media.url, "type": media.type}
