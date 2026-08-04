from __future__ import annotations

import re
from datetime import UTC, datetime, timedelta

from sqlalchemy import func, or_, select, tuple_
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.errors import AppError
from app.core.pagination import PageParams, paginate_items
from app.models.chat import Friendship, LiveSession, LiveTurn
from app.models.product import Product, ProductFavorite, ProductView
from app.models.user import BusinessProfile, ProfileView, Subscription, User
from app.services import trust_score as trust_score_service
from app.services import scam_detection as scam_detection_service
from app.services import verification as verification_service
from app.services.business_card import business_card_url
from app.services.factory_verification import build_factory_verification


def _user_spoken_languages(user: User) -> list[str]:
    codes: list[str] = []
    for raw in (user.native_language, user.app_language):
        if not raw:
            continue
        code = str(raw).strip().lower().replace("-", "_").split("_", 1)[0]
        if len(code) >= 2 and code not in codes:
            codes.append(code)
    return codes


def _business_completeness(business: BusinessProfile, *, has_listing: bool) -> int:
    score = 0
    if business.logo_url:
        score += 10
    if business.company_name.strip():
        score += 10
    if business.country:
        score += 10
    if business.business_role:
        score += 10
    if business.website:
        score += 10
    if business.description and len(business.description) >= 20:
        score += 10
    if business.founded_year is not None:
        score += 10
    if business.certificates:
        score += 5
    if business.factory_images:
        score += 5
    if business.export_countries:
        score += 5
    if business.moq or business.incoterms or business.payment_methods:
        score += 5
    if business.seo_text or business.keywords or business.description_i18n:
        score += 5
    if business.audit_report_url:
        score += 5
    if business.factory_verified or business.inspection_passed:
        score += 5
    if has_listing:
        score += 10
    return min(score, 100)


async def _business_stats(
    db: AsyncSession,
    user_id: int,
    business: BusinessProfile | None = None,
) -> dict:
    listings_result = await db.execute(
        select(func.count())
        .select_from(Product)
        .where(Product.seller_id == user_id, Product.status == "published")
    )
    listings_count = int(listings_result.scalar() or 0)

    views_result = await db.execute(
        select(func.coalesce(func.sum(Product.views_count), 0)).where(Product.seller_id == user_id)
    )
    total_views = int(views_result.scalar() or 0)

    export_countries: list[str] = []
    rating = None
    reviews_count = 0
    founded_year = None
    export_years = None
    if business is not None:
        export_countries = [
            str(c).upper()
            for c in (business.export_countries or [])
            if str(c).strip()
        ]
        if business.rating is not None:
            rating = float(business.rating)
        reviews_count = int(business.reviews_count or 0)
        founded_year = business.founded_year
        if founded_year is not None and 1800 <= int(founded_year) <= 2100:
            export_years = max(0, datetime.now(UTC).year - int(founded_year))

    return {
        "listings_count": listings_count,
        "total_views": total_views,
        "rating": rating,
        "reviews_count": reviews_count,
        "countries_count": len(export_countries),
        "export_countries": export_countries,
        "founded_year": founded_year,
        "export_years": export_years,
    }


def _serialize_subscription(subscription: Subscription) -> dict:
    return {
        "plan": subscription.plan,
        "billing_cycle": subscription.billing_cycle,
        "started_at": subscription.started_at,
        "expires_at": subscription.expires_at,
        "auto_renew": subscription.auto_renew,
        "is_active": subscription.is_active,
        "source": subscription.source,
    }


def max_local_accounts_for(*, is_business: bool, extra_account_slots: int) -> int:
    """Free=3; business=5 + purchased extras (hard cap 10)."""
    if not is_business:
        return 3
    extras = max(0, int(extra_account_slots or 0))
    return min(10, 5 + extras)


def max_purchasable_account_slots(*, is_business: bool, extra_account_slots: int) -> int:
    """Faqat biznes: 5 dan 10 gacha — qolgan slotlar."""
    if not is_business:
        return 0
    extras = max(0, int(extra_account_slots or 0))
    return max(0, 10 - (5 + extras))


