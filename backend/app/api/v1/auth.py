from fastapi import APIRouter, Request, status

from app.api.deps_auth import CurrentUser
from app.core.deps import DbSession, RedisClient
from app.core.rate_limit import client_ip, enforce_rate_limit
from app.schemas.auth import (
    AuthSessionOut,
    ForgotIn,
    GoogleIn,
    LoginIn,
    LogoutIn,
    RefreshIn,
    RegisterIn,
    RegisterOut,
    ResendIn,
    ResetIn,
    TokenPairOut,
    VerifyEmailIn,
)
from app.schemas.common import MessageResponse, ResendMessageResponse
from app.services import auth as auth_service

router = APIRouter()


@router.post("/register", response_model=RegisterOut, status_code=status.HTTP_201_CREATED)
async def register(
    body: RegisterIn,
    request: Request,
    db: DbSession,
    redis: RedisClient,
) -> RegisterOut:
    ip = client_ip(request)
    await enforce_rate_limit(
        redis,
        f"auth:register:ip:{ip}",
        limit=10,
        window_seconds=3600,
        message="Juda ko'p ro'yxatdan o'tish urinishi",
    )
    data = await auth_service.register(
        db,
        redis,
        full_name=body.full_name,
        email=str(body.email),
        password=body.password,
        birth_date=body.birth_date,
        gender=body.gender,
        country=body.country,
        app_language=body.app_language,
        native_language=body.native_language,
    )
    return RegisterOut.model_validate(data)


@router.post("/verify-email", response_model=AuthSessionOut)
async def verify_email(
    body: VerifyEmailIn,
    request: Request,
    db: DbSession,
    redis: RedisClient,
) -> AuthSessionOut:
    ip = client_ip(request)
    await enforce_rate_limit(
        redis,
        f"auth:verify:ip:{ip}",
        limit=30,
        window_seconds=900,
    )
    data = await auth_service.verify_email(
        db,
        redis,
        email=str(body.email),
        code=body.code,
    )
    return AuthSessionOut.model_validate(data)


@router.post("/resend-verification", response_model=ResendMessageResponse)
async def resend_verification(
    body: ResendIn,
    request: Request,
    db: DbSession,
    redis: RedisClient,
) -> ResendMessageResponse:
    ip = client_ip(request)
    await enforce_rate_limit(
        redis,
        f"auth:resend:ip:{ip}",
        limit=20,
        window_seconds=3600,
    )
    data = await auth_service.resend_verification(
        db,
        redis,
        email=str(body.email),
        app_language=body.app_language,
    )
    return ResendMessageResponse.model_validate(data)


@router.post("/login", response_model=AuthSessionOut)
async def login(
    body: LoginIn,
    request: Request,
    db: DbSession,
    redis: RedisClient,
) -> AuthSessionOut:
    ip = client_ip(request)
    email_key = f"auth:login:email:{str(body.email).lower()}"
    ip_key = f"auth:login:ip:{ip}"

    await enforce_rate_limit(
        redis,
        ip_key,
        limit=40,
        window_seconds=900,
        message="Bu IP dan juda ko'p login urinishi",
    )
    await enforce_rate_limit(
        redis,
        email_key,
        limit=10,
        window_seconds=900,
        message="Juda ko'p urinish — 15 daqiqadan keyin qayta urinib ko'ring",
    )

    data = await auth_service.login(
        db,
        redis,
        email=str(body.email),
        password=body.password,
        app_language=body.app_language,
        native_language=body.native_language,
    )
    await redis.delete(email_key)
    return AuthSessionOut.model_validate(data)


@router.post("/google", response_model=AuthSessionOut)
async def google_sign_in(
    body: GoogleIn,
    request: Request,
    db: DbSession,
    redis: RedisClient,
) -> AuthSessionOut:
    ip = client_ip(request)
    await enforce_rate_limit(
        redis,
        f"auth:google:ip:{ip}",
        limit=30,
        window_seconds=900,
        message="Juda ko'p Google login urinishi",
    )
    data = await auth_service.google_sign_in(
        db,
        id_token_str=body.id_token,
        app_language=body.app_language,
        native_language=body.native_language,
    )
    return AuthSessionOut.model_validate(data)


@router.post("/logout", response_model=MessageResponse)
async def logout(
    body: LogoutIn,
    db: DbSession,
    current_user: CurrentUser,
) -> MessageResponse:
    await auth_service.logout(db, user_id=current_user.id, refresh_token=body.refresh_token)
    return MessageResponse(message="Chiqildi")


@router.post("/refresh", response_model=TokenPairOut)
async def refresh(
    body: RefreshIn,
    request: Request,
    db: DbSession,
    redis: RedisClient,
) -> TokenPairOut:
    ip = client_ip(request)
    await enforce_rate_limit(
        redis,
        f"auth:refresh:ip:{ip}",
        limit=120,
        window_seconds=900,
    )
    data = await auth_service.refresh_tokens(db, refresh_token=body.refresh_token)
    return TokenPairOut.model_validate(data)


@router.post("/password/forgot", response_model=ResendMessageResponse)
async def forgot_password(
    body: ForgotIn,
    request: Request,
    db: DbSession,
    redis: RedisClient,
) -> ResendMessageResponse:
    ip = client_ip(request)
    await enforce_rate_limit(
        redis,
        f"auth:forgot:ip:{ip}",
        limit=20,
        window_seconds=3600,
    )
    data = await auth_service.forgot_password(
        db,
        redis,
        email=str(body.email),
        app_language=body.app_language,
    )
    return ResendMessageResponse.model_validate(data)


@router.post("/password/reset", response_model=MessageResponse)
async def reset_password(
    body: ResetIn,
    request: Request,
    db: DbSession,
    redis: RedisClient,
) -> MessageResponse:
    ip = client_ip(request)
    await enforce_rate_limit(
        redis,
        f"auth:reset:ip:{ip}",
        limit=20,
        window_seconds=900,
    )
    data = await auth_service.reset_password(
        db,
        email=str(body.email),
        code=body.code,
        new_password=body.new_password,
    )
    return MessageResponse.model_validate(data)
