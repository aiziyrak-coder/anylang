from fastapi import APIRouter, Request, status

from app.api.deps_auth import CurrentUser
from app.core.deps import DbSession, RedisClient
from app.core.rate_limit import client_ip, enforce_rate_limit
from app.schemas.auth import (
    AuthSessionOut,
    ChangePasswordIn,
    DeviceSessionListOut,
    ForgotIn,
    GoogleIn,
    LoginIn,
    LogoutIn,
    RefreshIn,
    RegisterIn,
    RegisterOut,
    ResendIn,
    ResetIn,
    RevokeOthersIn,
    TokenPairOut,
    VerifyEmailIn,
)
from app.schemas.common import MessageResponse, ResendMessageResponse
from app.services import auth as auth_service

router = APIRouter()


def _device_dict(device) -> dict | None:
    if device is None:
        return None
    return device.model_dump()


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
        limit=30,
        window_seconds=3600,
        message="Juda ko'p ro'yxatdan o'tish urinishi. Biroz kutib qayta urinib ko'ring",
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
        device=_device_dict(body.device),
        ip_address=ip,
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
        device=_device_dict(body.device),
        ip_address=ip,
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
        device=_device_dict(body.device),
        ip_address=ip,
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
    data = await auth_service.refresh_tokens(
        db,
        refresh_token=body.refresh_token,
        device=_device_dict(body.device),
        ip_address=ip,
    )
    return TokenPairOut.model_validate(data)


@router.get("/sessions", response_model=DeviceSessionListOut)
async def list_sessions(
    request: Request,
    db: DbSession,
    current_user: CurrentUser,
) -> DeviceSessionListOut:
    """Faol qurilma seanslari. Joriy seans: Authorization + X-Refresh-Token yoki query."""
    refresh = request.headers.get("X-Refresh-Token") or request.query_params.get(
        "refresh_token"
    )
    data = await auth_service.list_device_sessions(
        db, user_id=current_user.id, refresh_token=refresh
    )
    return DeviceSessionListOut.model_validate(data)


@router.delete("/sessions/{session_id}", response_model=MessageResponse)
async def revoke_session(
    session_id: str,
    request: Request,
    db: DbSession,
    current_user: CurrentUser,
) -> MessageResponse:
    refresh = request.headers.get("X-Refresh-Token") or request.query_params.get(
        "refresh_token"
    )
    data = await auth_service.revoke_device_session(
        db,
        user_id=current_user.id,
        session_id=session_id,
        refresh_token=refresh,
    )
    return MessageResponse.model_validate(data)


@router.post("/sessions/revoke-others", response_model=MessageResponse)
async def revoke_other_sessions(
    body: RevokeOthersIn,
    db: DbSession,
    current_user: CurrentUser,
) -> MessageResponse:
    data = await auth_service.revoke_other_device_sessions(
        db,
        user_id=current_user.id,
        refresh_token=body.refresh_token,
    )
    # revoked_count MessageResponse da yo'q — message yetarli
    return MessageResponse(message=str(data.get("message") or "OK"))


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


@router.post("/password/change", response_model=MessageResponse)
async def change_password(
    body: ChangePasswordIn,
    current_user: CurrentUser,
    db: DbSession,
) -> MessageResponse:
    data = await auth_service.change_password(
        db,
        user=current_user,
        current_password=body.current_password,
        new_password=body.new_password,
    )
    return MessageResponse.model_validate(data)
