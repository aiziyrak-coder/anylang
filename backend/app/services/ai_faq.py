"""AI FAQ — bir xil savol ko‘p berilsa avtomatik javob."""

from __future__ import annotations

import hashlib
import logging
import re
import uuid
from datetime import UTC, datetime

from redis.asyncio import Redis
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import get_settings
from app.integrations.translation import _openai_chat
from app.models.chat import Chat, ChatFaq, ChatParticipant, Message
from app.models.user import User
from app.services.messages import (
    _load_reply_to_payloads,
    _sender_public_fields,
    _serialize_message,
)
from app.ws.hub import get_hub

logger = logging.getLogger(__name__)

FAQ_BOT_EMAIL = "ai-faq@anylang.system"
FAQ_BOT_NUMBER = "0000001"
FAQ_BOT_NAME = "AnyLang FAQ"

# Shu ko‘p marta so‘ralganda birinchi AI javob chiqadi.
ASK_THRESHOLD = 3
# Bir xil FAQ uchun qayta javob oralig‘i (spam oldini olish).
REPLY_COOLDOWN_SEC = 90
MAX_ANSWER_LEN = 1200

_QUESTION_STARTERS = (
    "qancha",
    "qanday",
    "nima",
    "qayer",
    "kim",
    "qachon",
    "nega",
    "bor mi",
    "bormi",
    "mumkinmi",
    "what",
    "how",
    "when",
    "where",
    "who",
    "why",
    "which",
    "how much",
    "how many",
    "price",
    "moq",
    "lead time",
    "delivery",
    "сколько",
    "как",
    "где",
    "что",
    "какой",
    "какая",
    "когда",
    "почему",
    "цена",
    "наличие",
)


def normalize_faq_text(text: str) -> str:
    t = (text or "").strip().lower()
    t = re.sub(r"[^\w\s]", " ", t, flags=re.UNICODE)
    t = re.sub(r"\s+", " ", t).strip()
    return t[:240]


def faq_fingerprint(text: str) -> str:
    norm = normalize_faq_text(text)
    return hashlib.sha256(norm.encode("utf-8")).hexdigest()[:40]


def looks_like_question(text: str) -> bool:
    t = (text or "").strip()
    if len(t) < 8 or len(t) > 400:
        return False
    if "?" in t or "؟" in t or "？" in t:
        return True
    low = t.lower()
    padded = f" {low} "
    for s in _QUESTION_STARTERS:
        if low.startswith(s) or f" {s} " in padded:
            return True
    return False


async def ensure_faq_bot_user(db: AsyncSession) -> User:
    result = await db.execute(select(User).where(User.email == FAQ_BOT_EMAIL))
    user = result.scalar_one_or_none()
    if user is not None:
        return user
    by_number = await db.execute(select(User).where(User.number == FAQ_BOT_NUMBER))
    existing_num = by_number.scalar_one_or_none()
    number = FAQ_BOT_NUMBER if existing_num is None else "0000002"
    user = User(
        email=FAQ_BOT_EMAIL,
        password_hash=None,
        full_name=FAQ_BOT_NAME,
        number=number,
        is_verified=True,
        verified_badge=True,
        is_active=True,
        app_language="uz_UZ",
        native_language="uz",
    )
    db.add(user)
    await db.flush()
    return user


async def _ensure_bot_participant(db: AsyncSession, *, chat_id: int, bot_id: int) -> None:
    existing = await db.execute(
        select(ChatParticipant.id).where(
            ChatParticipant.chat_id == chat_id,
            ChatParticipant.user_id == bot_id,
        )
    )
    if existing.scalar_one_or_none() is not None:
        return
    db.add(ChatParticipant(chat_id=chat_id, user_id=bot_id, role="member"))
    await db.flush()


async def _find_prior_human_answer(
    db: AsyncSession,
    *,
    chat_id: int,
    fingerprint: str,
    exclude_message_id: int,
) -> str | None:
    """Oldingi o‘xshash savolga berilgan inson javobini qidiradi."""
    result = await db.execute(
        select(Message)
        .where(
            Message.chat_id == chat_id,
            Message.type == "text",
            Message.deleted_for_everyone.is_(False),
            Message.id != exclude_message_id,
        )
        .order_by(Message.id.desc())
        .limit(120)
    )
    messages = list(result.scalars().all())
    chronological = list(reversed(messages))
    for i, msg in enumerate(chronological):
        text = (msg.text_original or "").strip()
        if not text or faq_fingerprint(text) != fingerprint:
            continue
        meta = msg.meta if isinstance(msg.meta, dict) else {}
        if meta.get("ai_faq"):
            continue
        # Reply to this question
        for cand in chronological[i + 1 :]:
            if cand.reply_to_id == msg.id and cand.type == "text":
                ans = (cand.text_original or "").strip()
                cmeta = cand.meta if isinstance(cand.meta, dict) else {}
                if ans and not cmeta.get("ai_faq") and len(ans) >= 3:
                    return ans[:MAX_ANSWER_LEN]
        # Next few messages from another sender
        for j in range(i + 1, min(i + 6, len(chronological))):
            cand = chronological[j]
            if cand.sender_id == msg.sender_id or cand.type != "text":
                continue
            ans = (cand.text_original or "").strip()
            cmeta = cand.meta if isinstance(cand.meta, dict) else {}
            if cmeta.get("ai_faq"):
                continue
            if ans and len(ans) >= 3:
                return ans[:MAX_ANSWER_LEN]
    return None


