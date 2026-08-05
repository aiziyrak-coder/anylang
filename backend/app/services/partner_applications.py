"""Partner outreach applications — submit, upload, admin approve."""

from __future__ import annotations

import logging
from datetime import UTC, datetime, timedelta
from decimal import Decimal
from io import BytesIO
from typing import Any
from uuid import uuid4

from PIL import Image
from sqlalchemy import func, or_, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.errors import AppError
from app.core.pagination import normalize_page
from app.core.security import hash_password
from app.integrations.storage import get_storage
from app.models.partner_application import PartnerApplication, PartnerApplicationProduct
from app.models.product import Product, ProductImage
from app.models.user import (
    AdminUser,
    BusinessProfile,
    FactoryImage,
    NumberAssignment,
    User,
)
from app.schemas.partner_application import PartnerApplicationSubmitIn, PartnerDecideIn
from app.services.admin_ops import write_audit
from app.services.numbers import assign_random_standard_number
from app.services.users import ensure_basic_subscription

logger = logging.getLogger(__name__)

MAX_IMAGE_BYTES = 5 * 1024 * 1024
MAX_VIDEO_BYTES = 25 * 1024 * 1024
ALLOWED_IMAGE_TYPES = {"image/jpeg", "image/png", "image/webp"}
ALLOWED_VIDEO_TYPES = {"video/mp4", "video/quicktime", "video/webm", "video/x-m4v"}


def _clean(value: str | None, *, max_len: int) -> str | None:
    if value is None:
        return None
    s = str(value).strip()
    if not s:
        return None
    return s[:max_len]


def _product_out(p: PartnerApplicationProduct) -> dict[str, Any]:
    return {
        "id": p.id,
        "position": p.position,
        "name": p.name,
        "short_description": p.short_description or "",
        "description": p.description or "",
        "price": p.price,
        "currency": p.currency,
        "category": p.category,
        "moq": p.moq,
        "shipping_info": p.shipping_info,
        "image_urls": list(p.image_urls or []),
        "video_url": p.video_url,
    }


def _phone_digits(phone: str | None) -> str:
    if not phone:
        return ""
    return "".join(c for c in phone if c.isdigit())


ONBOARDING_CHECKLIST = [
    {
        "id": "login",
        "uz": "AnyLang ilovasiga email/parol bilan kiring",
        "ru": "Войдите в приложение AnyLang с email/паролем",
        "en": "Sign in to the AnyLang app with your email/password",
    },
    {
        "id": "profile",
        "uz": "Biznes profilini to‘ldiring (logo, bio, eksport)",
        "ru": "Заполните бизнес-профиль (лого, bio, экспорт)",
        "en": "Complete your business profile (logo, bio, export)",
    },
    {
        "id": "verification",
        "uz": "Hujjatlarni yuklab verifikatsiyaga yuboring",
        "ru": "Загрузите документы и отправьте на верификацию",
        "en": "Upload documents and submit for verification",
    },
    {
        "id": "products",
        "uz": "Mahsulotlaringiz bozorda e’lon qilinganligini tekshiring",
        "ru": "Проверьте, что товары опубликованы на маркетплейсе",
        "en": "Confirm your products are live on the marketplace",
    },
    {
        "id": "notifications",
        "uz": "Bildirishnomalarni yoqing (chat / buyurtmalar)",
        "ru": "Включите уведомления (чат / заказы)",
        "en": "Enable notifications (chat / orders)",
    },
]


def onboarding_checklist(*, locale: str = "uz") -> list[dict[str, str]]:
    loc = (locale or "uz").lower()[:2]
    key = "ru" if loc == "ru" else "en" if loc == "en" else "uz"
    return [{"id": i["id"], "label": i[key]} for i in ONBOARDING_CHECKLIST]


def _gallery_urls(app: PartnerApplication) -> list[str]:
    urls: list[str] = []
    if app.logo_url:
        urls.append(str(app.logo_url))
    for u in list(app.factory_image_urls or [])[:8]:
        if u and str(u) not in urls:
            urls.append(str(u))
    for p in list(app.products or []):
        for u in list(p.image_urls or [])[:4]:
            if u and str(u) not in urls:
                urls.append(str(u))
            if len(urls) >= 24:
                return urls
    return urls


