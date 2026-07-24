from __future__ import annotations

from datetime import UTC, datetime, timedelta
from decimal import Decimal
from io import BytesIO
from uuid import uuid4

from PIL import Image
from sqlalchemy import and_, func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.errors import AppError
from app.core.pagination import normalize_page
from app.integrations.storage import get_storage
from app.models.product import Product, ProductFavorite, ProductImage, ProductTopRequest, ProductView
from app.models.user import Subscription, User
from app.schemas.product import ProductCreateIn, ProductUpdateIn

MAX_IMAGES_PER_PRODUCT = 10
MAX_IMAGE_BYTES = 5 * 1024 * 1024
ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}
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

    if not image_ids:
        for img in list(product.images):
            img.product_id = None
            img.is_primary = False
            img.position = 0
            img.attached_at = None
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

    for img in list(product.images):
        if img.id not in image_ids:
            img.product_id = None
            img.is_primary = False
            img.position = 0
            img.attached_at = None

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
    return {
        "id": user.id,
        "company_name": business.company_name if business else "",
        "logo_url": business.logo_url if business else None,
        "verified_badge": user.verified_badge,
        "country": business.country if business else user.country,
        "business_role": business.business_role if business else None,
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
            "seller": _serialize_seller(product.seller),
            "top_request": None,
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
    sort: str,
    page: int | None,
    limit: int | None,
) -> dict:
    params = normalize_page(page, limit, default_size=20, max_size=50)
    query = await _load_products_query(published_only=True)

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

    sort_map = {
        "newest": Product.created_at.desc(),
        "price_asc": Product.price.asc(),
        "price_desc": Product.price.desc(),
        "most_viewed": Product.views_count.desc(),
    }
    query = query.order_by(sort_map.get(sort, Product.created_at.desc()))

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
    existing = await db.execute(
        select(ProductView.id).where(
            ProductView.user_id == viewer_id,
            ProductView.product_id == product_id,
            ProductView.day_bucket == bucket,
        )
    )
    if existing.scalar_one_or_none() is not None:
        return

    db.add(ProductView(user_id=viewer_id, product_id=product_id, day_bucket=bucket))
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


async def delete_product_image(db: AsyncSession, *, user: User, image_id: int) -> None:
    result = await db.execute(select(ProductImage).where(ProductImage.id == image_id))
    image = result.scalar_one_or_none()
    if image is None or image.uploader_id != user.id:
        raise AppError(
            message="Rasm topilmadi",
            error_code="PRODUCT_IMAGE_NOT_FOUND",
            status_code=400,
        )
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

    data = payload.model_dump(exclude_unset=True)
    attributes = data.pop("attributes", None)
    image_ids = data.pop("image_ids", None)
    primary_image_id = data.pop("primary_image_id", None)
    new_status = data.pop("status", None)

    for field, value in data.items():
        if field in {"name", "short_description", "description"} and isinstance(value, str):
            value = value.strip()
        setattr(product, field, value)

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

    if new_status is not None:
        if new_status not in {"draft", "published", "archived"}:
            raise AppError(
                message="Status noto'g'ri",
                error_code="VALIDATION_ERROR",
                status_code=400,
            )
        product.status = new_status

    if image_ids is not None:
        await _attach_images(
            db,
            product=product,
            seller_id=user.id,
            image_ids=image_ids,
            primary_image_id=primary_image_id,
        )

    await db.refresh(product, attribute_names=["images", "seller"])
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
        .options(selectinload(Product.images))
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