async def _ai_synthesize_answer(
    *,
    question: str,
    locale: str,
    context_lines: list[str],
) -> str | None:
    settings = get_settings()
    if not settings.openai_api_key:
        return None
    lang = (locale or "uz").lower().split("_")[0]
    lang_name = {"uz": "Uzbek", "ru": "Russian", "en": "English"}.get(lang, "Uzbek")
    system = (
        "You are AnyLang AI FAQ for B2B trade chats.\n"
        "A question was asked repeatedly. Write a short, clear FAQ answer.\n"
        f"Reply in {lang_name}.\n"
        "Rules:\n"
        "- 1–4 short sentences or compact bullets.\n"
        "- Use chat context if helpful; do not invent prices/MOQ/certs.\n"
        "- If context has no answer, say what info is still missing.\n"
        "- No markdown fences, no preamble."
    )
    ctx = "\n".join(context_lines[-20:]) if context_lines else "(no context)"
    user = f"Repeated question:\n{question}\n\nRecent chat context:\n{ctx}"
    try:
        out = await _openai_chat(
            api_key=settings.openai_api_key,
            model=(settings.openai_model or "gpt-4o-mini").strip(),
            system=system,
            user=user,
            temperature=0.2,
            timeout=25.0,
        )
        cleaned = (out or "").strip()
        return cleaned[:MAX_ANSWER_LEN] if cleaned else None
    except Exception as exc:  # noqa: BLE001
        logger.warning("AI FAQ synthesize failed: %s", exc)
        return None


async def _publish_faq_message(
    db: AsyncSession,
    *,
    chat: Chat,
    message: Message,
    bot: User,
) -> None:
    result = await db.execute(
        select(ChatParticipant.user_id).where(ChatParticipant.chat_id == chat.id)
    )
    member_ids = [int(x) for x in result.scalars().all()]
    if bot.id not in member_ids:
        member_ids.append(bot.id)

    users_result = await db.execute(
        select(User)
        .where(User.id.in_(member_ids))
        .options(selectinload(User.business), selectinload(User.subscription))
    )
    users = {u.id: u for u in users_result.scalars().all()}
    s_name, s_avatar = _sender_public_fields(bot)
    hub = get_hub()
    event_data = {"chat_id": chat.id}
    for uid in member_ids:
        viewer = users.get(uid)
        if viewer is None:
            continue
        reply_map = await _load_reply_to_payloads(
            db, [message], viewer_language=viewer.native_language or "uz"
        )
        payload = _serialize_message(
            message,
            viewer_id=uid,
            viewer_language=viewer.native_language or "uz",
            reply_to=reply_map.get(message.reply_to_id) if message.reply_to_id else None,
            sender_name=s_name,
            sender_avatar_url=s_avatar,
        )
        try:
            await hub.publish(uid, "new_message", {**event_data, "message": payload})
        except Exception as exc:  # noqa: BLE001
            logger.warning("AI FAQ publish failed user=%s: %s", uid, exc)