def _app_out(
    app: PartnerApplication,
    *,
    include_products: bool = True,
    duplicates: list[dict[str, Any]] | None = None,
    welcome_email_sent: bool | None = None,
    include_checklist: bool = False,
) -> dict[str, Any]:
    products = list(app.products or [])
    dups = duplicates or []
    out: dict[str, Any] = {
        "id": app.id,
        "status": app.status,
        "email": app.email,
        "contact_name": app.contact_name,
        "phone": app.phone,
        "company_name": app.company_name,
        "country": app.country,
        "business_role": app.business_role,
        "website": app.website,
        "bio": app.bio,
        "description": app.description,
        "founded_year": app.founded_year,
        "moq": app.moq,
        "production_capacity": app.production_capacity,
        "lead_time": app.lead_time,
        "certificates": list(app.certificates or []),
        "export_countries": list(app.export_countries or []),
        "payment_methods": list(app.payment_methods or []),
        "incoterms": list(app.incoterms or []),
        "logo_url": app.logo_url,
        "factory_image_urls": list(app.factory_image_urls or []),
        "factory_video_url": app.factory_video_url,
        "admin_note": app.admin_note,
        "reviewed_at": app.reviewed_at,
        "reviewed_by": app.reviewed_by,
        "created_user_id": app.created_user_id,
        "submitted_at": app.submitted_at,
        "created_at": app.created_at,
        "products": [_product_out(p) for p in products] if include_products else [],
        "products_count": len(products),
        "duplicates": dups,
        "is_duplicate": len(dups) > 0,
        "gallery_urls": _gallery_urls(app),
    }
    if welcome_email_sent is not None:
        out["welcome_email_sent"] = welcome_email_sent
    if include_checklist:
        src = (app.source_lang or "uz").lower()[:2]
        out["onboarding_checklist"] = onboarding_checklist(locale=src)
    return out


async def find_duplicates(db: AsyncSession, app: PartnerApplication) -> list[dict[str, Any]]:
    hits: list[dict[str, Any]] = []
    email = (app.email or "").lower().strip()
    phone = _phone_digits(app.phone)
    company = (app.company_name or "").strip()

    if email:
        user_id = (
            await db.execute(select(User.id).where(User.email == email))
        ).scalar_one_or_none()
        if user_id is not None:
            hits.append(
                {
                    "kind": "user_email",
                    "matched_id": int(user_id),
                    "matched_type": "user",
                    "label": f"Mavjud foydalanuvchi email: #{user_id}",
                }
            )
        other_apps = (
            await db.execute(
                select(PartnerApplication.id, PartnerApplication.status)
                .where(
                    PartnerApplication.email == email,
                    PartnerApplication.id != app.id,
                )
                .limit(5)
            )
        ).all()
        for oid, st in other_apps:
            hits.append(
                {
                    "kind": "email",
                    "matched_id": int(oid),
                    "matched_type": "application",
                    "label": f"Anketa #{oid} ({st}) — bir xil email",
                }
            )

    if phone and len(phone) >= 7:
        # Match last 9+ digits against applications / users with phone-like fields
        # Users don't have phone column — check partner apps only + contact in other apps
        phone_apps = (
            await db.execute(
                select(PartnerApplication.id, PartnerApplication.status, PartnerApplication.phone)
                .where(
                    PartnerApplication.id != app.id,
                    PartnerApplication.phone.is_not(None),
                )
                .limit(200)
            )
        ).all()
        for oid, st, ph in phone_apps:
            if _phone_digits(ph).endswith(phone[-9:]) or phone.endswith(
                _phone_digits(ph)[-9:]
            ):
                hits.append(
                    {
                        "kind": "phone",
                        "matched_id": int(oid),
                        "matched_type": "application",
                        "label": f"Anketa #{oid} ({st}) — o‘xshash telefon",
                    }
                )
                if len([h for h in hits if h["kind"] == "phone"]) >= 3:
                    break

    if company and len(company) >= 3:
        like = f"%{company}%"
        company_apps = (
            await db.execute(
                select(PartnerApplication.id, PartnerApplication.status, PartnerApplication.company_name)
                .where(
                    PartnerApplication.id != app.id,
                    PartnerApplication.company_name.ilike(like),
                )
                .limit(5)
            )
        ).all()
        for oid, st, name in company_apps:
            hits.append(
                {
                    "kind": "company",
                    "matched_id": int(oid),
                    "matched_type": "application",
                    "label": f"Anketa #{oid} ({st}) — kompaniya: {name}",
                }
            )
        biz_rows = (
            await db.execute(
                select(BusinessProfile.user_id, BusinessProfile.company_name)
                .where(BusinessProfile.company_name.ilike(like))
                .limit(5)
            )
        ).all()
        for uid, name in biz_rows:
            hits.append(
                {
                    "kind": "company",
                    "matched_id": int(uid),
                    "matched_type": "user",
                    "label": f"Biznes user #{uid} — kompaniya: {name}",
                }
            )

    # Dedupe by (kind, matched_type, matched_id)
    seen: set[tuple] = set()
    unique: list[dict[str, Any]] = []
    for h in hits:
        key = (h["kind"], h["matched_type"], h["matched_id"])
        if key in seen:
            continue
        seen.add(key)
        unique.append(h)
    return unique[:12]


