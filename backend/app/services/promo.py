"""Promo code validate / apply / admin CRUD."""

from __future__ import annotations

from datetime import UTC, datetime
from decimal import Decimal, ROUND_HALF_UP

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.models.promo import PromoCode, PromoRedemption
from app.models.user import User


def _normalize_code(code: str) -> str:
    return (code or "").strip().upper()


def _money(value: Decimal) -> Decimal:
    return value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def serialize_promo(promo: PromoCode) -> dict:
    return {
        "id": promo.id,
        "code": promo.code,
        "description": promo.description,
        "discount_type": promo.discount_type,
        "discount_value": f"{promo.discount_value:.2f}",
        "applies_to_plans": list(promo.applies_to_plans or []) or None,
        "min_months": promo.min_months,
        "max_uses": promo.max_uses,
        "used_count": promo.used_count,
        "max_uses_per_user": promo.max_uses_per_user,
        "valid_from": promo.valid_from,
        "valid_until": promo.valid_until,
        "is_active": promo.is_active,
        "created_at": promo.created_at,
        "updated_at": promo.updated_at,
    }


def compute_discount(
    *,
    amount: Decimal,
    discount_type: str,
    discount_value: Decimal,
) -> Decimal:
    if amount <= 0:
        return Decimal("0.00")
    if discount_type == "percent":
        pct = min(max(discount_value, Decimal("0")), Decimal("100"))
        return _money(amount * pct / Decimal("100"))
    # fixed
    return _money(min(max(discount_value, Decimal("0")), amount))


async def list_promos(
    db: AsyncSession,
    *,
    page: int = 1,
    limit: int = 50,
    q: str | None = None,
    active_only: bool = False,
) -> dict:
    query = select(PromoCode)
    if active_only:
        query = query.where(PromoCode.is_active.is_(True))
    if q:
        like = f"%{_normalize_code(q)}%"
        query = query.where(PromoCode.code.ilike(like))
    total = (
        await db.execute(select(func.count()).select_from(query.subquery()))
    ).scalar_one()
    rows = list(
        (
            await db.execute(
                query.order_by(PromoCode.id.desc())
                .offset(max(page - 1, 0) * limit)
                .limit(limit)
            )
        ).scalars().all()
    )
    return {
        "items": [serialize_promo(p) for p in rows],
        "page": page,
        "limit": limit,
        "total": total,
        "has_more": page * limit < total,
    }


async def get_promo(db: AsyncSession, promo_id: int) -> PromoCode:
    promo = await db.get(PromoCode, promo_id)
    if promo is None:
        raise AppError(message="Promokod topilmadi", error_code="PROMO_NOT_FOUND", status_code=404)
    return promo


async def create_promo(
    db: AsyncSession,
    *,
    code: str,
    discount_type: str,
    discount_value: Decimal,
    description: str | None = None,
    applies_to_plans: list[str] | None = None,
    min_months: int | None = None,
    max_uses: int | None = None,
    max_uses_per_user: int = 1,
    valid_from: datetime | None = None,
    valid_until: datetime | None = None,
    is_active: bool = True,
) -> dict:
    normalized = _normalize_code(code)
    if len(normalized) < 3:
        raise AppError(message="Kod kamida 3 belgi", error_code="VALIDATION_ERROR", status_code=400)
    if discount_type not in {"percent", "fixed"}:
        raise AppError(message="discount_type noto'g'ri", error_code="VALIDATION_ERROR", status_code=400)
    if discount_value <= 0:
        raise AppError(message="Chegirma > 0 bo'lishi kerak", error_code="VALIDATION_ERROR", status_code=400)
    if discount_type == "percent" and discount_value > 100:
        raise AppError(message="Foiz 100 dan oshmasin", error_code="VALIDATION_ERROR", status_code=400)
    if min_months is not None and min_months not in {1, 3, 6, 12}:
        raise AppError(message="min_months 1/3/6/12", error_code="VALIDATION_ERROR", status_code=400)

    existing = await db.execute(select(PromoCode).where(PromoCode.code == normalized))
    if existing.scalar_one_or_none() is not None:
        raise AppError(message="Bu kod allaqachon bor", error_code="PROMO_EXISTS", status_code=409)

    promo = PromoCode(
        code=normalized,
        description=description,
        discount_type=discount_type,
        discount_value=discount_value,
        applies_to_plans=applies_to_plans or None,
        min_months=min_months,
        max_uses=max_uses,
        max_uses_per_user=max(1, max_uses_per_user),
        valid_from=valid_from,
        valid_until=valid_until,
        is_active=is_active,
        used_count=0,
    )
    db.add(promo)
    await db.flush()
    return serialize_promo(promo)


