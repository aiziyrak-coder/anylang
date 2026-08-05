"""Product moderation queue: AI pre-score, SLA kanban, bulk, seller strikes."""

from __future__ import annotations

import re
from datetime import UTC, datetime, timedelta
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.errors import AppError
from app.models.product import Product
from app.models.user import AdminUser, User
from app.services.admin_ops import write_audit

SLA_HOURS = 24
STRIKE_LIMIT = 3
RESTRICT_DAYS = 14

PRODUCT_REJECT_MACROS: list[dict[str, str]] = [
    {
        "id": "low_quality_photos",
        "uz": "Rasmlar sifatsiz yoki mahsulotni aniq ko‘rsatmaydi",
        "ru": "Фото низкого качества или не показывают товар",
        "en": "Photos are low quality or do not clearly show the product",
    },
    {
        "id": "incomplete_description",
        "uz": "Tavsif to‘liq emas (MOQ, material, o‘lcham va h.k.)",
        "ru": "Описание неполное (MOQ, материал, размеры и т.д.)",
        "en": "Description incomplete (MOQ, material, sizes, etc.)",
    },
    {
        "id": "misleading",
        "uz": "Narx yoki tavsif chalg‘ituvchi",
        "ru": "Цена или описание вводят в заблуждение",
        "en": "Price or description is misleading",
    },
    {
        "id": "prohibited",
        "uz": "Taqiqlangan toifa / kontent",
        "ru": "Запрещённая категория / контент",
        "en": "Prohibited category or content",
    },
    {
        "id": "spam_duplicate",
        "uz": "Spam yoki takroriy e’lon",
        "ru": "Спам или дублирующее объявление",
        "en": "Spam or duplicate listing",
    },
    {
        "id": "wrong_category",
        "uz": "Noto‘g‘ri kategoriya",
        "ru": "Неверная категория",
        "en": "Wrong category",
    },
]

_PROHIBITED = [
    r"\b(weapon|gun|firearm|наркотик|narkotik|cannabis|cocaine|viagra\s*bulk)\b",
    r"\b(counterfeit|replica\s*rolex|fake\s*passport|pirated?\s*software)\b",
    r"\b(human\s*traffick|organ\s*sale|child\s*porn)\b",
]

_SPAM = [
    r"(.)\1{8,}",
    r"\b(free\s*crypto|airdrop|guaranteed\s*profit|1000%\s*profit)\b",
    r"(whats?\s*app|telegram)\s*[:\-]?\s*\+?\d{9,}",
    r"(https?://|t\.me/)[^\s]{6,}.*(https?://|t\.me/)",
]

_LOW_QUALITY_HINTS = [
    r"^\s*$",
    r"^.{0,15}$",  # very short body checked separately
]


def get_reject_macros(*, locale: str = "uz") -> list[dict[str, Any]]:
    loc = (locale or "uz").lower()[:2]
    key = "ru" if loc == "ru" else "en" if loc == "en" else "uz"
    return [{"id": m["id"], "label": m[key], "text": m[key]} for m in PRODUCT_REJECT_MACROS]


def _hit(text: str, patterns: list[str]) -> bool:
    for p in patterns:
        try:
            if re.search(p, text, flags=re.IGNORECASE):
                return True
        except re.error:
            continue
    return False


def score_product_listing(
    *,
    name: str,
    short_description: str,
    description: str,
    category: str,
    image_count: int,
    price: float,
) -> dict[str, Any]:
    """Heuristic AI pre-score: spam / low_quality / prohibited (0–1)."""
    blob = f"{name}\n{short_description}\n{description}\n{category}".strip().lower()
    reasons: list[str] = []

    prohibited = 0.05
    if _hit(blob, _PROHIBITED):
        prohibited = 0.92
        reasons.append("prohibited_keywords")

    spam = 0.05
    if _hit(blob, _SPAM):
        spam = 0.88
        reasons.append("spam_patterns")
    # repeated title in description
    if name and description and description.count(name.strip().lower()[:20]) >= 4:
        spam = max(spam, 0.7)
        reasons.append("repetitive_text")

    low_quality = 0.1
    desc_len = len((description or "").strip())
    if image_count <= 0:
        low_quality = max(low_quality, 0.85)
        reasons.append("no_images")
    elif image_count == 1:
        low_quality = max(low_quality, 0.45)
        reasons.append("single_image")
    if desc_len < 40:
        low_quality = max(low_quality, 0.75)
        reasons.append("short_description")
    elif desc_len < 80:
        low_quality = max(low_quality, 0.4)
    if len((name or "").strip()) < 3:
        low_quality = max(low_quality, 0.8)
        reasons.append("weak_title")
    if price is not None and price <= 0:
        low_quality = max(low_quality, 0.55)
        reasons.append("zero_price")

    # overall risk label
    top = max(
        ("prohibited", prohibited),
        ("spam", spam),
        ("low_quality", low_quality),
        key=lambda x: x[1],
    )
    label = "ok"
    if top[1] >= 0.7:
        label = top[0]
    elif top[1] >= 0.45:
        label = f"review_{top[0]}"

    return {
        "spam": round(spam, 3),
        "low_quality": round(low_quality, 3),
        "prohibited": round(prohibited, 3),
        "label": label,
        "reasons": reasons,
        "risk": round(max(spam, low_quality, prohibited), 3),
        "source": "rules",
        "scored_at": datetime.now(UTC).isoformat(),
    }