async def serialize_user(
    user: User,
    db: AsyncSession,
    redis=None,
) -> dict:
    """Build a dict matching UserOut / TZ section 4.1."""
    loaded = await load_user_for_response(db, user.id)
    if loaded is not None:
        user = loaded

    subscription = user.subscription
    if subscription is None:
        subscription = await ensure_basic_subscription(user, db)
        loaded = await load_user_for_response(db, user.id)
        if loaded is not None:
            user = loaded
            subscription = user.subscription or subscription

    is_business = bool(subscription.plan == "business" and subscription.is_active)

    business_payload: dict | None = None
    if is_business and user.business is not None:
        stats = await _business_stats(db, user.id, user.business)
        has_listing = stats["listings_count"] > 0
        trust = await trust_score_service.compute_trust_score(db, user, user.business)
        scam = await scam_detection_service.compute_scam_risk(
            db,
            user,
            user.business,
            redis=redis,
            locale=user.app_language or "uz",
            trust=trust,
        )
        business_payload = {
            "company_name": user.business.company_name,
            "logo_url": user.business.logo_url,
            "country": user.business.country,
            "business_role": user.business.business_role,
            "website": user.business.website,
            "bio": (user.business.bio or "").strip() or None,
            "description": user.business.description,
            "seo_text": user.business.seo_text,
            "keywords": list(user.business.keywords or []),
            "description_i18n": dict(user.business.description_i18n or {}),
            "founded_year": user.business.founded_year,
            "certificates": list(user.business.certificates or []),
            "export_countries": list(stats.get("export_countries") or []),
            "moq": user.business.moq,
            "production_capacity": user.business.production_capacity,
            "lead_time": user.business.lead_time,
            "incoterms": list(user.business.incoterms or []),
            "payment_methods": list(user.business.payment_methods or []),
            "successful_deals": int(user.business.successful_deals or 0),
            "complaints_count": int(user.business.complaints_count or 0),
            "documents_verified": bool(
                user.business.documents_verified or user.verified_badge
            ),
            "verification_status": await verification_service.verification_status_summary(
                db, user, user.business
            ),
            "factory_verified": bool(
                build_factory_verification(user.business, user=user)["factory_verified"]
            ),
            "inspection_passed": bool(user.business.inspection_passed),
            "audit_report_url": (user.business.audit_report_url or "").strip() or None,
            "factory_verification": build_factory_verification(user.business, user=user),
            "trust_score": trust,
            "scam_risk": scam,
            "factory_images": [
                {"id": img.id, "url": img.url} for img in (user.business.factory_images or [])
            ],
            "completeness": _business_completeness(user.business, has_listing=has_listing),
            "stats": stats,
        }

    return {
        "id": user.id,
        "full_name": user.full_name,
        "number": user.number,
        "email": user.email,
        "birth_date": user.birth_date,
        "gender": user.gender,
        "country": (user.country or "").strip().upper() or None,
        "avatar_url": user.avatar_url,
        "app_language": user.app_language,
        "native_language": user.native_language,
        "spoken_languages": _user_spoken_languages(user),
        "translation_domain": getattr(user, "translation_domain", None) or "general",
        "is_verified": user.is_verified,
        "verified_badge": user.verified_badge,
        "is_active": user.is_active,
        "profile_completed": user.profile_completed,
        "created_at": user.created_at,
        "last_number_change_at": user.last_number_change_at,
        "subscription": _serialize_subscription(subscription),
        "is_business": is_business,
        "business": business_payload,
        "networking": (networking := await _networking_for(db, user)),
        "profile_insights": await _profile_insights(db, user, networking=networking),
        "extra_account_slots": int(getattr(user, "extra_account_slots", 0) or 0),
        "max_local_accounts": max_local_accounts_for(
            is_business=is_business,
            extra_account_slots=int(getattr(user, "extra_account_slots", 0) or 0),
        ),
    }


async def _networking_for(db: AsyncSession, user: User) -> dict:
    from app.services import networking_score as networking_score_service

    return await networking_score_service.build_networking_score(db, user)