async def _enrich(db: AsyncSession, apps: list[PartnerApplication]) -> list[dict[str, Any]]:
    out = []
    for app in apps:
        dups = await find_duplicates(db, app)
        out.append(_app_out(app, duplicates=dups))
    return out


async def check_email_available(db: AsyncSession, email: str) -> dict[str, Any]:
    email_norm = email.lower().strip()
    existing_user = (
        await db.execute(select(User.id).where(User.email == email_norm))
    ).scalar_one_or_none()
    if existing_user is not None:
        return {
            "available": False,
            "message": "Bu email allaqachon ro‘yxatdan o‘tgan",
        }
    pending = (
        await db.execute(
            select(PartnerApplication.id).where(
                PartnerApplication.email == email_norm,
                PartnerApplication.status.in_(("pending", "review")),
            )
        )
    ).scalar_one_or_none()
    if pending is not None:
        return {
            "available": False,
            "message": "Bu email bilan kutilayotgan anketa allaqachon bor",
        }
    return {"available": True, "message": "Email bo‘sh"}


def _sniff_video(data: bytes, declared: str | None, filename: str) -> str:
    raw = (declared or "").split(";")[0].strip().lower()
    if raw in ALLOWED_VIDEO_TYPES:
        return raw
    name = (filename or "").lower()
    if name.endswith((".mp4", ".m4v")):
        return "video/mp4"
    if name.endswith(".mov"):
        return "video/quicktime"
    if name.endswith(".webm"):
        return "video/webm"
    if len(data) >= 12 and data[4:8] == b"ftyp":
        return "video/mp4"
    return raw or "application/octet-stream"


async def upload_media(
    *,
    filename: str,
    content_type: str,
    data: bytes,
) -> dict[str, str]:
    raw_ct = (content_type or "").split(";")[0].strip().lower()
    is_image = raw_ct in ALLOWED_IMAGE_TYPES or (filename or "").lower().endswith(
        (".jpg", ".jpeg", ".png", ".webp")
    )
    is_video = (
        raw_ct in ALLOWED_VIDEO_TYPES
        or (filename or "").lower().endswith((".mp4", ".mov", ".webm", ".m4v"))
        or (len(data) >= 12 and data[4:8] == b"ftyp")
    )

    if is_image and not is_video:
        if len(data) > MAX_IMAGE_BYTES:
            raise AppError(
                message="Rasm hajmi 5 MB dan oshmasligi kerak",
                error_code="FILE_TOO_LARGE",
                status_code=413,
            )
        try:
            Image.open(BytesIO(data)).verify()
        except Exception as exc:
            raise AppError(
                message="Rasm fayli noto‘g‘ri",
                error_code="VALIDATION_ERROR",
                status_code=400,
            ) from exc
        ct = raw_ct if raw_ct in ALLOWED_IMAGE_TYPES else "image/jpeg"
        ext = "jpg" if ct == "image/jpeg" else ct.split("/")[-1]
        key = f"partner-apply/images/{uuid4().hex}.{ext}"
        url = await get_storage().upload_bytes(key, data, ct)
        return {"url": url, "kind": "image"}

    if is_video:
        ct = _sniff_video(data, content_type, filename)
        if ct not in ALLOWED_VIDEO_TYPES:
            raise AppError(
                message="Faqat MP4, MOV yoki WebM video ruxsat etilgan",
                error_code="VALIDATION_ERROR",
                status_code=400,
            )
        if len(data) > MAX_VIDEO_BYTES:
            raise AppError(
                message="Video hajmi 25 MB dan oshmasligi kerak",
                error_code="FILE_TOO_LARGE",
                status_code=413,
            )
        ext = {
            "video/mp4": "mp4",
            "video/x-m4v": "m4v",
            "video/quicktime": "mov",
            "video/webm": "webm",
        }.get(ct, "mp4")
        key = f"partner-apply/videos/{uuid4().hex}.{ext}"
        url = await get_storage().upload_bytes(key, data, ct)
        return {"url": url, "kind": "video"}

    raise AppError(
        message="Faqat rasm (JPG/PNG/WebP) yoki video (MP4/MOV/WebM) yuklash mumkin",
        error_code="VALIDATION_ERROR",
        status_code=400,
    )


