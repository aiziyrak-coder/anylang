"""Business reviews: sentiment/toxic, fake IP, hide, company reply, stats."""

from __future__ import annotations

import re
from datetime import UTC, datetime, timedelta
from decimal import Decimal
from typing import Any, Literal

from sqlalchemy import and_, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.errors import AppError
from app.core.pagination import normalize_page
from app.models.business_review import BusinessReview
from app.models.user import AdminUser, BusinessProfile, User
from app.schemas.business_review import BusinessReviewCreateIn
from app.services.admin_ops import write_audit

_TOXIC = [
    r"\b(idiot|stupid|scam|fraud|лох|мраз|гандон|сука|блять|jinn|ahmoq|firibgar)\b",
    r"(kill\s*yourself|die\s*scammer)",
    r"[\U0001F4A9]{3,}",
]

_POSITIVE = [
    r"\b(excellent|great|amazing|reliable|tavsiya|аъло|отличн|super|professional)\b",
    r"\b(tez|sifatli|ishonchli|recommend)\b",
]

_NEGATIVE = [
    r"\b(terrible|awful|worst|kechik|yomon|ужас|обман|delay|slow)\b",
    r"\b(never\s*again|do\s*not\s*buy|sotib\s*olmang)\b",
]


def score_review_text(*, text: str, rating: int) -> dict[str, Any]:
    """Helper sentiment / toxic flags (admin final)."""
    blob = (text or "").strip().lower()
    reasons: list[str] = []

    toxic = 0.05
    if _hit(blob, _TOXIC):
        toxic = 0.9
        reasons.append("toxic_keywords")
    if re.search(r"(.)\1{7,}", blob):
        toxic = max(toxic, 0.55)
        reasons.append("spammy_chars")

    pos = 0.2 if _hit(blob, _POSITIVE) else 0.0
    neg = 0.2 if _hit(blob, _NEGATIVE) else 0.0
    if rating >= 4:
        pos += 0.35
    elif rating <= 2:
        neg += 0.45

    if pos > neg + 0.15:
        sentiment = "positive"
    elif neg > pos + 0.15:
        sentiment = "negative"
    else:
        sentiment = "neutral"

    if toxic >= 0.7:
        sentiment = "toxic" if sentiment != "positive" else sentiment

    return {
        "sentiment": sentiment,
        "toxic": round(toxic, 3),
        "is_toxic": toxic >= 0.7,
        "positive": round(min(1.0, pos), 3),
        "negative": round(min(1.0, neg), 3),
        "reasons": reasons,
        "source": "rules",
        "scored_at": datetime.now(UTC).isoformat(),
    }


def _hit(text: str, patterns: list[str]) -> bool:
    for p in patterns:
        try:
            if re.search(p, text, flags=re.IGNORECASE):
                return True
        except re.error:
            continue
    return False


def _author_name(user: User) -> str:
    biz = user.business
    if biz is not None and (biz.company_name or "").strip():
        return biz.company_name.strip()
    return (user.full_name or "").strip() or f"User #{user.id}"


def _author_avatar(user: User) -> str | None:
    if user.avatar_url:
        return user.avatar_url
    if user.business is not None and user.business.logo_url:
        return user.business.logo_url
    return None


