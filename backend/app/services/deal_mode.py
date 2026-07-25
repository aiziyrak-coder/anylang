"""Deal Mode — chat ichida bitim shartlarini bitta joyda jamlaydi."""

from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.models.chat import ChatDeal, ChatParticipant, Message
from app.models.user import User
from app.services.chats import _get_chat_for_user


def _docs_list(raw) -> list[dict]:
    if isinstance(raw, list):
        return [d for d in raw if isinstance(d, dict)]
    return []


def _accepted_list(raw) -> list[int]:
    if not isinstance(raw, list):
        return []
    out: list[int] = []
    for x in raw:
        try:
            out.append(int(x))
        except (TypeError, ValueError):
            continue
    return out


def _serialize_deal(deal: ChatDeal, *, viewer_id: int) -> dict:
    accepted = _accepted_list(deal.accepted_by)
    docs = []
    for d in _docs_list(deal.documents):
        mid = d.get("message_id")
        try:
            mid_i = int(mid)
        except (TypeError, ValueError):
            continue
        docs.append(
            {
                "message_id": mid_i,
                "title": str(d.get("title") or "").strip() or f"#{mid_i}",
                "kind": str(d.get("kind") or "file"),
                "url": d.get("url"),
            }
        )
    updated_at = None
    if getattr(deal, "updated_at", None) is not None:
        updated_at = deal.updated_at.isoformat()
    return {
        "id": deal.id,
        "chat_id": deal.chat_id,
        "product": deal.product or "",
        "price": deal.price or "",
        "currency": deal.currency or "USD",
        "quantity": deal.quantity or "",
        "unit": deal.unit or "",
        "delivery": deal.delivery or "",
        "payment": deal.payment or "",
        "status": deal.status,
        "version": int(deal.version or 1),
        "documents": docs,
        "accepted_by": accepted,
        "accepted_count": len(accepted),
        "viewer_accepted": viewer_id in accepted,
        "created_by": deal.created_by,
        "updated_by": deal.updated_by,
        "updated_at": updated_at,
    }


async def _member_count(db: AsyncSession, chat_id: int) -> int:
    result = await db.execute(
        select(ChatParticipant).where(ChatParticipant.chat_id == chat_id)
    )
    return len(list(result.scalars().all()))


async def _active_deal(db: AsyncSession, chat_id: int) -> ChatDeal | None:
    result = await db.execute(
        select(ChatDeal)
        .where(ChatDeal.chat_id == chat_id, ChatDeal.status.in_(("open", "agreed")))
        .order_by(ChatDeal.id.desc())
        .limit(1)
    )
    return result.scalar_one_or_none()


async def _prefill_from_messages(db: AsyncSession, chat_id: int) -> dict[str, str]:
    """Oxirgi offer / RFQ dan boshlang‘ich qiymatlar."""
    result = await db.execute(
        select(Message)
        .where(
            Message.chat_id == chat_id,
            Message.type.in_(("offer", "rfq")),
            Message.deleted_for_everyone.is_(False),
            Message.is_deleted.is_(False),
        )
        .order_by(Message.id.desc())
        .limit(8)
    )
    messages = list(result.scalars().all())
    out: dict[str, str] = {}
    for m in messages:
        meta = m.meta if isinstance(m.meta, dict) else {}
        if m.type == "offer":
            if not out.get("product"):
                out["product"] = str(meta.get("product") or meta.get("product_name") or "").strip()
            if not out.get("price"):
                out["price"] = str(meta.get("price") or "").strip()
            if not out.get("currency"):
                out["currency"] = str(meta.get("currency") or "USD").strip() or "USD"
            if not out.get("quantity"):
                out["quantity"] = str(meta.get("moq") or meta.get("quantity") or "").strip()
            if not out.get("delivery"):
                out["delivery"] = str(meta.get("delivery") or "").strip()
            if not out.get("payment"):
                out["payment"] = str(meta.get("payment") or "").strip()
        elif m.type == "rfq":
            if not out.get("product"):
                out["product"] = str(meta.get("product") or meta.get("product_name") or "").strip()
            if not out.get("quantity"):
                out["quantity"] = str(meta.get("quantity") or "").strip()
            if not out.get("unit"):
                out["unit"] = str(meta.get("unit") or "").strip()
            if not out.get("delivery"):
                out["delivery"] = str(meta.get("deadline") or meta.get("delivery") or "").strip()
    return out


