"""Business verification — required docs, submit, admin approve."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime, timedelta
from typing import Any

from fastapi import UploadFile
from sqlalchemy import and_, case, func, nulls_last, or_, select
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.errors import AppError
from app.core.uploads import read_upload_limited
from app.integrations.storage import get_storage
from app.models.user import AdminUser, BusinessProfile, User
from app.models.verification import (
    BusinessVerificationDocument,
    BusinessVerificationRequest,
)

MAX_DOC_BYTES = 8 * 1024 * 1024
ALLOWED_CONTENT_TYPES = {
    "image/jpeg",
    "image/png",
    "image/webp",
    "application/pdf",
}

SLA_HOURS = 24

# Majburiy hujjatlar — hammasi yuklanishi kerak.
REQUIRED_DOC_TYPES: list[dict[str, str]] = [
    {
        "type": "business_license",
        "label_uz": "Kompaniya guvohnomasi / registratsiya",
        "label_ru": "Свидетельство / регистрация компании",
        "label_en": "Company registration / business license",
    },
    {
        "type": "tax_certificate",
        "label_uz": "STIR / soliq guvohnomasi",
        "label_ru": "ИНН / налоговый сертификат",
        "label_en": "Tax ID / tax certificate",
    },
    {
        "type": "owner_id",
        "label_uz": "Rahbar passport / ID",
        "label_ru": "Паспорт / ID руководителя",
        "label_en": "Director passport / ID",
    },
]

# Tavsiya etiladi — yetishmasa ro‘yxatda ko‘rinadi, lekin submit uchun majburiy emas.
RECOMMENDED_DOC_TYPES: list[dict[str, str]] = [
    {
        "type": "iso_certificate",
        "label_uz": "ISO / CE / FDA sertifikat",
        "label_ru": "Сертификат ISO / CE / FDA",
        "label_en": "ISO / CE / FDA certificate",
    },
    {
        "type": "factory_photo",
        "label_uz": "Zavod / ofis fotosurati",
        "label_ru": "Фото завода / офиса",
        "label_en": "Factory / office photo",
    },
    {
        "type": "audit_report",
        "label_uz": "Audit hisoboti",
        "label_ru": "Аудиторский отчёт",
        "label_en": "Audit report",
    },
]

ALL_DOC_TYPES = {d["type"] for d in REQUIRED_DOC_TYPES + RECOMMENDED_DOC_TYPES}

# Har hujjat turi uchun admin checklist (ko‘p tilli).
DOC_CHECKLISTS: dict[str, list[dict[str, str]]] = {
    "business_license": [
        {
            "id": "readable",
            "uz": "Matn o‘qiladi, sifat yetarli",
            "ru": "Текст читаемый, качество достаточное",
            "en": "Text is readable, quality is sufficient",
        },
        {
            "id": "company_match",
            "uz": "Kompaniya nomi profil bilan mos",
            "ru": "Название компании совпадает с профилем",
            "en": "Company name matches the profile",
        },
        {
            "id": "valid_date",
            "uz": "Amal qilish muddati yaroqli / muddati o‘tmagan",
            "ru": "Срок действия действителен",
            "en": "Document is not expired",
        },
        {
            "id": "official",
            "uz": "Rasmiy blank / muhur ko‘rinadi",
            "ru": "Официальный бланк / печать видны",
            "en": "Official letterhead / seal visible",
        },
    ],
    "tax_certificate": [
        {
            "id": "readable",
            "uz": "STIR / INN raqami o‘qiladi",
            "ru": "ИНН читается",
            "en": "Tax ID is readable",
        },
        {
            "id": "name_match",
            "uz": "Soliq to‘lovchi nomi mos",
            "ru": "Имя налогоплательщика совпадает",
            "en": "Taxpayer name matches",
        },
        {
            "id": "authority",
            "uz": "Rasmiy organ berganligi ko‘rinadi",
            "ru": "Выдан официальным органом",
            "en": "Issued by an official authority",
        },
    ],
    "owner_id": [
        {
            "id": "face_visible",
            "uz": "Yuz / foto aniq",
            "ru": "Лицо / фото чёткое",
            "en": "Face / photo is clear",
        },
        {
            "id": "name_match",
            "uz": "Ism profil / rahbar bilan mos",
            "ru": "Имя совпадает с профилем / директором",
            "en": "Name matches profile / director",
        },
        {
            "id": "not_expired",
            "uz": "Passport / ID muddati o‘tmagan",
            "ru": "Паспорт / ID не просрочен",
            "en": "ID is not expired",
        },
        {
            "id": "full_page",
            "uz": "To‘liq sahifa / kerakli maydonlar ko‘rinadi",
            "ru": "Полная страница / нужные поля видны",
            "en": "Full page / required fields visible",
        },
    ],
    "iso_certificate": [
        {
            "id": "readable",
            "uz": "Sertifikat raqami / turi o‘qiladi",
            "ru": "Номер / тип сертификата читается",
            "en": "Certificate number / type readable",
        },
        {
            "id": "company_match",
            "uz": "Kompaniya nomi mos",
            "ru": "Название компании совпадает",
            "en": "Company name matches",
        },
        {
            "id": "valid_date",
            "uz": "Amal qilish muddati yaroqli",
            "ru": "Срок действия действителен",
            "en": "Certificate is valid",
        },
    ],
    "factory_photo": [
        {
            "id": "real_photo",
            "uz": "Haqiqiy zavod / ofis (stock emas)",
            "ru": "Реальный завод / офис (не сток)",
            "en": "Real factory / office (not stock)",
        },
        {
            "id": "relevant",
            "uz": "Biznes faoliyatiga mos",
            "ru": "Соответствует деятельности",
            "en": "Relevant to the business",
        },
        {
            "id": "clear",
            "uz": "Rasm sifatli",
            "ru": "Фото качественное",
            "en": "Photo quality is good",
        },
    ],
    "audit_report": [
        {
            "id": "readable",
            "uz": "Hisobot o‘qiladi",
            "ru": "Отчёт читается",
            "en": "Report is readable",
        },
        {
            "id": "company_match",
            "uz": "Kompaniya / joy mos",
            "ru": "Компания / объект совпадает",
            "en": "Company / site matches",
        },
        {
            "id": "recent",
            "uz": "Yaqinda o‘tkazilgan (eskirmagan)",
            "ru": "Недавний (не устаревший)",
            "en": "Recent (not outdated)",
        },
    ],
}

# Tezkor rad sabablari (makro) — ko‘p tilli.
REJECT_MACROS: list[dict[str, str]] = [
    {
        "id": "blurry",
        "uz": "Hujjat sifati past / xira — aniqroq nusxa yuklang.",
        "ru": "Документ размыт / низкое качество — загрузите чёткую копию.",
        "en": "Document is blurry / low quality — please upload a clearer copy.",
    },
    {
        "id": "mismatch",
        "uz": "Hujjatdagi ma’lumotlar profil (kompaniya nomi) bilan mos kelmaydi.",
        "ru": "Данные в документе не совпадают с профилем (название компании).",
        "en": "Document details do not match the profile (company name).",
    },
    {
        "id": "expired",
        "uz": "Hujjat muddati o‘tgan — yangilangan nusxa kerak.",
        "ru": "Документ просрочен — нужна актуальная копия.",
        "en": "Document is expired — please upload a valid copy.",
    },
    {
        "id": "incomplete",
        "uz": "Hujjat to‘liq emas (qirqilgan / kerakli sahifa yo‘q).",
        "ru": "Документ неполный (обрезан / нет нужной страницы).",
        "en": "Document is incomplete (cropped / missing pages).",
    },
    {
        "id": "wrong_type",
        "uz": "Noto‘g‘ri hujjat turi yuklangan — kerakli turdagi hujjatni yuboring.",
        "ru": "Загружен неверный тип документа — отправьте нужный вид.",
        "en": "Wrong document type uploaded — please submit the required type.",
    },
    {
        "id": "unreadable",
        "uz": "Muhim maydonlar o‘qilmaydi (raqam, sana, ism).",
        "ru": "Важные поля не читаются (номер, дата, имя).",
        "en": "Key fields are unreadable (number, date, name).",
    },
    {
        "id": "suspicious",
        "uz": "Hujjat shubhali ko‘rinadi — rasmiy asl nusxa talab qilinadi.",
        "ru": "Документ выглядит подозрительно — требуется официальный оригинал.",
        "en": "Document looks suspicious — an official original is required.",
    },
]


def _label_for(meta: dict[str, str], locale: str) -> str:
    loc = (locale or "uz").lower().split("_")[0]
    if loc in {"ru", "rus"}:
        return meta["label_ru"]
    if loc in {"en", "us", "gb", "eng"}:
        return meta["label_en"]
    return meta["label_uz"]


def _i18n_text(row: dict[str, str], locale: str) -> str:
    loc = (locale or "uz").lower().split("_")[0]
    if loc in {"ru", "rus"}:
        return row.get("ru") or row.get("uz") or ""
    if loc in {"en", "us", "gb", "eng"}:
        return row.get("en") or row.get("uz") or ""
    return row.get("uz") or ""


def get_reject_macros(*, locale: str = "uz") -> list[dict[str, Any]]:
    return [
        {
            "id": m["id"],
            "text": _i18n_text(m, locale),
            "uz": m["uz"],
            "ru": m["ru"],
            "en": m["en"],
        }
        for m in REJECT_MACROS
    ]


def get_doc_checklist(doc_type: str, *, locale: str = "uz") -> list[dict[str, str]]:
    items = DOC_CHECKLISTS.get(doc_type, [])
    return [{"id": i["id"], "label": _i18n_text(i, locale)} for i in items]


def _require_business(user: User) -> BusinessProfile:
    if not user.is_business or user.business is None:
        raise AppError(
            message="Faqat business akkaunt uchun",
            error_code="NOT_A_BUSINESS",
            status_code=403,
        )
    return user.business


EDITABLE_STATUSES = {"draft", "rejected", "pending", "needs_resubmit"}


async def _latest_editable_request(
    db: AsyncSession, *, user_id: int, business_id: int
) -> BusinessVerificationRequest:
    result = await db.execute(
        select(BusinessVerificationRequest)
        .where(BusinessVerificationRequest.user_id == user_id)
        .options(selectinload(BusinessVerificationRequest.documents))
        .order_by(BusinessVerificationRequest.id.desc())
        .limit(1)
    )
    req = result.scalar_one_or_none()
    if req is not None and req.status in {"draft", "rejected", "pending", "needs_resubmit"}:
        return req
    if req is not None and req.status == "approved":
        # Approved — read-only snapshot; yangi draft ochilmaydi.
        return req

    req = BusinessVerificationRequest(
        user_id=user_id,
        business_id=business_id,
        status="draft",
    )
    db.add(req)
    await db.flush()
    await db.refresh(req, attribute_names=["documents"])
    return req


def _serialize_doc(doc: BusinessVerificationDocument) -> dict:
    return {
        "id": doc.id,
        "doc_type": doc.doc_type,
        "url": doc.url,
        "file_name": doc.file_name,
        "review_status": getattr(doc, "review_status", None) or "pending",
        "review_note": getattr(doc, "review_note", None),
        "created_at": doc.created_at.isoformat() if doc.created_at else None,
        "checklist": get_doc_checklist(doc.doc_type, locale="uz"),
    }


def _sla_fields(submitted_at: datetime | None, *, now: datetime | None = None) -> dict[str, Any]:
    if submitted_at is None:
        return {"age_hours": None, "sla_breached": False, "sla_hours": SLA_HOURS}
    n = now or datetime.now(UTC)
    ts = submitted_at if submitted_at.tzinfo else submitted_at.replace(tzinfo=UTC)
    age = max(0.0, (n - ts).total_seconds() / 3600.0)
    return {
        "age_hours": round(age, 1),
        "sla_breached": age >= SLA_HOURS,
        "sla_hours": SLA_HOURS,
    }


def _catalog(locale: str) -> list[dict]:
    out: list[dict] = []
    for meta in REQUIRED_DOC_TYPES:
        out.append(
            {
                "type": meta["type"],
                "label": _label_for(meta, locale),
                "required": True,
            }
        )
    for meta in RECOMMENDED_DOC_TYPES:
        out.append(
            {
                "type": meta["type"],
                "label": _label_for(meta, locale),
                "required": False,
            }
        )
    return out


def build_verification_payload(
    *,
    user: User,
    business: BusinessProfile,
    request: BusinessVerificationRequest | None,
    locale: str = "uz",
) -> dict:
    docs = list(request.documents) if request is not None else []
    uploaded_types = {d.doc_type for d in docs}
    # Zavod rasmlari allaqachon bo‘lsa — factory_photo qisman hisoblanadi.
    factory_ok = bool(business.factory_images) or "factory_photo" in uploaded_types
    audit_ok = bool((business.audit_report_url or "").strip()) or "audit_report" in uploaded_types
    effective = set(uploaded_types)
    if factory_ok:
        effective.add("factory_photo")
    if audit_ok:
        effective.add("audit_report")

    catalog = _catalog(locale)
    items: list[dict] = []
    missing_required: list[dict] = []
    missing_recommended: list[dict] = []
    for entry in catalog:
        dtype = entry["type"]
        uploaded = dtype in effective
        item = {
            **entry,
            "uploaded": uploaded,
            "documents": [
                _serialize_doc(d) for d in docs if d.doc_type == dtype
            ],
        }
        if dtype == "factory_photo" and factory_ok and "factory_photo" not in uploaded_types:
            item["satisfied_by"] = "factory_images"
        if dtype == "audit_report" and audit_ok and "audit_report" not in uploaded_types:
            item["satisfied_by"] = "audit_report_url"
        items.append(item)
        if not uploaded:
            if entry["required"]:
                missing_required.append({"type": dtype, "label": entry["label"]})
            else:
                missing_recommended.append({"type": dtype, "label": entry["label"]})

    status = "none"
    if business.documents_verified or user.verified_badge:
        status = "approved"
    elif request is not None:
        status = request.status

    can_submit = (
        status in {"draft", "rejected", "needs_resubmit"}
        and len(missing_required) == 0
        and not (business.documents_verified or user.verified_badge)
    )
    can_upload = status in {"draft", "rejected", "needs_resubmit", "none"} and not (
        business.documents_verified or user.verified_badge
    )

    return {
        "status": status,
        "documents_verified": bool(business.documents_verified or user.verified_badge),
        "verified_badge": bool(user.verified_badge),
        "can_upload": can_upload,
        "can_submit": can_submit,
        "missing_required": missing_required,
        "missing_recommended": missing_recommended,
        "items": items,
        "request": None
        if request is None
        else {
            "id": request.id,
            "status": request.status,
            "note": request.note,
            "admin_note": request.admin_note,
            "submitted_at": request.submitted_at.isoformat()
            if request.submitted_at
            else None,
            "reviewed_at": request.reviewed_at.isoformat()
            if request.reviewed_at
            else None,
        },
    }


async def verification_status_summary(
    db: AsyncSession, user: User, business: BusinessProfile | None
) -> str:
    """Tezkor status: approved | pending | rejected | draft | none."""
    if business is None:
        return "none"
    if business.documents_verified or user.verified_badge:
        return "approved"
    result = await db.execute(
        select(BusinessVerificationRequest.status)
        .where(BusinessVerificationRequest.user_id == user.id)
        .order_by(BusinessVerificationRequest.id.desc())
        .limit(1)
    )
    status = result.scalar_one_or_none()
    return status or "none"


async def get_my_verification(
    db: AsyncSession, user: User, *, locale: str = "uz"
) -> dict:
    business = _require_business(user)
    result = await db.execute(
        select(BusinessVerificationRequest)
        .where(BusinessVerificationRequest.user_id == user.id)
        .options(selectinload(BusinessVerificationRequest.documents))
        .order_by(BusinessVerificationRequest.id.desc())
        .limit(1)
    )
    req = result.scalar_one_or_none()
    await db.refresh(business, attribute_names=["factory_images"])
    return build_verification_payload(
        user=user, business=business, request=req, locale=locale
    )


async def upload_verification_document(
    db: AsyncSession,
    user: User,
    file: UploadFile,
    *,
    doc_type: str,
) -> dict:
    business = _require_business(user)
    dtype = (doc_type or "").strip().lower()
    if dtype not in ALL_DOC_TYPES:
        raise AppError(
            message="Noto‘g‘ri hujjat turi",
            error_code="INVALID_DOC_TYPE",
            status_code=400,
        )
    if business.documents_verified or user.verified_badge:
        raise AppError(
            message="Allaqachon tasdiqlangan",
            error_code="ALREADY_VERIFIED",
            status_code=400,
        )

    req = await _latest_editable_request(db, user_id=user.id, business_id=business.id)
    if req.status == "pending":
        raise AppError(
            message="Ariza ko‘rib chiqilmoqda — yangi hujjat yuklab bo‘lmaydi",
            error_code="VERIFICATION_PENDING",
            status_code=400,
        )
    if req.status == "approved":
        raise AppError(
            message="Allaqachon tasdiqlangan",
            error_code="ALREADY_VERIFIED",
            status_code=400,
        )
    if req.status in {"rejected", "needs_resubmit"}:
        req.status = "draft"
        req.admin_note = None
        req.reviewed_at = None
        req.reviewed_by_admin_id = None

    content_type = (file.content_type or "").split(";")[0].strip().lower()
    if content_type not in ALLOWED_CONTENT_TYPES:
        raise AppError(
            message="Faqat JPG, PNG, WEBP yoki PDF",
            error_code="UNSUPPORTED_FILE",
            status_code=400,
        )

    raw = await read_upload_limited(file, max_bytes=MAX_DOC_BYTES)
    if content_type == "application/pdf":
        out_bytes = raw
        out_type = "application/pdf"
        ext = "pdf"
    else:
        from PIL import Image
        import io

        try:
            img = Image.open(io.BytesIO(raw)).convert("RGB")
            buf = io.BytesIO()
            img.save(buf, format="WEBP", quality=85)
            out_bytes = buf.getvalue()
            out_type = "image/webp"
            ext = "webp"
        except Exception as exc:
            raise AppError(
                message="Rasmni o‘qib bo‘lmadi",
                error_code="INVALID_IMAGE",
                status_code=400,
            ) from exc

    key = f"verification/{business.id}/{dtype}/{uuid.uuid4().hex}.{ext}"
    url = await get_storage().upload_bytes(key, out_bytes, out_type)

    # Bitta tur uchun eski faylni almashtirish
    for old in list(req.documents or []):
        if old.doc_type == dtype:
            await db.delete(old)

    doc = BusinessVerificationDocument(
        request_id=req.id,
        doc_type=dtype,
        url=url,
        file_name=(file.filename or "")[:255] or None,
        review_status="pending",
        review_note=None,
    )
    db.add(doc)
    await db.flush()
    await db.refresh(req, attribute_names=["documents"])
    await db.refresh(business, attribute_names=["factory_images"])
    return build_verification_payload(
        user=user, business=business, request=req, locale="uz"
    )


async def delete_verification_document(
    db: AsyncSession, user: User, document_id: int
) -> dict:
    business = _require_business(user)
    result = await db.execute(
        select(BusinessVerificationDocument)
        .join(BusinessVerificationRequest)
        .where(
            BusinessVerificationDocument.id == document_id,
            BusinessVerificationRequest.user_id == user.id,
        )
        .options(
            selectinload(BusinessVerificationDocument.request).selectinload(
                BusinessVerificationRequest.documents
            )
        )
    )
    doc = result.scalar_one_or_none()
    if doc is None:
        raise AppError(message="Hujjat topilmadi", error_code="NOT_FOUND", status_code=404)
    req = doc.request
    if req.status == "pending":
        raise AppError(
            message="Ko‘rib chiqilayotgan arizadan hujjat o‘chirib bo‘lmaydi",
            error_code="VERIFICATION_PENDING",
            status_code=400,
        )
    if req.status == "approved" or business.documents_verified:
        raise AppError(
            message="Tasdiqlangan arizani o‘zgartirib bo‘lmaydi",
            error_code="ALREADY_VERIFIED",
            status_code=400,
        )
    if req.status not in {"draft", "rejected", "needs_resubmit"}:
        raise AppError(
            message="Bu holatda hujjat o‘chirib bo‘lmaydi",
            error_code="INVALID_STATUS",
            status_code=400,
        )
    await db.delete(doc)
    await db.flush()
    await db.refresh(req, attribute_names=["documents"])
    await db.refresh(business, attribute_names=["factory_images"])
    return build_verification_payload(
        user=user, business=business, request=req, locale="uz"
    )


async def submit_verification(
    db: AsyncSession, user: User, *, note: str | None = None, locale: str = "uz"
) -> dict:
    business = _require_business(user)
    if business.documents_verified or user.verified_badge:
        raise AppError(
            message="Allaqachon tasdiqlangan",
            error_code="ALREADY_VERIFIED",
            status_code=400,
        )
    req = await _latest_editable_request(db, user_id=user.id, business_id=business.id)
    if req.status == "pending":
        raise AppError(
            message="Ariza allaqachon yuborilgan",
            error_code="ALREADY_SUBMITTED",
            status_code=400,
        )
    await db.refresh(business, attribute_names=["factory_images"])
    payload = build_verification_payload(
        user=user, business=business, request=req, locale=locale
    )
    if payload["missing_required"]:
        raise AppError(
            message="Majburiy hujjatlar yetishmayapti",
            error_code="MISSING_REQUIRED_DOCS",
            status_code=400,
            extra={"missing": payload["missing_required"]},
        )
    req.status = "pending"
    req.note = (note or "").strip()[:500] or None
    req.submitted_at = datetime.now(UTC)
    req.admin_note = None
    req.reviewed_at = None
    req.reviewed_by_admin_id = None
    for d in req.documents or []:
        # Keep approved docs marked; resubmit/rejected reset to pending for re-review
        if (getattr(d, "review_status", None) or "pending") != "approved":
            d.review_status = "pending"
            d.review_note = None
    await db.flush()
    await db.refresh(req, attribute_names=["documents"])
    return build_verification_payload(
        user=user, business=business, request=req, locale=locale
    )


async def list_admin_verification_requests(
    db: AsyncSession,
    *,
    status: str | None = "pending",
    q: str | None = None,
    sla_only: bool = False,
    page: int | None = None,
    limit: int | None = None,
    sort: str | None = None,
    order: str | None = None,
) -> dict:
    from app.core.pagination import normalize_page
    from app.services.admin_list import apply_sort

    params = normalize_page(page, limit, default_size=50, max_size=100)
    query = select(BusinessVerificationRequest).options(
        selectinload(BusinessVerificationRequest.documents)
    )
    if status and status != "all":
        query = query.where(BusinessVerificationRequest.status == status)
    else:
        query = query.where(
            BusinessVerificationRequest.status.in_(
                ["pending", "approved", "rejected", "needs_resubmit"]
            )
        )

    now = datetime.now(UTC)
    if sla_only:
        sla_cutoff = now - timedelta(hours=SLA_HOURS)
        query = query.where(
            BusinessVerificationRequest.status == "pending",
            BusinessVerificationRequest.submitted_at.is_not(None),
            BusinessVerificationRequest.submitted_at <= sla_cutoff,
        )

    if q and q.strip():
        term = q.strip()
        user_ids_q = select(User.id).where(
            or_(
                User.email.ilike(f"%{term}%"),
                User.number.ilike(f"%{term}%"),
                User.full_name.ilike(f"%{term}%"),
            )
        )
        biz_ids_q = select(BusinessProfile.id).where(
            BusinessProfile.company_name.ilike(f"%{term}%")
        )
        query = query.where(
            or_(
                BusinessVerificationRequest.user_id.in_(user_ids_q),
                BusinessVerificationRequest.business_id.in_(biz_ids_q),
            )
        )

    total = int(
        (await db.execute(select(func.count()).select_from(query.order_by(None).subquery()))).scalar()
        or 0
    )

    # Default: pending queue — SLA first (red), then oldest submitted
    use_priority = (sort is None or sort == "priority") and (
        status in (None, "pending", "") or sla_only
    )
    if use_priority:
        sla_cutoff = now - timedelta(hours=SLA_HOURS)
        sla_rank = case(
            (
                and_(
                    BusinessVerificationRequest.submitted_at.is_not(None),
                    BusinessVerificationRequest.submitted_at <= sla_cutoff,
                ),
                0,
            ),
            else_=1,
        )
        # Need and_ import
        order_expr = (
            sla_rank.asc(),
            nulls_last(BusinessVerificationRequest.submitted_at.asc()),
            BusinessVerificationRequest.id.asc(),
        )
    else:
        order_by = apply_sort(
            {
                "id": BusinessVerificationRequest.id,
                "submitted_at": BusinessVerificationRequest.submitted_at,
                "status": BusinessVerificationRequest.status,
            },
            sort=sort,
            order=order,
            default="submitted_at",
        )
        if (sort or "submitted_at") == "submitted_at" and (order or "desc").lower() != "asc":
            order_expr = (nulls_last(BusinessVerificationRequest.submitted_at.desc()),)
        else:
            order_expr = (order_by,)

    rows = list(
        (
            await db.execute(
                query.order_by(*order_expr).offset(params.offset).limit(params.page_size)
            )
        )
        .scalars()
        .all()
    )

    # Rejection history counts for businesses on this page
    biz_ids = list({r.business_id for r in rows})
    reject_counts: dict[int, int] = {b: 0 for b in biz_ids}
    if biz_ids:
        rej_rows = (
            await db.execute(
                select(
                    BusinessVerificationRequest.business_id,
                    func.count(),
                )
                .where(
                    BusinessVerificationRequest.business_id.in_(biz_ids),
                    BusinessVerificationRequest.status.in_(["rejected", "needs_resubmit"]),
                )
                .group_by(BusinessVerificationRequest.business_id)
            )
        ).all()
        for bid, c in rej_rows:
            reject_counts[int(bid)] = int(c)

    out: list[dict] = []
    for req in rows:
        user = await db.get(User, req.user_id)
        biz = await db.get(BusinessProfile, req.business_id)
        sla = _sla_fields(req.submitted_at, now=now)
        out.append(
            {
                "id": req.id,
                "status": req.status,
                "user_id": req.user_id,
                "business_id": req.business_id,
                "company_name": (biz.company_name if biz else None)
                or (user.full_name if user else None),
                "email": user.email if user else None,
                "number": user.number if user else None,
                "note": req.note,
                "admin_note": req.admin_note,
                "submitted_at": req.submitted_at.isoformat()
                if req.submitted_at
                else None,
                "reviewed_at": req.reviewed_at.isoformat()
                if req.reviewed_at
                else None,
                "documents": [_serialize_doc(d) for d in (req.documents or [])],
                "documents_verified": bool(biz.documents_verified) if biz else False,
                "verified_badge": bool(user.verified_badge) if user else False,
                "rejection_count": reject_counts.get(req.business_id, 0),
                **sla,
            }
        )
    return {
        "items": out,
        "page": params.page,
        "limit": params.page_size,
        "total": total,
        "has_more": params.offset + len(out) < total,
        "sla_hours": SLA_HOURS,
        "reject_macros": get_reject_macros(locale="uz"),
    }


async def get_admin_verification_request(db: AsyncSession, request_id: int) -> dict:
    result = await db.execute(
        select(BusinessVerificationRequest)
        .where(BusinessVerificationRequest.id == request_id)
        .options(selectinload(BusinessVerificationRequest.documents))
    )
    req = result.scalar_one_or_none()
    if req is None:
        raise AppError(message="Ariza topilmadi", error_code="NOT_FOUND", status_code=404)

    user = await db.get(User, req.user_id)
    biz = await db.get(BusinessProfile, req.business_id)
    now = datetime.now(UTC)
    sla = _sla_fields(req.submitted_at, now=now)

    history_rows = list(
        (
            await db.execute(
                select(BusinessVerificationRequest)
                .where(
                    BusinessVerificationRequest.business_id == req.business_id,
                    BusinessVerificationRequest.id != req.id,
                    BusinessVerificationRequest.status.in_(
                        ["rejected", "needs_resubmit", "approved", "pending"]
                    ),
                )
                .order_by(BusinessVerificationRequest.id.desc())
                .limit(20)
            )
        )
        .scalars()
        .all()
    )
    rejection_count = int(
        (
            await db.execute(
                select(func.count())
                .select_from(BusinessVerificationRequest)
                .where(
                    BusinessVerificationRequest.business_id == req.business_id,
                    BusinessVerificationRequest.status.in_(["rejected", "needs_resubmit"]),
                )
            )
        ).scalar()
        or 0
    )

    return {
        "id": req.id,
        "status": req.status,
        "user_id": req.user_id,
        "business_id": req.business_id,
        "company_name": (biz.company_name if biz else None)
        or (user.full_name if user else None),
        "email": user.email if user else None,
        "number": user.number if user else None,
        "note": req.note,
        "admin_note": req.admin_note,
        "submitted_at": req.submitted_at.isoformat() if req.submitted_at else None,
        "reviewed_at": req.reviewed_at.isoformat() if req.reviewed_at else None,
        "documents": [_serialize_doc(d) for d in (req.documents or [])],
        "documents_verified": bool(biz.documents_verified) if biz else False,
        "verified_badge": bool(user.verified_badge) if user else False,
        "rejection_count": rejection_count,
        "history": [
            {
                "id": h.id,
                "status": h.status,
                "admin_note": h.admin_note,
                "submitted_at": h.submitted_at.isoformat() if h.submitted_at else None,
                "reviewed_at": h.reviewed_at.isoformat() if h.reviewed_at else None,
            }
            for h in history_rows
        ],
        "reject_macros": get_reject_macros(locale="uz"),
        **sla,
    }


async def decide_verification_request(
    db: AsyncSession,
    *,
    request_id: int,
    admin: AdminUser,
    approve: bool,
    admin_note: str | None = None,
) -> dict:
    result = await db.execute(
        select(BusinessVerificationRequest)
        .where(BusinessVerificationRequest.id == request_id)
        .options(selectinload(BusinessVerificationRequest.documents))
    )
    req = result.scalar_one_or_none()
    if req is None:
        raise AppError(message="Ariza topilmadi", error_code="NOT_FOUND", status_code=404)
    if req.status != "pending":
        raise AppError(
            message="Faqat pending arizani qaror qilish mumkin",
            error_code="INVALID_STATUS",
            status_code=400,
        )

    user = await db.get(User, req.user_id)
    biz = await db.get(BusinessProfile, req.business_id)
    if user is None or biz is None:
        raise AppError(message="Foydalanuvchi topilmadi", error_code="NOT_FOUND", status_code=404)

    req.reviewed_at = datetime.now(UTC)
    req.reviewed_by_admin_id = admin.id
    req.admin_note = (admin_note or "").strip()[:500] or None

    if approve:
        req.status = "approved"
        for d in req.documents or []:
            d.review_status = "approved"
            d.review_note = None
        biz.documents_verified = True
        user.verified_badge = True
        uploaded = {d.doc_type for d in (req.documents or [])}
        has_factory = "factory_photo" in uploaded
        if not has_factory:
            await db.refresh(biz, attribute_names=["factory_images"])
            has_factory = bool(biz.factory_images)
        if has_factory:
            biz.factory_verified = True
        if "audit_report" in uploaded or (biz.audit_report_url or "").strip():
            biz.inspection_passed = True
    else:
        req.status = "rejected"
        for d in req.documents or []:
            d.review_status = "rejected"
            if not d.review_note:
                d.review_note = req.admin_note
        if not req.admin_note:
            raise AppError(
                message="Rad etish sababi majburiy",
                error_code="ADMIN_NOTE_REQUIRED",
                status_code=400,
            )

    await db.flush()
    return {
        "id": req.id,
        "status": req.status,
        "admin_note": req.admin_note,
        "documents_verified": bool(biz.documents_verified),
        "verified_badge": bool(user.verified_badge),
        "factory_verified": bool(biz.factory_verified),
    }


async def partial_decide_verification_request(
    db: AsyncSession,
    *,
    request_id: int,
    admin: AdminUser,
    documents: list[dict[str, Any]],
    admin_note: str | None = None,
) -> dict:
    """Per-document approve / resubmit. Mix → needs_resubmit; all approve → approved."""
    result = await db.execute(
        select(BusinessVerificationRequest)
        .where(BusinessVerificationRequest.id == request_id)
        .options(selectinload(BusinessVerificationRequest.documents))
    )
    req = result.scalar_one_or_none()
    if req is None:
        raise AppError(message="Ariza topilmadi", error_code="NOT_FOUND", status_code=404)
    if req.status != "pending":
        raise AppError(
            message="Faqat pending arizani qaror qilish mumkin",
            error_code="INVALID_STATUS",
            status_code=400,
        )
    if not documents:
        raise AppError(
            message="Hujjat qarorlari kerak",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )

    user = await db.get(User, req.user_id)
    biz = await db.get(BusinessProfile, req.business_id)
    if user is None or biz is None:
        raise AppError(message="Foydalanuvchi topilmadi", error_code="NOT_FOUND", status_code=404)

    by_id = {d.id: d for d in (req.documents or [])}
    decisions: dict[int, tuple[str, str | None]] = {}
    for item in documents:
        doc_id = int(item.get("id") or 0)
        status = str(item.get("review_status") or "").strip().lower()
        note = (item.get("review_note") or item.get("note") or "").strip()[:500] or None
        if doc_id not in by_id:
            raise AppError(
                message=f"Hujjat topilmadi: {doc_id}",
                error_code="DOC_NOT_FOUND",
                status_code=400,
            )
        if status not in {"approved", "resubmit", "rejected"}:
            raise AppError(
                message="review_status: approved|resubmit|rejected",
                error_code="VALIDATION_ERROR",
                status_code=400,
            )
        if status in {"resubmit", "rejected"} and not note:
            raise AppError(
                message="Qayta so‘rov / rad uchun izoh majburiy",
                error_code="DOC_NOTE_REQUIRED",
                status_code=400,
            )
        decisions[doc_id] = (status, note)

    # Apply — docs not in payload stay pending (treated as not reviewed → error)
    pending_docs = [d for d in (req.documents or []) if d.id not in decisions]
    if pending_docs:
        raise AppError(
            message="Barcha hujjatlar uchun qaror kerak",
            error_code="INCOMPLETE_REVIEW",
            status_code=400,
            extra={"missing_doc_ids": [d.id for d in pending_docs]},
        )

    for doc_id, (status, note) in decisions.items():
        doc = by_id[doc_id]
        doc.review_status = status
        doc.review_note = note

    statuses = {s for s, _ in decisions.values()}
    req.reviewed_at = datetime.now(UTC)
    req.reviewed_by_admin_id = admin.id

    notes = [n for _, n in decisions.values() if n]
    summary = (admin_note or "").strip()[:500] or None
    if not summary and notes:
        summary = "; ".join(notes)[:500]
    req.admin_note = summary

    if statuses == {"approved"}:
        req.status = "approved"
        biz.documents_verified = True
        user.verified_badge = True
        uploaded = {d.doc_type for d in (req.documents or [])}
        has_factory = "factory_photo" in uploaded
        if not has_factory:
            await db.refresh(biz, attribute_names=["factory_images"])
            has_factory = bool(biz.factory_images)
        if has_factory:
            biz.factory_verified = True
        if "audit_report" in uploaded or (biz.audit_report_url or "").strip():
            biz.inspection_passed = True
    elif statuses == {"rejected"}:
        req.status = "rejected"
        if not req.admin_note:
            raise AppError(
                message="Rad etish sababi majburiy",
                error_code="ADMIN_NOTE_REQUIRED",
                status_code=400,
            )
    else:
        # Mix or any resubmit → partial
        req.status = "needs_resubmit"
        if not req.admin_note:
            raise AppError(
                message="Qisman rad / qayta so‘rov uchun umumiy izoh kerak",
                error_code="ADMIN_NOTE_REQUIRED",
                status_code=400,
            )

    await db.flush()
    return {
        "id": req.id,
        "status": req.status,
        "admin_note": req.admin_note,
        "documents": [_serialize_doc(d) for d in (req.documents or [])],
        "documents_verified": bool(biz.documents_verified),
        "verified_badge": bool(user.verified_badge),
        "factory_verified": bool(biz.factory_verified),
    }