async def submit_application(
    db: AsyncSession, body: PartnerApplicationSubmitIn
) -> dict[str, Any]:
    email_norm = str(body.email).lower().strip()
    check = await check_email_available(db, email_norm)
    if not check["available"]:
        raise AppError(
            message=check["message"],
            error_code="EMAIL_ALREADY_EXISTS",
            status_code=409,
        )

    if not body.products:
        raise AppError(
            message="Kamida bitta mahsulot qo‘shing",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )

    now = datetime.now(UTC)
    app = PartnerApplication(
        status="pending",
        email=email_norm,
        password_hash=hash_password(body.password),
        contact_name=body.contact_name.strip(),
        phone=_clean(body.phone, max_len=40),
        source_lang=(body.source_lang or "uz").strip().lower()[:8] or "uz",
        company_name=body.company_name.strip(),
        country=(body.country or "").upper()[:2] or None,
        business_role=body.business_role,
        website=_clean(body.website, max_len=255),
        bio=_clean(body.bio, max_len=300),
        description=_clean(body.description, max_len=5000),
        founded_year=body.founded_year,
        moq=_clean(body.moq, max_len=120),
        production_capacity=_clean(body.production_capacity, max_len=160),
        lead_time=_clean(body.lead_time, max_len=120),
        certificates=[str(c).strip()[:80] for c in (body.certificates or []) if str(c).strip()][
            :20
        ],
        export_countries=[
            str(c).strip().upper()[:2] for c in (body.export_countries or []) if str(c).strip()
        ][:50],
        payment_methods=[
            str(c).strip()[:40] for c in (body.payment_methods or []) if str(c).strip()
        ][:20],
        incoterms=[str(c).strip()[:20] for c in (body.incoterms or []) if str(c).strip()][:20],
        logo_url=_clean(body.logo_url, max_len=512),
        factory_image_urls=list(body.factory_image_urls or [])[:12],
        factory_video_url=_clean(body.factory_video_url, max_len=512),
        submitted_at=now,
    )
    db.add(app)
    await db.flush()

    for idx, p in enumerate(body.products):
        short = (p.short_description or "").strip() or (p.name.strip()[:120])
        db.add(
            PartnerApplicationProduct(
                application_id=app.id,
                position=idx,
                name=p.name.strip(),
                short_description=short[:120],
                description=(p.description or "").strip()[:2000],
                price=p.price if p.price is not None else Decimal("0"),
                currency=p.currency or "USD",
                category=p.category or "other",
                moq=_clean(p.moq, max_len=120),
                shipping_info=_clean(p.shipping_info, max_len=255),
                image_urls=list(p.image_urls or [])[:10],
                video_url=_clean(p.video_url, max_len=512),
            )
        )

    await db.commit()
    await db.refresh(app)
    return {
        "id": app.id,
        "status": app.status,
        "message": "Anketa yuborildi. Admin tekshirgach biznes akkountingiz ochiladi.",
    }


