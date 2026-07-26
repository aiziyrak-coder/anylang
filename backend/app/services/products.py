from __future__ import annotations

from datetime import UTC, datetime, timedelta
from decimal import Decimal
from io import BytesIO
from uuid import uuid4

from PIL import Image
from sqlalchemy import String, and_, case, cast, func, or_, select, update
from sqlalchemy.dialects.postgresql import insert as pg_insert
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.errors import AppError
from app.core.pagination import normalize_page
from app.integrations.storage import get_storage
from app.models.product import Product, ProductFavorite, ProductImage, ProductTopRequest, ProductView
from app.models.user import BusinessProfile, Subscription, User
from app.schemas.product import ProductCreateIn, ProductUpdateIn
from app.services.factory_verification import build_factory_verification, build_product_trust_badges
from app.services.business import _key_from_url

MAX_IMAGES_PER_PRODUCT = 10
MAX_IMAGE_BYTES = 5 * 1024 * 1024
ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}
MAX_VIDEO_BYTES = 25 * 1024 * 1024
ALLOWED_VIDEO_TYPES = {"video/mp4", "video/quicktime", "video/webm", "video/x-m4v"}
MAX_PENDING_TOP_REQUESTS = 3

PRODUCT_CATEGORIES: dict[str, dict[str, str]] = {
    "clothing_accessories": {
        "uz_UZ": "Kiyim & aksessuar",
        "ru_RU": "Одежда и аксессуары",
        "us_US": "Clothing & accessories",
    },
    "pottery": {"uz_UZ": "Kulolchilik", "ru_RU": "Керамика", "us_US": "Pottery"},
    "woodwork": {"uz_UZ": "Yog'och buyumlar", "ru_RU": "Изделия из дерева", "us_US": "Woodwork"},
    "jewelry": {"uz_UZ": "Taqinchoq", "ru_RU": "Украшения", "us_US": "Jewelry"},
    "other": {"uz_UZ": "Boshqa", "ru_RU": "Другое", "us_US": "Other"},
}

SUPPORTED_CURRENCIES = {"USD", "EUR", "RUB", "UZS"}

# Xaridorga tushunarli imkoniyatlar (tavsif emas).
PRODUCT_CAPABILITIES: frozenset[str] = frozenset(
    {
        "breathable",
        "export_quality",
        "oem_available",
        "odm_available",
        "private_label",
        "custom_logo",
        "sample_available",
        "ready_stock",
        "fast_delivery",
        "waterproof",
        "eco_friendly",
        "bulk_discount",
        "durable",
        "lightweight",
    }
)
MAX_CAPABILITIES = 8


def _normalize_capabilities(raw: list | None) -> list[str]:
    if not raw:
        return []
    out: list[str] = []
    seen: set[str] = set()
    for item in raw:
        code = str(item).strip().lower().replace(" ", "_").replace("-", "_")
        if not code or code in seen or code not in PRODUCT_CAPABILITIES:
            continue
        seen.add(code)
        out.append(code)
        if len(out) >= MAX_CAPABILITIES:
            break
    return out


def _has_active_business(subscription: Subscription | None) -> bool:
    return bool(subscription and subscription.plan == "business" and subscription.is_active)


def _format_price(price: Decimal) -> str:
    return f"{price.quantize(Decimal('0.01'))}"


def _day_bucket(dt: datetime | None = None) -> str:
    value = dt or datetime.now(UTC)
    return value.astimezone(UTC).strftime("%Y-%m-%d")


def _seller_filter():
    return and_(
        Subscription.plan == "business",
        Subscription.is_active.is_(True),
    )


async def _require_business_account(user: User) -> None:
    if not _has_active_business(user.subscription):
        raise AppError(
            message="Biznes hisob talab qilinadi",
            error_code="NOT_A_BUSINESS_ACCOUNT",
            status_code=403,
        )


async def _get_product_or_404(
    db: AsyncSession,
    product_id: int,
    *,
    viewer: User | None = None,
    allow_owner_draft: bool = False,
) -> Product:
    result = await db.execute(
        select(Product)
        .where(Product.id == product_id)
        .options(
            selectinload(Product.images),
            selectinload(Product.seller).selectinload(User.subscription),
            selectinload(Product.seller).selectinload(User.business),
        )
    )
    product = result.scalar_one_or_none()
    if product is None:
        raise AppError(
            message="Mahsulot topilmadi",
            error_code="PRODUCT_NOT_FOUND",
            status_code=404,
        )

    is_owner = viewer is not None and product.seller_id == viewer.id
    seller_active = _has_active_business(product.seller.subscription)

    if product.status == "archived" and not is_owner:
        raise AppError(
            message="Mahsulot topilmadi",
            error_code="PRODUCT_NOT_FOUND",
            status_code=404,
        )

    if product.status == "draft" and not (allow_owner_draft and is_owner):
        raise AppError(
            message="Mahsulot topilmadi",
            error_code="PRODUCT_NOT_FOUND",
            status_code=404,
        )

    if product.status == "published" and not seller_active and not is_owner:
        raise AppError(
            message="Mahsulot topilmadi",
            error_code="PRODUCT_NOT_FOUND",
            status_code=404,
        )

    return product


async def _favorite_ids(db: AsyncSession, user_id: int, product_ids: list[int]) -> set[int]:
    if not product_ids:
        return set()
    result = await db.execute(
        select(ProductFavorite.product_id).where(
            ProductFavorite.user_id == user_id,
            ProductFavorite.product_id.in_(product_ids),
        )
    )
    return set(result.scalars().all())