def serialize_review(
    review: BusinessReview,
    *,
    author: User | None = None,
    business_user: User | None = None,
    include_moderation_note: bool = False,
    include_admin_flags: bool = False,
) -> dict:
    author = author or review.author
    business_user = business_user or getattr(review, "business_user", None)
    company = None
    if business_user is not None and business_user.business is not None:
        company = (business_user.business.company_name or "").strip() or None
    note = ""
    if include_moderation_note or review.status == "rejected":
        note = review.moderation_note or ""
    ai = dict(review.ai_flags or {})
    out: dict[str, Any] = {
        "id": review.id,
        "business_user_id": review.business_user_id,
        "author_id": review.author_id,
        "author_name": _author_name(author) if author is not None else "",
        "author_avatar_url": _author_avatar(author) if author is not None else None,
        "rating": int(review.rating),
        "text": review.text or "",
        "status": review.status,
        "moderation_note": note if (include_moderation_note or review.status == "rejected") else "",
        "created_at": review.created_at,
        "moderated_at": review.moderated_at,
        "company_name": company,
        "company_reply": (review.company_reply or "").strip(),
        "company_replied_at": review.company_replied_at,
        "is_hidden": review.hidden_at is not None,
    }
    if include_admin_flags:
        out.update(
            {
                "client_ip": review.client_ip,
                "ai_flags": ai,
                "sentiment": ai.get("sentiment") or "neutral",
                "toxic": float(ai.get("toxic") or 0),
                "is_toxic": bool(ai.get("is_toxic")),
                "fake_flag": bool(review.fake_flag),
                "fake_signals": dict(review.fake_signals or {}),
                "hidden_at": review.hidden_at,
                "hidden_by": review.hidden_by,
                "hidden_reason": review.hidden_reason or "",
            }
        )
    return out


async def _require_business_target(db: AsyncSession, business_user_id: int) -> User:
    result = await db.execute(
        select(User)
        .where(User.id == business_user_id)
        .options(
            selectinload(User.business),
            selectinload(User.subscription),
        )
    )
    user = result.scalar_one_or_none()
    if user is None or user.deleted_at is not None:
        raise AppError(message="Kompaniya topilmadi", error_code="USER_NOT_FOUND", status_code=404)
    if not user.is_business or user.business is None:
        raise AppError(
            message="Faqat biznes kompaniyaga otziv qoldirish mumkin",
            error_code="NOT_A_BUSINESS",
            status_code=400,
        )
    return user


def _visible_approved() -> Any:
    return and_(
        BusinessReview.status == "approved",
        BusinessReview.hidden_at.is_(None),
    )


async def refresh_business_rating(db: AsyncSession, business_user_id: int) -> None:
    biz = (
        await db.execute(
            select(BusinessProfile).where(BusinessProfile.user_id == business_user_id)
        )
    ).scalar_one_or_none()
    if biz is None:
        return
    row = (
        await db.execute(
            select(
                func.coalesce(func.avg(BusinessReview.rating), 0),
                func.count(BusinessReview.id),
            ).where(
                BusinessReview.business_user_id == business_user_id,
                _visible_approved(),
            )
        )
    ).one()
    avg_val, count = row[0], int(row[1] or 0)
    if count <= 0:
        biz.rating = None
        biz.reviews_count = 0
    else:
        biz.rating = Decimal(str(round(float(avg_val), 2)))
        biz.reviews_count = count
    await db.flush()


async def detect_fake_same_ip_day(
    db: AsyncSession,
    *,
    client_ip: str | None,
    exclude_review_id: int | None = None,
) -> dict[str, Any]:
    """Fake signal: bir IP dan bir kunda bir nechta otziv."""
    if not client_ip or client_ip in {"127.0.0.1", "::1", "unknown"}:
        return {"fake_flag": False, "same_ip_same_day": 0}

    now = datetime.now(UTC)
    day_start = now.replace(hour=0, minute=0, second=0, microsecond=0)
    day_end = day_start + timedelta(days=1)

    q = select(func.count()).select_from(BusinessReview).where(
        BusinessReview.client_ip == client_ip,
        BusinessReview.created_at >= day_start,
        BusinessReview.created_at < day_end,
    )
    if exclude_review_id is not None:
        q = q.where(BusinessReview.id != exclude_review_id)
    count = int((await db.execute(q)).scalar() or 0)
    # count = other reviews; total with this one = count + 1
    total = count + 1
    fake = total >= 2
    return {
        "fake_flag": fake,
        "same_ip_same_day": total,
        "client_ip": client_ip,
        "day": day_start.date().isoformat(),
    }