async def list_applications(
    db: AsyncSession,
    *,
    status: str = "pending",
    q: str | None = None,
    page: int = 1,
    limit: int = 20,
) -> dict[str, Any]:
    params = normalize_page(page, limit)
    query = select(PartnerApplication).options(
        selectinload(PartnerApplication.products)
    )
    count_q = select(func.count()).select_from(PartnerApplication)

    if status and status != "all":
        query = query.where(PartnerApplication.status == status)
        count_q = count_q.where(PartnerApplication.status == status)

    if q and q.strip():
        like = f"%{q.strip()}%"
        filt = or_(
            PartnerApplication.email.ilike(like),
            PartnerApplication.company_name.ilike(like),
            PartnerApplication.contact_name.ilike(like),
        )
        query = query.where(filt)
        count_q = count_q.where(filt)

    total = int((await db.execute(count_q)).scalar() or 0)
    rows = list(
        (
            await db.execute(
                query.order_by(PartnerApplication.submitted_at.desc().nullslast())
                .offset(params.offset)
                .limit(params.limit)
            )
        )
        .scalars()
        .all()
    )

    return {
        "items": await _enrich(db, rows),
        "total": total,
        "page": params.page,
        "limit": params.limit,
        "has_more": params.page * params.limit < total,
    }


async def get_application(db: AsyncSession, app_id: int) -> dict[str, Any]:
    app = (
        await db.execute(
            select(PartnerApplication)
            .where(PartnerApplication.id == app_id)
            .options(selectinload(PartnerApplication.products))
        )
    ).scalar_one_or_none()
    if app is None:
        raise AppError(
            message="Anketa topilmadi",
            error_code="NOT_FOUND",
            status_code=404,
        )
    dups = await find_duplicates(db, app)
    return _app_out(app, duplicates=dups)


async def set_application_stage(
    db: AsyncSession,
    *,
    app_id: int,
    stage: str,
    admin: AdminUser,
    ip: str | None,
) -> dict[str, Any]:
    if stage not in {"pending", "review"}:
        raise AppError(message="Invalid stage", error_code="VALIDATION_ERROR", status_code=400)
    app = (
        await db.execute(
            select(PartnerApplication)
            .where(PartnerApplication.id == app_id)
            .options(selectinload(PartnerApplication.products))
            .with_for_update()
        )
    ).scalar_one_or_none()
    if app is None:
        raise AppError(message="Anketa topilmadi", error_code="NOT_FOUND", status_code=404)
    if app.status not in {"pending", "review"}:
        raise AppError(
            message="Faqat ochiq anketani ko‘chirib bo‘ladi",
            error_code="INVALID_STATUS",
            status_code=400,
        )
    app.status = stage
    await write_audit(
        db,
        admin=admin,
        action="partner_application.stage",
        target_type="partner_application",
        target_id=str(app.id),
        meta={"stage": stage},
        ip=ip,
    )
    await db.commit()
    await db.refresh(app)
    dups = await find_duplicates(db, app)
    return _app_out(app, duplicates=dups)


async def board_applications(db: AsyncSession, *, per_column: int = 30) -> dict[str, Any]:
    per_column = max(5, min(per_column, 50))

    async def _col(status: str, limit: int) -> list[PartnerApplication]:
        return list(
            (
                await db.execute(
                    select(PartnerApplication)
                    .where(PartnerApplication.status == status)
                    .options(selectinload(PartnerApplication.products))
                    .order_by(PartnerApplication.submitted_at.desc().nullslast())
                    .limit(limit)
                )
            )
            .scalars()
            .all()
        )

    new_rows = await _col("pending", per_column)
    review_rows = await _col("review", per_column)
    approved_rows = await _col("approved", per_column)
    rejected_rows = await _col("rejected", per_column)

    counts = {}
    for st in ("pending", "review", "approved", "rejected"):
        counts[st] = int(
            (
                await db.execute(
                    select(func.count())
                    .select_from(PartnerApplication)
                    .where(PartnerApplication.status == st)
                )
            ).scalar()
            or 0
        )
    counts["new"] = counts["pending"]

    return {
        "new": await _enrich(db, new_rows),
        "review": await _enrich(db, review_rows),
        "approved": await _enrich(db, approved_rows),
        "rejected": await _enrich(db, rejected_rows),
        "counts": counts,
    }


