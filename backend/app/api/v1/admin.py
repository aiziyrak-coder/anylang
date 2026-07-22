from __future__ import annotations

from decimal import Decimal

from fastapi import APIRouter, Query, Request, status
from pydantic import BaseModel, EmailStr, Field
from sqlalchemy import func, or_, select

from app.api.deps_admin import CurrentAdmin
from app.core.deps import DbSession, RedisClient
from app.core.errors import AppError
from app.core.pagination import normalize_page
from app.models.chat import Chat, Message
from app.models.payment import Payment
from app.models.product import Product
from app.models.user import NumberGroup, Subscription, User
from app.services import admin_auth
from app.services import numbers as numbers_service
from app.services.admin_ops import ModeratorPlus, client_ip, write_audit

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


class AdminNumberGroupOut(BaseModel):
    id: int
    name: str
    patterns: list[str]
    price: str
    currency: str
    bonus_plan: str | None = None
    bonus_duration_months: int | None = None
    priority: int
    is_active: bool


class AdminNumberGroupCreateIn(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    patterns: list[str] = Field(min_length=1)
    price: Decimal = Field(ge=0)
    currency: str = "USD"
    bonus_plan: str | None = None
    bonus_duration_months: int | None = None
    priority: int = 0
    is_active: bool = True


class AdminNumberGroupPatchIn(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=100)
    patterns: list[str] | None = None
    price: Decimal | None = Field(default=None, ge=0)
    currency: str | None = None
    bonus_plan: str | None = None
    bonus_duration_months: int | None = None
    priority: int | None = None
    is_active: bool | None = None


class AdminPinProductIn(BaseModel):
    pinned: bool


class AdminStatsOut(BaseModel):
    users_total: int
    users_active: int
    subscriptions_active: int
    products_published: int
    products_archived: int
    chats_total: int
    messages_total: int
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
    return {
        "id": user.id,
        "full_name": user.full_name,
        "email": user.email,
        "number": user.number,
        "is_active": user.is_active,
        "is_verified": user.is_verified,
        "verified_badge": user.verified_badge,
        "created_at": user.created_at,
    }


def _serialize_number_group(group: NumberGroup) -> dict:
    return {
        "id": group.id,
        "name": group.name,
        "patterns": list(group.patterns or []),
        "price": f"{group.price:.2f}",
        "currency": group.currency,
        "bonus_plan": group.bonus_plan,
        "bonus_duration_months": group.bonus_duration_months,
        "priority": group.priority,
        "is_active": group.is_active,
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
async def admin_login(body: AdminLoginIn, db: DbSession, redis: RedisClient) -> AdminLoginOut:
    key = f"admin:login:{str(body.email).lower()}"
    attempts = await redis.incr(key)
    if attempts == 1:
        await redis.expire(key, 900)
    if attempts > 10:
        raise AppError(
            message="Juda ko'p urinish — 15 daqiqadan keyin qayta urinib ko'ring",
            error_code="TOO_MANY_ATTEMPTS",
            status_code=429,
        )

    data = await admin_auth.login_admin(db, email=str(body.email), password=body.password)
    await redis.delete(key)
    return AdminLoginOut.model_validate(data)


@router.get("/users", response_model=None)
async def admin_list_users(
    db: DbSession,
    _admin: ModeratorPlus,
    search: str | None = Query(default=None),
    status_filter: str | None = Query(default="all", alias="status"),
    plan: str | None = Query(default=None),
    page: int | None = Query(default=None, ge=1),
    limit: int | None = Query(default=None, ge=1, le=100),
) -> dict:
    from app.services import admin_console as console

    st = status_filter if status_filter in {"all", "active", "inactive", "deleted"} else "all"
    return await console.list_users(
        db,
        search=search,
        status=st,  # type: ignore[arg-type]
        plan=plan,
        page=page,
        limit=limit,
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

    for field, value in data.items():
        setattr(user, field, value)

    await db.flush()
    await write_audit(
        db,
        admin=admin,
        action="user.patch",
        target_type="user",
        target_id=user_id,
        meta=data,
        ip=client_ip(request),
    )
    await db.refresh(user)
    return AdminUserOut.model_validate(_serialize_admin_user(user))


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

    group = NumberGroup(
        name=body.name,
        patterns=list(body.patterns),
        price=body.price,
        currency=body.currency,
        bonus_plan=body.bonus_plan,
        bonus_duration_months=body.bonus_duration_months,
        priority=body.priority,
        is_active=body.is_active,
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
    for field, value in data.items():
        setattr(group, field, value)

    await db.flush()
    await write_audit(
        db,
        admin=admin,
        action="number_group.patch",
        target_type="number_group",
        target_id=group_id,
        meta=data,
        ip=client_ip(request),
    )
    await db.refresh(group)
    return AdminNumberGroupOut.model_validate(_serialize_number_group(group))


@router.get("/products")
async def admin_list_products(
    db: DbSession,
    _admin: ModeratorPlus,
    status_filter: str | None = Query(default=None, alias="status"),
    search: str | None = Query(default=None),
    page: int | None = Query(default=None, ge=1),
    limit: int | None = Query(default=None, ge=1, le=100),
) -> dict:
    params = normalize_page(page, limit, default_size=50, max_size=100)
    query = select(Product)
    if status_filter in {"draft", "published", "archived"}:
        query = query.where(Product.status == status_filter)
    if search and search.strip():
        term = f"%{search.strip()}%"
        query = query.where(or_(Product.name.ilike(term), Product.category.ilike(term)))
    total = int(
        (await db.execute(select(func.count()).select_from(query.order_by(None).subquery()))).scalar()
        or 0
    )
    rows = list(
        (
            await db.execute(
                query.order_by(Product.id.desc()).offset(params.offset).limit(params.page_size)
            )
        ).scalars().all()
    )
    return {
        "items": [
            {
                "id": p.id,
                "seller_id": p.seller_id,
                "name": p.name,
                "price": f"{p.price:.2f}",
                "currency": p.currency,
                "category": p.category,
                "status": p.status,
                "is_top_pinned": p.is_top_pinned,
                "views_count": p.views_count,
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
    product = await db.get(Product, product_id)
    if product is None:
        raise AppError(message="Mahsulot topilmadi", error_code="PRODUCT_NOT_FOUND", status_code=404)

    product.is_top_pinned = body.pinned
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
    messages_total = int((await db.execute(select(func.count()).select_from(Message))).scalar() or 0)
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
    _admin: ModeratorPlus,
    status_filter: str | None = Query(default=None, alias="status"),
    kind: str | None = None,
    plan: str | None = None,
    date_from: str | None = Query(default=None, alias="from"),
    date_to: str | None = Query(default=None, alias="to"),
    page: int | None = Query(default=None, ge=1),
    limit: int | None = Query(default=None, ge=1, le=100),
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
        date_from=df,
        date_to=dt,
        page=page,
        limit=limit,
    )
