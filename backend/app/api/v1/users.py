from fastapi import APIRouter, File, Query, Request, UploadFile, status
from pydantic import BaseModel, EmailStr, Field

from app.api.deps_auth import CurrentUser
from app.core.deps import DbSession, RedisClient
from app.core.errors import AppError
from app.core.pagination import normalize_page
from app.schemas.business import (
    AiCompanyProfileIn,
    AiCompanyProfileOut,
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
from app.schemas.profile_views import ProfileViewersOut
from app.schemas.nearby import (
    LocationOut,
    LocationSharingIn,
    LocationUpdateIn,
    NearbyOut,
)
from app.services import admin_console as console
from app.services import business as business_service
from app.services import chats as chats_service
from app.services import company_profile as company_profile_service
from app.services import nearby as nearby_service
from app.services import profile_views as profile_views_service
from app.services import verification as verification_service
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
async def get_me(
    current_user: CurrentUser,
    db: DbSession,
    redis: RedisClient,
) -> UserOut:
    loaded = await load_user_for_response(db, current_user.id)
    assert loaded is not None
    data = await serialize_user(loaded, db, redis=redis)
    return UserOut.model_validate(data)


@router.put("/me/location", response_model=LocationOut)
async def put_my_location(
    body: LocationUpdateIn,
    current_user: CurrentUser,
    db: DbSession,
) -> LocationOut:
    data = await nearby_service.update_my_location(
        db,
        user=current_user,
        lat=body.latitude,
        lng=body.longitude,
        sharing_enabled=body.sharing_enabled,
    )
    await db.commit()
    return LocationOut.model_validate(data)


@router.patch("/me/location-sharing", response_model=LocationOut)
async def patch_location_sharing(
    body: LocationSharingIn,
    current_user: CurrentUser,
    db: DbSession,
) -> LocationOut:
    data = await nearby_service.set_location_sharing(
        db,
        user=current_user,
        enabled=body.enabled,
    )
    await db.commit()
    return LocationOut.model_validate(
        {
            "location_lat": float(current_user.location_lat)
            if current_user.location_lat is not None
            else None,
            "location_lng": float(current_user.location_lng)
            if current_user.location_lng is not None
            else None,
            "location_updated_at": current_user.location_updated_at,
            "location_sharing_enabled": data["location_sharing_enabled"],
        }
    )


@router.get("/nearby", response_model=NearbyOut)
async def get_nearby(
    current_user: CurrentUser,
    db: DbSession,
    lat: float = Query(..., ge=-90, le=90),
    lng: float = Query(..., ge=-180, le=180),
    radius_m: int = Query(default=2000, ge=100, le=20000),
    language: str | None = Query(default=None, max_length=8),
    limit: int = Query(default=40, ge=1, le=80),
) -> NearbyOut:
    data = await nearby_service.list_nearby(
        db,
        viewer=current_user,
        lat=lat,
        lng=lng,
        radius_m=radius_m,
        language=language,
        limit=limit,
    )
    await db.commit()
    return NearbyOut.model_validate(data)


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
        translation_domain=body.translation_domain,
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
async def get_my_business(
    current_user: CurrentUser,
    db: DbSession,
    redis: RedisClient,
) -> BusinessOut:
    data = await business_service.serialize_business(db, current_user, redis=redis)
    return BusinessOut.model_validate(data)


@router.get("/me/business-card")
async def get_my_business_card(current_user: CurrentUser) -> dict:
    """Ko‘rgazma QR kartochkasi — profil ochiladigan havola."""
    if not current_user.is_business:
        raise AppError(
            message="Business Card faqat Business akkaunt uchun",
            error_code="NOT_A_BUSINESS",
            status_code=403,
        )
    from app.services.business_card import business_card_url

    return {
        "user_id": current_user.id,
        "url": business_card_url(current_user.id),
    }


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
        bio=body.bio,
        description=body.description,
        seo_text=body.seo_text,
        ai_knowledge=body.ai_knowledge,
        keywords=body.keywords,
        description_i18n=body.description_i18n,
        founded_year=body.founded_year,
        certificates=body.certificates,
        export_countries=body.export_countries,
        moq=body.moq,
        production_capacity=body.production_capacity,
        lead_time=body.lead_time,
        incoterms=body.incoterms,
        payment_methods=body.payment_methods,
    )
    await db.commit()
    return BusinessOut.model_validate(data)