async def update_promo(
    db: AsyncSession,
    promo_id: int,
    **fields,
) -> dict:
    promo = await get_promo(db, promo_id)
    if "code" in fields and fields["code"] is not None:
        normalized = _normalize_code(fields["code"])
        if normalized != promo.code:
            clash = await db.execute(select(PromoCode).where(PromoCode.code == normalized))
            if clash.scalar_one_or_none() is not None:
                raise AppError(message="Bu kod allaqachon bor", error_code="PROMO_EXISTS", status_code=409)
            promo.code = normalized
    if "description" in fields:
        promo.description = fields["description"]
    if "discount_type" in fields and fields["discount_type"] is not None:
        if fields["discount_type"] not in {"percent", "fixed"}:
            raise AppError(message="discount_type noto'g'ri", error_code="VALIDATION_ERROR", status_code=400)
        promo.discount_type = fields["discount_type"]
    if "discount_value" in fields and fields["discount_value"] is not None:
        promo.discount_value = fields["discount_value"]
    if "applies_to_plans" in fields:
        promo.applies_to_plans = fields["applies_to_plans"] or None
    if "min_months" in fields:
        months = fields["min_months"]
        if months is not None and months not in {1, 3, 6, 12}:
            raise AppError(message="min_months 1/3/6/12", error_code="VALIDATION_ERROR", status_code=400)
        promo.min_months = months
    if "max_uses" in fields:
        promo.max_uses = fields["max_uses"]
    if "max_uses_per_user" in fields and fields["max_uses_per_user"] is not None:
        promo.max_uses_per_user = max(1, int(fields["max_uses_per_user"]))
    if "valid_from" in fields:
        promo.valid_from = fields["valid_from"]
    if "valid_until" in fields:
        promo.valid_until = fields["valid_until"]
    if "is_active" in fields and fields["is_active"] is not None:
        promo.is_active = fields["is_active"]
    await db.flush()
    return serialize_promo(promo)


async def delete_promo(db: AsyncSession, promo_id: int) -> None:
    promo = await get_promo(db, promo_id)
    await db.delete(promo)
    await db.flush()


async def _load_by_code(db: AsyncSession, code: str) -> PromoCode:
    normalized = _normalize_code(code)
    result = await db.execute(select(PromoCode).where(PromoCode.code == normalized))
    promo = result.scalar_one_or_none()
    if promo is None:
        raise AppError(message="Promokod topilmadi", error_code="PROMO_NOT_FOUND", status_code=404)
    return promo


async def validate_promo_for_checkout(
    db: AsyncSession,
    user: User,
    *,
    code: str,
    plan: str,
    months: int,
    amount: Decimal,
) -> dict:
    promo = await _load_by_code(db, code)
    now = datetime.now(UTC)

    if not promo.is_active:
        raise AppError(message="Promokod faol emas", error_code="PROMO_INACTIVE", status_code=400)
    if promo.valid_from and now < promo.valid_from:
        raise AppError(message="Promokod hali boshlanmagan", error_code="PROMO_NOT_STARTED", status_code=400)
    if promo.valid_until and now > promo.valid_until:
        raise AppError(message="Promokod muddati tugagan", error_code="PROMO_EXPIRED", status_code=400)
    if promo.max_uses is not None and promo.used_count >= promo.max_uses:
        raise AppError(message="Promokod limiga yetgan", error_code="PROMO_EXHAUSTED", status_code=400)

    plans = promo.applies_to_plans or []
    if plans and plan not in plans:
        raise AppError(
            message="Bu promokod ushbu tarif uchun emas",
            error_code="PROMO_PLAN_MISMATCH",
            status_code=400,
        )
    if promo.min_months is not None and months < promo.min_months:
        raise AppError(
            message=f"Kamida {promo.min_months} oylik tarif kerak",
            error_code="PROMO_MIN_MONTHS",
            status_code=400,
        )

    used_by_user = (
        await db.execute(
            select(func.count())
            .select_from(PromoRedemption)
            .where(
                PromoRedemption.promo_code_id == promo.id,
                PromoRedemption.user_id == user.id,
            )
        )
    ).scalar_one()
    if used_by_user >= promo.max_uses_per_user:
        raise AppError(
            message="Siz bu promokodni allaqachon ishlatgansiz",
            error_code="PROMO_ALREADY_USED",
            status_code=400,
        )

    discount = compute_discount(
        amount=amount,
        discount_type=promo.discount_type,
        discount_value=promo.discount_value,
    )
    after = _money(max(amount - discount, Decimal("0.00")))
    return {
        "promo_id": promo.id,
        "code": promo.code,
        "discount_type": promo.discount_type,
        "discount_value": f"{promo.discount_value:.2f}",
        "amount_before": f"{_money(amount):.2f}",
        "discount_amount": f"{discount:.2f}",
        "amount_after": f"{after:.2f}",
        "currency": "USD",
    }


async def redeem_promo_on_payment(
    db: AsyncSession,
    *,
    promo_id: int,
    user_id: int,
    payment_id: int,
    amount_before: Decimal,
    discount_amount: Decimal,
    amount_after: Decimal,
) -> None:
    promo = await get_promo(db, promo_id)
    promo.used_count = int(promo.used_count or 0) + 1
    db.add(
        PromoRedemption(
            promo_code_id=promo.id,
            user_id=user_id,
            payment_id=payment_id,
            amount_before=_money(amount_before),
            discount_amount=_money(discount_amount),
            amount_after=_money(amount_after),
        )
    )
    await db.flush()