async def upsert_review(
    db: AsyncSession,
    *,
    author: User,
    business_user_id: int,
    payload: BusinessReviewCreateIn,
    client_ip: str | None = None,
) -> dict:
    if author.id == business_user_id:
        raise AppError(
            message="O‘z kompaniyangizga otziv qoldira olmaysiz",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )
    await _require_business_target(db, business_user_id)

    text = (payload.text or "").strip()
    if len(text) < 3:
        raise AppError(
            message="Otziv matni kamida 3 belgi bo‘lishi kerak",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )

    existing = (
        await db.execute(
            select(BusinessReview)
            .where(
                BusinessReview.business_user_id == business_user_id,
                BusinessReview.author_id == author.id,
            )
            .options(
                selectinload(BusinessReview.author).selectinload(User.business),
                selectinload(BusinessReview.business_user).selectinload(User.business),
            )
        )
    ).scalar_one_or_none()

    was_approved = existing is not None and existing.status == "approved"
    ai = score_review_text(text=text, rating=payload.rating)

    if existing is None:
        review = BusinessReview(
            business_user_id=business_user_id,
            author_id=author.id,
            rating=payload.rating,
            text=text[:1000],
            status="pending",
            moderation_note="",
            client_ip=(client_ip or None),
            ai_flags=ai,
            company_reply="",
            company_replied_at=None,
        )
        db.add(review)
        await db.flush()
        signals = await detect_fake_same_ip_day(
            db, client_ip=client_ip, exclude_review_id=review.id
        )
        review.fake_flag = bool(signals.get("fake_flag"))
        review.fake_signals = signals
    else:
        review = existing
        review.rating = payload.rating
        review.text = text[:1000]
        review.status = "pending"
        review.moderation_note = ""
        review.moderated_at = None
        review.moderated_by = None
        review.client_ip = client_ip or review.client_ip
        review.ai_flags = ai
        review.hidden_at = None
        review.hidden_by = None
        review.hidden_reason = ""
        review.company_reply = ""
        review.company_replied_at = None
        await db.flush()
        signals = await detect_fake_same_ip_day(
            db, client_ip=review.client_ip, exclude_review_id=review.id
        )
        review.fake_flag = bool(signals.get("fake_flag"))
        review.fake_signals = signals

    await db.flush()
    if was_approved:
        await refresh_business_rating(db, business_user_id)

    result = await db.execute(
        select(BusinessReview)
        .where(BusinessReview.id == review.id)
        .options(
            selectinload(BusinessReview.author).selectinload(User.business),
            selectinload(BusinessReview.business_user).selectinload(User.business),
        )
    )
    review = result.scalar_one()
    return serialize_review(review, include_moderation_note=True)


async def list_reviews(
    db: AsyncSession,
    *,
    business_user_id: int,
    viewer: User | None,
    page: int | None = None,
    limit: int | None = None,
) -> dict:
    await _require_business_target(db, business_user_id)
    params = normalize_page(page, limit, default_size=20, max_size=50)

    base = select(BusinessReview).where(
        BusinessReview.business_user_id == business_user_id,
        _visible_approved(),
    )
    total = int(
        (
            await db.execute(
                select(func.count()).select_from(base.order_by(None).subquery())
            )
        ).scalar()
        or 0
    )
    rows = list(
        (
            await db.execute(
                base.options(
                    selectinload(BusinessReview.author).selectinload(User.business),
                    selectinload(BusinessReview.business_user).selectinload(User.business),
                )
                .order_by(BusinessReview.created_at.desc())
                .offset(params.offset)
                .limit(params.page_size)
            )
        )
        .scalars()
        .all()
    )

    biz = (
        await db.execute(
            select(BusinessProfile).where(BusinessProfile.user_id == business_user_id)
        )
    ).scalar_one_or_none()
    avg = float(biz.rating) if biz is not None and biz.rating is not None else None
    count = int(biz.reviews_count or 0) if biz is not None else 0

    dist = await rating_distribution(db, business_user_id=business_user_id)

    my_review = None
    if viewer is not None and viewer.id != business_user_id:
        mine = (
            await db.execute(
                select(BusinessReview)
                .where(
                    BusinessReview.business_user_id == business_user_id,
                    BusinessReview.author_id == viewer.id,
                )
                .options(
                    selectinload(BusinessReview.author).selectinload(User.business),
                    selectinload(BusinessReview.business_user).selectinload(User.business),
                )
            )
        ).scalar_one_or_none()
        if mine is not None:
            my_review = serialize_review(mine, include_moderation_note=True)

    return {
        "items": [serialize_review(r) for r in rows],
        "page": params.page,
        "limit": params.page_size,
        "total": total,
        "has_more": params.offset + len(rows) < total,
        "average_rating": avg,
        "reviews_count": count,
        "rating_distribution": dist,
        "my_review": my_review,
    }