def _age_hours(ts: datetime | None) -> float | None:
    if ts is None:
        return None
    t = ts if ts.tzinfo else ts.replace(tzinfo=UTC)
    return max(0.0, (datetime.now(UTC) - t).total_seconds() / 3600.0)


def listing_is_restricted(user: User) -> bool:
    until = user.listing_restricted_until
    if until is None:
        return False
    u = until if until.tzinfo else until.replace(tzinfo=UTC)
    return u > datetime.now(UTC)


async def assert_can_submit_listing(db: AsyncSession, user: User) -> None:
    # Refresh restriction fields
    fresh = await db.get(User, user.id)
    if fresh is None:
        return
    if listing_is_restricted(fresh):
        until = fresh.listing_restricted_until
        raise AppError(
            message="E’lon cheklovi: 3 marta rad etilgan. Keyinroq urinib ko‘ring.",
            error_code="LISTING_RESTRICTED",
            status_code=403,
            extra={
                "listing_restricted_until": until.isoformat() if until else None,
                "product_reject_strikes": int(fresh.product_reject_strikes or 0),
            },
        )


async def apply_ai_pre_score(db: AsyncSession, product: Product) -> dict[str, Any]:
    score = score_product_listing(
        name=product.name or "",
        short_description=product.short_description or "",
        description=product.description or "",
        category=product.category or "",
        image_count=len(product.images or []),
        price=float(product.price or 0),
    )
    product.ai_pre_score = score
    await db.flush()
    return score


def _serialize_card(product: Product, *, seller: User | None = None) -> dict[str, Any]:
    submitted = product.submitted_at or product.created_at
    age = _age_hours(submitted)
    ai = dict(product.ai_pre_score or {})
    risk = float(ai.get("risk") or 0)
    return {
        "id": product.id,
        "seller_id": product.seller_id,
        "seller_name": (seller.full_name if seller else None),
        "seller_email": (seller.email if seller else None),
        "name": product.name,
        "short_description": product.short_description,
        "description": product.description,
        "price": f"{product.price:.2f}",
        "currency": product.currency,
        "category": product.category,
        "status": product.status,
        "moderation_note": product.moderation_note or "",
        "ai_pre_score": ai,
        "ai_risk": risk,
        "ai_label": ai.get("label") or "ok",
        "submitted_at": submitted,
        "age_hours": round(age, 1) if age is not None else None,
        "sla_hours": SLA_HOURS,
        "sla_breached": bool(age is not None and age >= SLA_HOURS and product.status == "pending"),
        "primary_image_url": next(
            (img.url for img in (product.images or []) if img.is_primary),
            (product.images[0].url if product.images else None),
        ),
        "image_urls": [img.url for img in sorted(product.images or [], key=lambda x: x.position)],
        "created_at": product.created_at,
    }


