"""Business verification — required docs, submit, admin approve."""

from __future__ import annotations

import uuid
from datetime import UTC, datetime

from fastapi import UploadFile
from sqlalchemy import select
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


def _label_for(meta: dict[str, str], locale: str) -> str:
    loc = (locale or "uz").lower().split("_")[0]
    if loc in {"ru", "rus"}:
        return meta["label_ru"]
    if loc in {"en", "us", "gb", "eng"}:
        return meta["label_en"]
    return meta["label_uz"]


def _require_business(user: User) -> BusinessProfile:
    if not user.is_business or user.business is None:
        raise AppError(
            message="Faqat business akkaunt uchun",
            error_code="NOT_A_BUSINESS",
            status_code=403,
        )
    return user.business


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
    if req is not None and req.status in {"draft", "rejected", "pending"}:
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
        "created_at": doc.created_at.isoformat() if doc.created_at else None,
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
        status in {"draft", "rejected"}
        and len(missing_required) == 0
        and not (business.documents_verified or user.verified_badge)
    )
    can_upload = status in {"draft", "rejected", "none"} and not (
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
    if req.status == "rejected":
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
    await db.flush()
    await db.refresh(req, attribute_names=["documents"])
    return build_verification_payload(
        user=user, business=business, request=req, locale=locale
    )


async def list_admin_verification_requests(
    db: AsyncSession,
    *,
    status: str | None = "pending",
    limit: int = 50,
) -> list[dict]:
    q = (
        select(BusinessVerificationRequest)
        .options(selectinload(BusinessVerificationRequest.documents))
        .order_by(BusinessVerificationRequest.submitted_at.desc().nullslast())
        .limit(min(limit, 100))
    )
    if status and status != "all":
        q = q.where(BusinessVerificationRequest.status == status)
    else:
        q = q.where(BusinessVerificationRequest.status.in_(["pending", "approved", "rejected"]))
    rows = (await db.execute(q)).scalars().all()
    out: list[dict] = []
    for req in rows:
        user = await db.get(User, req.user_id)
        biz = await db.get(BusinessProfile, req.business_id)
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
            }
        )
    return out


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
        biz.documents_verified = True
        user.verified_badge = True
        # Zavod/audit hujjati bo‘lsa — factory ishonch belgisini ham beramiz.
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
