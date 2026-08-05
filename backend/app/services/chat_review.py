"""Superadmin chat review: report/search gate, PII highlight, TTL, cases, watermark export."""

from __future__ import annotations

import csv
import io
import json
import re
from datetime import UTC, datetime, timedelta
from typing import Any, Literal

from sqlalchemy import func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.db.redis import get_redis
from app.models.chat import Chat, Message
from app.models.chat_review import ChatReviewCase
from app.models.user import AdminUser
from app.services.admin_ops import write_audit

ACCESS_TTL_SEC = 15 * 60
CASE_REASONS = {"spam", "harassment", "scam", "pii", "keyword", "other"}
CASE_STATUSES = {"open", "reviewing", "decided"}
DECISIONS = {"warn", "ban", "dismiss", "none"}

# Card: 13–19 digits with optional spaces/dashes (Luhn not required for highlight)
_CARD_RE = re.compile(r"(?<!\d)(?:\d[ -]*?){13,19}(?!\d)")
# Phone-ish: +? and 9–15 digits with separators
_PHONE_RE = re.compile(
    r"(?<!\d)(?:\+?\d[\d\s().-]{7,18}\d)(?!\d)"
)


def find_pii_spans(text: str | None, *, keyword: str | None = None) -> list[dict[str, Any]]:
    if not text:
        return []
    spans: list[dict[str, Any]] = []
    for m in _CARD_RE.finditer(text):
        raw = re.sub(r"\D", "", m.group(0))
        if 13 <= len(raw) <= 19:
            spans.append(
                {
                    "type": "card",
                    "start": m.start(),
                    "end": m.end(),
                    "masked": _mask_card(raw),
                }
            )
    for m in _PHONE_RE.finditer(text):
        digits = re.sub(r"\D", "", m.group(0))
        if 9 <= len(digits) <= 15:
            # avoid double-counting card spans
            if any(s["start"] <= m.start() < s["end"] for s in spans if s["type"] == "card"):
                continue
            spans.append(
                {
                    "type": "phone",
                    "start": m.start(),
                    "end": m.end(),
                    "masked": _mask_phone(digits),
                }
            )
    if keyword and keyword.strip():
        kw = keyword.strip()
        for m in re.finditer(re.escape(kw), text, flags=re.IGNORECASE):
            spans.append(
                {
                    "type": "keyword",
                    "start": m.start(),
                    "end": m.end(),
                    "masked": None,
                }
            )
    spans.sort(key=lambda s: (s["start"], s["end"]))
    return spans


def _mask_card(digits: str) -> str:
    if len(digits) < 8:
        return "*" * len(digits)
    return f"{digits[:4]}{'*' * (len(digits) - 8)}{digits[-4:]}"


def _mask_phone(digits: str) -> str:
    if len(digits) < 4:
        return "*" * len(digits)
    return f"{'*' * (len(digits) - 4)}{digits[-4:]}"


def _access_key(admin_id: int, chat_id: int) -> str:
    return f"admin:chat_access:{admin_id}:{chat_id}"


async def grant_access(
    *,
    admin: AdminUser,
    chat_id: int,
    case_id: int | None,
    reason: str,
    search_query: str | None = None,
) -> dict[str, Any]:
    reason_clean = (reason or "").strip()
    if len(reason_clean) < 5:
        raise AppError(
            message="Kirish sababi kamida 5 belgi",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )
    now = datetime.now(UTC)
    expires = now + timedelta(seconds=ACCESS_TTL_SEC)
    payload = {
        "admin_id": admin.id,
        "chat_id": chat_id,
        "case_id": case_id,
        "reason": reason_clean[:500],
        "search_query": (search_query or "")[:255] or None,
        "opened_at": now.isoformat(),
        "expires_at": expires.isoformat(),
    }
    redis = await get_redis()
    await redis.set(_access_key(admin.id, chat_id), json.dumps(payload), ex=ACCESS_TTL_SEC)
    return {
        **payload,
        "ttl_seconds": ACCESS_TTL_SEC,
        "remaining_seconds": ACCESS_TTL_SEC,
    }