@router.post("/me/business/ai-profile", response_model=AiCompanyProfileOut)
async def generate_ai_company_profile(
    body: AiCompanyProfileIn,
    current_user: CurrentUser,
) -> AiCompanyProfileOut:
    if not current_user.is_business:
        raise AppError(
            message="Biznes tarif talab qilinadi",
            error_code="NOT_A_BUSINESS_ACCOUNT",
            status_code=403,
        )
    data = await company_profile_service.generate_company_profile(
        prompt=body.prompt,
        company_name=body.company_name or "",
        country=body.country or "",
        business_role=body.business_role or "",
        locale=body.locale,
    )
    return AiCompanyProfileOut.model_validate(data)


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


class AuditReportOut(BaseModel):
    audit_report_url: str


@router.post("/me/business/audit-report", response_model=AuditReportOut)
async def upload_audit_report(
    current_user: CurrentUser,
    db: DbSession,
    file: UploadFile = File(...),
) -> AuditReportOut:
    data = await business_service.upload_audit_report(db, current_user, file)
    await db.commit()
    return AuditReportOut.model_validate(data)


@router.delete("/me/business/audit-report", response_model=MessageResponse)
async def delete_audit_report(
    current_user: CurrentUser,
    db: DbSession,
) -> MessageResponse:
    await business_service.delete_audit_report(db, current_user)
    await db.commit()
    return MessageResponse(message="Audit report o'chirildi")


class VerificationSubmitIn(BaseModel):
    note: str | None = Field(default=None, max_length=500)


@router.get("/me/business/verification")
async def get_my_business_verification(
    current_user: CurrentUser,
    db: DbSession,
    locale: str | None = Query(default=None),
) -> dict:
    data = await verification_service.get_my_verification(
        db,
        current_user,
        locale=locale or current_user.app_language or "uz",
    )
    return data


@router.post("/me/business/verification/documents")
async def upload_business_verification_document(
    current_user: CurrentUser,
    db: DbSession,
    doc_type: str = Query(..., min_length=3, max_length=40),
    file: UploadFile = File(...),
) -> dict:
    data = await verification_service.upload_verification_document(
        db, current_user, file, doc_type=doc_type
    )
    await db.commit()
    return data


@router.delete("/me/business/verification/documents/{document_id}")
async def delete_business_verification_document(
    document_id: int,
    current_user: CurrentUser,
    db: DbSession,
) -> dict:
    data = await verification_service.delete_verification_document(
        db, current_user, document_id
    )
    await db.commit()
    return data


@router.post("/me/business/verification/submit")
async def submit_business_verification(
    body: VerificationSubmitIn,
    current_user: CurrentUser,
    db: DbSession,
) -> dict:
    data = await verification_service.submit_verification(
        db,
        current_user,
        note=body.note,
        locale=current_user.app_language or "uz",
    )
    await db.commit()
    return data


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


@router.get("/me/profile-viewers", response_model=ProfileViewersOut)
async def list_my_profile_viewers(
    db: DbSession,
    current_user: CurrentUser,
    limit: int = Query(default=20, ge=1, le=50),
) -> ProfileViewersOut:
    """Premium: kim profilingizni ko‘rdi. Basic — locked + total_count."""
    data = await profile_views_service.list_profile_viewers(
        db,
        user=current_user,
        limit=limit,
    )
    return ProfileViewersOut.model_validate(data)


@router.get("/{user_id}", response_model=PublicUserProfileOut)
async def get_user_profile(
    user_id: int,
    db: DbSession,
    current_user: CurrentUser,
    redis: RedisClient,
) -> PublicUserProfileOut:
    data = await get_public_profile(db, user_id, viewer=current_user, redis=redis)
    return PublicUserProfileOut.model_validate(data)
