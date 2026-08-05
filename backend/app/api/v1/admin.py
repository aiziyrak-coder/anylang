from __future__ import annotations

from decimal import Decimal
from typing import Literal

from fastapi import APIRouter, Query, Request, Response, status
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy import func, select
from sqlalchemy.orm import selectinload

from app.api.deps_admin import CurrentAdmin
from app.core.deps import DbSession, RedisClient
from app.core.errors import AppError
from app.core.pagination import normalize_page
from app.models.chat import Chat
from app.models.payment import Payment
from app.models.product import Product
from app.models.user import BusinessProfile, NumberGroup, Subscription, User
from app.services import admin_auth
from app.services import numbers as numbers_service
from app.services import products as products_service
from app.services.admin_ops import (
    FinancePlus,
    ModeratorPlus,
    SupportOrModerator,
    client_ip,
    write_audit,
)
from app.schemas.product import AdminTopRequestReviewIn

router = APIRouter()


class AdminLoginIn(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8)


class AdminLoginOut(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    admin: dict


class AdminUserOut(BaseModel):
    id: int
    full_name: str
    email: str
    number: str
    is_active: bool
    is_verified: bool
    verified_badge: bool
    factory_verified: bool = False
    inspection_passed: bool = False
    audit_report_url: str | None = None
    created_at: object


class AdminUserListOut(BaseModel):
    items: list[AdminUserOut]
    page: int
    limit: int
    total: int
    has_more: bool


class AdminUserPatchIn(BaseModel):
    is_active: bool | None = None
    verified_badge: bool | None = None
    factory_verified: bool | None = None
    inspection_passed: bool | None = None
    audit_report_url: str | None = None


class AdminNumberGroupOut(BaseModel):
    id: int
    name: str
    patterns: list[str]
    price: str
    effective_price: str | None = None
    currency: str
    bonus_plan: str | None = None
    bonus_duration_months: int | None = None
    priority: int
    is_active: bool
    pricing_rules: dict = Field(default_factory=dict)
    capacity_est: int | None = None
    assigned: int | None = None
    reserved: int | None = None
    sold_7d: int | None = None
    fill_pct: float | None = None


class AdminNumberGroupCreateIn(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    patterns: list[str] = Field(min_length=1)
    price: Decimal = Field(ge=0)
    currency: str = "USD"
    bonus_plan: str | None = None
    bonus_duration_months: int | None = None
    priority: int = 0
    is_active: bool = True
    pricing_rules: dict | None = None


class AdminNumberGroupPatchIn(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=100)
    patterns: list[str] | None = None
    price: Decimal | None = Field(default=None, ge=0)
    currency: str | None = None
    bonus_plan: str | None = None
    bonus_duration_months: int | None = None
    priority: int | None = None
    is_active: bool | None = None
    pricing_rules: dict | None = None


class PatternSimulateIn(BaseModel):
    pattern: str = Field(min_length=1, max_length=64)
    preview_limit: int = Field(default=24, ge=1, le=100)


class NumberGroupImportIn(BaseModel):
    items: list[dict] = Field(min_length=1, max_length=200)
    upsert: bool = True


class AdminPinProductIn(BaseModel):
    pinned: bool


class AdminProductModerationIn(BaseModel):
    approve: bool
    admin_note: str | None = Field(default=None, max_length=500)


class AdminProductBulkModerateIn(BaseModel):
    product_ids: list[int] = Field(min_length=1, max_length=50)
    approve: bool
    admin_note: str | None = Field(default=None, max_length=500)


class AdminStatsOut(BaseModel):
    users_total: int
    users_active: int
    subscriptions_active: int
    products_published: int
    products_archived: int
    chats_total: int
    messages_total: int
    messages_total_approx: bool = False
    number_groups_total: int


class AdminPaymentOut(BaseModel):
    id: int
    user_id: int
    kind: str
    status: str
    provider: str
    amount: str
    currency: str
    plan: str | None = None
    billing_cycle: str | None = None
    number: str | None = None
    paid_at: object | None = None
    created_at: object


class AdminPaymentListOut(BaseModel):
    items: list[AdminPaymentOut]
    page: int
    limit: int
    total: int
    has_more: bool


def _serialize_admin_user(user: User) -> dict:
    biz = user.business
    return {
        "id": user.id,
        "full_name": user.full_name,
        "email": user.email,
        "number": user.number,
        "is_active": user.is_active,
        "is_verified": user.is_verified,
        "verified_badge": user.verified_badge,
        "factory_verified": bool(biz.factory_verified) if biz is not None else False,
        "inspection_passed": bool(biz.inspection_passed) if biz is not None else False,
        "audit_report_url": (biz.audit_report_url if biz is not None else None),
        "created_at": user.created_at,
    }


def _serialize_number_group(group: NumberGroup) -> dict:
    from app.services.numbers_admin import effective_group_price, estimate_group_capacity

    eff = effective_group_price(group)
    return {
        "id": group.id,
        "name": group.name,
        "patterns": list(group.patterns or []),
        "price": f"{group.price:.2f}",
        "effective_price": f"{eff:.2f}",
        "currency": group.currency,
        "bonus_plan": group.bonus_plan,
        "bonus_duration_months": group.bonus_duration_months,
        "priority": group.priority,
        "is_active": group.is_active,
        "pricing_rules": dict(group.pricing_rules or {}),
        "capacity_est": estimate_group_capacity(group),
    }


@router.get("/me")
async def admin_me(admin: CurrentAdmin) -> dict:
    return {
        "id": admin.id,
        "email": admin.email,
        "full_name": admin.full_name,
        "role": admin.role,
    }


@router.post("/auth/login", response_model=AdminLoginOut)
async def admin_login(
    body: AdminLoginIn,
    db: DbSession,
    redis: RedisClient,
    request: Request,
) -> AdminLoginOut:
    email = str(body.email).lower().strip()
    client_ip = (request.client.host if request.client else "unknown") or "unknown"
    # Rate-limit by email AND by IP (brute-force / credential stuffing).
    keys = [f"admin:login:email:{email}", f"admin:login:ip:{client_ip}"]
    for key in keys:
        attempts = await redis.incr(key)
        if attempts == 1:
            await redis.expire(key, 900)
        if attempts > 8:
            raise AppError(
                message="Juda ko'p urinish — 15 daqiqadan keyin qayta urinib ko'ring",
                error_code="TOO_MANY_ATTEMPTS",
                status_code=429,
            )

    data = await admin_auth.login_admin(db, email=email, password=body.password)
    for key in keys:
        await redis.delete(key)
    return AdminLoginOut.model_validate(data)


@router.get("/users", response_model=None)
async def admin_list_users(
    db: DbSession,
    _admin: SupportOrModerator,
    search: str | None = Query(default=None),
    q: str | None = Query(default=None),
    status_filter: str | None = Query(default="all", alias="status"),
    plan: str | None = Query(default=None),
    country: str | None = Query(default=None),
    verified: str | None = Query(default=None),
    risk: str | None = Query(default=None),
    last_active: str | None = Query(default=None),
    device: str | None = Query(default=None),
    page: int | None = Query(default=None, ge=1),
    limit: int | None = Query(default=None, ge=1, le=100),
    sort: str | None = Query(default=None),
    order: str | None = Query(default=None),
) -> dict:
    from app.services import admin_console as console

    st = status_filter if status_filter in {"all", "active", "inactive", "deleted"} else "all"
    return await console.list_users(
        db,
        search=search or q,
        status=st,  # type: ignore[arg-type]
        plan=plan,
        country=country,
        verified=verified,
        risk=risk,
        last_active=last_active,
        device=device,
        page=page,
        limit=limit,
        sort=sort,
        order=order,
    )


@router.patch("/users/{user_id}", response_model=AdminUserOut)
async def admin_patch_user(
    user_id: int,
    body: AdminUserPatchIn,
    db: DbSession,
    admin: ModeratorPlus,
    request: Request,
) -> AdminUserOut:
    user = await db.get(User, user_id)
    if user is None:
        raise AppError(message="Foydalanuvchi topilmadi", error_code="USER_NOT_FOUND", status_code=404)

    data = body.model_dump(exclude_unset=True)
    if not data:
        return AdminUserOut.model_validate(_serialize_admin_user(user))

    if user.deleted_at is not None:
        raise AppError(
            message="O'chirilgan akkauntni faqat tiklash orqali o'zgartirish mumkin",
            error_code="USER_DELETED",
            status_code=400,
        )

    factory_verified = data.pop("factory_verified", None)
    inspection_passed = data.pop("inspection_passed", None)
    audit_report_url = data.pop("audit_report_url", None)

    before: dict = {}
    after: dict = {}
    for field, value in data.items():
        before[field] = getattr(user, field, None)
        setattr(user, field, value)
        after[field] = value

    needs_biz = (
        data.get("verified_badge") is True
        or factory_verified is not None
        or inspection_passed is not None
        or audit_report_url is not None
    )
    biz = None
    if needs_biz:
        result = await db.execute(
            select(BusinessProfile).where(BusinessProfile.user_id == user.id)
        )
        biz = result.scalar_one_or_none()

    if data.get("verified_badge") is True and biz is not None:
        biz.documents_verified = True

    if biz is not None:
        if factory_verified is not None:
            before["factory_verified"] = bool(biz.factory_verified)
            biz.factory_verified = bool(factory_verified)
            after["factory_verified"] = bool(factory_verified)
            if factory_verified:
                biz.documents_verified = True
                user.verified_badge = True
        if inspection_passed is not None:
            before["inspection_passed"] = bool(biz.inspection_passed)
            biz.inspection_passed = bool(inspection_passed)
            after["inspection_passed"] = bool(inspection_passed)
            if inspection_passed:
                biz.factory_verified = True
                biz.documents_verified = True
                user.verified_badge = True
        if audit_report_url is not None:
            before["audit_report_url"] = biz.audit_report_url
            cleaned = str(audit_report_url or "").strip()
            biz.audit_report_url = cleaned[:512] or None
            after["audit_report_url"] = biz.audit_report_url

    await db.flush()
    await write_audit(
        db,
        admin=admin,
        action="user.patch",
        target_type="user",
        target_id=user_id,
        meta={
            **data,
            **(
                {"factory_verified": factory_verified}
                if factory_verified is not None
                else {}
            ),
            **(
                {"inspection_passed": inspection_passed}
                if inspection_passed is not None
                else {}
            ),
            **(
                {"audit_report_url": audit_report_url}
                if audit_report_url is not None
                else {}
            ),
        },
        before=before,
        after=after,
        ip=client_ip(request),
    )
    # Reload business for serialize
    await db.refresh(user, attribute_names=["business"])
    return AdminUserOut.model_validate(_serialize_admin_user(user))


class AdminAssignNumberIn(BaseModel):
    number: str = Field(min_length=7, max_length=16)
    apply_bonus: bool = False
    force: bool = False


@router.post("/users/{user_id}/assign-number")
async def admin_assign_number(
    user_id: int,
    body: AdminAssignNumberIn,
    db: DbSession,
    admin: ModeratorPlus,
    request: Request,
) -> dict:
    user = await db.get(User, user_id)
    if user is None:
        raise AppError(message="Foydalanuvchi topilmadi", error_code="USER_NOT_FOUND", status_code=404)
    if user.deleted_at is not None:
        raise AppError(
            message="O'chirilgan akkauntga raqam biriktirib bo'lmaydi",
            error_code="USER_DELETED",
            status_code=400,
        )
    data = await numbers_service.admin_assign_number(
        db,
        user,
        body.number,
        apply_bonus=body.apply_bonus,
        force=body.force,
    )
    await write_audit(
        db,
        admin=admin,
        action="number.assign",
        target_type="user",
        target_id=user_id,
        meta={"number": data["number"], "mode": "manual", "force": body.force, "apply_bonus": body.apply_bonus},
        ip=client_ip(request),
    )
    return data


@router.post("/users/{user_id}/assign-random-number")
async def admin_assign_random_number(
    user_id: int,
    db: DbSession,
    admin: ModeratorPlus,
    request: Request,
    apply_bonus: bool = Query(default=False),
) -> dict:
    user = await db.get(User, user_id)
    if user is None:
        raise AppError(message="Foydalanuvchi topilmadi", error_code="USER_NOT_FOUND", status_code=404)
    if user.deleted_at is not None:
        raise AppError(
            message="O'chirilgan akkauntga raqam biriktirib bo'lmaydi",
            error_code="USER_DELETED",
            status_code=400,
        )
    data = await numbers_service.admin_assign_random_number(
        db, user, apply_bonus=apply_bonus
    )
    await write_audit(
        db,
        admin=admin,
        action="number.assign",
        target_type="user",
        target_id=user_id,
        meta={"number": data["number"], "mode": "random", "apply_bonus": apply_bonus},
        ip=client_ip(request),
    )
    return data


@router.get("/number-groups", response_model=list[AdminNumberGroupOut])
async def admin_list_number_groups(
    db: DbSession,
    _admin: ModeratorPlus,
) -> list[AdminNumberGroupOut]:
    await numbers_service.ensure_seed_groups(db)
    result = await db.execute(select(NumberGroup).order_by(NumberGroup.priority.desc()))
    groups = list(result.scalars().all())
    return [AdminNumberGroupOut.model_validate(_serialize_number_group(g)) for g in groups]


@router.post("/number-groups", response_model=AdminNumberGroupOut, status_code=status.HTTP_201_CREATED)
async def admin_create_number_group(
    body: AdminNumberGroupCreateIn,
    db: DbSession,
    admin: ModeratorPlus,
    request: Request,
) -> AdminNumberGroupOut:
    existing = await db.execute(select(NumberGroup).where(NumberGroup.name == body.name))
    if existing.scalar_one_or_none() is not None:
        raise AppError(
            message="Guruh nomi band",
            error_code="GROUP_EXISTS",
            status_code=409,
        )

    from app.services.numbers_admin import _normalize_pricing_rules

    group = NumberGroup(
        name=body.name,
        patterns=list(body.patterns),
        price=body.price,
        currency=body.currency,
        bonus_plan=body.bonus_plan,
        bonus_duration_months=body.bonus_duration_months,
        priority=body.priority,
        is_active=body.is_active,
        pricing_rules=_normalize_pricing_rules(body.pricing_rules) if body.pricing_rules else {},
    )
    db.add(group)
    await db.flush()
    await write_audit(
        db,
        admin=admin,
        action="number_group.create",
        target_type="number_group",
        target_id=group.id,
        meta={"name": group.name},
        ip=client_ip(request),
    )
    await db.refresh(group)
    return AdminNumberGroupOut.model_validate(_serialize_number_group(group))


@router.patch("/number-groups/{group_id}", response_model=AdminNumberGroupOut)
async def admin_patch_number_group(
    group_id: int,
    body: AdminNumberGroupPatchIn,
    db: DbSession,
    admin: ModeratorPlus,
    request: Request,
) -> AdminNumberGroupOut:
    group = await db.get(NumberGroup, group_id)
    if group is None:
        raise AppError(message="Guruh topilmadi", error_code="NOT_FOUND", status_code=404)

    data = body.model_dump(exclude_unset=True)
    if "patterns" in data and data["patterns"] is not None:
        data["patterns"] = list(data["patterns"])
    if "pricing_rules" in data and data["pricing_rules"] is not None:
        from app.services.numbers_admin import _normalize_pricing_rules

        data["pricing_rules"] = _normalize_pricing_rules(data["pricing_rules"])
    before = {k: getattr(group, k) for k in data if hasattr(group, k)}
    for field, value in data.items():
        setattr(group, field, value)

    await db.flush()
    await write_audit(
        db,
        admin=admin,
        action="number_group.patch",
        target_type="number_group",
        target_id=group_id,
        before={k: (dict(v) if isinstance(v, dict) else v) for k, v in before.items()},
        after=data,
        ip=client_ip(request),
    )
    await db.refresh(group)
    return AdminNumberGroupOut.model_validate(_serialize_number_group(group))


@router.get("/number-groups/inventory")
async def admin_number_inventory(db: DbSession, _admin: ModeratorPlus) -> dict:
    from app.services import numbers_admin

    return await numbers_admin.inventory_snapshot(db)


@router.post("/number-groups/simulate")
async def admin_simulate_pattern(
    body: PatternSimulateIn,
    _admin: ModeratorPlus,
) -> dict:
    from app.services import numbers_admin

    return numbers_admin.simulate_pattern(body.pattern, preview_limit=body.preview_limit)


@router.get("/number-groups/sales")
async def admin_number_sales(
    db: DbSession,
    _admin: ModeratorPlus,
    days: int = Query(default=90, ge=1, le=365),
) -> dict:
    from app.services import numbers_admin

    return await numbers_admin.sales_analytics(db, days=days)


@router.get("/number-groups/export")
async def admin_export_number_groups(
    db: DbSession,
    admin: ModeratorPlus,
    request: Request,
    fmt: Literal["csv", "json"] = Query(default="csv"),
) -> Response:
    from app.services import numbers_admin

    filename, media, payload = await numbers_admin.export_groups(
        db, admin=admin, fmt=fmt, ip=client_ip(request)
    )
    return Response(
        content=payload,
        media_type=media,
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.post("/number-groups/import")
async def admin_import_number_groups(
    body: NumberGroupImportIn,
    db: DbSession,
    admin: ModeratorPlus,
    request: Request,
) -> dict:
    from app.services import numbers_admin

    return await numbers_admin.import_groups(
        db,
        admin=admin,
        rows=body.items,
        upsert=body.upsert,
        ip=client_ip(request),
    )


@router.patch("/number-groups/{group_id}/pricing")
async def admin_patch_number_pricing(
    group_id: int,
    body: dict,
    db: DbSession,
    admin: ModeratorPlus,
    request: Request,
) -> dict:
    from app.services import numbers_admin

    return await numbers_admin.patch_pricing_rules(
        db,
        group_id=group_id,
        pricing_rules=body.get("pricing_rules") or body,
        admin=admin,
        ip=client_ip(request),
    )


@router.get("/products")
async def admin_list_products(
    db: DbSession,
    _admin: ModeratorPlus,
    status_filter: str | None = Query(default=None, alias="status"),
    search: str | None = Query(default=None),
    q: str | None = Query(default=None),
    page: int | None = Query(default=None, ge=1),
    limit: int | None = Query(default=None, ge=1, le=100),
    sort: str | None = Query(default=None),
    order: str | None = Query(default=None),
) -> dict:
    from app.services.admin_list import apply_sort, smart_text_search

    params = normalize_page(page, limit, default_size=50, max_size=100)
    query = select(Product)
    if status_filter in {"draft", "pending", "published", "rejected", "archived"}:
        query = query.where(Product.status == status_filter)
    term = (search or q or "").strip()
    if term:
        query = query.where(smart_text_search(term, Product.name, Product.category))
    total = int(
        (await db.execute(select(func.count()).select_from(query.order_by(None).subquery()))).scalar()
        or 0
    )
    order_by = apply_sort(
        {
            "id": Product.id,
            "created_at": Product.created_at,
            "name": Product.name,
            "price": Product.price,
            "status": Product.status,
            "views_count": Product.views_count,
        },
        sort=sort,
        order=order,
        default="id",
    )
    rows = list(
        (
            await db.execute(
                query.options(selectinload(Product.images))
                .order_by(order_by)
                .offset(params.offset)
                .limit(params.page_size)
            )
        ).scalars().all()
    )
    return {
        "items": [
            {
                "id": p.id,
                "seller_id": p.seller_id,
                "name": p.name,
                "short_description": p.short_description,
                "description": p.description,
                "price": f"{p.price:.2f}",
                "currency": p.currency,
                "category": p.category,
                "status": p.status,
                "moderation_note": p.moderation_note or "",
                "moderated_at": p.moderated_at,
                "ai_pre_score": dict(p.ai_pre_score or {}),
                "submitted_at": p.submitted_at,
                "is_top_pinned": p.is_top_pinned,
                "views_count": p.views_count,
                "primary_image_url": next(
                    (img.url for img in (p.images or []) if img.is_primary),
                    (p.images[0].url if p.images else None),
                ),
                "image_urls": [img.url for img in sorted(p.images or [], key=lambda x: x.position)],
                "created_at": p.created_at,
            }
            for p in rows
        ],
        "page": params.page,
        "limit": params.page_size,
        "total": total,
        "has_more": params.offset + len(rows) < total,
    }


@router.post("/products/{product_id}/pin")
async def admin_pin_product(
    product_id: int,
    body: AdminPinProductIn,
    db: DbSession,
    admin: ModeratorPlus,
    request: Request,
) -> dict:
    from datetime import UTC, datetime, timedelta

    from app.services.products import (
        PRODUCT_TOP_BOOST_DAYS,
        PRODUCT_TOP_SLOTS,
        count_active_top_slots,
        promote_top_queue,
    )

    product = await db.get(Product, product_id)
    if product is None:
        raise AppError(message="Mahsulot topilmadi", error_code="PRODUCT_NOT_FOUND", status_code=404)

    if body.pinned:
        if product.status != "published":
            raise AppError(
                message="Faqat tasdiqlangan (published) mahsulotni pin qilish mumkin",
                error_code="VALIDATION_ERROR",
                status_code=400,
            )
        slots = await count_active_top_slots(db)
        if not product.is_top_pinned and slots >= PRODUCT_TOP_SLOTS:
            raise AppError(
                message=f"Top band ({PRODUCT_TOP_SLOTS}/{PRODUCT_TOP_SLOTS}). Navbatdan chiqishini kuting yoki birini oling.",
                error_code="TOP_SLOTS_FULL",
                status_code=400,
            )
        product.is_top_pinned = True
        product.top_pinned_until = datetime.now(UTC) + timedelta(days=PRODUCT_TOP_BOOST_DAYS)
    else:
        product.is_top_pinned = False
        product.top_pinned_until = None
        await promote_top_queue(db)

    await db.flush()
    await write_audit(
        db,
        admin=admin,
        action="product.pin",
        target_type="product",
        target_id=product_id,
        meta={"pinned": body.pinned},
        ip=client_ip(request),
    )
    return {"id": product.id, "pinned": product.is_top_pinned}


@router.get("/products/moderation/kanban")
async def admin_product_moderation_kanban(
    db: DbSession,
    _admin: ModeratorPlus,
) -> dict:
    from app.services import product_moderation

    return await product_moderation.moderation_kanban(db)


@router.get("/products/moderation/{product_id}")
async def admin_product_moderation_detail(
    product_id: int,
    db: DbSession,
    _admin: ModeratorPlus,
) -> dict:
    from app.services import product_moderation

    return await product_moderation.moderation_detail(db, product_id=product_id)


@router.post("/products/moderation/bulk")
async def admin_product_moderation_bulk(
    body: AdminProductBulkModerateIn,
    db: DbSession,
    admin: ModeratorPlus,
    request: Request,
) -> dict:
    from app.services import product_moderation

    return await product_moderation.bulk_moderate(
        db,
        product_ids=body.product_ids,
        approve=body.approve,
        admin_note=body.admin_note,
        admin=admin,
        ip=client_ip(request),
    )


@router.post("/products/{product_id}/moderate")
async def admin_moderate_product(
    product_id: int,
    body: AdminProductModerationIn,
    db: DbSession,
    admin: ModeratorPlus,
    request: Request,
) -> dict:
    data = await products_service.moderate_product(
        db,
        product_id=product_id,
        admin_id=admin.id,
        approve=body.approve,
        admin_note=body.admin_note,
    )
    await write_audit(
        db,
        admin=admin,
        action="product.moderate.approve" if body.approve else "product.moderate.reject",
        target_type="product",
        target_id=product_id,
        meta={"approve": body.approve, "status": data.get("status"), "strike": data.get("seller_strike")},
        before=None,
        after={"status": data.get("status"), "note": data.get("moderation_note")},
        ip=client_ip(request),
    )
    return data


@router.post("/products/{product_id}/archive")
async def admin_archive_product(
    product_id: int,
    db: DbSession,
    admin: ModeratorPlus,
    request: Request,
) -> dict:
    product = await db.get(Product, product_id)
    if product is None:
        raise AppError(message="Mahsulot topilmadi", error_code="PRODUCT_NOT_FOUND", status_code=404)

    product.status = "archived"
    product.is_top_pinned = False
    await db.flush()
    await write_audit(
        db,
        admin=admin,
        action="product.archive",
        target_type="product",
        target_id=product_id,
        ip=client_ip(request),
    )
    return {"id": product.id, "status": product.status}


@router.get("/product-top-requests")
async def admin_list_top_requests(
    db: DbSession,
    _admin: ModeratorPlus,
    status_filter: str | None = Query(default="queued", alias="status"),
    page: int | None = Query(default=None, ge=1),
    limit: int | None = Query(default=None, ge=1, le=100),
) -> dict:
    return await products_service.list_top_requests(
        db,
        status=status_filter,
        page=page,
        limit=limit,
    )


@router.post("/product-top-requests/{request_id}/approve")
async def admin_approve_top_request(
    request_id: int,
    db: DbSession,
    admin: ModeratorPlus,
    request: Request,
    body: AdminTopRequestReviewIn | None = None,
) -> dict:
    data = await products_service.review_top_request(
        db,
        request_id=request_id,
        approve=True,
        admin_id=admin.id,
        admin_note=(body.admin_note if body else ""),
    )
    await write_audit(
        db,
        admin=admin,
        action="product.top_request.approve",
        target_type="product_top_request",
        target_id=request_id,
        meta={"product_id": data.get("product_id")},
        ip=client_ip(request),
    )
    return data


@router.post("/product-top-requests/{request_id}/reject")
async def admin_reject_top_request(
    request_id: int,
    db: DbSession,
    admin: ModeratorPlus,
    request: Request,
    body: AdminTopRequestReviewIn | None = None,
) -> dict:
    data = await products_service.review_top_request(
        db,
        request_id=request_id,
        approve=False,
        admin_id=admin.id,
        admin_note=(body.admin_note if body else ""),
    )
    await write_audit(
        db,
        admin=admin,
        action="product.top_request.reject",
        target_type="product_top_request",
        target_id=request_id,
        meta={"product_id": data.get("product_id")},
        ip=client_ip(request),
    )
    return data


@router.get("/stats", response_model=AdminStatsOut)
async def admin_stats(db: DbSession, _admin: ModeratorPlus) -> AdminStatsOut:
    users_total = int((await db.execute(select(func.count()).select_from(User))).scalar() or 0)
    users_active = int(
        (await db.execute(select(func.count()).select_from(User).where(User.is_active.is_(True)))).scalar()
        or 0
    )
    subscriptions_active = int(
        (
            await db.execute(
                select(func.count()).select_from(Subscription).where(Subscription.is_active.is_(True))
            )
        ).scalar()
        or 0
    )
    products_published = int(
        (
            await db.execute(
                select(func.count()).select_from(Product).where(Product.status == "published")
            )
        ).scalar()
        or 0
    )
    products_archived = int(
        (
            await db.execute(
                select(func.count()).select_from(Product).where(Product.status == "archived")
            )
        ).scalar()
        or 0
    )
    chats_total = int((await db.execute(select(func.count()).select_from(Chat))).scalar() or 0)
    from app.services.admin_console import approx_message_count

    messages_total, messages_approx = await approx_message_count(db)
    number_groups_total = int(
        (await db.execute(select(func.count()).select_from(NumberGroup))).scalar() or 0
    )

    return AdminStatsOut.model_validate(
        {
            "users_total": users_total,
            "users_active": users_active,
            "subscriptions_active": subscriptions_active,
            "products_published": products_published,
            "products_archived": products_archived,
            "chats_total": chats_total,
            "messages_total": messages_total,
            "messages_total_approx": messages_approx,
            "number_groups_total": number_groups_total,
        }
    )


def _serialize_admin_payment(payment: Payment) -> dict:
    return {
        "id": payment.id,
        "user_id": payment.user_id,
        "kind": payment.kind,
        "status": payment.status,
        "provider": payment.provider,
        "amount": f"{payment.amount:.2f}",
        "currency": payment.currency,
        "plan": payment.plan,
        "billing_cycle": payment.billing_cycle,
        "number": payment.number,
        "paid_at": payment.paid_at,
        "created_at": payment.created_at,
    }


@router.get("/payments")
async def admin_list_payments(
    db: DbSession,
    _admin: FinancePlus,
    status_filter: str | None = Query(default=None, alias="status"),
    kind: str | None = None,
    plan: str | None = None,
    provider: str | None = None,
    q: str | None = None,
    date_from: str | None = Query(default=None, alias="from"),
    date_to: str | None = Query(default=None, alias="to"),
    page: int | None = Query(default=None, ge=1),
    limit: int | None = Query(default=None, ge=1, le=100),
    sort: str | None = Query(default=None),
    order: str | None = Query(default=None),
) -> dict:
    from datetime import date as date_cls

    from app.services import admin_console as console

    try:
        df = date_cls.fromisoformat(date_from) if date_from else None
        dt = date_cls.fromisoformat(date_to) if date_to else None
    except ValueError as exc:
        raise AppError(
            message="Sana formati noto'g'ri (YYYY-MM-DD)",
            error_code="VALIDATION_ERROR",
            status_code=400,
        ) from exc
    return await console.list_payments_filtered(
        db,
        status=status_filter,
        kind=kind,
        plan=plan,
        provider=provider,
        q=q,
        date_from=df,
        date_to=dt,
        page=page,
        limit=limit,
        sort=sort,
        order=order,
    )


class AdminVerificationDecideIn(BaseModel):
    approve: bool
    admin_note: str | None = Field(default=None, max_length=500)


class AdminBusinessReviewModerateIn(BaseModel):
    approve: bool
    admin_note: str | None = Field(default=None, max_length=500)


class AdminBusinessReviewHideIn(BaseModel):
    hide: bool = True
    reason: str | None = Field(default=None, max_length=500)


class AdminBusinessReviewBulkIn(BaseModel):
    review_ids: list[int] = Field(min_length=1, max_length=50)
    action: Literal["approve", "reject", "hide", "unhide"]
    admin_note: str | None = Field(default=None, max_length=500)


@router.get("/business-reviews/stats")
async def admin_business_review_stats(
    db: DbSession,
    _admin: ModeratorPlus,
    business_user_id: int | None = Query(default=None),
) -> dict:
    from app.services import business_reviews as reviews_service

    return await reviews_service.admin_review_stats(
        db, business_user_id=business_user_id
    )


@router.get("/business-reviews")
async def admin_list_business_reviews(
    db: DbSession,
    _admin: ModeratorPlus,
    status_filter: str | None = Query(default="pending", alias="status"),
    q: str | None = Query(default=None),
    page: int | None = Query(default=None, ge=1),
    limit: int | None = Query(default=None, ge=1, le=100),
    fake_only: bool = Query(default=False),
    toxic_only: bool = Query(default=False),
    business_user_id: int | None = Query(default=None),
) -> dict:
    from app.services import business_reviews as reviews_service

    return await reviews_service.list_admin_reviews(
        db,
        status=status_filter,
        q=q,
        page=page,
        limit=limit,
        fake_only=fake_only,
        toxic_only=toxic_only,
        business_user_id=business_user_id,
    )


@router.post("/business-reviews/bulk")
async def admin_bulk_business_reviews(
    body: AdminBusinessReviewBulkIn,
    db: DbSession,
    admin: ModeratorPlus,
    request: Request,
) -> dict:
    from app.services import business_reviews as reviews_service

    return await reviews_service.bulk_moderate(
        db,
        review_ids=body.review_ids,
        action=body.action,
        admin=admin,
        admin_note=body.admin_note,
        ip=client_ip(request),
    )


@router.post("/business-reviews/{review_id}/moderate")
async def admin_moderate_business_review(
    review_id: int,
    body: AdminBusinessReviewModerateIn,
    db: DbSession,
    admin: ModeratorPlus,
    request: Request,
) -> dict:
    from app.services import business_reviews as reviews_service

    data = await reviews_service.moderate_review(
        db,
        review_id=review_id,
        admin_id=admin.id,
        approve=body.approve,
        admin_note=body.admin_note,
    )
    await write_audit(
        db,
        admin=admin,
        action="business_review.moderate.approve"
        if body.approve
        else "business_review.moderate.reject",
        target_type="business_review",
        target_id=review_id,
        meta={"approve": body.approve, "status": data.get("status")},
        ip=client_ip(request),
    )
    return data


@router.post("/business-reviews/{review_id}/hide")
async def admin_hide_business_review(
    review_id: int,
    body: AdminBusinessReviewHideIn,
    db: DbSession,
    admin: ModeratorPlus,
    request: Request,
) -> dict:
    from app.services import business_reviews as reviews_service

    data = await reviews_service.hide_review(
        db,
        review_id=review_id,
        admin_id=admin.id,
        reason=body.reason,
        hide=body.hide,
    )
    await write_audit(
        db,
        admin=admin,
        action="business_review.hide" if body.hide else "business_review.unhide",
        target_type="business_review",
        target_id=review_id,
        meta={"hide": body.hide, "is_hidden": data.get("is_hidden")},
        ip=client_ip(request),
    )
    return data


@router.get("/verification-requests")
async def admin_list_verification_requests(
    db: DbSession,
    admin: SupportOrModerator,
    status_filter: str | None = Query(default="pending", alias="status"),
    q: str | None = Query(default=None),
    sla_only: bool = Query(default=False),
    page: int | None = Query(default=None, ge=1),
    limit: int = Query(default=50, ge=1, le=100),
    sort: str | None = Query(default=None),
    order: str | None = Query(default=None),
) -> dict:
    from app.services import verification as verification_service

    return await verification_service.list_admin_verification_requests(
        db,
        status=status_filter,
        q=q,
        sla_only=sla_only,
        page=page,
        limit=limit,
        sort=sort,
        order=order,
    )


@router.get("/verification-requests/{request_id}")
async def admin_get_verification_request(
    request_id: int,
    db: DbSession,
    _admin: SupportOrModerator,
) -> dict:
    from app.services import verification as verification_service

    return await verification_service.get_admin_verification_request(db, request_id)


class AdminVerificationDocDecision(BaseModel):
    id: int
    review_status: Literal["approved", "resubmit", "rejected"]
    review_note: str | None = Field(default=None, max_length=500)


class AdminVerificationPartialIn(BaseModel):
    documents: list[AdminVerificationDocDecision] = Field(min_length=1)
    admin_note: str | None = Field(default=None, max_length=500)


@router.post("/verification-requests/{request_id}/partial")
async def admin_partial_verification_request(
    request_id: int,
    body: AdminVerificationPartialIn,
    db: DbSession,
    admin: SupportOrModerator,
    request: Request,
) -> dict:
    from app.services import verification as verification_service

    data = await verification_service.partial_decide_verification_request(
        db,
        request_id=request_id,
        admin=admin,
        documents=[d.model_dump() for d in body.documents],
        admin_note=body.admin_note,
    )
    await write_audit(
        db,
        admin=admin,
        action="verification.partial",
        target_type="verification_request",
        target_id=request_id,
        meta={"status": data.get("status")},
        ip=client_ip(request),
    )
    await db.commit()
    return data


@router.post("/verification-requests/{request_id}/decide")
async def admin_decide_verification_request(
    request_id: int,
    body: AdminVerificationDecideIn,
    db: DbSession,
    admin: SupportOrModerator,
    request: Request,
) -> dict:
    from app.services import verification as verification_service

    data = await verification_service.decide_verification_request(
        db,
        request_id=request_id,
        admin=admin,
        approve=body.approve,
        admin_note=body.admin_note,
    )
    await write_audit(
        db,
        admin=admin,
        action="verification.decide",
        target_type="verification_request",
        target_id=request_id,
        meta={"approve": body.approve, "status": data.get("status")},
        ip=client_ip(request),
    )
    await db.commit()
    return data