async def _profile_insights(
    db: AsyncSession,
    user: User,
    *,
    networking: dict | None = None,
) -> dict:
    """Profil sahifasi uchun statistika, analitika va yutuqlar."""
    uid = user.id
    now = datetime.now(UTC)
    since = now - timedelta(days=7)
    prev_since = now - timedelta(days=14)
    day_keys = [(now - timedelta(days=i)).strftime("%Y-%m-%d") for i in range(6, -1, -1)]
    prev_day_keys = [
        (now - timedelta(days=i)).strftime("%Y-%m-%d") for i in range(13, 6, -1)
    ]
    net = networking if networking is not None else await _networking_for(db, user)

    followers = int(
        (
            await db.execute(
                select(func.count())
                .select_from(Friendship)
                .where(
                    Friendship.status == "accepted",
                    or_(
                        Friendship.user_low_id == uid,
                        Friendship.user_high_id == uid,
                    ),
                )
            )
        ).scalar()
        or 0
    )

    likes = int(
        (
            await db.execute(
                select(func.count())
                .select_from(ProductFavorite)
                .join(Product, Product.id == ProductFavorite.product_id)
                .where(Product.seller_id == uid)
            )
        ).scalar()
        or 0
    )

    translations_count = int(
        (
            await db.execute(
                select(func.count())
                .select_from(LiveTurn)
                .join(LiveSession, LiveSession.id == LiveTurn.session_id)
                .where(
                    LiveSession.user_id == uid,
                    LiveTurn.text_translated.is_not(None),
                    LiveTurn.text_translated != "",
                )
            )
        ).scalar()
        or 0
    )

    lang_rows = (
        await db.execute(
            select(LiveTurn.source_language, LiveTurn.target_language)
            .join(LiveSession, LiveSession.id == LiveTurn.session_id)
            .where(LiveSession.user_id == uid)
            .limit(2000)
        )
    ).all()
    languages_used: set[str] = set()
    for src, tgt in lang_rows:
        for code in (src, tgt):
            c = str(code or "").strip().lower().split("-", 1)[0]
            if len(c) >= 2:
                languages_used.add(c)
    for raw in (user.native_language, user.app_language):
        c = str(raw or "").strip().lower().replace("-", "_").split("_", 1)[0]
        if len(c) >= 2:
            languages_used.add(c)

    listings_count = int(
        (
            await db.execute(
                select(func.count())
                .select_from(Product)
                .where(Product.seller_id == uid, Product.status == "published")
            )
        ).scalar()
        or 0
    )

    total_views = int(
        (
            await db.execute(
                select(func.coalesce(func.sum(Product.views_count), 0)).where(
                    Product.seller_id == uid
                )
            )
        ).scalar()
        or 0
    )

    profile_visits_total = int(
        (
            await db.execute(
                select(func.count(ProfileView.id)).where(ProfileView.profile_user_id == uid)
            )
        ).scalar()
        or 0
    )

    profile_visits_7d = int(
        (
            await db.execute(
                select(func.count(ProfileView.id)).where(
                    ProfileView.profile_user_id == uid,
                    ProfileView.last_viewed_at >= since,
                )
            )
        ).scalar()
        or 0
    )

    listing_clicks_7d = int(
        (
            await db.execute(
                select(func.count())
                .select_from(ProductView)
                .join(Product, Product.id == ProductView.product_id)
                .where(
                    Product.seller_id == uid,
                    ProductView.day_bucket.in_(day_keys),
                )
            )
        ).scalar()
        or 0
    )

    profile_visits_prev = int(
        (
            await db.execute(
                select(func.count(ProfileView.id)).where(
                    ProfileView.profile_user_id == uid,
                    ProfileView.last_viewed_at >= prev_since,
                    ProfileView.last_viewed_at < since,
                )
            )
        ).scalar()
        or 0
    )

    listing_clicks_prev = int(
        (
            await db.execute(
                select(func.count())
                .select_from(ProductView)
                .join(Product, Product.id == ProductView.product_id)
                .where(
                    Product.seller_id == uid,
                    ProductView.day_bucket.in_(prev_day_keys),
                )
            )
        ).scalar()
        or 0
    )

    views_by_day_raw = (
        await db.execute(
            select(ProductView.day_bucket, func.count())
            .join(Product, Product.id == ProductView.product_id)
            .where(
                Product.seller_id == uid,
                ProductView.day_bucket.in_(day_keys),
            )
            .group_by(ProductView.day_bucket)
        )
    ).all()
    views_map = {str(d): int(n or 0) for d, n in views_by_day_raw}
    views_series = [{"day": d, "views": views_map.get(d, 0)} for d in day_keys]
    views_7d = sum(v["views"] for v in views_series)

    views_prev_raw = (
        await db.execute(
            select(func.count())
            .select_from(ProductView)
            .join(Product, Product.id == ProductView.product_id)
            .where(
                Product.seller_id == uid,
                ProductView.day_bucket.in_(prev_day_keys),
            )
        )
    ).scalar()
    views_prev = int(views_prev_raw or 0)

    conversion_pct = None
    if views_7d > 0:
        conversion_pct = round(100.0 * listing_clicks_7d / views_7d, 1)

    rating = None
    if user.business is not None and user.business.rating is not None:
        rating = float(user.business.rating)

    trust_pct = None
    if net.get("trust") is not None:
        trust_pct = int(net["trust"])
    elif user.business is not None:
        trust = await trust_score_service.compute_trust_score(db, user, user.business)
        if isinstance(trust, dict) and trust.get("score") is not None:
            trust_pct = int(trust["score"])

    return {
        "followers": followers,
        "likes": likes,
        "translations_count": translations_count,
        "languages_used": len(languages_used),
        "trust_percent": trust_pct,
        "listings_count": listings_count,
        "total_views": total_views,
        "rating": rating,
        "profile_visits_total": profile_visits_total,
        "analytics_7d": {
            "views": views_7d,
            "profile_visits": profile_visits_7d,
            "listing_clicks": listing_clicks_7d,
            "views_prev": views_prev,
            "profile_visits_prev": profile_visits_prev,
            "listing_clicks_prev": listing_clicks_prev,
            "conversion_pct": conversion_pct,
            "views_series": views_series,
        },
    }


