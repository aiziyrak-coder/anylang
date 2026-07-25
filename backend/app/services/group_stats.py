"""Group Statistics — eng faol davlat / kompaniya / mahsulot / bitim."""

from __future__ import annotations

from collections import defaultdict

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.models.chat import ChatParticipant, Message
from app.models.product import Product
from app.models.user import User
from app.services.chats import _get_chat_for_user
from app.services.ai_faq import FAQ_BOT_EMAIL

LEADER_LIMIT = 5


def _display_name(user: User) -> str:
    biz = user.business
    if biz and (biz.company_name or "").strip():
        return biz.company_name.strip()
    return (user.full_name or "").strip() or f"User {user.id}"


def _logo(user: User) -> str | None:
    if user.business and user.business.logo_url:
        return user.business.logo_url
    return user.avatar_url


def _country_of(user: User) -> str | None:
    if user.business and user.business.country:
        cc = user.business.country.strip().upper()
        if len(cc) == 2:
            return cc
    if user.country:
        cc = user.country.strip().upper()
        if len(cc) == 2:
            return cc
    return None


async def get_group_stats(
    db: AsyncSession,
    *,
    user: User,
    chat_id: int,
) -> dict:
    await _get_chat_for_user(db, chat_id, user.id)

    members_result = await db.execute(
        select(User)
        .join(ChatParticipant, ChatParticipant.user_id == User.id)
        .where(ChatParticipant.chat_id == chat_id)
        .options(selectinload(User.business), selectinload(User.subscription))
    )
    members = [
        m
        for m in members_result.scalars().all()
        if (m.email or "").lower() != FAQ_BOT_EMAIL
    ]
    member_ids = [m.id for m in members]
    members_by_id = {m.id: m for m in members}

    # Message counts per sender in this chat
    msg_counts: dict[int, int] = defaultdict(int)
    total_messages = 0
    if member_ids:
        msg_result = await db.execute(
            select(Message.sender_id, func.count())
            .where(
                Message.chat_id == chat_id,
                Message.deleted_for_everyone.is_(False),
                Message.sender_id.in_(member_ids),
            )
            .group_by(Message.sender_id)
        )
        for sid, cnt in msg_result.all():
            msg_counts[int(sid)] = int(cnt or 0)
            total_messages += int(cnt or 0)

    # --- Countries ---
    country_msgs: dict[str, int] = defaultdict(int)
    country_members: dict[str, int] = defaultdict(int)
    for m in members:
        cc = _country_of(m)
        if not cc:
            continue
        country_members[cc] += 1
        country_msgs[cc] += msg_counts.get(m.id, 0)

    countries = sorted(
        [
            {
                "code": cc,
                "message_count": country_msgs[cc],
                "member_count": country_members[cc],
            }
            for cc in country_msgs
        ],
        key=lambda x: (x["message_count"], x["member_count"]),
        reverse=True,
    )[:LEADER_LIMIT]

    # --- Companies (business only) ---
    companies: list[dict] = []
    for m in members:
        biz = m.business
        if not biz or not (biz.company_name or "").strip():
            continue
        # Prefer active business plan, but include any with company profile
        companies.append(
            {
                "user_id": m.id,
                "company_name": biz.company_name.strip(),
                "logo_url": _logo(m),
                "country": _country_of(m),
                "message_count": msg_counts.get(m.id, 0),
                "verified_badge": bool(m.verified_badge),
            }
        )
    companies.sort(key=lambda x: x["message_count"], reverse=True)
    companies = companies[:LEADER_LIMIT]

    # --- Products: published catalog size + shared in this chat ---
    product_counts: dict[int, int] = defaultdict(int)
    if member_ids:
        prod_result = await db.execute(
            select(Product.seller_id, func.count())
            .where(
                Product.seller_id.in_(member_ids),
                Product.status == "published",
            )
            .group_by(Product.seller_id)
        )
        for sid, cnt in prod_result.all():
            product_counts[int(sid)] = int(cnt or 0)

    shared_counts: dict[int, int] = defaultdict(int)
    if member_ids:
        shared_result = await db.execute(
            select(Message.sender_id, func.count())
            .where(
                Message.chat_id == chat_id,
                Message.deleted_for_everyone.is_(False),
                Message.type.in_(("product", "catalog")),
                Message.sender_id.in_(member_ids),
            )
            .group_by(Message.sender_id)
        )
        for sid, cnt in shared_result.all():
            shared_counts[int(sid)] = int(cnt or 0)

    products_leaders: list[dict] = []
    for uid in set(product_counts) | set(shared_counts):
        m = members_by_id.get(uid)
        if m is None:
            continue
        pc = product_counts.get(uid, 0)
        sc = shared_counts.get(uid, 0)
        if pc <= 0 and sc <= 0:
            continue
        products_leaders.append(
            {
                "user_id": uid,
                "company_name": _display_name(m),
                "logo_url": _logo(m),
                "product_count": pc,
                "shared_in_chat": sc,
            }
        )
    products_leaders.sort(
        key=lambda x: (x["product_count"], x["shared_in_chat"]),
        reverse=True,
    )
    products_leaders = products_leaders[:LEADER_LIMIT]

    # --- Deals: invoices + accepted offers in this chat ---
    invoice_counts: dict[int, int] = defaultdict(int)
    offer_counts: dict[int, int] = defaultdict(int)
    if member_ids:
        inv_result = await db.execute(
            select(Message.sender_id, func.count())
            .where(
                Message.chat_id == chat_id,
                Message.deleted_for_everyone.is_(False),
                Message.type == "invoice",
                Message.sender_id.in_(member_ids),
            )
            .group_by(Message.sender_id)
        )
        for sid, cnt in inv_result.all():
            invoice_counts[int(sid)] = int(cnt or 0)

        offer_result = await db.execute(
            select(Message.sender_id, Message.meta)
            .where(
                Message.chat_id == chat_id,
                Message.deleted_for_everyone.is_(False),
                Message.type == "offer",
                Message.sender_id.in_(member_ids),
            )
        )
        for sid, meta in offer_result.all():
            status = ""
            if isinstance(meta, dict):
                status = str(meta.get("status") or "").lower()
            if status == "accepted":
                offer_counts[int(sid)] += 1

    # Also fold in business.successful_deals for ranking soft signal
    deals_leaders: list[dict] = []
    deal_uids = set(invoice_counts) | set(offer_counts)
    for m in members:
        if m.business and int(m.business.successful_deals or 0) > 0:
            deal_uids.add(m.id)

    for uid in deal_uids:
        m = members_by_id.get(uid)
        if m is None:
            continue
        inv = invoice_counts.get(uid, 0)
        off = offer_counts.get(uid, 0)
        manual = int(m.business.successful_deals or 0) if m.business else 0
        # Chat activity weighs more; profile deals as secondary boost
        deal_count = inv + off + (1 if manual > 0 and (inv + off) == 0 else 0)
        # Prefer explicit chat deals; if only profile deals, use that count capped
        if inv + off > 0:
            deal_count = inv + off
        else:
            deal_count = manual
        if deal_count <= 0:
            continue
        deals_leaders.append(
            {
                "user_id": uid,
                "company_name": _display_name(m),
                "logo_url": _logo(m),
                "deal_count": deal_count,
                "invoice_count": inv,
                "offer_count": off,
            }
        )
    deals_leaders.sort(key=lambda x: x["deal_count"], reverse=True)
    deals_leaders = deals_leaders[:LEADER_LIMIT]

    return {
        "chat_id": chat_id,
        "member_count": len(members),
        "message_count": total_messages,
        "top_country": countries[0] if countries else None,
        "top_company": companies[0] if companies else None,
        "top_products": products_leaders[0] if products_leaders else None,
        "top_deals": deals_leaders[0] if deals_leaders else None,
        "countries": countries,
        "companies": companies,
        "products_leaders": products_leaders,
        "deals_leaders": deals_leaders,
    }