async def conversion_analytics(db: AsyncSession, *, days: int = 30) -> dict[str, Any]:
    days = days if days in (7, 30, 90) else 30
    since = datetime.now(UTC) - timedelta(days=days)

    applications = int(
        (
            await db.execute(
                select(func.count())
                .select_from(PartnerApplication)
                .where(PartnerApplication.submitted_at >= since)
            )
        ).scalar()
        or 0
    )
    in_review = int(
        (
            await db.execute(
                select(func.count())
                .select_from(PartnerApplication)
                .where(
                    PartnerApplication.status == "review",
                    PartnerApplication.submitted_at >= since,
                )
            )
        ).scalar()
        or 0
    )
    approved = int(
        (
            await db.execute(
                select(func.count())
                .select_from(PartnerApplication)
                .where(
                    PartnerApplication.status == "approved",
                    PartnerApplication.reviewed_at >= since,
                )
            )
        ).scalar()
        or 0
    )
    rejected = int(
        (
            await db.execute(
                select(func.count())
                .select_from(PartnerApplication)
                .where(
                    PartnerApplication.status == "rejected",
                    PartnerApplication.reviewed_at >= since,
                )
            )
        ).scalar()
        or 0
    )
    accounts_created = int(
        (
            await db.execute(
                select(func.count())
                .select_from(PartnerApplication)
                .where(
                    PartnerApplication.created_user_id.is_not(None),
                    PartnerApplication.reviewed_at >= since,
                )
            )
        ).scalar()
        or 0
    )

    # First listing: approved apps whose user has ≥1 published product
    user_ids = list(
        (
            await db.execute(
                select(PartnerApplication.created_user_id).where(
                    PartnerApplication.created_user_id.is_not(None),
                    PartnerApplication.reviewed_at >= since,
                )
            )
        )
        .scalars()
        .all()
    )
    with_first = 0
    if user_ids:
        with_first = int(
            (
                await db.execute(
                    select(func.count(func.distinct(Product.seller_id))).where(
                        Product.seller_id.in_(user_ids),
                        Product.status == "published",
                    )
                )
            ).scalar()
            or 0
        )

    def pct(a: int, b: int) -> float:
        if b <= 0:
            return 0.0
        return round((a / b) * 100.0, 1)

    return {
        "applications": applications,
        "in_review": in_review,
        "approved": approved,
        "rejected": rejected,
        "accounts_created": accounts_created,
        "with_first_listing": with_first,
        "conversion_account_pct": pct(accounts_created, applications),
        "conversion_listing_pct": pct(with_first, applications),
        "days": days,
    }