async def rating_distribution(
    db: AsyncSession,
    *,
    business_user_id: int | None = None,
) -> dict[str, Any]:
    """Approved + not hidden: stars 1..5 counts (company yoki umumiy)."""
    q = (
        select(BusinessReview.rating, func.count())
        .where(_visible_approved())
        .group_by(BusinessReview.rating)
    )
    if business_user_id is not None:
        q = q.where(BusinessReview.business_user_id == business_user_id)
    rows = (await db.execute(q)).all()
    buckets = {str(i): 0 for i in range(1, 6)}
    total = 0
    for rating, cnt in rows:
        key = str(int(rating))
        if key in buckets:
            buckets[key] = int(cnt or 0)
            total += int(cnt or 0)
    return {"buckets": buckets, "total": total}


async def list_admin_reviews(
    db: AsyncSession,
    *,
    status: str | None = "pending",
    q: str | None = None,
    page: int | None = None,
    limit: int | None = None,
    fake_only: bool = False,
    toxic_only: bool = False,
    business_user_id: int | None = None,
) -> dict:
    params = normalize_page(page, limit, default_size=50, max_size=100)
    query = select(BusinessReview).options(
        selectinload(BusinessReview.author).selectinload(User.business),
        selectinload(BusinessReview.business_user).selectinload(User.business),
    )
    st = (status or "").strip().lower()
    if st == "hidden":
        query = query.where(BusinessReview.hidden_at.is_not(None))
    elif st in {"pending", "approved", "rejected"}:
        query = query.where(BusinessReview.status == st)
        if st == "approved":
            query = query.where(BusinessReview.hidden_at.is_(None))
    # "all" / empty → no status filter

    if business_user_id is not None:
        query = query.where(BusinessReview.business_user_id == business_user_id)
    if fake_only:
        query = query.where(BusinessReview.fake_flag.is_(True))
    if toxic_only:
        query = query.where(BusinessReview.ai_flags.contains({"is_toxic": True}))

    term = (q or "").strip()
    if term:
        like = f"%{term}%"
        query = (
            query.join(User, User.id == BusinessReview.business_user_id)
            .outerjoin(BusinessProfile, BusinessProfile.user_id == User.id)
            .where(
                or_(
                    BusinessProfile.company_name.ilike(like),
                    User.full_name.ilike(like),
                    BusinessReview.text.ilike(like),
                    BusinessReview.client_ip.ilike(like),
                )
            )
        )
    total = int(
        (
            await db.execute(
                select(func.count()).select_from(query.order_by(None).subquery())
            )
        ).scalar()
        or 0
    )
    rows = list(
        (
            await db.execute(
                query.order_by(
                    BusinessReview.fake_flag.desc(),
                    BusinessReview.created_at.desc(),
                )
                .offset(params.offset)
                .limit(params.page_size)
            )
        )
        .scalars()
        .all()
    )
    return {
        "items": [
            serialize_review(r, include_moderation_note=True, include_admin_flags=True)
            for r in rows
        ],
        "page": params.page,
        "limit": params.page_size,
        "total": total,
        "has_more": params.offset + len(rows) < total,
    }


