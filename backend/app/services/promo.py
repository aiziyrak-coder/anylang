"""Promo code validate / apply / admin CRUD / campaign / dashboard."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from decimal import ROUND_HALF_UP, Decimal
from typing import Any
from uuid import uuid4

from sqlalchemy import and_, func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.models.promo import PromoCode, PromoRedemption
from app.models.user import User

CODE_TYPES = {"standard", "campaign", "referral", "influencer"}
SEGMENTS = {"all", "new_users"}
VARIANTS = {"A", "B"}


def _normalize_code(code: str) -> str:
    return (code or "").strip().upper()


def _money(value: Decimal) -> Decimal:
    return value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def _clean_str_list(values: list[str] | None, *, upper: bool = False) -> list[str] | None:
    if values is None:
        return None
    out: list[str] = []
    for v in values:
        s = str(v).strip()
        if not s:
            continue
        out.append(s.upper() if upper else s)
    return out or None


def _effective_status(promo: PromoCode, now: datetime | None = None) -> str:
    """active | paused | expired | inactive | exhausted."""
    now = now or datetime.now(UTC)
    if not promo.is_active:
        return "inactive"
    if promo.is_paused:
        return "paused"
    if promo.valid_until and now > promo.valid_until:
        return "expired"
    if promo.valid_from and now < promo.valid_from:
        return "scheduled"
    if promo.max_uses is not None and promo.used_count >= promo.max_uses:
        return "exhausted"
    return "active"


def serialize_promo(promo: PromoCode) -> dict:
    now = datetime.now(UTC)
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
        "is_paused": promo.is_paused,
        "campaign_key": promo.campaign_key,
        "variant": promo.variant,
        "code_type": promo.code_type or "standard",
        "segment": promo.segment or "all",
        "new_user_max_age_days": promo.new_user_max_age_days or 7,
        "allowed_countries": list(promo.allowed_countries or []) or None,
        "allowed_languages": list(promo.allowed_languages or []) or None,
        "influencer_label": promo.influencer_label,
        "status": _effective_status(promo, now),
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
    return _money(min(max(discount_value, Decimal("0")), amount))


def _validate_common_fields(
    *,
    discount_type: str,
    discount_value: Decimal,
    min_months: int | None,
    code_type: str | None,
    segment: str | None,
    variant: str | None,
) -> None:
    if discount_type not in {"percent", "fixed"}:
        raise AppError(message="discount_type noto'g'ri", error_code="VALIDATION_ERROR", status_code=400)
    if discount_value <= 0:
        raise AppError(message="Chegirma > 0 bo'lishi kerak", error_code="VALIDATION_ERROR", status_code=400)
    if discount_type == "percent" and discount_value > 100:
        raise AppError(message="Foiz 100 dan oshmasin", error_code="VALIDATION_ERROR", status_code=400)
    if min_months is not None and min_months not in {1, 3, 6, 12}:
        raise AppError(message="min_months 1/3/6/12", error_code="VALIDATION_ERROR", status_code=400)
    if code_type is not None and code_type not in CODE_TYPES:
        raise AppError(message="code_type noto'g'ri", error_code="VALIDATION_ERROR", status_code=400)
    if segment is not None and segment not in SEGMENTS:
        raise AppError(message="segment noto'g'ri", error_code="VALIDATION_ERROR", status_code=400)
    if variant is not None and variant not in VARIANTS:
        raise AppError(message="variant A yoki B", error_code="VALIDATION_ERROR", status_code=400)


async def list_promos(
    db: AsyncSession,
    *,
    page: int = 1,
    limit: int = 50,
    q: str | None = None,
    active_only: bool = False,
    code_type: str | None = None,
    campaign_key: str | None = None,
    sort: str | None = None,
    order: str | None = None,
) -> dict:
    from app.services.admin_list import apply_sort

    # Auto-deactivate expired (soft expire) before listing.
    await expire_stale_promos(db)

    query = select(PromoCode)
    if active_only:
        now = datetime.now(UTC)
        query = query.where(
            PromoCode.is_active.is_(True),
            PromoCode.is_paused.is_(False),
            or_(PromoCode.valid_until.is_(None), PromoCode.valid_until >= now),
        )
    if code_type:
        query = query.where(PromoCode.code_type == code_type)
    if campaign_key:
        query = query.where(PromoCode.campaign_key == campaign_key.strip())
    if q:
        like = f"%{_normalize_code(q)}%"
        query = query.where(
            or_(
                PromoCode.code.ilike(like),
                PromoCode.campaign_key.ilike(f"%{q.strip()}%"),
                PromoCode.influencer_label.ilike(f"%{q.strip()}%"),
            )
        )
    total = (
        await db.execute(select(func.count()).select_from(query.subquery()))
    ).scalar_one()
    order_by = apply_sort(
        {
            "id": PromoCode.id,
            "code": PromoCode.code,
            "created_at": PromoCode.created_at,
            "valid_until": PromoCode.valid_until,
            "used_count": PromoCode.used_count,
        },
        sort=sort,
        order=order,
        default="id",
    )
    rows = list(
        (
            await db.execute(
                query.order_by(order_by).offset(max(page - 1, 0) * limit).limit(limit)
            )
        )
        .scalars()
        .all()
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
    campaign_key: str | None = None,
    variant: str | None = None,
    code_type: str = "standard",
    segment: str = "all",
    new_user_max_age_days: int = 7,
    allowed_countries: list[str] | None = None,
    allowed_languages: list[str] | None = None,
    influencer_label: str | None = None,
    is_paused: bool = False,
) -> dict:
    _validate_common_fields(
        discount_type=discount_type,
        discount_value=discount_value,
        min_months=min_months,
        code_type=code_type,
        segment=segment,
        variant=variant,
    )
    normalized = _normalize_code(code)
    if len(normalized) < 3:
        raise AppError(message="Kod kamida 3 belgi", error_code="VALIDATION_ERROR", status_code=400)

    existing = await db.execute(select(PromoCode).where(PromoCode.code == normalized))
    if existing.scalar_one_or_none() is not None:
        raise AppError(message="Bu kod allaqachon bor", error_code="PROMO_EXISTS", status_code=409)

    if code_type in {"referral", "influencer"} and not (influencer_label or "").strip():
        # soft: label optional but recommended — allow empty
        pass

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
        campaign_key=(campaign_key or "").strip() or None,
        variant=variant,
        code_type=code_type,
        segment=segment,
        new_user_max_age_days=max(1, min(int(new_user_max_age_days or 7), 90)),
        allowed_countries=_clean_str_list(allowed_countries, upper=True),
        allowed_languages=_clean_str_list(allowed_languages),
        influencer_label=(influencer_label or "").strip()[:120] or None,
        is_paused=is_paused,
    )
    db.add(promo)
    await db.flush()
    return serialize_promo(promo)


async def create_ab_campaign(
    db: AsyncSession,
    *,
    campaign_key: str | None,
    code_a: str,
    code_b: str,
    discount_type: str,
    discount_value_a: Decimal,
    discount_value_b: Decimal,
    description: str | None = None,
    applies_to_plans: list[str] | None = None,
    min_months: int | None = None,
    max_uses: int | None = None,
    max_uses_per_user: int = 1,
    valid_from: datetime | None = None,
    valid_until: datetime | None = None,
    segment: str = "all",
    new_user_max_age_days: int = 7,
    allowed_countries: list[str] | None = None,
    allowed_languages: list[str] | None = None,
) -> dict:
    key = (campaign_key or "").strip() or f"cmp_{uuid4().hex[:8]}"
    a = await create_promo(
        db,
        code=code_a,
        discount_type=discount_type,
        discount_value=discount_value_a,
        description=description,
        applies_to_plans=applies_to_plans,
        min_months=min_months,
        max_uses=max_uses,
        max_uses_per_user=max_uses_per_user,
        valid_from=valid_from,
        valid_until=valid_until,
        campaign_key=key,
        variant="A",
        code_type="campaign",
        segment=segment,
        new_user_max_age_days=new_user_max_age_days,
        allowed_countries=allowed_countries,
        allowed_languages=allowed_languages,
    )
    b = await create_promo(
        db,
        code=code_b,
        discount_type=discount_type,
        discount_value=discount_value_b,
        description=description,
        applies_to_plans=applies_to_plans,
        min_months=min_months,
        max_uses=max_uses,
        max_uses_per_user=max_uses_per_user,
        valid_from=valid_from,
        valid_until=valid_until,
        campaign_key=key,
        variant="B",
        code_type="campaign",
        segment=segment,
        new_user_max_age_days=new_user_max_age_days,
        allowed_countries=allowed_countries,
        allowed_languages=allowed_languages,
    )
    return {"campaign_key": key, "variants": [a, b]}


async def update_promo(
    db: AsyncSession,
    promo_id: int,
    **fields: Any,
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
    if "is_paused" in fields and fields["is_paused"] is not None:
        promo.is_paused = bool(fields["is_paused"])
    if "campaign_key" in fields:
        promo.campaign_key = (fields["campaign_key"] or "").strip() or None
    if "variant" in fields:
        v = fields["variant"]
        if v is not None and v not in VARIANTS:
            raise AppError(message="variant A yoki B", error_code="VALIDATION_ERROR", status_code=400)
        promo.variant = v
    if "code_type" in fields and fields["code_type"] is not None:
        if fields["code_type"] not in CODE_TYPES:
            raise AppError(message="code_type noto'g'ri", error_code="VALIDATION_ERROR", status_code=400)
        promo.code_type = fields["code_type"]
    if "segment" in fields and fields["segment"] is not None:
        if fields["segment"] not in SEGMENTS:
            raise AppError(message="segment noto'g'ri", error_code="VALIDATION_ERROR", status_code=400)
        promo.segment = fields["segment"]
    if "new_user_max_age_days" in fields and fields["new_user_max_age_days"] is not None:
        promo.new_user_max_age_days = max(1, min(int(fields["new_user_max_age_days"]), 90))
    if "allowed_countries" in fields:
        promo.allowed_countries = _clean_str_list(fields["allowed_countries"], upper=True)
    if "allowed_languages" in fields:
        promo.allowed_languages = _clean_str_list(fields["allowed_languages"])
    if "influencer_label" in fields:
        label = fields["influencer_label"]
        promo.influencer_label = (str(label).strip()[:120] if label else None) or None
    await db.flush()
    return serialize_promo(promo)


async def set_paused(db: AsyncSession, promo_id: int, *, paused: bool) -> dict:
    return await update_promo(db, promo_id, is_paused=paused)


async def delete_promo(db: AsyncSession, promo_id: int) -> None:
    promo = await get_promo(db, promo_id)
    await db.delete(promo)
    await db.flush()


async def expire_stale_promos(db: AsyncSession) -> int:
    """Deactivate codes past valid_until (auto-expire)."""
    now = datetime.now(UTC)
    result = await db.execute(
        update(PromoCode)
        .where(
            PromoCode.is_active.is_(True),
            PromoCode.valid_until.is_not(None),
            PromoCode.valid_until < now,
        )
        .values(is_active=False, is_paused=False)
    )
    await db.flush()
    return int(result.rowcount or 0)


async def _load_by_code(db: AsyncSession, code: str) -> PromoCode:
    normalized = _normalize_code(code)
    result = await db.execute(select(PromoCode).where(PromoCode.code == normalized))
    promo = result.scalar_one_or_none()
    if promo is None:
        raise AppError(message="Promokod topilmadi", error_code="PROMO_NOT_FOUND", status_code=404)
    return promo


def _lang_match(allowed: list[str], user_lang: str) -> bool:
    ul = (user_lang or "").strip()
    if not ul:
        return False
    short = ul.split("_")[0].split("-")[0].lower()
    for a in allowed:
        a_s = a.strip()
        if not a_s:
            continue
        if a_s.lower() == ul.lower() or a_s.split("_")[0].lower() == short:
            return True
    return False


async def validate_promo_for_checkout(
    db: AsyncSession,
    user: User,
    *,
    code: str,
    plan: str,
    months: int,
    amount: Decimal,
) -> dict:
    await expire_stale_promos(db)
    promo = await _load_by_code(db, code)
    now = datetime.now(UTC)

    if not promo.is_active:
        raise AppError(message="Promokod faol emas", error_code="PROMO_INACTIVE", status_code=400)
    if promo.is_paused:
        raise AppError(message="Promokod pauzada", error_code="PROMO_PAUSED", status_code=400)
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

    countries = list(promo.allowed_countries or [])
    if countries:
        uc = (user.country or "").strip().upper()
        if not uc or uc not in countries:
            raise AppError(
                message="Bu promokod sizning mintaqangiz uchun emas",
                error_code="PROMO_GEO_MISMATCH",
                status_code=400,
            )

    langs = list(promo.allowed_languages or [])
    if langs and not _lang_match(langs, getattr(user, "app_language", "") or ""):
        raise AppError(
            message="Bu promokod sizning tilingiz uchun emas",
            error_code="PROMO_LANG_MISMATCH",
            status_code=400,
        )

    if (promo.segment or "all") == "new_users":
        age_days = int(promo.new_user_max_age_days or 7)
        created = user.created_at
        if created is None or (now - created) > timedelta(days=age_days):
            raise AppError(
                message="Bu promokod faqat yangi foydalanuvchilar uchun",
                error_code="PROMO_SEGMENT_NEW_ONLY",
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
        "code_type": promo.code_type,
        "variant": promo.variant,
        "campaign_key": promo.campaign_key,
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
    promo = await db.execute(
        select(PromoCode).where(PromoCode.id == promo_id).with_for_update()
    )
    promo = promo.scalar_one_or_none()
    if promo is None:
        raise AppError(message="Promokod topilmadi", error_code="PROMO_NOT_FOUND", status_code=404)
    if promo.is_paused or not promo.is_active:
        raise AppError(message="Promokod faol emas", error_code="PROMO_INACTIVE", status_code=409)
    used = int(promo.used_count or 0)
    if promo.max_uses is not None and used >= int(promo.max_uses):
        raise AppError(
            message="Promokod limiti tugagan",
            error_code="PROMO_EXHAUSTED",
            status_code=409,
        )
    promo.used_count = used + 1
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


async def promo_dashboard(db: AsyncSession, *, days: int = 7) -> dict[str, Any]:
    await expire_stale_promos(db)
    now = datetime.now(UTC)
    since = now - timedelta(days=days)
    since_24h = now - timedelta(hours=24)

    totals = (
        await db.execute(
            select(
                func.count(PromoCode.id),
                func.count(PromoCode.id).filter(
                    PromoCode.is_active.is_(True), PromoCode.is_paused.is_(False)
                ),
                func.count(PromoCode.id).filter(PromoCode.is_paused.is_(True)),
                func.coalesce(func.sum(PromoCode.used_count), 0),
            ).select_from(PromoCode)
        )
    ).one()
    codes_total, codes_live, codes_paused, uses_all_time = (
        int(totals[0] or 0),
        int(totals[1] or 0),
        int(totals[2] or 0),
        int(totals[3] or 0),
    )

    redeem_q = await db.execute(
        select(
            func.count(PromoRedemption.id),
            func.count(func.distinct(PromoRedemption.user_id)),
            func.coalesce(func.sum(PromoRedemption.discount_amount), 0),
        ).where(PromoRedemption.created_at >= since)
    )
    redemptions, unique_users, discount_sum = redeem_q.one()

    last_24h = int(
        (
            await db.execute(
                select(func.count())
                .select_from(PromoRedemption)
                .where(PromoRedemption.created_at >= since_24h)
            )
        ).scalar_one()
        or 0
    )

    by_type = (
        await db.execute(
            select(PromoCode.code_type, func.count(), func.coalesce(func.sum(PromoCode.used_count), 0))
            .group_by(PromoCode.code_type)
        )
    ).all()

    # Top codes in window
    top_rows = (
        await db.execute(
            select(
                PromoCode.id,
                PromoCode.code,
                PromoCode.code_type,
                PromoCode.variant,
                PromoCode.campaign_key,
                PromoCode.used_count,
                PromoCode.max_uses,
                PromoCode.is_paused,
                PromoCode.is_active,
                func.count(PromoRedemption.id).label("window_uses"),
                func.coalesce(func.sum(PromoRedemption.discount_amount), 0).label("window_discount"),
            )
            .outerjoin(
                PromoRedemption,
                and_(
                    PromoRedemption.promo_code_id == PromoCode.id,
                    PromoRedemption.created_at >= since,
                ),
            )
            .group_by(PromoCode.id)
            .order_by(func.count(PromoRedemption.id).desc())
            .limit(15)
        )
    ).all()

    # A/B campaign comparison
    campaign_rows = (
        await db.execute(
            select(
                PromoCode.campaign_key,
                PromoCode.variant,
                PromoCode.code,
                func.count(PromoRedemption.id),
            )
            .outerjoin(
                PromoRedemption,
                and_(
                    PromoRedemption.promo_code_id == PromoCode.id,
                    PromoRedemption.created_at >= since,
                ),
            )
            .where(PromoCode.campaign_key.is_not(None), PromoCode.code_type == "campaign")
            .group_by(PromoCode.campaign_key, PromoCode.variant, PromoCode.code)
            .order_by(PromoCode.campaign_key, PromoCode.variant)
        )
    ).all()
    campaigns: dict[str, list] = {}
    for key, variant, code, cnt in campaign_rows:
        if not key:
            continue
        campaigns.setdefault(key, []).append(
            {"variant": variant, "code": code, "uses": int(cnt or 0)}
        )

    # Abuse signals: users with many redemptions in window; new accounts redeeming non-new codes
    multi_user = (
        await db.execute(
            select(
                PromoRedemption.user_id,
                User.email,
                func.count(PromoRedemption.id).label("n"),
            )
            .join(User, User.id == PromoRedemption.user_id)
            .where(PromoRedemption.created_at >= since)
            .group_by(PromoRedemption.user_id, User.email)
            .having(func.count(PromoRedemption.id) >= 3)
            .order_by(func.count(PromoRedemption.id).desc())
            .limit(20)
        )
    ).all()

    fresh_abuse = (
        await db.execute(
            select(
                PromoRedemption.id,
                PromoCode.code,
                User.id,
                User.email,
                User.created_at,
                PromoRedemption.created_at,
            )
            .join(PromoCode, PromoCode.id == PromoRedemption.promo_code_id)
            .join(User, User.id == PromoRedemption.user_id)
            .where(
                PromoRedemption.created_at >= since,
                PromoCode.segment != "new_users",
                User.created_at.is_not(None),
                PromoRedemption.created_at - User.created_at < timedelta(hours=2),
            )
            .order_by(PromoRedemption.created_at.desc())
            .limit(20)
        )
    ).all()

    velocity_flag = last_24h >= 50

    return {
        "days": days,
        "summary": {
            "codes_total": codes_total,
            "codes_live": codes_live,
            "codes_paused": codes_paused,
            "uses_all_time": uses_all_time,
            "redemptions_window": int(redemptions or 0),
            "unique_users_window": int(unique_users or 0),
            "discount_sum_window": float(discount_sum or 0),
            "redemptions_24h": last_24h,
        },
        "by_type": [
            {"code_type": t or "standard", "codes": int(c or 0), "uses": int(u or 0)}
            for t, c, u in by_type
        ],
        "top_codes": [
            {
                "id": r.id,
                "code": r.code,
                "code_type": r.code_type,
                "variant": r.variant,
                "campaign_key": r.campaign_key,
                "used_count": r.used_count,
                "max_uses": r.max_uses,
                "is_paused": r.is_paused,
                "is_active": r.is_active,
                "window_uses": int(r.window_uses or 0),
                "window_discount": float(r.window_discount or 0),
            }
            for r in top_rows
        ],
        "ab_campaigns": [
            {"campaign_key": k, "variants": v} for k, v in campaigns.items()
        ],
        "abuse": {
            "velocity_alert": velocity_flag,
            "multi_redeem_users": [
                {"user_id": uid, "email": email, "count": int(n)}
                for uid, email, n in multi_user
            ],
            "fresh_account_redeems": [
                {
                    "redemption_id": rid,
                    "code": code,
                    "user_id": uid,
                    "email": email,
                    "user_created_at": uc.isoformat() if uc else None,
                    "redeemed_at": rc.isoformat() if rc else None,
                }
                for rid, code, uid, email, uc, rc in fresh_abuse
            ],
        },
    }