async def moderation_kanban(db: AsyncSession, *, limit_per_column: int = 40) -> dict[str, Any]:
    """Kanban: queue / ai_flagged / sla_breached (+ macros)."""
    pending = list(
        (
            await db.execute(
                select(Product)
                .where(Product.status == "pending")
                .options(
                    selectinload(Product.images),
                    selectinload(Product.seller),
                )
                .order_by(Product.submitted_at.asc().nullsfirst(), Product.id.asc())
                .limit(300)
            )
        )
        .scalars()
        .all()
    )

    queue: list[dict[str, Any]] = []
    ai_flagged: list[dict[str, Any]] = []
    sla_breached: list[dict[str, Any]] = []

    for p in pending:
        card = _serialize_card(p, seller=p.seller)
        if card["sla_breached"]:
            sla_breached.append(card)
        elif float(card["ai_risk"] or 0) >= 0.7 or str(card["ai_label"]).startswith("review_"):
            ai_flagged.append(card)
        else:
            queue.append(card)

    def trim(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
        return rows[:limit_per_column]

    return {
        "sla_hours": SLA_HOURS,
        "columns": {
            "queue": {"title": "Navbat", "items": trim(queue), "total": len(queue)},
            "ai_flagged": {
                "title": "AI shubha",
                "items": trim(ai_flagged),
                "total": len(ai_flagged),
            },
            "sla_breached": {
                "title": "SLA buzilgan",
                "items": trim(sla_breached),
                "total": len(sla_breached),
            },
        },
        "reject_macros": get_reject_macros(locale="uz"),
        "counts": {
            "pending": len(pending),
            "queue": len(queue),
            "ai_flagged": len(ai_flagged),
            "sla_breached": len(sla_breached),
        },
    }


async def moderation_detail(db: AsyncSession, *, product_id: int) -> dict[str, Any]:
    result = await db.execute(
        select(Product)
        .where(Product.id == product_id)
        .options(
            selectinload(Product.images),
            selectinload(Product.seller).selectinload(User.business),
            selectinload(Product.seller).selectinload(User.subscription),
        )
    )
    product = result.scalar_one_or_none()
    if product is None:
        raise AppError(message="Mahsulot topilmadi", error_code="PRODUCT_NOT_FOUND", status_code=404)

    seller = product.seller
    trust = None
    if seller is not None:
        try:
            from app.services import trust_score as trust_score_service

            biz = seller.business
            trust = await trust_score_service.compute_trust_score(db, seller, biz)
        except Exception:
            trust = None

    reject_count = int(
        (
            await db.execute(
                select(func.count())
                .select_from(Product)
                .where(
                    Product.seller_id == product.seller_id,
                    Product.status == "rejected",
                )
            )
        ).scalar()
        or 0
    )

    card = _serialize_card(product, seller=seller)
    return {
        **card,
        "seller": None
        if seller is None
        else {
            "id": seller.id,
            "full_name": seller.full_name,
            "email": seller.email,
            "number": seller.number,
            "is_verified": seller.is_verified,
            "verified_badge": seller.verified_badge,
            "product_reject_strikes": int(seller.product_reject_strikes or 0),
            "listing_restricted_until": seller.listing_restricted_until,
            "listing_restricted": listing_is_restricted(seller),
            "company_name": (seller.business.company_name if seller.business else None),
            "trust_score": trust,
            "lifetime_rejects": reject_count,
        },
        "reject_macros": get_reject_macros(locale="uz"),
        "side_by_side": {
            "images": card["image_urls"],
            "text": {
                "name": product.name,
                "short_description": product.short_description,
                "description": product.description,
                "category": product.category,
                "price": f"{product.price:.2f} {product.currency}",
                "moq": product.moq,
                "shipping_info": product.shipping_info,
            },
        },
    }


async def bulk_moderate(
    db: AsyncSession,
    *,
    product_ids: list[int],
    approve: bool,
    admin_note: str | None,
    admin: AdminUser,
    ip: str | None = None,
) -> dict[str, Any]:
    from app.services.products import moderate_product

    if not product_ids:
        raise AppError(message="product_ids required", error_code="VALIDATION_ERROR", status_code=400)
    ids = list(dict.fromkeys(product_ids))[:50]
    ok: list[int] = []
    errors: list[dict[str, Any]] = []
    for pid in ids:
        try:
            await moderate_product(
                db,
                product_id=pid,
                admin_id=admin.id,
                approve=approve,
                admin_note=admin_note,
            )
            ok.append(pid)
        except AppError as exc:
            errors.append({"id": pid, "error": exc.message, "code": exc.error_code})
        except Exception as exc:
            errors.append({"id": pid, "error": str(exc)[:200], "code": "ERROR"})

    await write_audit(
        db,
        admin=admin,
        action="product.moderate.bulk_approve" if approve else "product.moderate.bulk_reject",
        target_type="product",
        target_id="bulk",
        meta={"ok": ok, "errors": len(errors), "approve": approve},
        ip=ip,
    )
    return {"ok": ok, "errors": errors, "approve": approve}


async def apply_reject_strike(db: AsyncSession, *, seller_id: int) -> dict[str, Any]:
    user = await db.get(User, seller_id, with_for_update=True)
    if user is None:
        return {"strikes": 0, "restricted": False}
    user.product_reject_strikes = int(user.product_reject_strikes or 0) + 1
    restricted = False
    if user.product_reject_strikes >= STRIKE_LIMIT:
        user.listing_restricted_until = datetime.now(UTC) + timedelta(days=RESTRICT_DAYS)
        user.product_reject_strikes = 0
        restricted = True
    await db.flush()
    return {
        "strikes": int(user.product_reject_strikes or 0),
        "restricted": restricted,
        "listing_restricted_until": user.listing_restricted_until,
    }


async def clear_strike_on_approve(db: AsyncSession, *, seller_id: int) -> None:
    """Optional soft reset: successful publish reduces strike by 1."""
    user = await db.get(User, seller_id, with_for_update=True)
    if user is None:
        return
    if int(user.product_reject_strikes or 0) > 0:
        user.product_reject_strikes = int(user.product_reject_strikes) - 1
        await db.flush()