def _candidate_from_message(m: Message) -> dict | None:
    meta = m.meta if isinstance(m.meta, dict) else {}
    kind = m.type
    title = ""
    url = None
    if kind == "file":
        title = str(meta.get("name") or meta.get("file_name") or meta.get("filename") or "File").strip()
        url = meta.get("url") or meta.get("file_url")
    elif kind == "invoice":
        title = str(meta.get("title") or "Invoice").strip()
        url = meta.get("url")
    elif kind == "product":
        title = str(meta.get("title") or meta.get("name") or "Product").strip()
        url = meta.get("image_url") or meta.get("url")
    elif kind == "catalog":
        title = str(meta.get("title") or "Catalog").strip()
        url = meta.get("url")
    elif kind == "image":
        title = str(meta.get("caption") or "Image").strip() or "Image"
        url = meta.get("url") or meta.get("image_url")
    else:
        return None
    return {
        "message_id": m.id,
        "title": title[:120],
        "kind": kind,
        "url": url,
        "created_at": m.created_at.isoformat() if m.created_at else None,
    }


async def _list_candidates(db: AsyncSession, chat_id: int, *, limit: int = 30) -> list[dict]:
    result = await db.execute(
        select(Message)
        .where(
            Message.chat_id == chat_id,
            Message.type.in_(("file", "invoice", "product", "catalog", "image")),
            Message.deleted_for_everyone.is_(False),
            Message.is_deleted.is_(False),
        )
        .order_by(Message.id.desc())
        .limit(limit)
    )
    items = []
    for m in result.scalars().all():
        c = _candidate_from_message(m)
        if c is not None:
            items.append(c)
    return items


async def get_deal(db: AsyncSession, *, user: User, chat_id: int) -> dict:
    await _get_chat_for_user(db, chat_id, user.id)
    deal = await _active_deal(db, chat_id)
    candidates = await _list_candidates(db, chat_id)
    return {
        "deal": _serialize_deal(deal, viewer_id=user.id) if deal else None,
        "candidates": candidates,
    }


async def start_deal(db: AsyncSession, *, user: User, chat_id: int) -> dict:
    await _get_chat_for_user(db, chat_id, user.id)
    existing = await _active_deal(db, chat_id)
    if existing is not None:
        return {
            "deal": _serialize_deal(existing, viewer_id=user.id),
            "candidates": await _list_candidates(db, chat_id),
        }
    prefill = await _prefill_from_messages(db, chat_id)
    deal = ChatDeal(
        chat_id=chat_id,
        created_by=user.id,
        updated_by=user.id,
        product=prefill.get("product", "")[:240],
        price=prefill.get("price", "")[:64],
        currency=(prefill.get("currency") or "USD")[:8],
        quantity=prefill.get("quantity", "")[:64],
        unit=prefill.get("unit", "")[:32],
        delivery=prefill.get("delivery", "")[:240],
        payment=prefill.get("payment", "")[:240],
        status="open",
        version=1,
        documents=[],
        accepted_by=[],
    )
    db.add(deal)
    await db.flush()
    return {
        "deal": _serialize_deal(deal, viewer_id=user.id),
        "candidates": await _list_candidates(db, chat_id),
    }


async def update_deal(
    db: AsyncSession,
    *,
    user: User,
    chat_id: int,
    data: dict,
) -> dict:
    await _get_chat_for_user(db, chat_id, user.id)
    deal = await _active_deal(db, chat_id)
    if deal is None:
        raise AppError(
            message="Deal Mode ochilmagan",
            error_code="NOT_FOUND",
            status_code=404,
        )
    if deal.status == "closed":
        raise AppError(
            message="Deal yopilgan",
            error_code="DEAL_CLOSED",
            status_code=400,
        )
    changed = False
    for field in ("product", "price", "currency", "quantity", "unit", "delivery", "payment"):
        if field not in data or data[field] is None:
            continue
        val = str(data[field]).strip()
        if getattr(deal, field) != val:
            setattr(deal, field, val)
            changed = True
    if changed:
        deal.version = int(deal.version or 1) + 1
        deal.accepted_by = []
        deal.updated_by = user.id
        if deal.status == "agreed":
            deal.status = "open"
    await db.flush()
    return {
        "deal": _serialize_deal(deal, viewer_id=user.id),
        "candidates": await _list_candidates(db, chat_id),
    }