async def _top_product_ids(db: AsyncSession, *, limit: int = 10) -> list[int]:
    pinned_result = await db.execute(
        select(Product.id)
        .join(User, User.id == Product.seller_id)
        .join(Subscription, Subscription.user_id == User.id)
        .where(
            Product.status == "published",
            Product.is_top_pinned.is_(True),
            _seller_filter(),
        )
        .order_by(Product.created_at.desc())
    )
    pinned_ids = list(pinned_result.scalars().all())

    remaining = max(limit - len(pinned_ids), 0)
    if remaining == 0:
        return pinned_ids[:limit]

    cutoff = (datetime.now(UTC) - timedelta(days=30)).strftime("%Y-%m-%d")
    views_subq = (
        select(
            ProductView.product_id.label("product_id"),
            func.count(ProductView.id).label("recent_views"),
        )
        .where(ProductView.day_bucket >= cutoff)
        .group_by(ProductView.product_id)
        .subquery()
    )

    popular_result = await db.execute(
        select(
            Product.id,
            Product.seller_id,
            func.coalesce(views_subq.c.recent_views, 0).label("rv"),
        )
        .join(User, User.id == Product.seller_id)
        .join(Subscription, Subscription.user_id == User.id)
        .outerjoin(views_subq, views_subq.c.product_id == Product.id)
        .where(
            Product.status == "published",
            _seller_filter(),
            Product.id.notin_(pinned_ids) if pinned_ids else True,
        )
        .order_by(func.coalesce(views_subq.c.recent_views, 0).desc(), Product.created_at.desc())
    )

    selected: list[int] = list(pinned_ids)
    seller_counts: dict[int, int] = {}
    for row in popular_result:
        pid = int(row.id)
        sid = int(row.seller_id)
        if seller_counts.get(sid, 0) >= 2:
            continue
        selected.append(pid)
        seller_counts[sid] = seller_counts.get(sid, 0) + 1
        if len(selected) >= limit:
            break

    return selected[:limit]


