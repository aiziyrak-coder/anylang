from __future__ import annotations

import logging
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

logger = logging.getLogger(__name__)

MAX_IMAGES_PER_PRODUCT = 10
MAX_IMAGE_BYTES = 5 * 1024 * 1024
ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}
MAX_VIDEO_BYTES = 25 * 1024 * 1024
ALLOWED_VIDEO_TYPES = {"video/mp4", "video/quicktime", "video/webm", "video/x-m4v"}
MAX_PENDING_TOP_REQUESTS = 3
PRODUCT_TOP_BOOST_DAYS = 7
PRODUCT_TOP_SLOTS = 10


def _aware(dt: datetime | None) -> datetime | None:
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=UTC)
    return dt


def is_effectively_top_pinned(product: Product) -> bool:
    """Paid boost expires via top_pinned_until; admin pin may have until=None."""
    if not product.is_top_pinned:
        return False
    until = _aware(product.top_pinned_until)
    if until is None:
        return True
    return until > datetime.now(UTC)


async def count_active_top_slots(db: AsyncSession) -> int:
    now = datetime.now(UTC)
    result = await db.execute(
        select(func.count())
        .select_from(Product)
        .where(
            Product.is_top_pinned.is_(True),
            or_(
                Product.top_pinned_until.is_(None),
                Product.top_pinned_until > now,
            ),
        )
    )
    return int(result.scalar() or 0)


async def _activate_top_slot(
    db: AsyncSession,
    *,
    product: Product,
    req: ProductTopRequest,
    days: int,
    now: datetime | None = None,
) -> None:
    now = now or datetime.now(UTC)
    until = now + timedelta(days=max(1, days))
    product.is_top_pinned = True
    product.top_pinned_until = until
    if product.status != "published":
        product.status = "published"
    req.status = "active"
    req.activated_at = now
    req.expires_at = until


async def _extend_top_slot(
    db: AsyncSession,
    *,
    product: Product,
    days: int,
    payment_id: int | None = None,
    seller_id: int | None = None,
    now: datetime | None = None,
) -> ProductTopRequest:
    """Uzaytirish — navbatsiz, joriy muddatga +N kun."""
    now = now or datetime.now(UTC)
    until = _aware(product.top_pinned_until)
    base = until if (product.is_top_pinned and until and until > now) else now
    new_until = base + timedelta(days=max(1, days))
    product.is_top_pinned = True
    product.top_pinned_until = new_until
    if product.status != "published":
        product.status = "published"

    result = await db.execute(
        select(ProductTopRequest)
        .where(
            ProductTopRequest.product_id == product.id,
            ProductTopRequest.status == "active",
        )
        .order_by(ProductTopRequest.created_at.desc())
        .limit(1)
    )
    req = result.scalar_one_or_none()
    if req is None:
        req = ProductTopRequest(
            product_id=product.id,
            seller_id=seller_id or product.seller_id,
            status="active",
            note="extend",
            payment_id=payment_id,
            paid_at=now,
            activated_at=now,
            expires_at=new_until,
        )
        db.add(req)
    else:
        req.expires_at = new_until
        if payment_id is not None:
            req.payment_id = payment_id
            req.paid_at = now
    await db.flush()
    return req


async def promote_top_queue(db: AsyncSession) -> int:
    """Bo'sh slot bo'lsa — to'langan navbatdan FIFO bo'yicha chiqaradi."""
    now = datetime.now(UTC)
    promoted = 0
    while await count_active_top_slots(db) < PRODUCT_TOP_SLOTS:
        result = await db.execute(
            select(ProductTopRequest, Product)
            .join(Product, Product.id == ProductTopRequest.product_id)
            .where(ProductTopRequest.status == "queued")
            .order_by(
                ProductTopRequest.paid_at.asc().nullslast(),
                ProductTopRequest.id.asc(),
            )
            .limit(1)
        )
        row = result.one_or_none()
        if row is None:
            break
        req, product = row
        if product.status == "archived":
            req.status = "cancelled"
            req.reviewed_at = now
            await db.flush()
            continue
        await _activate_top_slot(
            db,
            product=product,
            req=req,
            days=PRODUCT_TOP_BOOST_DAYS,
            now=now,
        )
        promoted += 1
        await db.flush()
    return promoted