async def get_access(admin_id: int, chat_id: int) -> dict[str, Any] | None:
    redis = await get_redis()
    raw = await redis.get(_access_key(admin_id, chat_id))
    if not raw:
        return None
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return None
    ttl = await redis.ttl(_access_key(admin_id, chat_id))
    data["remaining_seconds"] = max(0, int(ttl)) if ttl and ttl > 0 else 0
    data["ttl_seconds"] = ACCESS_TTL_SEC
    if data["remaining_seconds"] <= 0:
        return None
    return data


async def require_access(admin_id: int, chat_id: int) -> dict[str, Any]:
    access = await get_access(admin_id, chat_id)
    if access is None:
        raise AppError(
            message="Chat access muddati tugagan yoki ochilmagan (15 daqiqa TTL)",
            error_code="CHAT_ACCESS_EXPIRED",
            status_code=403,
        )
    return access


async def revoke_access(admin_id: int, chat_id: int) -> None:
    redis = await get_redis()
    await redis.delete(_access_key(admin_id, chat_id))


def serialize_case(c: ChatReviewCase) -> dict[str, Any]:
    return {
        "id": c.id,
        "chat_id": c.chat_id,
        "reporter_user_id": c.reporter_user_id,
        "reported_user_id": c.reported_user_id,
        "reason": c.reason,
        "description": c.description,
        "status": c.status,
        "decision": c.decision,
        "decision_note": c.decision_note,
        "decided_by_admin_id": c.decided_by_admin_id,
        "decided_at": c.decided_at.isoformat() if c.decided_at else None,
        "source": c.source,
        "search_query": c.search_query,
        "created_by_admin_id": c.created_by_admin_id,
        "created_at": c.created_at.isoformat() if c.created_at else None,
        "updated_at": c.updated_at.isoformat() if c.updated_at else None,
    }


async def list_cases(
    db: AsyncSession,
    *,
    status: str | None = "open",
    page: int = 1,
    limit: int = 30,
) -> dict[str, Any]:
    query = select(ChatReviewCase)
    if status:
        query = query.where(ChatReviewCase.status == status)
    total = int(
        (await db.execute(select(func.count()).select_from(query.subquery()))).scalar_one()
    )
    rows = list(
        (
            await db.execute(
                query.order_by(ChatReviewCase.id.desc())
                .offset(max(page - 1, 0) * limit)
                .limit(limit)
            )
        )
        .scalars()
        .all()
    )
    return {
        "items": [serialize_case(c) for c in rows],
        "page": page,
        "limit": limit,
        "total": total,
        "has_more": page * limit < total,
    }


async def create_case(
    db: AsyncSession,
    *,
    chat_id: int,
    reason: str,
    description: str,
    source: str = "report",
    reporter_user_id: int | None = None,
    reported_user_id: int | None = None,
    search_query: str | None = None,
    admin: AdminUser,
    ip: str | None = None,
) -> dict[str, Any]:
    chat = await db.get(Chat, chat_id)
    if chat is None:
        raise AppError(message="Chat not found", error_code="CHAT_NOT_FOUND", status_code=404)
    reason_clean = (reason or "other").strip().lower()
    if reason_clean not in CASE_REASONS:
        reason_clean = "other"
    desc = (description or "").strip()
    if len(desc) < 5:
        raise AppError(
            message="Tavsif kamida 5 belgi",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )
    case = ChatReviewCase(
        chat_id=chat_id,
        reason=reason_clean,
        description=desc[:4000],
        status="open",
        source=source if source in {"report", "search"} else "report",
        reporter_user_id=reporter_user_id,
        reported_user_id=reported_user_id,
        search_query=(search_query or "")[:255] or None,
        created_by_admin_id=admin.id,
    )
    db.add(case)
    await db.flush()
    await write_audit(
        db,
        admin=admin,
        action="chat.case_create",
        target_type="chat",
        target_id=chat_id,
        meta={"case_id": case.id, "reason": reason_clean, "source": case.source},
        ip=ip,
    )
    return serialize_case(case)