async def ensure_basic_subscription(user: User, db: AsyncSession) -> Subscription:
    result = await db.execute(select(Subscription).where(Subscription.user_id == user.id))
    existing = result.scalar_one_or_none()
    if existing is not None:
        return existing

    subscription = Subscription(
        user_id=user.id,
        plan="basic",
        billing_cycle=None,
        started_at=None,
        expires_at=None,
        auto_renew=False,
        is_active=True,
        source="purchase",
    )
    db.add(subscription)
    await db.flush()
    return subscription


async def load_user_for_response(db: AsyncSession, user_id: int) -> User | None:
    result = await db.execute(
        select(User)
        .where(User.id == user_id)
        .options(
            selectinload(User.subscription),
            selectinload(User.business).selectinload(BusinessProfile.factory_images),
        )
    )
    return result.scalar_one_or_none()


def _normalize_number_query(query: str) -> str:
    return re.sub(r"[\s\-]", "", query)


async def _friendship_context(
    db: AsyncSession, viewer_id: int, target_id: int
) -> tuple[str, int | None, bool]:
    low_id, high_id = sorted((viewer_id, target_id))
    result = await db.execute(
        select(Friendship).where(
            Friendship.user_low_id == low_id,
            Friendship.user_high_id == high_id,
        )
    )
    friendship = result.scalar_one_or_none()
    return _friendship_tuple(viewer_id, friendship)


def _friendship_tuple(
    viewer_id: int, friendship: Friendship | None
) -> tuple[str, int | None, bool]:
    if friendship is None or friendship.status not in {"pending", "accepted"}:
        return "none", None, False
    if friendship.status == "accepted":
        return "accepted", friendship.id, False
    is_incoming = friendship.requester_id != viewer_id
    return "pending", friendship.id, is_incoming


async def _friendship_context_map(
    db: AsyncSession, viewer_id: int, target_ids: list[int]
) -> dict[int, tuple[str, int | None, bool]]:
    """Batch-load friendship status for many targets (avoids N+1 in search)."""
    out: dict[int, tuple[str, int | None, bool]] = {
        tid: ("none", None, False) for tid in target_ids
    }
    if not target_ids:
        return out
    lows_highs = [(min(viewer_id, tid), max(viewer_id, tid), tid) for tid in target_ids]
    pairs = {(lo, hi) for lo, hi, _ in lows_highs}
    result = await db.execute(
        select(Friendship).where(
            tuple_(Friendship.user_low_id, Friendship.user_high_id).in_(list(pairs))
        )
    )
    by_pair = {
        (f.user_low_id, f.user_high_id): f for f in result.scalars().all()
    }
    for lo, hi, tid in lows_highs:
        out[tid] = _friendship_tuple(viewer_id, by_pair.get((lo, hi)))
    return out