async def expire_stale_top_pins(db: AsyncSession) -> int:
    """Muddati o'tgan Top ni yechadi va navbatdan keyingisini chiqaradi."""
    now = datetime.now(UTC)
    expired_result = await db.execute(
        select(Product).where(
            Product.is_top_pinned.is_(True),
            Product.top_pinned_until.is_not(None),
            Product.top_pinned_until <= now,
        )
    )
    expired_products = list(expired_result.scalars().all())
    for product in expired_products:
        product.is_top_pinned = False
        await db.execute(
            update(ProductTopRequest)
            .where(
                ProductTopRequest.product_id == product.id,
                ProductTopRequest.status == "active",
            )
            .values(status="expired", expires_at=product.top_pinned_until or now)
        )
    if expired_products:
        await db.flush()
    promoted = await promote_top_queue(db)
    return len(expired_products) + promoted

PRODUCT_CATEGORIES: dict[str, dict[str, str]] = {
    "clothing_accessories": {
        "uz_UZ": "Kiyim & aksessuar",
        "ru_RU": "Одежда и аксессуары",
        "us_US": "Clothing & accessories",
    },
    "pottery": {"uz_UZ": "Kulolchilik", "ru_RU": "Керамика", "us_US": "Pottery"},
    "woodwork": {
        "uz_UZ": "Yog‘och buyumlar",
        "ru_RU": "Изделия из дерева",
        "us_US": "Woodwork",
    },
    "jewelry": {"uz_UZ": "Taqinchoq", "ru_RU": "Украшения", "us_US": "Jewelry"},
    "agriculture_food": {
        "uz_UZ": "Qishloq xo‘jaligi va oziq-ovqat",
        "ru_RU": "Сельское хозяйство и продукты",
        "us_US": "Agriculture & food",
    },
    "animals_pets": {
        "uz_UZ": "Hayvonlar / pet",
        "ru_RU": "Животные / pet",
        "us_US": "Animals & pets",
    },
    "apparel_footwear": {
        "uz_UZ": "Poyabzal",
        "ru_RU": "Обувь",
        "us_US": "Footwear",
    },
    "auto_parts": {
        "uz_UZ": "Avto ehtiyot qismlari",
        "ru_RU": "Автозапчасти",
        "us_US": "Auto parts",
    },
    "beauty_personal_care": {
        "uz_UZ": "Go‘zallik / shaxsiy gigiyena",
        "ru_RU": "Красота и уход",
        "us_US": "Beauty & personal care",
    },
    "building_materials": {
        "uz_UZ": "Qurilish materiallari",
        "ru_RU": "Стройматериалы",
        "us_US": "Building materials",
    },
    "chemicals": {"uz_UZ": "Kimyo", "ru_RU": "Химия", "us_US": "Chemicals"},
    "consumer_electronics": {
        "uz_UZ": "Maishiy elektronika",
        "ru_RU": "Бытовая электроника",
        "us_US": "Consumer electronics",
    },
    "electrical_equipment": {
        "uz_UZ": "Elektr jihozlari",
        "ru_RU": "Электрооборудование",
        "us_US": "Electrical equipment",
    },
    "energy_solar": {
        "uz_UZ": "Energetika / quyosh",
        "ru_RU": "Энергетика / солнечная",
        "us_US": "Energy & solar",
    },
    "environment_recycling": {
        "uz_UZ": "Ekologiya / qayta ishlash",
        "ru_RU": "Экология / переработка",
        "us_US": "Environment & recycling",
    },
    "fabric_textiles": {
        "uz_UZ": "Matolar / to‘qimachilik",
        "ru_RU": "Ткани / текстиль",
        "us_US": "Fabric & textiles",
    },
    "furniture": {"uz_UZ": "Mebel", "ru_RU": "Мебель", "us_US": "Furniture"},
    "gifts_crafts": {
        "uz_UZ": "Sovg‘alar / hunarmandchilik",
        "ru_RU": "Подарки / хендмейд",
        "us_US": "Gifts & crafts",
    },
    "hardware_tools": {
        "uz_UZ": "Asbob-uskuna",
        "ru_RU": "Инструменты / hardware",
        "us_US": "Hardware & tools",
    },
    "health_medical": {
        "uz_UZ": "Tibbiyot / sog‘liq",
        "ru_RU": "Медицина / здоровье",
        "us_US": "Health & medical",
    },
    "home_garden": {
        "uz_UZ": "Uy-ro‘zg‘or / bog‘",
        "ru_RU": "Дом и сад",
        "us_US": "Home & garden",
    },
    "industrial_machinery": {
        "uz_UZ": "Sanoat uskunalari",
        "ru_RU": "Промышленное оборудование",
        "us_US": "Industrial machinery",
    },
    "it_software": {
        "uz_UZ": "IT / dasturiy ta’minot",
        "ru_RU": "IT / ПО",
        "us_US": "IT & software",
    },
    "lighting": {"uz_UZ": "Yorug‘lik", "ru_RU": "Освещение", "us_US": "Lighting"},
    "luggage_bags": {
        "uz_UZ": "Sumka / yuk",
        "ru_RU": "Сумки / багаж",
        "us_US": "Luggage & bags",
    },
    "metals_minerals": {
        "uz_UZ": "Metall / mineral",
        "ru_RU": "Металлы / минералы",
        "us_US": "Metals & minerals",
    },
    "office_school": {
        "uz_UZ": "Ofis / maktab",
        "ru_RU": "Офис / школа",
        "us_US": "Office & school",
    },
    "packaging_printing": {
        "uz_UZ": "Qadoqlash / bosma",
        "ru_RU": "Упаковка / печать",
        "us_US": "Packaging & printing",
    },
    "plastic_rubber": {
        "uz_UZ": "Plastmassa / kauchuk",
        "ru_RU": "Пластик / резина",
        "us_US": "Plastic & rubber",
    },
    "security_protection": {
        "uz_UZ": "Xavfsizlik",
        "ru_RU": "Безопасность",
        "us_US": "Security & protection",
    },
    "sports_outdoors": {
        "uz_UZ": "Sport / outdoor",
        "ru_RU": "Спорт / outdoor",
        "us_US": "Sports & outdoors",
    },
    "toys_kids": {
        "uz_UZ": "O‘yinchoq / bolalar",
        "ru_RU": "Игрушки / дети",
        "us_US": "Toys & kids",
    },
    "transportation": {
        "uz_UZ": "Transport vositalari",
        "ru_RU": "Транспорт",
        "us_US": "Transportation",
    },
    "telecom": {"uz_UZ": "Telekom", "ru_RU": "Телеком", "us_US": "Telecom"},
    "services_b2b": {
        "uz_UZ": "B2B xizmatlar",
        "ru_RU": "B2B услуги",
        "us_US": "B2B services",
    },
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

    # draft / pending / rejected — faqat egasi ko'radi
    if product.status in {"draft", "pending", "rejected"} and not (
        allow_owner_draft and is_owner
    ):
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
    """Faqat boost qilingan (is_top_pinned) mahsulotlar — max 10.
    Yangi e'lon avtomatik Topga tushmasin.
    Muddati o'tgan pinlarni expire_stale_top_pins (ARQ cron) yechadi.
    """
    now = datetime.now(UTC)
    pinned_result = await db.execute(
        select(Product.id)
        .join(User, User.id == Product.seller_id)
        .join(Subscription, Subscription.user_id == User.id)
        .where(
            Product.status == "published",
            Product.is_top_pinned.is_(True),
            or_(
                Product.top_pinned_until.is_(None),
                Product.top_pinned_until > now,
            ),
            _seller_filter(),
        )
        .order_by(Product.top_pinned_until.desc().nullslast(), Product.created_at.desc())
        .limit(max(1, min(limit, 10)))
    )
    return list(pinned_result.scalars().all())


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
                    logger.warning(
                        "S3 delete failed for product image key=%s",
                        key,
                        exc_info=True,
                    )
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
                    logger.warning(
                        "S3 delete failed for product image key=%s",
                        key,
                        exc_info=True,
                    )
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
    lang: str | None = None,
) -> dict:
    from app.services.catalog_i18n import pick_i18n

    effectively_pinned = is_effectively_top_pinned(product)
    is_top = force_top if force_top is not None else (
        effectively_pinned or (top_ids is not None and product.id in top_ids)
    )
    seller = getattr(product, "seller", None)
    trust = build_product_trust_badges(
        seller.business if seller is not None else None,
        user=seller,
    )
    name = pick_i18n(getattr(product, "name_i18n", None), product.name, lang)
    short = pick_i18n(
        getattr(product, "short_description_i18n", None),
        product.short_description,
        lang,
    )
    return {
        "id": product.id,
        "name": name,
        "short_description": short,
        "price": _format_price(product.price),
        "currency": product.currency,
        "primary_image_url": _primary_url(product),
        "views_count": product.views_count,
        "is_top": is_top,
        "top_pinned_until": product.top_pinned_until if effectively_pinned else None,
        "is_favorited": product.id in favorite_ids,
        "status": product.status,
        "moderation_note": (product.moderation_note or "") if product.status == "rejected" else "",
        "moderated_at": product.moderated_at,
        "seller_id": product.seller_id,
        "created_at": product.created_at,
        "trust_badges": trust,
        "capabilities": _normalize_capabilities(product.capabilities),
        "source_lang": getattr(product, "source_lang", None),
    }