async def decide_case(
    db: AsyncSession,
    *,
    case_id: int,
    decision: str,
    decision_note: str | None,
    admin: AdminUser,
    ip: str | None = None,
) -> dict[str, Any]:
    case = await db.get(ChatReviewCase, case_id)
    if case is None:
        raise AppError(message="Case topilmadi", error_code="CASE_NOT_FOUND", status_code=404)
    dec = (decision or "").strip().lower()
    if dec not in DECISIONS:
        raise AppError(message="decision noto'g'ri", error_code="VALIDATION_ERROR", status_code=400)
    case.decision = dec
    case.decision_note = (decision_note or "").strip()[:2000] or None
    case.status = "decided"
    case.decided_by_admin_id = admin.id
    case.decided_at = datetime.now(UTC)
    await db.flush()
    await write_audit(
        db,
        admin=admin,
        action="chat.case_decide",
        target_type="chat",
        target_id=case.chat_id,
        meta={"case_id": case.id, "decision": dec},
        ip=ip,
    )
    return serialize_case(case)


async def search_chats(
    db: AsyncSession,
    *,
    query: str,
    reason: str,
    admin: AdminUser,
    ip: str | None = None,
    limit: int = 30,
) -> dict[str, Any]:
    """Keyword search only — no full chat scan."""
    q = (query or "").strip()
    if len(q) < 3:
        raise AppError(
            message="Qidiruv kamida 3 belgi",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )
    reason_clean = (reason or "").strip()
    if len(reason_clean) < 5:
        raise AppError(
            message="Qidiruv sababi kamida 5 belgi",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )

    pattern = f"%{q}%"
    # Match chats by id / participant OR message text containing keyword (capped)
    msg_chat_ids = (
        await db.execute(
            select(Message.chat_id)
            .where(Message.text_original.ilike(pattern), Message.is_deleted.is_(False))
            .group_by(Message.chat_id)
            .order_by(func.max(Message.id).desc())
            .limit(limit)
        )
    ).scalars().all()

    chat_ids = list(dict.fromkeys(int(x) for x in msg_chat_ids))
    if q.isdigit():
        uid_or_cid = int(q)
        extra = (
            await db.execute(
                select(Chat.id).where(
                    or_(
                        Chat.id == uid_or_cid,
                        Chat.user_low_id == uid_or_cid,
                        Chat.user_high_id == uid_or_cid,
                    )
                ).limit(20)
            )
        ).scalars().all()
        for cid in extra:
            if int(cid) not in chat_ids:
                chat_ids.append(int(cid))

    chats: list[Chat] = []
    if chat_ids:
        chats = list(
            (await db.execute(select(Chat).where(Chat.id.in_(chat_ids)))).scalars().all()
        )
        # preserve order
        by_id = {c.id: c for c in chats}
        chats = [by_id[i] for i in chat_ids if i in by_id]

    await write_audit(
        db,
        admin=admin,
        action="chat.search",
        target_type=None,
        target_id=None,
        meta={"query": q[:100], "reason": reason_clean[:200], "hits": len(chats)},
        ip=ip,
    )

    items = []
    for chat in chats:
        items.append(
            {
                "id": chat.id,
                "user_low_id": chat.user_low_id,
                "user_high_id": chat.user_high_id,
                "title": chat.title,
                "type": chat.type,
                "message_count": int(getattr(chat, "message_count", 0) or 0),
                "last_message_at": chat.last_message_at.isoformat()
                if chat.last_message_at
                else None,
                "matched_via": "keyword",
            }
        )
    return {
        "query": q,
        "reason": reason_clean,
        "items": items,
        "total": len(items),
    }