def _sniff_image_content_type(data: bytes, declared: str | None) -> str:
    """Dio/Flutter ko'pincha application/octet-stream yuboradi — baytlardan aniqlaymiz."""
    raw = (declared or "").split(";")[0].strip().lower()
    if raw in ALLOWED_IMAGE_TYPES:
        return raw
    if data.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if len(data) >= 12 and data[0:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "image/webp"
    try:
        with Image.open(BytesIO(data)) as img:
            fmt = (img.format or "").upper()
            if fmt in {"JPEG", "JPG"}:
                return "image/jpeg"
            if fmt == "PNG":
                return "image/png"
            if fmt == "WEBP":
                return "image/webp"
    except Exception:
        pass
    return raw or "application/octet-stream"


def _normalize_short_description(name: str, short_description: str, description: str) -> str:
    text = (short_description or "").strip()
    if text:
        return text[:120]
    fallback = (description or "").strip() or (name or "").strip()
    return fallback[:120]


def _validate_published_payload(
    *,
    name: str,
    short_description: str,
    description: str,
    price: Decimal,
    currency: str,
    category: str,
    image_ids: list[int],
    attributes: list,
) -> None:
    errors: list[str] = []
    if not (2 <= len(name.strip()) <= 100):
        errors.append("name: 2-100 belgi")
    if not (1 <= len(short_description.strip()) <= 120):
        errors.append("short_description: 1-120 belgi")
    if len(description) > 500:
        errors.append("description: maksimal 500 belgi")
    if price <= 0:
        errors.append("price: 0 dan katta bo'lishi kerak")
    if currency not in SUPPORTED_CURRENCIES:
        errors.append("currency: noto'g'ri qiymat")
    if category not in PRODUCT_CATEGORIES:
        errors.append("category: noto'g'ri qiymat")
    if not image_ids:
        errors.append("image_ids: kamida 1 ta rasm")
    if len(image_ids) > MAX_IMAGES_PER_PRODUCT:
        errors.append("image_ids: maksimal 10 ta rasm")
    if len(attributes) > 10:
        errors.append("attributes: maksimal 10 ta")

    if errors:
        raise AppError(
            message="; ".join(errors),
            error_code="VALIDATION_ERROR",
            status_code=400,
        )


async def _attach_images(
    db: AsyncSession,
    *,
    product: Product,
    seller_id: int,
    image_ids: list[int],
    primary_image_id: int | None,
) -> None:
    if len(image_ids) > MAX_IMAGES_PER_PRODUCT:
        raise AppError(
            message="Mahsulotga maksimal 10 ta rasm biriktirish mumkin",
            error_code="PRODUCT_IMAGES_LIMIT",
            status_code=400,
        )

    # Async: product.images lazy-load qilmaslik (MissingGreenlet).
    existing_result = await db.execute(
        select(ProductImage).where(ProductImage.product_id == product.id)
    )
    existing = list(existing_result.scalars().all())

    if not image_ids:
        for img in existing:
            key = _key_from_url(img.url)
            if key:
                try:
                    await get_storage().delete_object(key)
                except Exception:
                    pass
            await db.delete(img)
        return

    result = await db.execute(
        select(ProductImage).where(
            ProductImage.id.in_(image_ids),
            ProductImage.uploader_id == seller_id,
        )
    )
    images = {img.id: img for img in result.scalars().all()}
    missing = [i for i in image_ids if i not in images]
    if missing:
        raise AppError(
            message="Rasm topilmadi yoki sizga tegishli emas",
            error_code="PRODUCT_IMAGE_NOT_FOUND",
            status_code=400,
        )

    keep = set(image_ids)
    for img in existing:
        if img.id not in keep:
            key = _key_from_url(img.url)
            if key:
                try:
                    await get_storage().delete_object(key)
                except Exception:
                    pass
            await db.delete(img)

    primary_id = primary_image_id or image_ids[0]
    if primary_id not in image_ids:
        primary_id = image_ids[0]

    now = datetime.now(UTC)
    for position, image_id in enumerate(image_ids):
        img = images[image_id]
        img.product_id = product.id
        img.position = position
        img.is_primary = image_id == primary_id
        img.attached_at = now


def _primary_url(product: Product) -> str | None:
    if not product.images:
        return None
    primary = next((img for img in product.images if img.is_primary), product.images[0])
    return primary.url


def _serialize_seller(user: User) -> dict:
    business = user.business
    rating = None
    reviews_count = 0
    moq = None
    export_countries: list[str] = []
    lead_time = None
    incoterms: list[str] = []
    if business is not None:
        if business.rating is not None:
            rating = float(business.rating)
        reviews_count = int(business.reviews_count or 0)
        moq = (business.moq or "").strip() or None
        export_countries = [
            str(c).strip().upper()
            for c in (business.export_countries or [])
            if str(c).strip()
        ]
        lead_time = (business.lead_time or "").strip() or None
        incoterms = [str(c).strip() for c in (business.incoterms or []) if str(c).strip()]
    return {
        "id": user.id,
        "company_name": business.company_name if business else "",
        "logo_url": business.logo_url if business else None,
        "verified_badge": user.verified_badge,
        "country": business.country if business else user.country,
        "business_role": business.business_role if business else None,
        "rating": rating,
        "reviews_count": reviews_count,
        "moq": moq,
        "export_countries": export_countries,
        "lead_time": lead_time,
        "incoterms": incoterms,
        "factory_verification": build_factory_verification(business, user=user),
        "trust_badges": build_product_trust_badges(business, user=user),
    }


def _clean_optional_str(value: str | None, *, max_len: int) -> str | None:
    if value is None:
        return None
    cleaned = value.strip()
    if not cleaned:
        return None
    return cleaned[:max_len]


def _normalize_country_list(raw: list | None) -> list[str]:
    if not raw:
        return []
    out: list[str] = []
    seen: set[str] = set()
    for item in raw:
        code = str(item).strip().upper()
        if not code or code in seen:
            continue
        seen.add(code)
        out.append(code[:8])
        if len(out) >= 50:
            break
    return out


def _effective_marketplace_fields(product: Product, seller: User) -> dict:
    business = seller.business
    seller_moq = (business.moq or "").strip() if business else ""
    seller_countries = (
        [str(c).strip().upper() for c in (business.export_countries or []) if str(c).strip()]
        if business
        else []
    )
    product_moq = (product.moq or "").strip()
    product_countries = _normalize_country_list(product.shipping_countries)
    shipping_info = (product.shipping_info or "").strip()
    if not shipping_info and business is not None:
        parts: list[str] = []
        lead = (business.lead_time or "").strip()
        if lead:
            parts.append(lead)
        terms = [str(c).strip() for c in (business.incoterms or []) if str(c).strip()]
        if terms:
            parts.append(" · ".join(terms))
        shipping_info = " · ".join(parts)

    rating = None
    reviews_count = 0
    if business is not None:
        if business.rating is not None:
            rating = float(business.rating)
        reviews_count = int(business.reviews_count or 0)

    return {
        "video_url": (product.video_url or "").strip() or None,
        "factory_video_url": (product.factory_video_url or "").strip() or None,
        "process_video_url": (product.process_video_url or "").strip() or None,
        "moq": product_moq or seller_moq or None,
        "shipping_info": shipping_info or None,
        "shipping_countries": product_countries or seller_countries,
        "rating": rating,
        "reviews_count": reviews_count,
    }


async def _serialize_product(
    product: Product,
    *,
    favorite_ids: set[int],
    top_ids: set[int] | None = None,
    force_top: bool | None = None,
) -> dict:
    is_top = force_top if force_top is not None else (
        product.is_top_pinned or (top_ids is not None and product.id in top_ids)
    )
    seller = getattr(product, "seller", None)
    trust = build_product_trust_badges(
        seller.business if seller is not None else None,
        user=seller,
    )
    return {
        "id": product.id,
        "name": product.name,
        "short_description": product.short_description,
        "price": _format_price(product.price),
        "currency": product.currency,
        "primary_image_url": _primary_url(product),
        "views_count": product.views_count,
        "is_top": is_top,
        "is_favorited": product.id in favorite_ids,
        "status": product.status,
        "seller_id": product.seller_id,
        "created_at": product.created_at,
        "trust_badges": trust,
        "capabilities": _normalize_capabilities(product.capabilities),
    }


async def _serialize_detail(
    db: AsyncSession,
    product: Product,
    *,
    favorite_ids: set[int],
    top_ids: set[int] | None = None,
    viewer: User | None = None,
) -> dict:
    base = await _serialize_product(product, favorite_ids=favorite_ids, top_ids=top_ids)
    marketplace = _effective_marketplace_fields(product, product.seller)
    base.update(
        {
            "description": product.description,
            "category": product.category,
            "images": [
                {
                    "id": img.id,
                    "url": img.url,
                    "is_primary": img.is_primary,
                    "position": img.position,
                }
                for img in sorted(product.images, key=lambda x: x.position)
            ],
            "attributes": list(product.attributes or []),
            "capabilities": _normalize_capabilities(product.capabilities),
            "seller": _serialize_seller(product.seller),
            "top_request": None,
            **marketplace,
        }
    )
    if viewer is not None and viewer.id == product.seller_id:
        result = await db.execute(
            select(ProductTopRequest)
            .where(ProductTopRequest.product_id == product.id)
            .order_by(ProductTopRequest.created_at.desc())
            .limit(1)
        )
        req = result.scalar_one_or_none()
        if req is not None:
            base["top_request"] = _serialize_top_request(req, product=product)
    return base


def _serialize_top_request(req: ProductTopRequest, *, product: Product | None = None) -> dict:
    return {
        "id": req.id,
        "product_id": req.product_id,
        "seller_id": req.seller_id,
        "status": req.status,
        "note": req.note or "",
        "admin_note": req.admin_note or "",
        "created_at": req.created_at,
        "reviewed_at": req.reviewed_at,
        "product_name": product.name if product is not None else None,
        "is_top_pinned": product.is_top_pinned if product is not None else None,
    }


async def _load_products_query(
    *,
    published_only: bool,
    seller_id: int | None = None,
    status_filter: str | None = None,
    require_active_business: bool = True,
):
    query = (
        select(Product)
        .join(User, User.id == Product.seller_id)
        .outerjoin(Subscription, Subscription.user_id == User.id)
        .options(
            selectinload(Product.images),
            selectinload(Product.seller).selectinload(User.subscription),
            selectinload(Product.seller).selectinload(User.business),
        )
    )

    if published_only:
        query = query.where(Product.status == "published")
        if require_active_business:
            query = query.where(_seller_filter())
    elif status_filter:
        query = query.where(Product.status == status_filter)

    if seller_id is not None:
        query = query.where(Product.seller_id == seller_id)

    return query


def _apply_marketplace_filters(
    query,
    *,
    search: str | None,
    category: str | None,
    min_price: Decimal | None,
    max_price: Decimal | None,
    currency: str | None,
    seller_id: int | None,
    country: str | None,
    business_role: str | None,
    verified_only: bool,
    ready_stock: bool = False,
    free_shipping: bool = False,
    premium_seller: bool = False,
    new_only: bool = False,
):
    """Seller/country/role filterlari — BusinessProfile outerjoin talab qiladi."""
    if search:
        pattern = f"%{search.strip()}%"
        query = query.where(
            or_(
                Product.name.ilike(pattern),
                Product.short_description.ilike(pattern),
            )
        )
    if category:
        query = query.where(Product.category == category)
    if min_price is not None:
        query = query.where(Product.price >= min_price)
    if max_price is not None:
        query = query.where(Product.price <= max_price)
    if currency:
        query = query.where(Product.currency == currency)
    if seller_id is not None:
        query = query.where(Product.seller_id == seller_id)
    if country:
        code = country.strip().upper()
        if len(code) == 2:
            query = query.where(
                or_(
                    BusinessProfile.country == code,
                    and_(BusinessProfile.country.is_(None), User.country == code),
                )
            )
    if business_role:
        role = business_role.strip().lower()
        if role:
            query = query.where(BusinessProfile.business_role == role)
    if verified_only:
        query = query.where(User.verified_badge.is_(True))
    if ready_stock:
        attrs_text = cast(Product.attributes, String)
        query = query.where(
            or_(
                Product.moq.is_(None),
                Product.moq == "",
                Product.moq.ilike("1%"),
                Product.shipping_info.ilike("%ready%"),
                Product.shipping_info.ilike("%stock%"),
                Product.shipping_info.ilike("%ombor%"),
                Product.shipping_info.ilike("%mavjud%"),
                Product.shipping_info.ilike("%in stock%"),
                attrs_text.ilike("%ready_stock%"),
                attrs_text.ilike("%in_stock%"),
                attrs_text.ilike("%ready%"),
            )
        )
    if free_shipping:
        attrs_text = cast(Product.attributes, String)
        query = query.where(
            or_(
                Product.shipping_info.ilike("%free%"),
                Product.shipping_info.ilike("%bepul%"),
                Product.shipping_info.ilike("%бесплат%"),
                Product.shipping_info.ilike("%free shipping%"),
                attrs_text.ilike("%free_shipping%"),
                attrs_text.ilike("%free shipping%"),
            )
        )
    if premium_seller:
        query = query.where(
            Subscription.is_active.is_(True),
            Subscription.plan.in_(("premium", "business")),
        )
    if new_only:
        cutoff = datetime.now(UTC) - timedelta(days=30)
        query = query.where(Product.created_at >= cutoff)
    return query


def _recommended_score(viewer: User):
    """AI-tavsiya skori: verified + top + ko‘rishlar + viewer davlati."""
    score = (
        case((User.verified_badge.is_(True), 100), else_=0)
        + case((Product.is_top_pinned.is_(True), 80), else_=0)
        + func.least(Product.views_count, 400)
    )
    viewer_country = (viewer.country or "").strip().upper()
    if len(viewer_country) == 2:
        score = score + case(
            (
                or_(
                    BusinessProfile.country == viewer_country,
                    and_(
                        BusinessProfile.country.is_(None),
                        User.country == viewer_country,
                    ),
                ),
                45,
            ),
            else_=0,
        )
    return score


async def list_for_you(
    db: AsyncSession,
    *,
    viewer: User,
    limit: int = 12,
) -> dict:
    """Ko‘rilgan mahsulotlar kategoriyasi asosida shaxsiy tavsiyalar."""
    safe_limit = min(max(int(limit or 12), 1), 30)

    viewed_result = await db.execute(
        select(Product)
        .join(ProductView, ProductView.product_id == Product.id)
        .where(
            ProductView.user_id == viewer.id,
            Product.status == "published",
        )
        .order_by(ProductView.day_bucket.desc(), ProductView.id.desc())
        .limit(40)
    )
    viewed = list(viewed_result.scalars().unique().all())
    viewed_ids = {int(p.id) for p in viewed}
    cat_counts: dict[str, int] = {}
    for p in viewed:
        cat = (p.category or "").strip().lower()
        if not cat:
            continue
        cat_counts[cat] = cat_counts.get(cat, 0) + 1
    top_categories = [
        c
        for c, _ in sorted(cat_counts.items(), key=lambda x: x[1], reverse=True)[:6]
    ]
    based_on_views = bool(top_categories)

    query = await _load_products_query(published_only=True)
    query = query.outerjoin(BusinessProfile, BusinessProfile.user_id == User.id)
    if top_categories:
        query = query.where(
            func.lower(Product.category).in_(top_categories),
            Product.id.notin_(list(viewed_ids)) if viewed_ids else True,
        )
        query = query.order_by(
            _recommended_score(viewer).desc(),
            Product.views_count.desc(),
            Product.created_at.desc(),
        )
    else:
        query = query.order_by(
            _recommended_score(viewer).desc(),
            Product.created_at.desc(),
        )

    result = await db.execute(query.limit(safe_limit))
    products = list(result.scalars().unique().all())

    # Yetarli bo‘lmasa — umumiy recommended bilan to‘ldirish
    if len(products) < max(4, safe_limit // 2):
        fallback = await list_products(
            db,
            viewer=viewer,
            search=None,
            category=None,
            min_price=None,
            max_price=None,
            currency=None,
            seller_id=None,
            sort="recommended",
            page=1,
            limit=safe_limit,
        )
        return {
            "items": fallback.get("items") or [],
            "based_on_views": based_on_views,
        }

    top_ids = set(await _top_product_ids(db))
    fav_ids = await _favorite_ids(db, viewer.id, [p.id for p in products])
    items = [
        await _serialize_product(p, favorite_ids=fav_ids, top_ids=top_ids)
        for p in products
    ]
    return {
        "items": items,
        "based_on_views": based_on_views,
    }


async def list_products(
    db: AsyncSession,
    *,
    viewer: User,
    search: str | None,
    category: str | None,
    min_price: Decimal | None,
    max_price: Decimal | None,
    currency: str | None,
    seller_id: int | None,
    country: str | None = None,
    business_role: str | None = None,
    verified_only: bool = False,
    ready_stock: bool = False,
    free_shipping: bool = False,
    premium_seller: bool = False,
    new_only: bool = False,
    sort: str,
    page: int | None,
    limit: int | None,
    smart_search: str | None = None,
) -> dict:
    params = normalize_page(page, limit, default_size=20, max_size=50)
    query = await _load_products_query(published_only=True)
    query = query.outerjoin(BusinessProfile, BusinessProfile.user_id == User.id)
    query = _apply_marketplace_filters(
        query,
        search=search if not smart_search else None,
        category=category,
        min_price=min_price,
        max_price=max_price,
        currency=currency,
        seller_id=seller_id,
        country=country,
        business_role=business_role,
        verified_only=verified_only,
        ready_stock=ready_stock,
        free_shipping=free_shipping,
        premium_seller=premium_seller,
        new_only=new_only,
    )
    if smart_search:
        from app.services.smart_search import apply_smart_keyword_filter

        query = apply_smart_keyword_filter(query, smart_search)

    sort_key = (sort or "newest").strip().lower()
    if sort_key == "recommended":
        query = query.order_by(
            _recommended_score(viewer).desc(),
            Product.created_at.desc(),
        )
    elif sort_key == "top":
        query = query.order_by(
            Product.is_top_pinned.desc(),
            Product.views_count.desc(),
            Product.created_at.desc(),
        )
    else:
        sort_map = {
            "newest": Product.created_at.desc(),
            "price_asc": Product.price.asc(),
            "price_desc": Product.price.desc(),
            "most_viewed": Product.views_count.desc(),
        }
        query = query.order_by(sort_map.get(sort_key, Product.created_at.desc()))

    count_query = select(func.count()).select_from(query.subquery())
    total = int((await db.execute(count_query)).scalar() or 0)

    result = await db.execute(query.offset(params.offset).limit(params.limit))
    products = list(result.scalars().unique().all())
    top_ids = set(await _top_product_ids(db))
    fav_ids = await _favorite_ids(db, viewer.id, [p.id for p in products])

    items = [
        await _serialize_product(p, favorite_ids=fav_ids, top_ids=top_ids)
        for p in products
    ]
    return {
        "items": items,
        "page": params.page,
        "limit": params.page_size,
        "total": total,
        "has_more": params.offset + len(items) < total,
    }


async def list_top_products(db: AsyncSession, *, viewer: User, limit: int = 10) -> dict:
    safe_limit = min(max(limit, 1), 20)
    top_ids = await _top_product_ids(db, limit=safe_limit)
    if not top_ids:
        return {"items": []}

    result = await db.execute(
        select(Product)
        .where(Product.id.in_(top_ids))
        .options(
            selectinload(Product.images),
            selectinload(Product.seller).selectinload(User.subscription),
            selectinload(Product.seller).selectinload(User.business),
        )
    )
    by_id = {p.id: p for p in result.scalars().unique().all()}
    ordered = [by_id[i] for i in top_ids if i in by_id]
    fav_ids = await _favorite_ids(db, viewer.id, top_ids)

    items = [
        await _serialize_product(p, favorite_ids=fav_ids, force_top=True)
        for p in ordered
    ]
    return {"items": items}


async def list_manufacturers_map(db: AsyncSession, *, viewer: User) -> dict:
    """Published mahsulotli manufacturer'larni davlat bo‘yicha guruhlash (xarita)."""
    _ = viewer
    country_expr = func.upper(func.coalesce(BusinessProfile.country, User.country))
    company_expr = func.coalesce(
        func.nullif(BusinessProfile.company_name, ""),
        func.nullif(User.full_name, ""),
        "Company",
    )

    result = await db.execute(
        select(
            country_expr.label("country"),
            User.id.label("seller_id"),
            company_expr.label("company_name"),
            User.verified_badge.label("verified"),
            func.coalesce(BusinessProfile.factory_verified, False).label(
                "factory_verified"
            ),
            func.count(Product.id).label("product_count"),
        )
        .select_from(Product)
        .join(User, User.id == Product.seller_id)
        .outerjoin(Subscription, Subscription.user_id == User.id)
        .outerjoin(BusinessProfile, BusinessProfile.user_id == User.id)
        .where(
            Product.status == "published",
            _seller_filter(),
            BusinessProfile.business_role == "manufacturer",
            country_expr.isnot(None),
            func.length(country_expr) == 2,
        )
        .group_by(
            country_expr,
            User.id,
            company_expr,
            User.verified_badge,
            BusinessProfile.factory_verified,
        )
        .order_by(func.count(Product.id).desc())
        .limit(500)
    )

    by_country: dict[str, dict] = {}
    for row in result.all():
        code = (row.country or "").strip().upper()
        if len(code) != 2:
            continue
        bucket = by_country.setdefault(
            code,
            {
                "country": code,
                "manufacturer_count": 0,
                "product_count": 0,
                "companies": [],
            },
        )
        product_count = int(row.product_count or 0)
        bucket["manufacturer_count"] += 1
        bucket["product_count"] += product_count
        if len(bucket["companies"]) < 8:
            bucket["companies"].append(
                {
                    "id": int(row.seller_id),
                    "company_name": (row.company_name or "Company").strip() or "Company",
                    "verified": bool(row.verified),
                    "factory_verified": bool(row.factory_verified),
                    "product_count": product_count,
                }
            )

    items = sorted(
        by_country.values(),
        key=lambda x: (-int(x["manufacturer_count"]), x["country"]),
    )
    return {
        "items": items,
        "total_manufacturers": sum(int(i["manufacturer_count"]) for i in items),
        "total_countries": len(items),
    }


def list_categories(language: str) -> list[dict]:
    lang = language if language in {"uz_UZ", "ru_RU", "us_US"} else "uz_UZ"
    return [
        {"code": code, "title": titles.get(lang, titles["uz_UZ"])}
        for code, titles in PRODUCT_CATEGORIES.items()
    ]


async def get_product_detail(
    db: AsyncSession,
    *,
    product_id: int,
    viewer: User,
) -> dict:
    product = await _get_product_or_404(db, product_id, viewer=viewer, allow_owner_draft=True)

    if product.seller_id != viewer.id:
        await _record_view(db, product_id=product.id, viewer_id=viewer.id)

    top_ids = set(await _top_product_ids(db))
    fav_ids = await _favorite_ids(db, viewer.id, [product.id])
    return await _serialize_detail(
        db,
        product,
        favorite_ids=fav_ids,
        top_ids=top_ids,
        viewer=viewer,
    )


async def _record_view(db: AsyncSession, *, product_id: int, viewer_id: int) -> None:
    bucket = _day_bucket()
    stmt = (
        pg_insert(ProductView)
        .values(user_id=viewer_id, product_id=product_id, day_bucket=bucket)
        .on_conflict_do_nothing(constraint="uq_view_day")
    )
    result = await db.execute(stmt)
    if not result.rowcount:
        return
    await db.execute(
        update(Product)
        .where(Product.id == product_id)
        .values(views_count=Product.views_count + 1)
    )


async def upload_product_image(
    db: AsyncSession,
    *,
    user: User,
    filename: str,
    content_type: str,
    data: bytes,
) -> dict:
    await _require_business_account(user)

    content_type = _sniff_image_content_type(data, content_type)
    if content_type not in ALLOWED_IMAGE_TYPES:
        raise AppError(
            message="Faqat JPEG, PNG yoki WebP ruxsat etilgan",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )
    if len(data) > MAX_IMAGE_BYTES:
        raise AppError(
            message="Rasm hajmi 5 MB dan oshmasligi kerak",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )

    try:
        Image.open(BytesIO(data)).verify()
    except Exception as exc:
        raise AppError(
            message="Rasm fayli noto'g'ri",
            error_code="VALIDATION_ERROR",
            status_code=400,
        ) from exc

    ext = "jpg" if content_type == "image/jpeg" else content_type.split("/")[-1]
    key = f"products/uploads/{user.id}/{uuid4().hex}.{ext}"
    url = await get_storage().upload_bytes(key, data, content_type)

    image = ProductImage(uploader_id=user.id, url=url, product_id=None)
    db.add(image)
    await db.flush()
    await db.refresh(image)
    return {"id": image.id, "url": image.url}


def _sniff_video_content_type(data: bytes, declared: str | None, filename: str) -> str:
    raw = (declared or "").split(";")[0].strip().lower()
    if raw in ALLOWED_VIDEO_TYPES:
        return raw
    name = (filename or "").lower()
    if name.endswith(".mp4") or name.endswith(".m4v"):
        return "video/mp4"
    if name.endswith(".mov"):
        return "video/quicktime"
    if name.endswith(".webm"):
        return "video/webm"
    # ISO BMFF / MP4 signature
    if len(data) >= 12 and data[4:8] == b"ftyp":
        return "video/mp4"
    return raw or "application/octet-stream"


async def upload_product_video(
    db: AsyncSession,
    *,
    user: User,
    filename: str,
    content_type: str,
    data: bytes,
) -> dict:
    """Qisqa mahsulot videosi (≈15s) — URL qaytaradi, product.video_url ga yoziladi."""
    await _require_business_account(user)

    content_type = _sniff_video_content_type(data, content_type, filename)
    if content_type not in ALLOWED_VIDEO_TYPES:
        raise AppError(
            message="Faqat MP4, MOV yoki WebM video ruxsat etilgan",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )
    if len(data) > MAX_VIDEO_BYTES:
        raise AppError(
            message="Video hajmi 25 MB dan oshmasligi kerak",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )
    if len(data) < 64:
        raise AppError(
            message="Video fayli noto'g'ri",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )

    ext = {
        "video/mp4": "mp4",
        "video/x-m4v": "m4v",
        "video/quicktime": "mov",
        "video/webm": "webm",
    }.get(content_type, "mp4")
    key = f"products/videos/{user.id}/{uuid4().hex}.{ext}"
    url = await get_storage().upload_bytes(key, data, content_type)
    return {"url": url}


async def delete_product_image(db: AsyncSession, *, user: User, image_id: int) -> None:
    result = await db.execute(select(ProductImage).where(ProductImage.id == image_id))
    image = result.scalar_one_or_none()
    if image is None or image.uploader_id != user.id:
        raise AppError(
            message="Rasm topilmadi",
            error_code="PRODUCT_IMAGE_NOT_FOUND",
            status_code=400,
        )
    key = _key_from_url(image.url)
    if key:
        try:
            await get_storage().delete_object(key)
        except Exception:
            pass
    await db.delete(image)


async def create_product(db: AsyncSession, *, user: User, payload: ProductCreateIn) -> dict:
    await _require_business_account(user)

    if payload.status not in {"draft", "published"}:
        raise AppError(
            message="Status qoralama yoki e'lon qilingan bo'lishi kerak",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )

    name = payload.name.strip()
    short_description = _normalize_short_description(
        name, payload.short_description, payload.description
    )
    description = payload.description.strip()

    if payload.status == "draft":
        if not name:
            raise AppError(
                message="Qoralama uchun nom majburiy",
                error_code="VALIDATION_ERROR",
                status_code=400,
            )
    else:
        _validate_published_payload(
            name=name,
            short_description=short_description,
            description=description,
            price=payload.price,
            currency=payload.currency,
            category=payload.category,
            image_ids=payload.image_ids,
            attributes=payload.attributes,
        )

    product = Product(
        seller_id=user.id,
        name=name,
        short_description=short_description,
        description=description,
        price=payload.price,
        currency=payload.currency,
        category=payload.category,
        status=payload.status,
        attributes=[a.model_dump() for a in payload.attributes],
        capabilities=_normalize_capabilities(payload.capabilities),
        video_url=_clean_optional_str(payload.video_url, max_len=512),
        factory_video_url=_clean_optional_str(payload.factory_video_url, max_len=512),
        process_video_url=_clean_optional_str(payload.process_video_url, max_len=512),
        moq=_clean_optional_str(payload.moq, max_len=120),
        shipping_info=_clean_optional_str(payload.shipping_info, max_len=255),
        shipping_countries=_normalize_country_list(payload.shipping_countries),
    )
    db.add(product)
    await db.flush()

    await _attach_images(
        db,
        product=product,
        seller_id=user.id,
        image_ids=payload.image_ids,
        primary_image_id=payload.primary_image_id,
    )

    result = await db.execute(
        select(Product)
        .where(Product.id == product.id)
        .options(
            selectinload(Product.images),
            selectinload(Product.seller).selectinload(User.subscription),
            selectinload(Product.seller).selectinload(User.business),
        )
    )
    product = result.scalar_one()

    if product.status == "published":
        from app.services.feed import create_system_post

        primary = next(
            (img.url for img in (product.images or []) if img.is_primary),
            (product.images[0].url if product.images else None),
        )
        await create_system_post(
            db,
            user=user,
            post_type="new_product",
            title=product.name,
            body=(product.short_description or product.description or "")[:400],
            image_url=primary,
            meta={"product_id": product.id},
        )

    fav_ids = await _favorite_ids(db, user.id, [product.id])
    top_ids = set(await _top_product_ids(db))
    return await _serialize_detail(
        db,
        product,
        favorite_ids=fav_ids,
        top_ids=top_ids,
        viewer=user,
    )


async def update_product(
    db: AsyncSession,
    *,
    user: User,
    product_id: int,
    payload: ProductUpdateIn,
) -> dict:
    product = await _get_product_or_404(db, product_id, viewer=user, allow_owner_draft=True)
    if product.seller_id != user.id:
        raise AppError(
            message="Bu mahsulot sizga tegishli emas",
            error_code="NOT_PRODUCT_OWNER",
            status_code=403,
        )

    was_published = product.status == "published"
    data = payload.model_dump(exclude_unset=True)
    attributes = data.pop("attributes", None)
    capabilities = data.pop("capabilities", None)
    image_ids = data.pop("image_ids", None)
    primary_image_id = data.pop("primary_image_id", None)
    new_status = data.pop("status", None)

    for field, value in data.items():
        if field in {
            "name",
            "short_description",
            "description",
            "video_url",
            "factory_video_url",
            "process_video_url",
            "moq",
            "shipping_info",
        } and isinstance(value, str):
            value = value.strip()
            if field in {
                "video_url",
                "factory_video_url",
                "process_video_url",
                "moq",
                "shipping_info",
            } and not value:
                value = None
        if field == "shipping_countries" and value is not None:
            value = _normalize_country_list(value)
        setattr(product, field, value)

    if capabilities is not None:
        product.capabilities = _normalize_capabilities(capabilities)
    if attributes is not None:
        product.attributes = [a.model_dump() if hasattr(a, "model_dump") else a for a in attributes]

    target_status = new_status or product.status
    if target_status == "published":
        short_description = product.short_description
        if not short_description.strip():
            short_description = _normalize_short_description(
                product.name, product.short_description, product.description
            )
            product.short_description = short_description
        _validate_published_payload(
            name=product.name,
            short_description=product.short_description,
            description=product.description,
            price=product.price,
            currency=product.currency,
            category=product.category,
            image_ids=image_ids if image_ids is not None else [img.id for img in product.images],
            attributes=product.attributes or [],
        )

    if image_ids is not None:
        await _attach_images(
            db,
            product=product,
            seller_id=user.id,
            image_ids=image_ids,
            primary_image_id=primary_image_id,
        )

    if new_status is not None:
        if new_status not in {"draft", "published", "archived"}:
            raise AppError(
                message="Status noto'g'ri",
                error_code="VALIDATION_ERROR",
                status_code=400,
            )
        product.status = new_status

    await db.flush()
    result = await db.execute(
        select(Product)
        .where(Product.id == product.id)
        .options(
            selectinload(Product.images),
            selectinload(Product.seller).selectinload(User.subscription),
            selectinload(Product.seller).selectinload(User.business),
        )
    )
    product = result.scalar_one()
    if not was_published and product.status == "published":
        from app.services.feed import create_system_post

        primary = next(
            (img.url for img in (product.images or []) if img.is_primary),
            (product.images[0].url if product.images else None),
        )
        await create_system_post(
            db,
            user=user,
            post_type="new_product",
            title=product.name,
            body=(product.short_description or product.description or "")[:400],
            image_url=primary,
            meta={"product_id": product.id},
        )
    fav_ids = await _favorite_ids(db, user.id, [product.id])
    top_ids = set(await _top_product_ids(db))
    return await _serialize_detail(
        db,
        product,
        favorite_ids=fav_ids,
        top_ids=top_ids,
        viewer=user,
    )


async def archive_product(db: AsyncSession, *, user: User, product_id: int) -> None:
    product = await _get_product_or_404(db, product_id, viewer=user, allow_owner_draft=True)
    if product.seller_id != user.id:
        raise AppError(
            message="Bu mahsulot sizga tegishli emas",
            error_code="NOT_PRODUCT_OWNER",
            status_code=403,
        )
    product.status = "archived"


async def list_my_products(
    db: AsyncSession,
    *,
    user: User,
    status: str | None,
    page: int | None,
    limit: int | None,
) -> dict:
    params = normalize_page(page, limit, default_size=20, max_size=50)
    query = await _load_products_query(
        published_only=False,
        seller_id=user.id,
        status_filter=status,
        require_active_business=False,
    )
    query = query.order_by(Product.created_at.desc())

    count_query = select(func.count()).select_from(query.subquery())
    total = int((await db.execute(count_query)).scalar() or 0)
    result = await db.execute(query.offset(params.offset).limit(params.limit))
    products = list(result.scalars().unique().all())
    fav_ids = await _favorite_ids(db, user.id, [p.id for p in products])
    top_ids = set(await _top_product_ids(db))

    items = [
        await _serialize_product(p, favorite_ids=fav_ids, top_ids=top_ids)
        for p in products
    ]
    return {
        "items": items,
        "page": params.page,
        "limit": params.page_size,
        "total": total,
        "has_more": params.offset + len(items) < total,
    }


async def list_user_products(
    db: AsyncSession,
    *,
    viewer: User,
    user_id: int,
    page: int | None,
    limit: int | None,
) -> dict:
    target = await db.get(User, user_id)
    if target is None or not target.is_active:
        raise AppError(
            message="Foydalanuvchi topilmadi",
            error_code="USER_NOT_FOUND",
            status_code=404,
        )

    sub_result = await db.execute(select(Subscription).where(Subscription.user_id == user_id))
    subscription = sub_result.scalar_one_or_none()
    if not _has_active_business(subscription):
        params = normalize_page(page, limit, default_size=20, max_size=50)
        return {
            "items": [],
            "page": params.page,
            "limit": params.page_size,
            "total": 0,
            "has_more": False,
        }

    return await list_products(
        db,
        viewer=viewer,
        search=None,
        category=None,
        min_price=None,
        max_price=None,
        currency=None,
        seller_id=user_id,
        sort="newest",
        page=page,
        limit=limit,
    )


async def add_favorite(db: AsyncSession, *, user: User, product_id: int) -> dict:
    product = await _get_product_or_404(db, product_id, viewer=user)
    if product.status != "published":
        raise AppError(
            message="Faqat nashr qilingan mahsulotni sevimlilarga qo'shish mumkin",
            error_code="PRODUCT_NOT_PUBLISHED",
            status_code=400,
        )
    existing = await db.execute(
        select(ProductFavorite).where(
            ProductFavorite.user_id == user.id,
            ProductFavorite.product_id == product_id,
        )
    )
    if existing.scalar_one_or_none() is None:
        db.add(ProductFavorite(user_id=user.id, product_id=product_id))
    return {"is_favorited": True}


async def remove_favorite(db: AsyncSession, *, user: User, product_id: int) -> dict:
    result = await db.execute(
        select(ProductFavorite).where(
            ProductFavorite.user_id == user.id,
            ProductFavorite.product_id == product_id,
        )
    )
    favorite = result.scalar_one_or_none()
    if favorite is not None:
        await db.delete(favorite)
    return {"is_favorited": False}


async def list_favorites(
    db: AsyncSession,
    *,
    user: User,
    page: int | None,
    limit: int | None,
) -> dict:
    params = normalize_page(page, limit, default_size=20, max_size=50)

    base = (
        select(Product)
        .join(ProductFavorite, ProductFavorite.product_id == Product.id)
        .join(User, User.id == Product.seller_id)
        .join(Subscription, Subscription.user_id == User.id)
        .where(
            ProductFavorite.user_id == user.id,
            Product.status == "published",
            _seller_filter(),
        )
        .options(
            selectinload(Product.images),
            selectinload(Product.seller).selectinload(User.subscription),
            selectinload(Product.seller).selectinload(User.business),
        )
        .order_by(ProductFavorite.created_at.desc())
    )

    count_query = select(func.count()).select_from(base.subquery())
    total = int((await db.execute(count_query)).scalar() or 0)
    result = await db.execute(base.offset(params.offset).limit(params.limit))
    products = list(result.scalars().unique().all())
    fav_ids = set(p.id for p in products)
    top_ids = set(await _top_product_ids(db))

    items = [
        await _serialize_product(p, favorite_ids=fav_ids, top_ids=top_ids)
        for p in products
    ]
    return {
        "items": items,
        "page": params.page,
        "limit": params.page_size,
        "total": total,
        "has_more": params.offset + len(items) < total,
    }


async def request_top_promotion(
    db: AsyncSession,
    *,
    user: User,
    product_id: int,
    note: str = "",
) -> dict:
    await _require_business_account(user)
    product = await _get_product_or_404(db, product_id, viewer=user, allow_owner_draft=True)
    if product.seller_id != user.id:
        raise AppError(
            message="Bu mahsulot sizga tegishli emas",
            error_code="NOT_PRODUCT_OWNER",
            status_code=403,
        )
    if product.status != "published":
        raise AppError(
            message="Faqat e'lon qilingan mahsulot uchun TOP so'rov yuboriladi",
            error_code="PRODUCT_NOT_PUBLISHED",
            status_code=400,
        )
    if product.is_top_pinned:
        raise AppError(
            message="Mahsulot allaqachon TOP'da",
            error_code="ALREADY_TOP_PINNED",
            status_code=400,
        )

    pending = await db.execute(
        select(ProductTopRequest).where(
            ProductTopRequest.product_id == product_id,
            ProductTopRequest.status == "pending",
        )
    )
    if pending.scalar_one_or_none() is not None:
        raise AppError(
            message="Bu mahsulot uchun so'rov allaqachon yuborilgan",
            error_code="TOP_REQUEST_ALREADY_PENDING",
            status_code=409,
        )

    seller_pending_count = int(
        (
            await db.execute(
                select(func.count())
                .select_from(ProductTopRequest)
                .where(
                    ProductTopRequest.seller_id == user.id,
                    ProductTopRequest.status == "pending",
                )
            )
        ).scalar()
        or 0
    )
    if seller_pending_count >= MAX_PENDING_TOP_REQUESTS:
        raise AppError(
            message=f"Bir vaqtda maksimal {MAX_PENDING_TOP_REQUESTS} ta TOP so'rov",
            error_code="TOP_REQUEST_LIMIT",
            status_code=400,
        )

    req = ProductTopRequest(
        product_id=product.id,
        seller_id=user.id,
        status="pending",
        note=(note or "").strip()[:300],
    )
    db.add(req)
    await db.flush()
    await db.refresh(req)
    return _serialize_top_request(req, product=product)


async def cancel_top_request(db: AsyncSession, *, user: User, product_id: int) -> dict:
    product = await _get_product_or_404(db, product_id, viewer=user, allow_owner_draft=True)
    if product.seller_id != user.id:
        raise AppError(
            message="Bu mahsulot sizga tegishli emas",
            error_code="NOT_PRODUCT_OWNER",
            status_code=403,
        )
    result = await db.execute(
        select(ProductTopRequest)
        .where(
            ProductTopRequest.product_id == product_id,
            ProductTopRequest.status == "pending",
        )
        .order_by(ProductTopRequest.created_at.desc())
        .limit(1)
    )
    req = result.scalar_one_or_none()
    if req is None:
        raise AppError(
            message="Kutilayotgan so'rov topilmadi",
            error_code="TOP_REQUEST_NOT_FOUND",
            status_code=404,
        )
    req.status = "cancelled"
    req.reviewed_at = datetime.now(UTC)
    await db.flush()
    return _serialize_top_request(req, product=product)


async def list_top_requests(
    db: AsyncSession,
    *,
    status: str | None = None,
    page: int | None = None,
    limit: int | None = None,
) -> dict:
    params = normalize_page(page, limit, default_size=50, max_size=100)
    query = select(ProductTopRequest, Product).join(
        Product, Product.id == ProductTopRequest.product_id
    )
    if status in {"pending", "approved", "rejected", "cancelled"}:
        query = query.where(ProductTopRequest.status == status)
    query = query.order_by(ProductTopRequest.created_at.desc())

    count_query = select(func.count()).select_from(query.order_by(None).subquery())
    total = int((await db.execute(count_query)).scalar() or 0)
    rows = list(
        (await db.execute(query.offset(params.offset).limit(params.page_size))).all()
    )
    items = [_serialize_top_request(req, product=product) for req, product in rows]
    return {
        "items": items,
        "page": params.page,
        "limit": params.page_size,
        "total": total,
        "has_more": params.offset + len(items) < total,
    }


async def review_top_request(
    db: AsyncSession,
    *,
    request_id: int,
    approve: bool,
    admin_id: int,
    admin_note: str = "",
) -> dict:
    result = await db.execute(
        select(ProductTopRequest, Product)
        .join(Product, Product.id == ProductTopRequest.product_id)
        .where(ProductTopRequest.id == request_id)
    )
    row = result.one_or_none()
    if row is None:
        raise AppError(
            message="So'rov topilmadi",
            error_code="TOP_REQUEST_NOT_FOUND",
            status_code=404,
        )
    req, product = row
    if req.status != "pending":
        raise AppError(
            message="So'rov allaqachon ko'rib chiqilgan",
            error_code="TOP_REQUEST_NOT_PENDING",
            status_code=400,
        )

    req.status = "approved" if approve else "rejected"
    req.admin_note = (admin_note or "").strip()[:300]
    req.reviewed_by = admin_id
    req.reviewed_at = datetime.now(UTC)
    if approve:
        product.is_top_pinned = True
        if product.status != "published":
            product.status = "published"
    await db.flush()
    return _serialize_top_request(req, product=product)