async def admin_review_stats(
    db: AsyncSession,
    *,
    business_user_id: int | None = None,
) -> dict[str, Any]:
    dist = await rating_distribution(db, business_user_id=business_user_id)

    pending = int(
        (
            await db.execute(
                select(func.count())
                .select_from(BusinessReview)
                .where(
                    BusinessReview.status == "pending",
                    *(
                        [BusinessReview.business_user_id == business_user_id]
                        if business_user_id is not None
                        else []
                    ),
                )
            )
        ).scalar()
        or 0
    )
    fake = int(
        (
            await db.execute(
                select(func.count())
                .select_from(BusinessReview)
                .where(
                    BusinessReview.fake_flag.is_(True),
                    BusinessReview.status == "pending",
                    *(
                        [BusinessReview.business_user_id == business_user_id]
                        if business_user_id is not None
                        else []
                    ),
                )
            )
        ).scalar()
        or 0
    )
    hidden = int(
        (
            await db.execute(
                select(func.count())
                .select_from(BusinessReview)
                .where(
                    BusinessReview.hidden_at.is_not(None),
                    *(
                        [BusinessReview.business_user_id == business_user_id]
                        if business_user_id is not None
                        else []
                    ),
                )
            )
        ).scalar()
        or 0
    )

    # Top companies by review volume (for chart picker)
    companies: list[dict[str, Any]] = []
    if business_user_id is None:
        top_q = (
            select(
                BusinessReview.business_user_id,
                func.count().label("cnt"),
                BusinessProfile.company_name,
            )
            .outerjoin(
                BusinessProfile,
                BusinessProfile.user_id == BusinessReview.business_user_id,
            )
            .where(_visible_approved())
            .group_by(BusinessReview.business_user_id, BusinessProfile.company_name)
            .order_by(func.count().desc())
            .limit(20)
        )
        for uid, cnt, name in (await db.execute(top_q)).all():
            companies.append(
                {
                    "business_user_id": int(uid),
                    "company_name": (name or "").strip() or f"User #{uid}",
                    "reviews_count": int(cnt or 0),
                }
            )

    company_name = None
    if business_user_id is not None:
        biz = (
            await db.execute(
                select(BusinessProfile).where(BusinessProfile.user_id == business_user_id)
            )
        ).scalar_one_or_none()
        company_name = (biz.company_name if biz else None) or f"User #{business_user_id}"

    return {
        "business_user_id": business_user_id,
        "company_name": company_name,
        "rating_distribution": dist,
        "pending": pending,
        "fake_pending": fake,
        "hidden": hidden,
        "companies": companies,
    }


async def moderate_review(
    db: AsyncSession,
    *,
    review_id: int,
    admin_id: int,
    approve: bool,
    admin_note: str | None = None,
) -> dict:
    result = await db.execute(
        select(BusinessReview)
        .where(BusinessReview.id == review_id)
        .options(
            selectinload(BusinessReview.author).selectinload(User.business),
            selectinload(BusinessReview.business_user).selectinload(User.business),
        )
    )
    review = result.scalar_one_or_none()
    if review is None:
        raise AppError(
            message="Otziv topilmadi",
            error_code="REVIEW_NOT_FOUND",
            status_code=404,
        )

    note = (admin_note or "").strip()
    now = datetime.now(UTC)
    if approve:
        review.status = "approved"
        review.moderation_note = ""
        review.moderated_at = now
        review.moderated_by = admin_id
        # unhide on re-approve
        review.hidden_at = None
        review.hidden_by = None
        review.hidden_reason = ""
    else:
        if len(note) < 3:
            raise AppError(
                message="Rad etish sababi majburiy",
                error_code="VALIDATION_ERROR",
                status_code=400,
            )
        review.status = "rejected"
        review.moderation_note = note[:500]
        review.moderated_at = now
        review.moderated_by = admin_id
        review.company_reply = ""
        review.company_replied_at = None

    await db.flush()
    await refresh_business_rating(db, review.business_user_id)
    return serialize_review(
        review, include_moderation_note=True, include_admin_flags=True
    )


