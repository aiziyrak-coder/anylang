from __future__ import annotations

import io
import uuid
from datetime import date

from fastapi import UploadFile
from PIL import Image
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.errors import AppError
from app.integrations.storage import get_storage
from app.models.user import BusinessProfile, FactoryImage, User
from app.services import trust_score as trust_score_service
from app.services.business_card import business_card_url
from app.services.factory_verification import build_factory_verification
from app.services.users import (
    _business_completeness,
    _business_stats,
    load_user_for_response,
    serialize_user,
)

MAX_FACTORY_IMAGES = 10
MAX_IMAGE_BYTES = 5 * 1024 * 1024
ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp"}


def _clean_str_list(items: list[str] | None, *, max_items: int = 20, max_len: int = 40) -> list[str]:
    cleaned: list[str] = []
    seen: set[str] = set()
    for raw in items or []:
        value = " ".join(str(raw or "").split()).strip()
        if not value:
            continue
        key = value.upper()
        if key in seen:
            continue
        seen.add(key)
        cleaned.append(value[:max_len])
        if len(cleaned) >= max_items:
            break
    return cleaned


def _trade_fields(business: BusinessProfile) -> dict:
    return {
        "moq": business.moq,
        "production_capacity": business.production_capacity,
        "lead_time": business.lead_time,
        "incoterms": list(business.incoterms or []),
        "payment_methods": list(business.payment_methods or []),
    }


def _ai_profile_fields(business: BusinessProfile) -> dict:
    return {
        "seo_text": business.seo_text,
        "keywords": list(business.keywords or []),
        "description_i18n": dict(business.description_i18n or {}),
    }


def _clean_i18n(raw: dict[str, str] | None) -> dict[str, str]:
    out: dict[str, str] = {}
    if not isinstance(raw, dict):
        return out
    for code, text in raw.items():
        key = str(code or "").strip().lower()[:8]
        val = str(text or "").strip()
        if not key or not val:
            continue
        out[key] = val[:4000]
        if len(out) >= 40:
            break
    return out


def _require_business_account(user: User) -> None:
    if not user.is_business:
        raise AppError(
            message="Biznes tarif talab qilinadi",
            error_code="NOT_A_BUSINESS_ACCOUNT",
            status_code=403,
        )


async def _ensure_business_profile(db: AsyncSession, user: User) -> BusinessProfile:
    _require_business_account(user)
    if user.business is not None:
        return user.business
    profile = BusinessProfile(user_id=user.id, company_name="")
    db.add(profile)
    await db.flush()
    await db.refresh(user, attribute_names=["business"])
    return profile


ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp"}


