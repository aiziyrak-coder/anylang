from fastapi import APIRouter, File, Query, Request, UploadFile, status
from pydantic import BaseModel, EmailStr, Field

from app.api.deps_auth import CurrentUser
from app.core.deps import DbSession, RedisClient
from app.core.errors import AppError
from app.core.pagination import normalize_page
from app.schemas.business import (
    AvatarOut,
    BusinessUpdateIn,
    FactoryImageCreateOut,
    LogoOut,
    PublicUserProfileOut,
    UserSearchOut,
    UserUpdateIn,
)
from app.schemas.common import MessageResponse
from app.schemas.user import BusinessOut, UserOut
from app.services import admin_console as console
from app.services import business as business_service
from app.services import chats as chats_service
from app.services.admin_ops import client_ip
from app.services.users import (
    get_public_profile,
    load_user_for_response,
    search_users,
    serialize_user,
)

router = APIRouter()


class SoftDeleteMeIn(BaseModel):
    reason: str | None = Field(default="user_requested", max_length=255)


class PublicRestoreIn(BaseModel):
    email: EmailStr
    number: str | None = Field(default=None, min_length=7, max_length=7)
    reason: str = Field(min_length=5, max_length=2000)


@router.get("/me", response_model=UserOut)
async def get_me(current_user: CurrentUser, db: DbSession) -> UserOut:
    loaded = await load_user_for_response(db, current_user.id)
    assert loaded is not None
    data = await serialize_user(loaded, db)
    return UserOut.model_validate(data)


@router.delete("/me", response_model=MessageResponse)
async def delete_me(
    current_user: CurrentUser,
    db: DbSession,
    request: Request,
    body: SoftDeleteMeIn | None = None,
) -> MessageResponse:
    reason = body.reason if body else "user_requested"
    await console.soft_delete_user(
        db,
        user=current_user,
        reason=reason,
        admin=None,
        ip=client_ip(request),
    )
    return MessageResponse(message="Akkount soft-delete qilindi (365 kun ichida tiklash mumkin)")


@router.post("/restore-request", response_model=dict)
async def public_restore_request(
    body: PublicRestoreIn,
    db: DbSession,
    redis: RedisClient,
    request: Request,
) -> dict:
    ip = client_ip(request) or "unknown"
    email_key = f"restore:email:{str(body.email).lower()}"
    ip_key = f"restore:ip:{ip}"
    email_n = await redis.incr(email_key)
    if email_n == 1:
        await redis.expire(email_key, 3600)
    ip_n = await redis.incr(ip_key)
    if ip_n == 1:
        await redis.expire(ip_key, 3600)
    if email_n > 3 or ip_n > 20:
        raise AppError(
            message="Juda ko'p tiklash arizasi — keyinroq qayta urinib ko'ring",
            error_code="TOO_MANY_ATTEMPTS",
            status_code=429,
        )
    return await console.create_restore_request(
        db,
        email=str(body.email),
        number=body.number,
        reason=body.reason,
    )


@router.patch("/me", response_model=UserOut)
async def patch_me(body: UserUpdateIn, current_user: CurrentUser, db: DbSession) -> UserOut:
    if body.email is not None:
        raise AppError(
            message="Email o'zgartirish hozircha qo'llab-quvvatlanmaydi",
            error_code="EMAIL_CHANGE_NOT_SUPPORTED",
            status_code=400,
        )

    data = await business_service.update_user_profile(
        db,
        current_user,
        full_name=body.full_name,
        birth_date=body.birth_date,
        gender=body.gender,
        country=body.country,
        app_language=body.app_language,
        native_language=body.native_language,
    )
    await db.commit()
    return UserOut.model_validate(data)


@router.post("/me/avatar", response_model=AvatarOut)
async def upload_avatar(
    current_user: CurrentUser,
    db: DbSession,
    file: UploadFile = File(...),
) -> AvatarOut:
    data = await business_service.upload_avatar(db, current_user, file)
    await db.commit()
    return AvatarOut.model_validate(data)