async def accept_deal(db: AsyncSession, *, user: User, chat_id: int) -> dict:
    await _get_chat_for_user(db, chat_id, user.id)
    deal = await _active_deal(db, chat_id)
    if deal is None:
        raise AppError(message="Deal Mode ochilmagan", error_code="NOT_FOUND", status_code=404)
    if deal.status == "closed":
        raise AppError(message="Deal yopilgan", error_code="DEAL_CLOSED", status_code=400)
    accepted = _accepted_list(deal.accepted_by)
    if user.id not in accepted:
        accepted.append(user.id)
        deal.accepted_by = accepted
        deal.updated_by = user.id
    members = await _member_count(db, chat_id)
    # Direct: 2 a’zo; guruh: kamida 2 tasdiq
    need = 2 if members >= 2 else 1
    if len(accepted) >= need:
        deal.status = "agreed"
    await db.flush()
    return {
        "deal": _serialize_deal(deal, viewer_id=user.id),
        "candidates": await _list_candidates(db, chat_id),
    }


async def attach_document(
    db: AsyncSession,
    *,
    user: User,
    chat_id: int,
    message_id: int,
) -> dict:
    await _get_chat_for_user(db, chat_id, user.id)
    deal = await _active_deal(db, chat_id)
    if deal is None:
        raise AppError(message="Deal Mode ochilmagan", error_code="NOT_FOUND", status_code=404)
    result = await db.execute(
        select(Message).where(
            Message.id == message_id,
            Message.chat_id == chat_id,
            Message.deleted_for_everyone.is_(False),
        )
    )
    msg = result.scalar_one_or_none()
    if msg is None:
        raise AppError(message="Xabar topilmadi", error_code="NOT_FOUND", status_code=404)
    cand = _candidate_from_message(msg)
    if cand is None:
        raise AppError(
            message="Bu xabarni hujjat sifatida qo‘shib bo‘lmaydi",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )
    docs = _docs_list(deal.documents)
    if any(int(d.get("message_id") or 0) == message_id for d in docs):
        return {
            "deal": _serialize_deal(deal, viewer_id=user.id),
            "candidates": await _list_candidates(db, chat_id),
        }
    docs.append(
        {
            "message_id": cand["message_id"],
            "title": cand["title"],
            "kind": cand["kind"],
            "url": cand.get("url"),
        }
    )
    deal.documents = docs
    deal.updated_by = user.id
    # Hujjat qo‘shilganda kelishuvni qayta tasdiqlash kerak
    deal.accepted_by = []
    deal.version = int(deal.version or 1) + 1
    if deal.status == "agreed":
        deal.status = "open"
    await db.flush()
    return {
        "deal": _serialize_deal(deal, viewer_id=user.id),
        "candidates": await _list_candidates(db, chat_id),
    }


async def detach_document(
    db: AsyncSession,
    *,
    user: User,
    chat_id: int,
    message_id: int,
) -> dict:
    await _get_chat_for_user(db, chat_id, user.id)
    deal = await _active_deal(db, chat_id)
    if deal is None:
        raise AppError(message="Deal Mode ochilmagan", error_code="NOT_FOUND", status_code=404)
    docs = [d for d in _docs_list(deal.documents) if int(d.get("message_id") or 0) != message_id]
    deal.documents = docs
    deal.updated_by = user.id
    await db.flush()
    return {
        "deal": _serialize_deal(deal, viewer_id=user.id),
        "candidates": await _list_candidates(db, chat_id),
    }


async def close_deal(db: AsyncSession, *, user: User, chat_id: int) -> dict:
    await _get_chat_for_user(db, chat_id, user.id)
    deal = await _active_deal(db, chat_id)
    if deal is None:
        raise AppError(message="Deal Mode ochilmagan", error_code="NOT_FOUND", status_code=404)
    deal.status = "closed"
    deal.updated_by = user.id
    await db.flush()
    return {
        "deal": _serialize_deal(deal, viewer_id=user.id),
        "candidates": await _list_candidates(db, chat_id),
    }