def _sniff_image_content_type(data: bytes, declared: str | None) -> str:
    """Dio/Flutter ko'pincha application/octet-stream yuboradi — baytlardan aniqlaymiz."""
    raw = (declared or "").split(";")[0].strip().lower()
    if raw in ALLOWED_CONTENT_TYPES:
        return raw
    if data.startswith(b"\xff\xd8\xff"):
        return "image/jpeg"
    if data.startswith(b"\x89PNG\r\n\x1a\n"):
        return "image/png"
    if len(data) >= 12 and data[0:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "image/webp"
    try:
        with Image.open(io.BytesIO(data)) as img:
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


async def _process_image(data: bytes, content_type: str) -> tuple[bytes, str]:
    if len(data) > MAX_IMAGE_BYTES:
        raise AppError(
            message="Rasm hajmi 5 MB dan oshmasligi kerak",
            error_code="FILE_TOO_LARGE",
            status_code=400,
        )
    content_type = _sniff_image_content_type(data, content_type)
    if content_type not in ALLOWED_CONTENT_TYPES:
        raise AppError(
            message="Faqat JPEG, PNG yoki WebP qabul qilinadi",
            error_code="INVALID_FILE_TYPE",
            status_code=400,
        )

    try:
        with Image.open(io.BytesIO(data)) as img:
            img = img.convert("RGB")
            size = min(img.size)
            left = (img.width - size) // 2
            top = (img.height - size) // 2
            img = img.crop((left, top, left + size, top + size))
            img = img.resize((512, 512), Image.Resampling.LANCZOS)
            buf = io.BytesIO()
            img.save(buf, format="WEBP", quality=85)
            return buf.getvalue(), "image/webp"
    except Exception as exc:
        raise AppError(
            message="Rasmni qayta ishlashda xatolik",
            error_code="INVALID_IMAGE",
            status_code=400,
        ) from exc


async def _upload_image(file: UploadFile, key: str) -> str:
    from app.core.uploads import read_upload_limited

    raw = await read_upload_limited(file, max_bytes=MAX_IMAGE_BYTES)
    if not raw:
        raise AppError(message="Fayl bo'sh", error_code="EMPTY_FILE", status_code=400)
    content_type = file.content_type or "application/octet-stream"
    processed, out_type = await _process_image(raw, content_type)
    storage = get_storage()
    return await storage.upload_bytes(key, processed, out_type)


def _key_from_url(url: str | None) -> str | None:
    if not url:
        return None
    settings = get_settings()
    base = settings.s3_public_base_url.rstrip("/")
    if base and url.startswith(base):
        return url[len(base) + 1 :]
    bucket = settings.s3_bucket
    marker = f"/{bucket}/"
    if marker in url:
        return url.split(marker, 1)[1]
    return url.rsplit("/", 1)[-1]


async def update_user_profile(
    db: AsyncSession,
    user: User,
    *,
    full_name: str | None = None,
    birth_date: date | None = None,
    gender: str | None = None,
    country: str | None = None,
    app_language: str | None = None,
    native_language: str | None = None,
    translation_domain: str | None = None,
) -> dict:
    if full_name is not None:
        cleaned = full_name.strip()
        if len(cleaned) < 2:
            raise AppError(
                message="Ism juda qisqa",
                error_code="VALIDATION_ERROR",
                status_code=400,
            )
        user.full_name = cleaned
    if birth_date is not None:
        user.birth_date = birth_date
    if gender is not None:
        g = gender.strip().lower()
        if g not in {"male", "female"}:
            raise AppError(
                message="Jins noto'g'ri",
                error_code="VALIDATION_ERROR",
                status_code=400,
            )
        user.gender = g
    if country is not None:
        code = country.strip().upper()
        if len(code) != 2:
            raise AppError(
                message="Davlat kodi noto'g'ri",
                error_code="VALIDATION_ERROR",
                status_code=400,
            )
        user.country = code
    if app_language is not None:
        user.app_language = app_language
        # Tizim tili = tarjima (ona) tili — bir xil saqlanadi.
        from app.integrations.translation import _normalize_lang

        user.native_language = _normalize_lang(app_language)
    if native_language is not None:
        from app.integrations.translation import _normalize_lang, app_locale_for_iso

        iso = _normalize_lang(native_language)
        user.native_language = iso
        # App tilini ham sync (faqat UI bor tillar).
        if iso in {"uz", "ru", "en"}:
            user.app_language = app_locale_for_iso(iso)
    if translation_domain is not None:
        from app.integrations.translation import normalize_translation_domain

        user.translation_domain = normalize_translation_domain(translation_domain)

    await db.flush()
    loaded = await load_user_for_response(db, user.id)
    assert loaded is not None
    return await serialize_user(loaded, db)


async def upload_avatar(db: AsyncSession, user: User, file: UploadFile) -> dict:
    # Unique key — URL o'zgaradi, telefon cache eski rasmni ko'rsatmaydi.
    key = f"avatars/{user.id}/{uuid.uuid4().hex}.webp"
    url = await _upload_image(file, key)
    if user.avatar_url:
        old_key = _key_from_url(user.avatar_url)
        if old_key and old_key != key:
            try:
                await get_storage().delete_object(old_key)
            except Exception:
                pass
    user.avatar_url = url
    await db.flush()
    return {"avatar_url": url}


async def delete_avatar(db: AsyncSession, user: User) -> None:
    if user.avatar_url:
        old_key = _key_from_url(user.avatar_url)
        if old_key:
            try:
                await get_storage().delete_object(old_key)
            except Exception:
                pass
    user.avatar_url = None
    await db.flush()


async def serialize_business(db: AsyncSession, user: User, redis=None) -> dict:
    _require_business_account(user)
    business = await _ensure_business_profile(db, user)
    stats = await _business_stats(db, user.id, business)
    has_listing = stats["listings_count"] > 0
    trust = await trust_score_service.compute_trust_score(db, user, business)
    from app.services import scam_detection as scam_detection_service

    scam = await scam_detection_service.compute_scam_risk(
        db,
        user,
        business,
        redis=redis,
        locale=user.app_language or "uz",
        trust=trust,
    )
    factory = build_factory_verification(business, user=user)
    from app.services import verification as verification_service

    ver_status = await verification_service.verification_status_summary(
        db, user, business
    )
    return {
        "company_name": business.company_name,
        "logo_url": business.logo_url,
        "country": business.country,
        "business_role": business.business_role,
        "website": business.website,
        "bio": (business.bio or "").strip() or None,
        "description": business.description,
        "founded_year": business.founded_year,
        "certificates": list(business.certificates or []),
        "export_countries": list(stats.get("export_countries") or []),
        **_trade_fields(business),
        **_ai_profile_fields(business),
        "successful_deals": int(business.successful_deals or 0),
        "complaints_count": int(business.complaints_count or 0),
        "documents_verified": bool(
            business.documents_verified or user.verified_badge
        ),
        "verification_status": ver_status,
        "factory_verified": bool(factory["factory_verified"]),
        "inspection_passed": bool(factory["inspection_passed"]),
        "audit_report_url": factory["audit_report_url"],
        "factory_verification": factory,
        "trust_score": trust,
        "scam_risk": scam,
        "factory_images": [
            {"id": img.id, "url": img.url} for img in (business.factory_images or [])
        ],
        "completeness": _business_completeness(business, has_listing=has_listing),
        "stats": stats,
        "business_card_url": business_card_url(user.id),
    }


async def update_business(
    db: AsyncSession,
    user: User,
    *,
    company_name: str | None = None,
    country: str | None = None,
    business_role: str | None = None,
    website: str | None = None,
    bio: str | None = None,
    description: str | None = None,
    seo_text: str | None = None,
    keywords: list[str] | None = None,
    description_i18n: dict[str, str] | None = None,
    founded_year: int | None = None,
    certificates: list[str] | None = None,
    export_countries: list[str] | None = None,
    moq: str | None = None,
    production_capacity: str | None = None,
    lead_time: str | None = None,
    incoterms: list[str] | None = None,
    payment_methods: list[str] | None = None,
) -> dict:
    business = await _ensure_business_profile(db, user)
    if company_name is not None:
        business.company_name = company_name.strip()
    if country is not None:
        business.country = country.upper()
    if business_role is not None:
        business.business_role = business_role
    if website is not None:
        business.website = website.strip() or None
    if bio is not None:
        cleaned = bio.strip()
        if len(cleaned) > 300:
            raise AppError(
                message="Bio 300 belgidan oshmasligi kerak",
                error_code="VALIDATION_ERROR",
                status_code=400,
            )
        business.bio = cleaned or None
    if description is not None:
        business.description = description.strip() or None
    if seo_text is not None:
        business.seo_text = seo_text.strip() or None
    if keywords is not None:
        business.keywords = _clean_str_list(keywords, max_items=20, max_len=48)
    if description_i18n is not None:
        business.description_i18n = _clean_i18n(description_i18n)
    if founded_year is not None:
        business.founded_year = founded_year
    old_certs = set(str(c).strip().lower() for c in (business.certificates or []) if str(c).strip())
    if certificates is not None:
        business.certificates = _clean_str_list(certificates, max_items=30, max_len=64)
        new_certs = [
            c
            for c in business.certificates
            if c.strip().lower() not in old_certs
        ]
        if new_certs:
            from app.services.feed import create_system_post

            await create_system_post(
                db,
                user=user,
                post_type="new_certificate",
                title=new_certs[0],
                body=", ".join(new_certs[:5]),
                meta={"certificates": new_certs[:10]},
            )
    if export_countries is not None:
        cleaned: list[str] = []
        seen: set[str] = set()
        for raw in export_countries:
            code = str(raw or "").strip().upper()
            if len(code) != 2 or code in seen:
                continue
            seen.add(code)
            cleaned.append(code)
            if len(cleaned) >= 40:
                break
        business.export_countries = cleaned
    if moq is not None:
        business.moq = moq.strip() or None
    if production_capacity is not None:
        business.production_capacity = production_capacity.strip() or None
    if lead_time is not None:
        business.lead_time = lead_time.strip() or None
    if incoterms is not None:
        business.incoterms = _clean_str_list(incoterms, max_items=12, max_len=16)
    if payment_methods is not None:
        business.payment_methods = _clean_str_list(payment_methods, max_items=12, max_len=40)

    await db.flush()
    return await serialize_business(db, user)


async def upload_business_logo(db: AsyncSession, user: User, file: UploadFile) -> dict:
    business = await _ensure_business_profile(db, user)
    key = f"logos/{user.id}/{uuid.uuid4().hex}.webp"
    url = await _upload_image(file, key)
    if business.logo_url:
        old_key = _key_from_url(business.logo_url)
        if old_key and old_key != key:
            try:
                await get_storage().delete_object(old_key)
            except Exception:
                pass
    business.logo_url = url
    await db.flush()
    return {"logo_url": url}


async def add_factory_image(db: AsyncSession, user: User, file: UploadFile) -> dict:
    business = await _ensure_business_profile(db, user)
    await db.refresh(business, attribute_names=["factory_images"])
    if len(business.factory_images or []) >= MAX_FACTORY_IMAGES:
        raise AppError(
            message="Zavod rasmlari limiti (10 ta) to'lgan",
            error_code="FACTORY_IMAGES_LIMIT",
            status_code=400,
        )

    image_id = uuid.uuid4().hex[:12]
    key = f"factory/{business.id}/{image_id}.webp"
    url = await _upload_image(file, key)
    image = FactoryImage(business_id=business.id, url=url)
    db.add(image)
    await db.flush()
    from app.services.feed import create_system_post

    await create_system_post(
        db,
        user=user,
        post_type="new_factory",
        title=business.company_name or "Factory",
        body="",
        image_url=url,
        meta={"factory_image_id": image.id},
    )
    return {"id": image.id, "url": url}


async def upload_audit_report(db: AsyncSession, user: User, file: UploadFile) -> dict:
    business = await _ensure_business_profile(db, user)
    key = f"audit/{business.id}/{uuid.uuid4().hex}.webp"
    url = await _upload_image(file, key)
    if business.audit_report_url:
        old_key = _key_from_url(business.audit_report_url)
        if old_key and old_key != key:
            try:
                await get_storage().delete_object(old_key)
            except Exception:
                pass
    business.audit_report_url = url
    await db.flush()
    return {"audit_report_url": url}


async def delete_audit_report(db: AsyncSession, user: User) -> None:
    business = await _ensure_business_profile(db, user)
    if not business.audit_report_url:
        return
    old_key = _key_from_url(business.audit_report_url)
    if old_key:
        try:
            await get_storage().delete_object(old_key)
        except Exception:
            pass
    business.audit_report_url = None
    await db.flush()


async def delete_factory_image(db: AsyncSession, user: User, image_id: int) -> None:
    business = await _ensure_business_profile(db, user)
    await db.refresh(business, attribute_names=["factory_images"])
    target = next((img for img in (business.factory_images or []) if img.id == image_id), None)
    if target is None:
        raise AppError(message="Rasm topilmadi", error_code="NOT_FOUND", status_code=404)

    old_key = _key_from_url(target.url)
    if old_key:
        try:
            await get_storage().delete_object(old_key)
        except Exception:
            pass
    await db.delete(target)
    await db.flush()