async def hide_review(
    db: AsyncSession,
    *,
    review_id: int,
    admin_id: int,
    reason: str | None = None,
    hide: bool = True,
) -> dict:
    """Soft hide — hard delete emas."""
    result = await db.execute(
        select(BusinessReview)
        .where(BusinessReview.id == review_id)
        .options(
            selectinload(BusinessReview.author).selectinload(User.business),
            selectinload(BusinessReview.business_user).selectinload(User.business),
        )
    )
    review = result.scalar_one_or_none()
    if review is None:
        raise AppError(
            message="Otziv topilmadi",
            error_code="REVIEW_NOT_FOUND",
            status_code=404,
        )
    if hide:
        review.hidden_at = datetime.now(UTC)
        review.hidden_by = admin_id
        review.hidden_reason = (reason or "").strip()[:500]
    else:
        review.hidden_at = None
        review.hidden_by = None
        review.hidden_reason = ""
    await db.flush()
    await refresh_business_rating(db, review.business_user_id)
    return serialize_review(
        review, include_moderation_note=True, include_admin_flags=True
    )


BulkAction = Literal["approve", "reject", "hide", "unhide"]


async def bulk_moderate(
    db: AsyncSession,
    *,
    review_ids: list[int],
    action: BulkAction,
    admin: AdminUser,
    admin_note: str | None = None,
    ip: str | None = None,
) -> dict[str, Any]:
    if not review_ids:
        raise AppError(
            message="review_ids required",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )
    ids = list(dict.fromkeys(review_ids))[:50]
    if action == "reject" and len((admin_note or "").strip()) < 3:
        raise AppError(
            message="Rad etish sababi majburiy",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )

    ok: list[int] = []
    errors: list[dict[str, Any]] = []
    for rid in ids:
        try:
            if action in {"approve", "reject"}:
                await moderate_review(
                    db,
                    review_id=rid,
                    admin_id=admin.id,
                    approve=action == "approve",
                    admin_note=admin_note,
                )
            elif action == "hide":
                await hide_review(
                    db,
                    review_id=rid,
                    admin_id=admin.id,
                    reason=admin_note,
                    hide=True,
                )
            else:
                await hide_review(
                    db,
                    review_id=rid,
                    admin_id=admin.id,
                    hide=False,
                )
            ok.append(rid)
        except AppError as exc:
            errors.append({"id": rid, "error": exc.message, "code": exc.error_code})
        except Exception as exc:
            errors.append({"id": rid, "error": str(exc)[:200], "code": "ERROR"})

    await write_audit(
        db,
        admin=admin,
        action=f"business_review.bulk_{action}",
        target_type="business_review",
        target_id="bulk",
        meta={"ok": ok, "errors": len(errors), "action": action},
        ip=ip,
    )
    return {"ok": ok, "errors": errors, "action": action}


async def company_reply_to_review(
    db: AsyncSession,
    *,
    business_owner: User,
    review_id: int,
    reply_text: str,
) -> dict:
    """Kompaniya javobi — faqat moderatsiyadan (approved) keyin."""
    text = (reply_text or "").strip()
    if len(text) < 2:
        raise AppError(
            message="Javob matni kamida 2 belgi bo‘lishi kerak",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )
    result = await db.execute(
        select(BusinessReview)
        .where(BusinessReview.id == review_id)
        .options(
            selectinload(BusinessReview.author).selectinload(User.business),
            selectinload(BusinessReview.business_user).selectinload(User.business),
        )
    )
    review = result.scalar_one_or_none()
    if review is None:
        raise AppError(
            message="Otziv topilmadi",
            error_code="REVIEW_NOT_FOUND",
            status_code=404,
        )
    if review.business_user_id != business_owner.id:
        raise AppError(
            message="Faqat o‘z kompaniyangiz otziviga javob bera olasiz",
            error_code="FORBIDDEN",
            status_code=403,
        )
    if review.status != "approved" or review.hidden_at is not None:
        raise AppError(
            message="Javob faqat tasdiqlangan (moderatsiyadan o‘tgan) otzivga yoziladi",
            error_code="REVIEW_NOT_APPROVED",
            status_code=400,
        )

    review.company_reply = text[:1000]
    review.company_replied_at = datetime.now(UTC)
    await db.flush()
    return serialize_review(review)