async def open_chat_access(
    db: AsyncSession,
    *,
    chat_id: int,
    case_id: int | None,
    reason: str,
    search_query: str | None,
    admin: AdminUser,
    ip: str | None = None,
) -> dict[str, Any]:
    chat = await db.get(Chat, chat_id)
    if chat is None:
        raise AppError(message="Chat not found", error_code="CHAT_NOT_FOUND", status_code=404)

    linked_case_id = case_id
    if case_id is not None:
        case = await db.get(ChatReviewCase, case_id)
        if case is None or case.chat_id != chat_id:
            raise AppError(
                message="Case chat bilan mos emas",
                error_code="VALIDATION_ERROR",
                status_code=400,
            )
        if case.status == "open":
            case.status = "reviewing"
            await db.flush()
    else:
        # Opening via search requires creating or linking a case for audit trail
        if not (search_query or "").strip() and len((reason or "").strip()) < 5:
            raise AppError(
                message="Case yoki qidiruv/sabab kerak",
                error_code="VALIDATION_ERROR",
                status_code=400,
            )
        case = await create_case(
            db,
            chat_id=chat_id,
            reason="keyword" if search_query else "other",
            description=reason,
            source="search" if search_query else "report",
            search_query=search_query,
            admin=admin,
            ip=ip,
        )
        linked_case_id = case["id"]
        # mark reviewing
        cobj = await db.get(ChatReviewCase, linked_case_id)
        if cobj:
            cobj.status = "reviewing"
            await db.flush()

    access = await grant_access(
        admin=admin,
        chat_id=chat_id,
        case_id=linked_case_id,
        reason=reason,
        search_query=search_query,
    )
    await write_audit(
        db,
        admin=admin,
        action="chat.access_open",
        target_type="chat",
        target_id=chat_id,
        meta={
            "case_id": linked_case_id,
            "ttl_seconds": ACCESS_TTL_SEC,
            "reason": reason[:200],
        },
        ip=ip,
    )
    return {
        "access": access,
        "case_id": linked_case_id,
        "chat": {
            "id": chat.id,
            "user_low_id": chat.user_low_id,
            "user_high_id": chat.user_high_id,
            "type": chat.type,
            "title": chat.title,
        },
    }


async def list_messages_gated(
    db: AsyncSession,
    *,
    chat_id: int,
    page: int | None,
    limit: int | None,
    admin: AdminUser,
    ip: str | None = None,
) -> dict[str, Any]:
    from app.core.pagination import normalize_page

    access = await require_access(admin.id, chat_id)
    chat = await db.get(Chat, chat_id)
    if chat is None:
        raise AppError(message="Chat not found", error_code="CHAT_NOT_FOUND", status_code=404)

    params = normalize_page(page, limit, default_size=100, max_size=200)
    total = int(
        (
            await db.execute(
                select(func.count()).select_from(Message).where(Message.chat_id == chat_id)
            )
        ).scalar()
        or 0
    )
    rows = list(
        (
            await db.execute(
                select(Message)
                .where(Message.chat_id == chat_id)
                .order_by(Message.id.asc())
                .offset(params.offset)
                .limit(params.page_size)
            )
        )
        .scalars()
        .all()
    )
    kw = access.get("search_query")
    await write_audit(
        db,
        admin=admin,
        action="chat.view_messages",
        target_type="chat",
        target_id=chat_id,
        meta={"count": len(rows), "case_id": access.get("case_id"), "remaining": access.get("remaining_seconds")},
        ip=ip,
    )
    items = []
    for m in rows:
        text = m.text_original
        items.append(
            {
                "id": m.id,
                "sender_id": m.sender_id,
                "type": m.type,
                "text_original": text,
                "original_language": m.original_language,
                "meta": m.meta,
                "is_deleted": m.is_deleted,
                "deleted_for_everyone": m.deleted_for_everyone,
                "created_at": m.created_at,
                "highlights": find_pii_spans(text, keyword=kw),
            }
        )
    return {
        "chat_id": chat_id,
        "user_low_id": chat.user_low_id,
        "user_high_id": chat.user_high_id,
        "access": {
            "remaining_seconds": access.get("remaining_seconds"),
            "expires_at": access.get("expires_at"),
            "case_id": access.get("case_id"),
            "reason": access.get("reason"),
        },
        "items": items,
        "page": params.page,
        "limit": params.page_size,
        "total": total,
        "has_more": params.offset + len(items) < total,
    }