async def _serialize_detail(
    db: AsyncSession,
    product: Product,
    *,
    favorite_ids: set[int],
    top_ids: set[int] | None = None,
    viewer: User | None = None,
) -> dict:
    from app.integrations.translation import user_preferred_lang
    from app.services.catalog_i18n import pick_i18n

    lang = user_preferred_lang(viewer) if viewer is not None else None
    base = await _serialize_product(
        product, favorite_ids=favorite_ids, top_ids=top_ids, lang=lang
    )
    marketplace = _effective_marketplace_fields(product, product.seller)
    base.update(
        {
            "description": pick_i18n(
                getattr(product, "description_i18n", None),
                product.description,
                lang,
            ),
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
            .where(
                ProductTopRequest.product_id == product.id,
                ProductTopRequest.status.in_(("queued", "active", "pending")),
            )
            .order_by(ProductTopRequest.created_at.desc())
            .limit(1)
        )
        req = result.scalar_one_or_none()
        if req is None:
            # Eng so'nggi yopilgan so'rov (UI uchun)
            result = await db.execute(
                select(ProductTopRequest)
                .where(ProductTopRequest.product_id == product.id)
                .order_by(ProductTopRequest.created_at.desc())
                .limit(1)
            )
            req = result.scalar_one_or_none()
        if req is not None:
            base["top_request"] = await _serialize_top_request(db, req, product=product)
    return base


def _seconds_until(dt: datetime | None) -> int | None:
    until = _aware(dt)
    if until is None:
        return None
    return max(0, int((until - datetime.now(UTC)).total_seconds()))


async def _queue_position(db: AsyncSession, req: ProductTopRequest) -> int | None:
    if req.status != "queued":
        return None
    paid_at = _aware(req.paid_at) or _aware(req.created_at)
    earlier = await db.execute(
        select(func.count())
        .select_from(ProductTopRequest)
        .where(
            ProductTopRequest.status == "queued",
            or_(
                and_(
                    ProductTopRequest.paid_at.is_not(None),
                    ProductTopRequest.paid_at < (paid_at or datetime.now(UTC)),
                ),
                and_(
                    ProductTopRequest.paid_at.is_(None),
                    ProductTopRequest.created_at < (paid_at or datetime.now(UTC)),
                ),
                and_(
                    ProductTopRequest.paid_at == paid_at,
                    ProductTopRequest.id < req.id,
                ),
            ),
        )
    )
    return int(earlier.scalar() or 0) + 1


async def _serialize_top_request(
    db: AsyncSession,
    req: ProductTopRequest,
    *,
    product: Product | None = None,
) -> dict:
    expires_at = req.expires_at
    if req.status == "active" and product is not None and product.top_pinned_until is not None:
        expires_at = product.top_pinned_until
    effectively = is_effectively_top_pinned(product) if product is not None else False
    return {
        "id": req.id,
        "product_id": req.product_id,
        "seller_id": req.seller_id,
        "status": req.status,
        "note": req.note or "",
        "admin_note": req.admin_note or "",
        "created_at": req.created_at,
        "reviewed_at": req.reviewed_at,
        "paid_at": req.paid_at,
        "activated_at": req.activated_at,
        "expires_at": expires_at,
        "seconds_left": _seconds_until(expires_at) if req.status == "active" else None,
        "queue_position": await _queue_position(db, req),
        "can_extend": effectively and req.status == "active",
        "product_name": product.name if product is not None else None,
        "is_top_pinned": effectively if product is not None else None,
        "price_usd": "30.00",
        "period_days": PRODUCT_TOP_BOOST_DAYS,
        "max_slots": PRODUCT_TOP_SLOTS,
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

    from app.integrations.translation import user_preferred_lang

    lang = user_preferred_lang(viewer)
    items = [
        await _serialize_product(p, favorite_ids=fav_ids, top_ids=top_ids, lang=lang)
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

    from app.integrations.translation import user_preferred_lang

    lang = user_preferred_lang(viewer)
    items = [
        await _serialize_product(
            p, favorite_ids=fav_ids, force_top=True, lang=lang
        )
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
            logger.warning(
                "S3 delete failed for product image key=%s",
                key,
                exc_info=True,
            )
    await db.delete(image)


async def create_product(db: AsyncSession, *, user: User, payload: ProductCreateIn) -> dict:
    await _require_business_account(user)
    from app.services import product_moderation as product_moderation_service

    await product_moderation_service.assert_can_submit_listing(db, user)

    # Mijoz "published" yuborsa — avtomatik e'lon emas, moderatsiya navbati
    requested = payload.status
    if requested not in {"draft", "pending", "published"}:
        raise AppError(
            message="Status qoralama yoki moderatsiyaga yuborish bo'lishi kerak",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )
    effective_status = "pending" if requested in {"published", "pending"} else "draft"

    name = payload.name.strip()
    short_description = _normalize_short_description(
        name, payload.short_description, payload.description
    )
    description = payload.description.strip()

    if effective_status == "draft":
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
        status=effective_status,
        moderation_note="",
        submitted_at=datetime.now(UTC) if effective_status == "pending" else None,
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

    if effective_status == "pending":
        await product_moderation_service.apply_ai_pre_score(db, product)

    if not product.source_lang:
        from app.integrations.translation import user_preferred_lang

        product.source_lang = user_preferred_lang(user)
        await db.flush()

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

    from app.services import product_moderation as product_moderation_service

    was_published = product.status == "published"
    data = payload.model_dump(exclude_unset=True)
    attributes = data.pop("attributes", None)
    capabilities = data.pop("capabilities", None)
    image_ids = data.pop("image_ids", None)
    primary_image_id = data.pop("primary_image_id", None)
    new_status = data.pop("status", None)

    content_keys = {
        "name",
        "short_description",
        "description",
        "price",
        "currency",
        "category",
        "video_url",
        "factory_video_url",
        "process_video_url",
        "moq",
        "shipping_info",
        "shipping_countries",
    }
    content_changed = bool(content_keys & set(data.keys())) or attributes is not None or (
        image_ids is not None
    )

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

    # Mijoz published yuborsa → pending (admin tasdiqlamaguncha e'lon emas)
    if new_status == "published":
        new_status = "pending"
    if new_status == "pending" or (
        was_published and content_changed and new_status is None
    ):
        # E'lon qilingan mahsulot o'zgarsa ham qayta moderatsiya
        if new_status is None and was_published and content_changed:
            new_status = "pending"

    target_status = new_status or product.status
    if target_status in {"published", "pending"}:
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
        if new_status not in {"draft", "pending", "archived"}:
            raise AppError(
                message="Status noto'g'ri",
                error_code="VALIDATION_ERROR",
                status_code=400,
            )
        product.status = new_status
        if new_status == "pending":
            await product_moderation_service.assert_can_submit_listing(db, user)
            product.moderation_note = ""
            product.moderated_at = None
            product.moderated_by = None
            product.is_top_pinned = False
            product.top_pinned_until = None
            product.submitted_at = datetime.now(UTC)
        elif new_status == "draft":
            product.is_top_pinned = False
            product.top_pinned_until = None

    # Content change on published → pending path above may set new_status via target
    if (new_status == "pending" or product.status == "pending") and (
        new_status == "pending" or (was_published and content_changed)
    ):
        if product.status == "pending" and product.submitted_at is None:
            product.submitted_at = datetime.now(UTC)

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
    if product.status == "pending":
        await product_moderation_service.apply_ai_pre_score(db, product)
    text_changed = bool(
        {"name", "short_description", "description"} & set(data.keys())
    )
    # Tarjima / feed faqat published holatda (admin approve)
    if product.status == "published" and (
        text_changed or not was_published or not (product.name_i18n or {})
    ):
        from app.integrations.translation import user_preferred_lang
        from app.services.catalog_i18n import enqueue_catalog_translate

        if not product.source_lang:
            product.source_lang = user_preferred_lang(user)
            await db.flush()
        await enqueue_catalog_translate(
            kind="product",
            entity_id=product.id,
            source_lang=product.source_lang or "uz",
            defer_seconds=2,
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


async def moderate_product(
    db: AsyncSession,
    *,
    product_id: int,
    admin_id: int,
    approve: bool,
    admin_note: str | None = None,
) -> dict:
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
    if product.status not in {"pending", "rejected", "draft", "published"}:
        raise AppError(
            message="Bu mahsulotni moderatsiya qilib bo'lmaydi",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )

    note = (admin_note or "").strip()
    now = datetime.now(UTC)
    strike = None
    from app.services import product_moderation as product_moderation_service

    if approve:
        _validate_published_payload(
            name=product.name,
            short_description=product.short_description,
            description=product.description,
            price=product.price,
            currency=product.currency,
            category=product.category,
            image_ids=[img.id for img in product.images],
            attributes=product.attributes or [],
        )
        was_published = product.status == "published"
        product.status = "published"
        product.moderation_note = ""
        product.moderated_at = now
        product.moderated_by = admin_id
        await db.flush()
        if not was_published:
            from app.services.feed import create_system_post

            primary = next(
                (img.url for img in (product.images or []) if img.is_primary),
                (product.images[0].url if product.images else None),
            )
            await create_system_post(
                db,
                user=product.seller,
                post_type="new_product",
                title=product.name,
                body=(product.short_description or product.description or "")[:400],
                image_url=primary,
                meta={"product_id": product.id},
            )
        from app.integrations.translation import user_preferred_lang
        from app.services.catalog_i18n import enqueue_catalog_translate

        if not product.source_lang:
            product.source_lang = user_preferred_lang(product.seller)
            await db.flush()
        await enqueue_catalog_translate(
            kind="product",
            entity_id=product.id,
            source_lang=product.source_lang or "uz",
            defer_seconds=2,
        )
        await product_moderation_service.clear_strike_on_approve(
            db, seller_id=product.seller_id
        )
    else:
        if len(note) < 3:
            raise AppError(
                message="Rad etish sababi majburiy",
                error_code="VALIDATION_ERROR",
                status_code=400,
            )
        product.status = "rejected"
        product.moderation_note = note[:500]
        product.moderated_at = now
        product.moderated_by = admin_id
        product.is_top_pinned = False
        product.top_pinned_until = None
        await db.flush()
        strike = await product_moderation_service.apply_reject_strike(
            db, seller_id=product.seller_id
        )

    out = {
        "id": product.id,
        "status": product.status,
        "moderation_note": product.moderation_note or "",
        "moderated_at": product.moderated_at,
        "moderated_by": product.moderated_by,
        "name": product.name,
        "seller_id": product.seller_id,
    }
    if strike is not None:
        out["seller_strike"] = strike
    return out


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
    result = await db.execute(query.offset(params.offset).limit(params.page_size))
    products = list(result.scalars().unique().all())
    fav_ids = await _favorite_ids(db, user.id, [p.id for p in products])
    top_ids = set(await _top_product_ids(db))

    open_reqs: dict[int, ProductTopRequest] = {}
    if products:
        req_rows = await db.execute(
            select(ProductTopRequest)
            .where(
                ProductTopRequest.product_id.in_([p.id for p in products]),
                ProductTopRequest.status.in_(("queued", "active", "pending")),
            )
            .order_by(ProductTopRequest.created_at.desc())
        )
        for req in req_rows.scalars().all():
            open_reqs.setdefault(req.product_id, req)

    from app.integrations.translation import user_preferred_lang

    lang = user_preferred_lang(user)
    items = []
    for p in products:
        row = await _serialize_product(
            p, favorite_ids=fav_ids, top_ids=top_ids, lang=lang
        )
        req = open_reqs.get(p.id)
        if req is not None:
            row["top_request"] = await _serialize_top_request(db, req, product=p)
        else:
            row["top_request"] = None
        items.append(row)
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
    """Eski bepul so'rov o'chirildi — faqat $30/hafta to'lov."""
    del db, user, product_id, note
    raise AppError(
        message="TOP uchun to'lov kerak: $30 / 1 hafta. Bo'sh joy bo'lmasa navbatga yozilasiz.",
        error_code="PRODUCT_TOP_PAYMENT_REQUIRED",
        status_code=400,
    )


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
            ProductTopRequest.status.in_(("pending", "queued")),
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
    if req.status == "queued" and req.payment_id is not None:
        raise AppError(
            message="To'langan navbatni bekor qilib bo'lmaydi — navbat kelganda Topga chiqadi",
            error_code="TOP_QUEUE_PAID",
            status_code=400,
        )
    req.status = "cancelled"
    req.reviewed_at = datetime.now(UTC)
    await db.flush()
    return await _serialize_top_request(db, req, product=product)


async def list_top_requests(
    db: AsyncSession,
    *,
    status: str | None = None,
    page: int | None = None,
    limit: int | None = None,
) -> dict:
    await expire_stale_top_pins(db)
    params = normalize_page(page, limit, default_size=50, max_size=100)
    query = select(ProductTopRequest, Product).join(
        Product, Product.id == ProductTopRequest.product_id
    )
    allowed = {
        "pending",
        "approved",
        "rejected",
        "cancelled",
        "queued",
        "active",
        "expired",
    }
    if status in allowed:
        query = query.where(ProductTopRequest.status == status)
    if status == "queued":
        query = query.order_by(
            ProductTopRequest.paid_at.asc().nullslast(),
            ProductTopRequest.id.asc(),
        )
    elif status == "active":
        query = query.order_by(ProductTopRequest.expires_at.asc().nullslast())
    else:
        query = query.order_by(ProductTopRequest.created_at.desc())

    count_query = select(func.count()).select_from(query.order_by(None).subquery())
    total = int((await db.execute(count_query)).scalar() or 0)
    rows = list(
        (await db.execute(query.offset(params.offset).limit(params.page_size))).all()
    )
    items = [
        await _serialize_top_request(db, req, product=product) for req, product in rows
    ]
    return {
        "items": items,
        "page": params.page,
        "limit": params.page_size,
        "total": total,
        "has_more": params.offset + len(items) < total,
        "slots_used": await count_active_top_slots(db),
        "max_slots": PRODUCT_TOP_SLOTS,
        "price_usd": "30.00",
        "period_days": PRODUCT_TOP_BOOST_DAYS,
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
        slots = await count_active_top_slots(db)
        if slots >= PRODUCT_TOP_SLOTS:
            req.status = "queued"
            req.paid_at = datetime.now(UTC)
        else:
            await _activate_top_slot(
                db,
                product=product,
                req=req,
                days=PRODUCT_TOP_BOOST_DAYS,
            )
            req.status = "active"
    await db.flush()
    return await _serialize_top_request(db, req, product=product)


async def prepare_product_top_checkout(
    db: AsyncSession,
    *,
    user: User,
    product_id: int,
    mode: str = "boost",
) -> tuple[Product, str]:
    """Validate ownership before creating a $30/week TOP boost payment.

    Returns (product, resolved_mode) where mode is 'boost' | 'extend'.
    """
    await expire_stale_top_pins(db)
    await _require_business_account(user)
    product = await _get_product_or_404(
        db, product_id, viewer=user, allow_owner_draft=True
    )
    if product.seller_id != user.id:
        raise AppError(
            message="Bu mahsulot sizga tegishli emas",
            error_code="NOT_PRODUCT_OWNER",
            status_code=403,
        )
    if product.status != "published":
        raise AppError(
            message="Faqat e'lon qilingan mahsulot uchun TOP boost",
            error_code="PRODUCT_NOT_PUBLISHED",
            status_code=400,
        )

    resolved = (mode or "boost").strip().lower()
    if resolved not in {"boost", "extend"}:
        resolved = "boost"

    open_req = (
        await db.execute(
            select(ProductTopRequest)
            .where(
                ProductTopRequest.product_id == product.id,
                ProductTopRequest.status.in_(("queued", "active", "pending")),
            )
            .order_by(ProductTopRequest.created_at.desc())
            .limit(1)
        )
    ).scalar_one_or_none()

    if is_effectively_top_pinned(product) or (
        open_req is not None and open_req.status == "active"
    ):
        # Topda turgan mahsulot — faqat uzaytirish.
        return product, "extend"

    if open_req is not None and open_req.status == "queued":
        raise AppError(
            message="Mahsulot allaqachon Top navbatida — navbat kelganda avtomatik chiqadi",
            error_code="TOP_ALREADY_QUEUED",
            status_code=409,
        )

    if resolved == "extend":
        raise AppError(
            message="Mahsulot hozir Topda emas — avval Topga chiqaring",
            error_code="NOT_TOP_PINNED",
            status_code=400,
        )

    return product, "boost"


async def activate_product_top_from_payment(db: AsyncSession, payment) -> Product:
    """To'lovdan keyin: slot bo'sh → Top; to'liq → navbat; Topda → uzaytirish."""
    await expire_stale_top_pins(db)
    meta = payment.meta or {}
    try:
        product_id = int(meta.get("product_id"))
    except (TypeError, ValueError) as exc:
        raise AppError(
            message="Noto'g'ri mahsulot TOP to'lovi",
            error_code="PAYMENT_INVALID",
            status_code=400,
        ) from exc
    try:
        days = int(meta.get("days") or PRODUCT_TOP_BOOST_DAYS)
    except (TypeError, ValueError):
        days = PRODUCT_TOP_BOOST_DAYS
    days = max(1, min(days, 366))
    mode = str(meta.get("mode") or "boost").strip().lower()

    product = await db.get(Product, product_id)
    if product is None:
        raise AppError(
            message="Mahsulot topilmadi",
            error_code="PRODUCT_NOT_FOUND",
            status_code=404,
        )
    if product.seller_id != payment.user_id:
        raise AppError(
            message="To'lov egasi mahsulot egasi emas",
            error_code="PAYMENT_INVALID",
            status_code=400,
        )

    now = datetime.now(UTC)

    if mode == "extend" or is_effectively_top_pinned(product):
        await _extend_top_slot(
            db,
            product=product,
            days=days,
            payment_id=payment.id,
            seller_id=payment.user_id,
            now=now,
        )
        await db.flush()
        return product

    open_req = (
        await db.execute(
            select(ProductTopRequest)
            .where(
                ProductTopRequest.product_id == product.id,
                ProductTopRequest.status.in_(("queued", "active")),
            )
            .order_by(ProductTopRequest.created_at.desc())
            .limit(1)
        )
    ).scalar_one_or_none()

    if open_req is not None and open_req.status == "active":
        await _extend_top_slot(
            db,
            product=product,
            days=days,
            payment_id=payment.id,
            seller_id=payment.user_id,
            now=now,
        )
        await db.flush()
        return product

    if open_req is not None and open_req.status == "queued":
        open_req.payment_id = payment.id
        open_req.paid_at = now
        await db.flush()
        await promote_top_queue(db)
        return product

    slots = await count_active_top_slots(db)
    req = ProductTopRequest(
        product_id=product.id,
        seller_id=product.seller_id,
        status="queued",
        note="paid",
        payment_id=payment.id,
        paid_at=now,
    )
    db.add(req)
    await db.flush()

    if slots < PRODUCT_TOP_SLOTS:
        await _activate_top_slot(
            db,
            product=product,
            req=req,
            days=days,
            now=now,
        )
    await db.flush()
    return product