async def decide_application(
    db: AsyncSession,
    *,
    app_id: int,
    body: PartnerDecideIn,
    admin: AdminUser,
    ip: str | None,
) -> dict[str, Any]:
    app = (
        await db.execute(
            select(PartnerApplication)
            .where(PartnerApplication.id == app_id)
            .options(selectinload(PartnerApplication.products))
            .with_for_update()
        )
    ).scalar_one_or_none()
    if app is None:
        raise AppError(
            message="Anketa topilmadi",
            error_code="NOT_FOUND",
            status_code=404,
        )
    if app.status not in {"pending", "review"}:
        raise AppError(
            message="Anketa allaqachon ko‘rib chiqilgan",
            error_code="ALREADY_REVIEWED",
            status_code=400,
        )

    now = datetime.now(UTC)
    if not body.approve:
        note = (body.admin_note or "").strip()
        if len(note) < 3:
            raise AppError(
                message="Rad etish uchun izoh yozing (kamida 3 belgi)",
                error_code="VALIDATION_ERROR",
                status_code=400,
            )
        app.status = "rejected"
        app.admin_note = note[:500]
        app.reviewed_at = now
        app.reviewed_by = admin.id
        await write_audit(
            db,
            admin=admin,
            action="partner_application.reject",
            target_type="partner_application",
            target_id=str(app.id),
            meta={"email": app.email, "company": app.company_name},
            ip=ip,
        )
        await db.commit()
        return _app_out(app, duplicates=await find_duplicates(db, app))

    # Approve → create user + business + products
    existing = (
        await db.execute(select(User.id).where(User.email == app.email))
    ).scalar_one_or_none()
    if existing is not None:
        raise AppError(
            message="Bu email bilan foydalanuvchi allaqachon mavjud",
            error_code="EMAIL_ALREADY_EXISTS",
            status_code=409,
        )

    src = (app.source_lang or "uz").strip().lower()[:8] or "uz"
    app_lang = {"ru": "ru_RU", "en": "us_US"}.get(src, "uz_UZ")
    native = {"ru": "ru", "en": "en"}.get(src, "uz")

    number = await assign_random_standard_number(db)
    user = User(
        email=app.email,
        password_hash=app.password_hash,
        full_name=app.contact_name,
        number=number,
        birth_date=None,
        gender="male",
        country=app.country,
        app_language=app_lang,
        native_language=native,
        is_verified=True,
        is_active=True,
        verified_badge=False,
    )
    db.add(user)
    await db.flush()

    await db.execute(
        update(NumberAssignment)
        .where(NumberAssignment.number == number)
        .values(user_id=user.id)
    )
    await ensure_basic_subscription(user, db)

    business = BusinessProfile(
        user_id=user.id,
        company_name=app.company_name,
        logo_url=app.logo_url,
        country=app.country,
        business_role=app.business_role,
        website=app.website,
        bio=app.bio,
        description=app.description,
        founded_year=app.founded_year,
        moq=app.moq,
        production_capacity=app.production_capacity,
        lead_time=app.lead_time,
        certificates=list(app.certificates or []),
        export_countries=list(app.export_countries or []),
        payment_methods=list(app.payment_methods or []),
        incoterms=list(app.incoterms or []),
    )
    db.add(business)
    await db.flush()

    for url in list(app.factory_image_urls or [])[:12]:
        if url:
            db.add(FactoryImage(business_id=business.id, url=str(url)[:512]))

    product_ids: list[int] = []
    for p in sorted(app.products or [], key=lambda x: x.position):
        product = Product(
            seller_id=user.id,
            name=p.name,
            short_description=p.short_description or p.name[:120],
            description=p.description or "",
            price=Decimal(str(p.price or 0)),
            currency=p.currency or "USD",
            category=p.category or "other",
            status="published",
            moq=p.moq,
            shipping_info=p.shipping_info,
            video_url=p.video_url,
            factory_video_url=app.factory_video_url,
            source_lang=src,
        )
        db.add(product)
        await db.flush()
        product_ids.append(product.id)
        for pos, url in enumerate(list(p.image_urls or [])[:10]):
            if not url:
                continue
            db.add(
                ProductImage(
                    product_id=product.id,
                    uploader_id=user.id,
                    url=str(url)[:512],
                    is_primary=pos == 0,
                    position=pos,
                    attached_at=now,
                )
            )

    app.status = "approved"
    app.admin_note = _clean(body.admin_note, max_len=500)
    app.reviewed_at = now
    app.reviewed_by = admin.id
    app.created_user_id = user.id

    await write_audit(
        db,
        admin=admin,
        action="partner_application.approve",
        target_type="partner_application",
        target_id=str(app.id),
        meta={
            "email": app.email,
            "company": app.company_name,
            "user_id": user.id,
            "number": number,
            "products": len(app.products or []),
        },
        ip=ip,
    )
    await db.commit()
    await db.refresh(app)

    # Background: translate business + products to all marketplace languages
    from app.services.catalog_i18n import enqueue_catalog_translate

    await enqueue_catalog_translate(
        kind="business", entity_id=user.id, source_lang=src, defer_seconds=2
    )
    for pid in product_ids:
        await enqueue_catalog_translate(
            kind="product", entity_id=pid, source_lang=src, defer_seconds=2
        )

    # Welcome email + onboarding checklist
    welcome_sent = False
    try:
        from app.integrations.email import send_partner_welcome_email

        welcome_sent = await send_partner_welcome_email(
            to_email=app.email,
            contact_name=app.contact_name,
            company_name=app.company_name,
            number=number,
            app_language=app_lang,
            checklist=onboarding_checklist(locale=src),
        )
    except Exception:
        logger.exception("partner welcome email failed app=%s", app.id)

    dups = await find_duplicates(db, app)
    return _app_out(
        app,
        duplicates=dups,
        welcome_email_sent=welcome_sent,
        include_checklist=True,
    )
