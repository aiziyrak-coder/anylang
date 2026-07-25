"""Group Catalog — guruh ichidagi Products / Documents / Companies."""

from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.chat import ChatParticipant, Message
from app.models.user import BusinessProfile, Subscription, User
from app.services.chats import _get_chat_for_user


def _meta(msg: Message) -> dict:
    return msg.meta if isinstance(msg.meta, dict) else {}


def _sender_name(user: User | None) -> str | None:
    if user is None:
        return None
    if (
        user.subscription
        and user.subscription.plan == "business"
        and user.subscription.is_active
        and user.business
        and user.business.company_name
    ):
        return user.business.company_name
    return user.full_name


async def _load_users_map(db: AsyncSession, user_ids: set[int]) -> dict[int, User]:
    if not user_ids:
        return {}
    result = await db.execute(
        select(User)
        .where(User.id.in_(user_ids))
        .options(selectinload(User.business), selectinload(User.subscription))
    )
    return {u.id: u for u in result.scalars().all()}


async def get_group_catalog(
    db: AsyncSession,
    *,
    user: User,
    chat_id: int,
    section: str = "all",
    limit: int = 100,
) -> dict:
    await _get_chat_for_user(db, chat_id, user.id)

    section = (section or "all").strip().lower()
    if section not in {"products", "documents", "companies", "all"}:
        section = "all"
    limit = max(1, min(int(limit or 100), 200))

    products: list[dict] = []
    documents: list[dict] = []
    companies: list[dict] = []

    if section in {"products", "documents", "all"}:
        types: list[str] = []
        if section in {"products", "all"}:
            types.extend(["product", "catalog"])
        if section in {"documents", "all"}:
            types.extend(["file", "invoice"])
        result = await db.execute(
            select(Message)
            .where(
                Message.chat_id == chat_id,
                Message.deleted_for_everyone.is_(False),
                Message.type.in_(types),
            )
            .order_by(Message.id.desc())
            .limit(limit * 2)
        )
        messages = list(result.scalars().all())
        users = await _load_users_map(db, {m.sender_id for m in messages})
        for msg in messages:
            meta = _meta(msg)
            sname = _sender_name(users.get(msg.sender_id))
            if msg.type == "product" and len(products) < limit:
                pid = meta.get("product_id")
                products.append(
                    {
                        "message_id": msg.id,
                        "product_id": int(pid) if isinstance(pid, (int, float)) else None,
                        "title": str(
                            meta.get("name")
                            or meta.get("title")
                            or meta.get("product")
                            or "Product"
                        ).strip()
                        or "Product",
                        "price": (
                            str(meta["price"]).strip()
                            if meta.get("price") is not None
                            else None
                        ),
                        "image_url": meta.get("image_url") or meta.get("url"),
                        "subtitle": None,
                        "source": "product",
                        "sender_id": msg.sender_id,
                        "sender_name": sname,
                        "created_at": msg.created_at,
                    }
                )
            elif msg.type == "catalog" and len(products) < limit:
                count = meta.get("count")
                products.append(
                    {
                        "message_id": msg.id,
                        "product_id": None,
                        "title": str(
                            meta.get("title")
                            or meta.get("company_name")
                            or "Catalog"
                        ).strip()
                        or "Catalog",
                        "price": None,
                        "image_url": meta.get("image_url"),
                        "subtitle": (
                            f"{count} products"
                            if count is not None
                            else (meta.get("preview") or meta.get("subtitle"))
                        ),
                        "source": "catalog",
                        "sender_id": msg.sender_id,
                        "sender_name": sname,
                        "created_at": msg.created_at,
                    }
                )
            elif msg.type == "file" and len(documents) < limit:
                filename = str(
                    meta.get("filename") or meta.get("name") or "file"
                ).strip() or "file"
                ext = filename.split(".")[-1].upper() if "." in filename else "FILE"
                size_raw = meta.get("size")
                size = int(size_raw) if isinstance(size_raw, (int, float)) else None
                documents.append(
                    {
                        "message_id": msg.id,
                        "filename": filename,
                        "url": meta.get("url"),
                        "size": size,
                        "ext": ext,
                        "sender_id": msg.sender_id,
                        "sender_name": sname,
                        "created_at": msg.created_at,
                    }
                )
            elif msg.type == "invoice" and len(documents) < limit:
                title = str(meta.get("title") or "Invoice").strip() or "Invoice"
                amount = str(meta.get("amount") or "").strip()
                currency = str(meta.get("currency") or "").strip()
                label = " · ".join(
                    b for b in (title, f"{amount} {currency}".strip()) if b
                )
                documents.append(
                    {
                        "message_id": msg.id,
                        "filename": f"{label}.invoice",
                        "url": meta.get("url"),
                        "size": None,
                        "ext": "INV",
                        "sender_id": msg.sender_id,
                        "sender_name": sname,
                        "created_at": msg.created_at,
                    }
                )

    if section in {"companies", "all"}:
        members_result = await db.execute(
            select(User)
            .join(ChatParticipant, ChatParticipant.user_id == User.id)
            .where(ChatParticipant.chat_id == chat_id)
            .options(selectinload(User.business), selectinload(User.subscription))
        )
        seen: set[int] = set()
        for member in members_result.scalars().all():
            sub: Subscription | None = member.subscription
            biz: BusinessProfile | None = member.business
            if not (
                sub
                and sub.plan == "business"
                and sub.is_active
                and biz
                and (biz.company_name or "").strip()
            ):
                continue
            seen.add(member.id)
            companies.append(
                {
                    "user_id": member.id,
                    "company_name": biz.company_name.strip(),
                    "logo_url": biz.logo_url or member.avatar_url,
                    "country": biz.country or member.country,
                    "business_role": biz.business_role,
                    "verified_badge": bool(member.verified_badge),
                    "website": biz.website,
                    "description": (biz.description or "")[:240] or None,
                    "source": "member",
                    "message_id": None,
                }
            )

        if len(companies) < limit:
            cards = await db.execute(
                select(Message)
                .where(
                    Message.chat_id == chat_id,
                    Message.deleted_for_everyone.is_(False),
                    Message.type == "business_card",
                )
                .order_by(Message.id.desc())
                .limit(limit)
            )
            for msg in cards.scalars().all():
                if len(companies) >= limit:
                    break
                meta = _meta(msg)
                uid_raw = meta.get("user_id")
                uid = int(uid_raw) if isinstance(uid_raw, (int, float)) else None
                if uid is not None and uid in seen:
                    continue
                name = str(
                    meta.get("company_name") or meta.get("name") or ""
                ).strip()
                if not name:
                    continue
                if uid is not None:
                    seen.add(uid)
                companies.append(
                    {
                        "user_id": uid or msg.sender_id,
                        "company_name": name,
                        "logo_url": meta.get("logo_url") or meta.get("avatar_url"),
                        "country": meta.get("country"),
                        "business_role": meta.get("role") or meta.get("business_role"),
                        "verified_badge": bool(meta.get("verified_badge")),
                        "website": meta.get("website"),
                        "description": meta.get("phone"),
                        "source": "business_card",
                        "message_id": msg.id,
                    }
                )

    if section == "products":
        documents, companies = [], []
    elif section == "documents":
        products, companies = [], []
    elif section == "companies":
        products, documents = [], []

    return {
        "chat_id": chat_id,
        "products": products[:limit],
        "documents": documents[:limit],
        "companies": companies[:limit],
        "counts": {
            "products": len(products),
            "documents": len(documents),
            "companies": len(companies),
        },
    }