async def export_chat_watermarked(
    db: AsyncSession,
    *,
    chat_id: int,
    fmt: Literal["json", "csv"],
    export_reason: str,
    admin: AdminUser,
    ip: str | None = None,
    cursor: int | None = None,
    limit: int = 500,
) -> tuple[str, str, bytes]:
    access = await require_access(admin.id, chat_id)
    reason = (export_reason or "").strip()
    if len(reason) < 5:
        raise AppError(
            message="Eksport sababi majburiy (kamida 5 belgi)",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )

    chat = await db.get(Chat, chat_id)
    if chat is None:
        raise AppError(message="Chat not found", error_code="CHAT_NOT_FOUND", status_code=404)

    page_size = max(1, min(limit, 1000))
    query = select(Message).where(Message.chat_id == chat_id)
    if cursor is not None:
        query = query.where(Message.id > cursor)
    rows = list(
        (await db.execute(query.order_by(Message.id.asc()).limit(page_size + 1))).scalars().all()
    )
    has_more = len(rows) > page_size
    rows = rows[:page_size]
    next_cursor = rows[-1].id if rows and has_more else None

    now = datetime.now(UTC)
    watermark = {
        "confidential": True,
        "exported_by": admin.email,
        "admin_id": admin.id,
        "exported_at": now.isoformat(),
        "export_reason": reason[:500],
        "access_reason": access.get("reason"),
        "case_id": access.get("case_id"),
        "chat_id": chat_id,
        "notice": "CONFIDENTIAL — AnyLang superadmin export. Unauthorized distribution prohibited.",
    }

    items = []
    for m in rows:
        text = m.text_original
        items.append(
            {
                "id": m.id,
                "sender_id": m.sender_id,
                "type": m.type,
                "text_original": text,
                "highlights": find_pii_spans(text, keyword=access.get("search_query")),
                "is_deleted": m.is_deleted,
                "created_at": m.created_at.isoformat() if m.created_at else None,
            }
        )

    await write_audit(
        db,
        admin=admin,
        action="chat.export",
        target_type="chat",
        target_id=chat_id,
        meta={
            "format": fmt,
            "export_reason": reason[:200],
            "case_id": access.get("case_id"),
            "exported_count": len(items),
            "next_cursor": next_cursor,
        },
        ip=ip,
    )

    if fmt == "json":
        data = {
            "_watermark": watermark,
            "chat_id": chat_id,
            "user_low_id": chat.user_low_id,
            "user_high_id": chat.user_high_id,
            "items": items,
            "next_cursor": next_cursor,
            "has_more": has_more,
            "exported_count": len(items),
        }
        payload = json.dumps(data, default=str, ensure_ascii=False, indent=2).encode("utf-8")
        return f"chat-{chat_id}-CONFIDENTIAL.json", "application/json", payload

    buf = io.StringIO()
    # Watermark as comment-like first rows
    buf.write(f"# {watermark['notice']}\n")
    buf.write(
        f"# exported_by={watermark['exported_by']}; at={watermark['exported_at']}; "
        f"reason={watermark['export_reason']}; case_id={watermark['case_id']}\n"
    )
    writer = csv.DictWriter(
        buf,
        fieldnames=["id", "sender_id", "type", "text_original", "created_at", "is_deleted", "pii_flags"],
    )
    writer.writeheader()
    for row in items:
        flags = ",".join(sorted({h["type"] for h in row.get("highlights") or []}))
        writer.writerow(
            {
                "id": row["id"],
                "sender_id": row["sender_id"],
                "type": row["type"],
                "text_original": row.get("text_original") or "",
                "created_at": row["created_at"],
                "is_deleted": row["is_deleted"],
                "pii_flags": flags,
            }
        )
    return f"chat-{chat_id}-CONFIDENTIAL.csv", "text/csv", buf.getvalue().encode("utf-8")