async def maybe_auto_faq_reply(
    *,
    chat_id: int,
    message_id: int,
    text: str,
    asker_id: int,
) -> None:
    """Background: takroriy savolga AI FAQ javob."""
    from app.db.redis import get_redis
    from app.db.session import get_session_factory

    text = (text or "").strip()
    if not looks_like_question(text):
        return

    factory = get_session_factory()
    redis: Redis = await get_redis()
    async with factory() as db:
        try:
            msg = await db.get(Message, message_id)
            chat = await db.get(Chat, chat_id)
            if msg is None or chat is None:
                return
            if msg.chat_id != chat_id or msg.type != "text":
                return
            meta = msg.meta if isinstance(msg.meta, dict) else {}
            if meta.get("ai_faq"):
                return

            bot = await ensure_faq_bot_user(db)
            if asker_id == bot.id:
                return

            fp = faq_fingerprint(text)
            now = datetime.now(UTC)

            # Cooldown — bir xil FAQ spam bo‘lmasin
            cool_key = f"faq:cool:{chat_id}:{fp}"
            cooled = bool(await redis.get(cool_key))

            faq = await _upsert_faq(
                db,
                chat_id=chat_id,
                fingerprint=fp,
                question_sample=text,
                message_id=message_id,
                now=now,
            )

            # Bootstrap count from history (first time row)
            if faq.ask_count <= 1:
                hist = await _count_similar_in_history(
                    db, chat_id=chat_id, fingerprint=fp, exclude_id=message_id
                )
                if hist > 0:
                    faq.ask_count = hist + 1

            should_reply = False
            if faq.answer and faq.ask_count >= ASK_THRESHOLD:
                should_reply = True
            elif faq.ask_count >= ASK_THRESHOLD and not faq.answer:
                should_reply = True

            if cooled or not should_reply:
                await db.commit()
                return

            answer = (faq.answer or "").strip()
            if not answer:
                answer = (
                    await _find_prior_human_answer(
                        db,
                        chat_id=chat_id,
                        fingerprint=fp,
                        exclude_message_id=message_id,
                    )
                    or ""
                ).strip()
            if not answer:
                # Context for AI
                recent = await db.execute(
                    select(Message)
                    .where(
                        Message.chat_id == chat_id,
                        Message.type == "text",
                        Message.deleted_for_everyone.is_(False),
                    )
                    .order_by(Message.id.desc())
                    .limit(30)
                )
                lines = []
                for m in reversed(list(recent.scalars().all())):
                    body = (m.text_original or "").strip()
                    if body:
                        lines.append(f"user{m.sender_id}: {body[:220]}")
                asker = await db.get(User, asker_id)
                locale = (asker.native_language if asker else None) or "uz"
                synthesized = await _ai_synthesize_answer(
                    question=text,
                    locale=locale,
                    context_lines=lines,
                )
                answer = (synthesized or "").strip()

            if not answer:
                # Fallback short notice
                answer = _fallback_answer(text)

            faq.answer = answer[:MAX_ANSWER_LEN]
            await _ensure_bot_participant(db, chat_id=chat_id, bot_id=bot.id)

            client_id = f"faq_{uuid.uuid4().hex[:20]}"
            reply_msg = Message(
                chat_id=chat_id,
                sender_id=bot.id,
                client_message_id=client_id,
                type="text",
                text_original=faq.answer,
                original_language="uz",
                meta={
                    "ai_faq": True,
                    "fingerprint": fp,
                    "ask_count": faq.ask_count,
                    "question": text[:240],
                },
                reply_to_id=message_id,
                status="sent",
                delivered_at=now,
            )
            reply_msg.translations = []
            db.add(reply_msg)
            await db.flush()

            chat.last_message_id = reply_msg.id
            chat.last_message_at = reply_msg.created_at
            chat.has_messages = True
            faq.last_answer_message_id = reply_msg.id
            await db.flush()
            await db.commit()

            await redis.set(cool_key, "1", ex=REPLY_COOLDOWN_SEC)
            await _publish_faq_message(db, chat=chat, message=reply_msg, bot=bot)
        except Exception as exc:  # noqa: BLE001
            logger.warning("AI FAQ job failed chat=%s msg=%s: %s", chat_id, message_id, exc)
            await db.rollback()


async def _upsert_faq(
    db: AsyncSession,
    *,
    chat_id: int,
    fingerprint: str,
    question_sample: str,
    message_id: int,
    now: datetime,
) -> ChatFaq:
    result = await db.execute(
        select(ChatFaq).where(
            ChatFaq.chat_id == chat_id,
            ChatFaq.fingerprint == fingerprint,
        )
    )
    faq = result.scalar_one_or_none()
    if faq is None:
        faq = ChatFaq(
            chat_id=chat_id,
            fingerprint=fingerprint,
            question_sample=question_sample[:400],
            ask_count=1,
            last_question_message_id=message_id,
            last_asked_at=now,
        )
        db.add(faq)
        await db.flush()
        return faq
    faq.ask_count = int(faq.ask_count or 0) + 1
    faq.question_sample = question_sample[:400]
    faq.last_question_message_id = message_id
    faq.last_asked_at = now
    await db.flush()
    return faq


async def _count_similar_in_history(
    db: AsyncSession,
    *,
    chat_id: int,
    fingerprint: str,
    exclude_id: int,
) -> int:
    result = await db.execute(
        select(Message)
        .where(
            Message.chat_id == chat_id,
            Message.type == "text",
            Message.deleted_for_everyone.is_(False),
            Message.id != exclude_id,
        )
        .order_by(Message.id.desc())
        .limit(80)
    )
    n = 0
    for m in result.scalars().all():
        meta = m.meta if isinstance(m.meta, dict) else {}
        if meta.get("ai_faq"):
            continue
        body = (m.text_original or "").strip()
        if body and faq_fingerprint(body) == fingerprint:
            n += 1
    return n


def _fallback_answer(question: str) -> str:
    q = question.strip()
    if len(q) > 80:
        q = q[:77] + "…"
    return (
        f"AI FAQ: «{q}» savoli ko‘p so‘ralmoqda. "
        "Aniq narx/MOQ/muddat uchun sotuvchi yoki admin javobini kuting — "
        "yoki mahsulot kartasini yuboring."
    )