async def get_public_profile(
    db: AsyncSession,
    user_id: int,
    viewer: User | None = None,
    redis=None,
) -> dict:
    user = await load_user_for_response(db, user_id)
    if user is None or not user.is_active or user.deleted_at is not None:
        raise AppError(message="Foydalanuvchi topilmadi", error_code="USER_NOT_FOUND", status_code=404)

    is_business = user.is_business
    name = user.full_name
    avatar_url = user.avatar_url
    subtitle_role = user.native_language
    business_payload: dict | None = None

    if is_business and user.business is not None:
        business = user.business
        name = business.company_name or user.full_name
        avatar_url = business.logo_url or user.avatar_url
        subtitle_role = business.business_role or user.native_language
        stats = await _business_stats(db, user.id, business)
        has_listing = stats["listings_count"] > 0
        trust = await trust_score_service.compute_trust_score(db, user, business)
        locale = (viewer.app_language if viewer else None) or user.app_language or "uz"
        scam = await scam_detection_service.compute_scam_risk(
            db,
            user,
            business,
            redis=redis,
            locale=locale,
            trust=trust,
        )
        business_payload = {
            "business_role": business.business_role,
            "founded_year": business.founded_year,
            "website": business.website,
            "bio": (business.bio or "").strip() or None,
            "description": business.description,
            "seo_text": business.seo_text,
            "keywords": list(business.keywords or []),
            "description_i18n": dict(business.description_i18n or {}),
            "completeness": _business_completeness(business, has_listing=has_listing),
            "certificates": list(business.certificates or []),
            "export_countries": list(stats.get("export_countries") or []),
            "moq": business.moq,
            "production_capacity": business.production_capacity,
            "lead_time": business.lead_time,
            "incoterms": list(business.incoterms or []),
            "payment_methods": list(business.payment_methods or []),
            "successful_deals": int(business.successful_deals or 0),
            "complaints_count": int(business.complaints_count or 0),
            "documents_verified": bool(
                business.documents_verified or user.verified_badge
            ),
            "verification_status": await verification_service.verification_status_summary(
                db, user, business
            ),
            "factory_verified": bool(
                build_factory_verification(business, user=user)["factory_verified"]
            ),
            "inspection_passed": bool(business.inspection_passed),
            "audit_report_url": (business.audit_report_url or "").strip() or None,
            "factory_verification": build_factory_verification(business, user=user),
            "trust_score": trust,
            "scam_risk": scam,
            "factory_images": [
                {"id": img.id, "url": img.url} for img in (business.factory_images or [])
            ],
            "stats": {
                "listings_count": stats["listings_count"],
                "total_views": stats["total_views"],
                "rating": stats["rating"],
                "reviews_count": stats["reviews_count"],
                "countries_count": stats["countries_count"],
                "export_years": stats["export_years"],
            },
        }

    payload = {
        "id": user.id,
        "is_business": is_business,
        "name": name,
        "verified_badge": user.verified_badge,
        "country": (user.business.country if user.business and user.business.country else user.country)
        if is_business
        else user.country,
        "subtitle_role": subtitle_role or user.native_language,
        "number": user.number,
        "avatar_url": avatar_url,
        "business": business_payload,
        "business_card_url": business_card_url(user.id) if is_business else None,
        "friendship_status": "none",
        "friendship_request_id": None,
        "is_request_incoming": False,
    }
    if viewer is not None and viewer.id != user.id:
        status, request_id, is_incoming = await _friendship_context(db, viewer.id, user.id)
        payload["friendship_status"] = status
        payload["friendship_request_id"] = request_id
        payload["is_request_incoming"] = is_incoming
        try:
            from app.services import profile_views as profile_views_service

            await profile_views_service.record_profile_view(
                db,
                profile_user_id=user.id,
                viewer_user_id=viewer.id,
            )
        except Exception as exc:
            # Profil ochilishi view yozilishiga bog'liq emas.
            import logging

            logging.getLogger(__name__).warning(
                "record_profile_view failed profile=%s viewer=%s: %s",
                user.id,
                viewer.id,
                exc,
            )
    try:
        from app.services import networking_score as networking_score_service

        payload["networking"] = await networking_score_service.build_networking_score(
            db, user
        )
    except Exception:
        payload["networking"] = {"connections": 0, "countries": 0, "trust": None}
    return payload


