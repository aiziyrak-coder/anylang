from fastapi import APIRouter, status

from app.api.deps_auth import CurrentUser
from app.core.deps import DbSession, RedisClient
from app.core.errors import AppError
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
async def register(body: RegisterIn, db: DbSession, redis: RedisClient) -> RegisterOut:
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
async def verify_email(body: VerifyEmailIn, db: DbSession, redis: RedisClient) -> AuthSessionOut:
    data = await auth_service.verify_email(
        db,
        redis,
        email=str(body.email),
        code=body.code,
    )
    return AuthSessionOut.model_validate(data)


@router.post("/resend-verification", response_model=ResendMessageResponse)
async def resend_verification(body: ResendIn, db: DbSession, redis: RedisClient) -> ResendMessageResponse:
    data = await auth_service.resend_verification(
        db,
        redis,
        email=str(body.email),
        app_language=body.app_language,
    )
    return ResendMessageResponse.model_validate(data)


@router.post("/login", response_model=AuthSessionOut)
async def login(body: LoginIn, db: DbSession, redis: RedisClient) -> AuthSessionOut:
    key = f"auth:login:{str(body.email).lower()}"
    attempts = await redis.incr(key)
    if attempts == 1:
        await redis.expire(key, 900)
    if attempts > 20:
        raise AppError(
            message="Juda ko'p urinish — 15 daqiqadan keyin qayta urinib ko'ring",
            error_code="TOO_MANY_ATTEMPTS",
            status_code=429,
        )

    data = await auth_service.login(
        db,
        redis,
        email=str(body.email),
        password=body.password,
        app_language=body.app_language,
        native_language=body.native_language,
    )
    await redis.delete(key)
    return AuthSessionOut.model_validate(data)


@router.post("/google", response_model=AuthSessionOut)
async def google_sign_in(body: GoogleIn, db: DbSession) -> AuthSessionOut:
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
async def refresh(body: RefreshIn, db: DbSession) -> TokenPairOut:
    data = await auth_service.refresh_tokens(db, refresh_token=body.refresh_token)
    return TokenPairOut.model_validate(data)


@router.post("/password/forgot", response_model=ResendMessageResponse)
async def forgot_password(body: ForgotIn, db: DbSession, redis: RedisClient) -> ResendMessageResponse:
    data = await auth_service.forgot_password(
        db,
        redis,
        email=str(body.email),
        app_language=body.app_language,
    )
    return ResendMessageResponse.model_validate(data)


@router.post("/password/reset", response_model=MessageResponse)
async def reset_password(body: ResetIn, db: DbSession) -> MessageResponse:
    data = await auth_service.reset_password(
        db,
        email=str(body.email),
        code=body.code,
        new_password=body.new_password,
    )
    return MessageResponse.model_validate(data)