@router.delete("/me/avatar", response_model=MessageResponse)
async def delete_avatar(current_user: CurrentUser, db: DbSession) -> MessageResponse:
    await business_service.delete_avatar(db, current_user)
    await db.commit()
    return MessageResponse(message="Avatar o'chirildi")


@router.get("/me/business", response_model=BusinessOut)
async def get_my_business(current_user: CurrentUser, db: DbSession) -> BusinessOut:
    data = await business_service.serialize_business(db, current_user)
    return BusinessOut.model_validate(data)


@router.patch("/me/business", response_model=BusinessOut)
async def patch_my_business(
    body: BusinessUpdateIn,
    current_user: CurrentUser,
    db: DbSession,
) -> BusinessOut:
    data = await business_service.update_business(
        db,
        current_user,
        company_name=body.company_name,
        country=body.country,
        business_role=body.business_role,
        website=body.website,
        description=body.description,
        founded_year=body.founded_year,
        certificates=body.certificates,
    )
    await db.commit()
    return BusinessOut.model_validate(data)


@router.post("/me/business/logo", response_model=LogoOut)
async def upload_business_logo(
    current_user: CurrentUser,
    db: DbSession,
    file: UploadFile = File(...),
) -> LogoOut:
    data = await business_service.upload_business_logo(db, current_user, file)
    await db.commit()
    return LogoOut.model_validate(data)


@router.post("/me/business/factory-images", response_model=FactoryImageCreateOut, status_code=status.HTTP_201_CREATED)
async def upload_factory_image(
    current_user: CurrentUser,
    db: DbSession,
    file: UploadFile = File(...),
) -> FactoryImageCreateOut:
    data = await business_service.add_factory_image(db, current_user, file)
    await db.commit()
    return FactoryImageCreateOut.model_validate(data)


@router.delete("/me/business/factory-images/{image_id}", response_model=MessageResponse)
async def delete_factory_image(
    image_id: int,
    current_user: CurrentUser,
    db: DbSession,
) -> MessageResponse:
    await business_service.delete_factory_image(db, current_user, image_id)
    await db.commit()
    return MessageResponse(message="Rasm o'chirildi")


@router.get("/search", response_model=UserSearchOut)
async def search_users_endpoint(
    current_user: CurrentUser,
    db: DbSession,
    query: str = Query(..., min_length=1),
    page: int | None = Query(default=1, ge=1),
    limit: int | None = Query(default=30, ge=1, le=100),
) -> UserSearchOut:
    params = normalize_page(page, limit, default_size=30)
    data = await search_users(db, current_user, query, params)
    return UserSearchOut.model_validate(data)


@router.get("/me/blocked")
async def list_blocked(
    current_user: CurrentUser,
    redis: RedisClient,
) -> dict:
    ids = await chats_service.list_blocked_user_ids(redis, user_id=current_user.id)
    return {"items": [{"id": i} for i in ids]}


@router.post("/me/blocked/{peer_id}", status_code=status.HTTP_200_OK)
async def block_peer(
    peer_id: int,
    current_user: CurrentUser,
    redis: RedisClient,
) -> dict:
    return await chats_service.block_user(redis, user_id=current_user.id, peer_id=peer_id)


@router.delete("/me/blocked/{peer_id}", status_code=status.HTTP_200_OK)
async def unblock_peer(
    peer_id: int,
    current_user: CurrentUser,
    redis: RedisClient,
) -> dict:
    return await chats_service.unblock_user(redis, user_id=current_user.id, peer_id=peer_id)


@router.get("/{user_id}", response_model=PublicUserProfileOut)
async def get_user_profile(
    user_id: int,
    db: DbSession,
    current_user: CurrentUser,
) -> PublicUserProfileOut:
    data = await get_public_profile(db, user_id, viewer=current_user)
    return PublicUserProfileOut.model_validate(data)