async def search_users(
    db: AsyncSession,
    viewer: User,
    query: str,
    params: PageParams,
) -> dict:
    raw = (query or "").strip()
    digits = _normalize_number_query(raw)
    by_number = digits.isdigit() and len(digits) >= 3
    by_name = len(raw) >= 2 and not (digits.isdigit() and len(digits) < 3)

    if not by_number and not by_name:
        raise AppError(
            message="Kamida 2 ta belgi yoki 3 ta raqam kiriting",
            error_code="SEARCH_QUERY_TOO_SHORT",
            status_code=400,
        )

    name_clause = or_(
        User.full_name.ilike(f"%{raw}%"),
        BusinessProfile.company_name.ilike(f"%{raw}%"),
    )
    filters = [
        User.is_active.is_(True),
        User.deleted_at.is_(None),
        User.id != viewer.id,
    ]
    if by_number and by_name:
        # Raqam ham, ism/kompaniya ham — OR
        filters.append(or_(User.number.like(f"{digits}%"), name_clause))
    elif by_number:
        filters.append(User.number.like(f"{digits}%"))
    else:
        filters.append(name_clause)

    result = await db.execute(
        select(User)
        .outerjoin(BusinessProfile, BusinessProfile.user_id == User.id)
        .where(*filters)
        .options(
            selectinload(User.subscription),
            selectinload(User.business),
        )
        .order_by(User.full_name, User.number)
        .limit(200)
    )
    candidates = list(result.scalars().all())
    friendship_map = await _friendship_context_map(
        db, viewer.id, [u.id for u in candidates]
    )
    items: list[dict] = []
    for user in candidates:
        status, request_id, is_incoming = friendship_map.get(
            user.id, ("none", None, False)
        )
        is_business = user.is_business
        biz = user.business
        display_name = user.full_name
        avatar_url = user.avatar_url
        country = user.country
        business_role = None
        rating = None
        verified = bool(user.verified_badge)
        if is_business and biz is not None:
            if (biz.company_name or "").strip():
                display_name = biz.company_name.strip()
            if biz.logo_url:
                avatar_url = biz.logo_url
            if biz.country:
                country = str(biz.country).strip().upper() or country
            if biz.business_role:
                business_role = str(biz.business_role).strip() or None
            if biz.rating is not None:
                rating = float(biz.rating)
            if biz.documents_verified:
                verified = True
        elif country:
            country = str(country).strip().upper() or None
        spoken: list[str] = []
        for raw in (user.native_language, user.app_language):
            if not raw:
                continue
            code = str(raw).strip().lower().replace("-", "_").split("_", 1)[0]
            if len(code) >= 2 and code not in spoken:
                spoken.append(code)
        export: set[str] = set()
        if is_business and biz is not None:
            for c in biz.export_countries or []:
                cc = str(c).strip().upper()
                if len(cc) == 2:
                    export.add(cc)
        if country and len(str(country).strip()) == 2:
            export.add(str(country).strip().upper())
        items.append(
            {
                "id": user.id,
                "full_name": display_name,
                "number": user.number,
                "avatar_url": avatar_url,
                "is_online": False,
                "last_seen_at": None,
                "native_language": user.native_language,
                "country": country,
                "is_business": is_business,
                "verified_badge": verified,
                "company_name": display_name,
                "business_role": business_role,
                "rating": rating,
                "friendship_status": status,
                "friendship_request_id": request_id,
                "is_request_incoming": is_incoming,
                "app_language": user.app_language,
                "spoken_languages": spoken,
                "products_count": 0,
                "countries_count": len(export),
                "keywords": list(biz.keywords or [])[:24]
                if is_business and biz is not None and biz.keywords
                else [],
            }
        )

    page_items, total = paginate_items(items, params)
    if page_items:
        from app.models.product import Product

        ids = [int(it["id"]) for it in page_items]
        counts_result = await db.execute(
            select(Product.seller_id, func.count())
            .where(Product.seller_id.in_(ids), Product.status == "published")
            .group_by(Product.seller_id)
        )
        counts = {int(sid): int(cnt) for sid, cnt in counts_result.all()}
        for it in page_items:
            it["products_count"] = counts.get(int(it["id"]), 0)
    return {
        "items": page_items,
        "page": params.page,
        "limit": params.page_size,
        "total": total,
        "has_more": params.offset + len(page_items) < total,
    }
