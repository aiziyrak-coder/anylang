from __future__ import annotations

import hashlib
import json
import logging
from base64 import urlsafe_b64decode
from datetime import UTC, datetime, timedelta
from typing import Any

import jwt
from redis.asyncio import Redis
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.orm import selectinload

from app.core.config import get_settings
from app.core.errors import AppError
from app.core.security import (
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_password,
    verify_password,
)
from app.models.user import NumberAssignment, RefreshToken, User
from app.services.numbers import assign_random_standard_number
from app.services.otp import (
    PURPOSE_RESET_PASSWORD,
    PURPOSE_VERIFY_EMAIL,
    RESEND_COOLDOWN_SECONDS,
    _enforce_hourly_limit,
    _set_resend_cooldown,
    check_resend_allowed,
    create_and_send_otp,
    get_resend_after_seconds,
    verify_otp,
)
from app.services.users import ensure_basic_subscription, load_user_for_response, serialize_user

logger = logging.getLogger(__name__)


def _hash_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def _refresh_expires_at() -> datetime:
    settings = get_settings()
    return datetime.now(UTC) + timedelta(days=settings.refresh_token_expire_days)


async def _store_refresh_token(
    db: AsyncSession,
    user_id: int,
    refresh_token: str,
    *,
    family: str | None = None,
) -> None:
    payload = decode_token(refresh_token)
    if payload.get("type") != "refresh":
        raise AppError(message="Token turi noto'g'ri", error_code="INVALID_REFRESH_TOKEN", status_code=401)

    record = RefreshToken(
        user_id=user_id,
        jti=str(payload["jti"]),
        family=str(payload.get("family") or family or payload["jti"]),
        token_hash=_hash_token(refresh_token),
        expires_at=_refresh_expires_at(),
    )
    db.add(record)
    await db.flush()


async def _issue_session(db: AsyncSession, user: User) -> dict[str, Any]:
    access_token = create_access_token(user.id)
    refresh_token = create_refresh_token(user.id)
    await _store_refresh_token(db, user.id, refresh_token)
    loaded = await load_user_for_response(db, user.id)
    assert loaded is not None
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "user": await serialize_user(loaded, db),
    }


async def register(
    db: AsyncSession,
    redis: Redis,
    *,
    full_name: str,
    email: str,
    password: str,
    birth_date,
    gender: str,
    country: str,
    app_language: str,
    native_language: str,
) -> dict[str, Any]:
    email_norm = email.lower().strip()

    existing = await db.execute(select(User.id).where(User.email == email_norm))
    if existing.scalar_one_or_none() is not None:
        raise AppError(
            message="Bu email allaqachon ro'yxatdan o'tgan",
            error_code="EMAIL_ALREADY_EXISTS",
            status_code=409,
        )

    number = await assign_random_standard_number(db)

    user = User(
        email=email_norm,
        password_hash=hash_password(password),
        full_name=full_name.strip(),
        number=number,
        birth_date=birth_date,
        gender=gender,
        country=country.upper(),
        app_language=app_language,
        native_language=native_language,
        is_verified=False,
    )
    db.add(user)
    await db.flush()

    await db.execute(
        update(NumberAssignment)
        .where(NumberAssignment.number == number)
        .values(user_id=user.id)
    )

    await ensure_basic_subscription(user, db)
    code, resend_after, emailed = await create_and_send_otp(
        db,
        redis,
        email=email_norm,
        purpose=PURPOSE_VERIFY_EMAIL,
        app_language=app_language,
        enforce_cooldown=False,
    )

    settings = get_settings()
    out: dict[str, Any] = {
        "email": email_norm,
        "message": "Tasdiqlash kodi emailingizga yuborildi"
        if emailed
        else "Ro'yxatdan o'tdingiz. Tasdiqlash kodi emailga yuborilmadi — keyinroq qayta yuboring",
        "resend_after_seconds": resend_after,
    }
    # Never expose OTP outside local/dev, and only when explicitly enabled.
    if (
        not settings.is_production
        and settings.allow_otp_in_response
        and ((not emailed) or settings.debug)
    ):
        out["debug_otp"] = code
    return out


async def verify_email(
    db: AsyncSession,
    redis: Redis,
    *,
    email: str,
    code: str,
) -> dict[str, Any]:
    email_norm = email.lower().strip()
    await verify_otp(db, email=email_norm, purpose=PURPOSE_VERIFY_EMAIL, code=code)

    result = await db.execute(select(User).where(User.email == email_norm))
    user = result.scalar_one_or_none()
    if user is None:
        raise AppError(message="Foydalanuvchi topilmadi", error_code="NOT_FOUND", status_code=404)

    user.is_verified = True
    await ensure_basic_subscription(user, db)
    await db.flush()
    return await _issue_session(db, user)


async def resend_verification(
    db: AsyncSession,
    redis: Redis,
    *,
    email: str,
    app_language: str,
) -> dict[str, Any]:
    email_norm = email.lower().strip()
    result = await db.execute(select(User).where(User.email == email_norm))
    user = result.scalar_one_or_none()

    if user is None or user.is_verified:
        return {
            "message": "Kod qayta yuborildi",
            "resend_after_seconds": RESEND_COOLDOWN_SECONDS,
        }

    _, resend_after, _ = await create_and_send_otp(
        db,
        redis,
        email=email_norm,
        purpose=PURPOSE_VERIFY_EMAIL,
        app_language=app_language,
        enforce_cooldown=True,
    )
    return {"message": "Kod qayta yuborildi", "resend_after_seconds": resend_after}


async def login(
    db: AsyncSession,
    redis: Redis,
    *,
    email: str,
    password: str,
    app_language: str | None = None,
    native_language: str | None = None,
) -> dict[str, Any]:
    email_norm = email.lower().strip()
    result = await db.execute(
        select(User).where(User.email == email_norm).options(selectinload(User.subscription))
    )
    user = result.scalar_one_or_none()

    if user is None or not user.password_hash or not verify_password(password, user.password_hash):
        raise AppError(
            message="Email yoki parol noto'g'ri",
            error_code="INVALID_CREDENTIALS",
            status_code=401,
        )

    if user.deleted_at is not None:
        raise AppError(
            message="Akkaunt o'chirilgan — tiklash uchun ariza yuboring",
            error_code="ACCOUNT_DELETED",
            status_code=403,
            extra={"email": email_norm},
        )

    if not user.is_active:
        raise AppError(
            message="Akkaunt bloklangan",
            error_code="ACCOUNT_DISABLED",
            status_code=403,
        )

    if not user.is_verified:
        try:
            await create_and_send_otp(
                db,
                redis,
                email=email_norm,
                purpose=PURPOSE_VERIFY_EMAIL,
                app_language=app_language or user.app_language,
                enforce_cooldown=True,
            )
            resend_after = await get_resend_after_seconds(redis, email_norm, PURPOSE_VERIFY_EMAIL)
        except AppError as exc:
            if exc.error_code == "RESEND_TOO_SOON":
                resend_after = exc.extra.get("resend_after_seconds", RESEND_COOLDOWN_SECONDS)
            else:
                raise
        raise AppError(
            message="Email hali tasdiqlanmagan",
            error_code="ACCOUNT_NOT_VERIFIED",
            status_code=403,
            extra={"email": email_norm, "resend_after_seconds": resend_after},
        )

    if app_language:
        user.app_language = app_language
    if native_language:
        user.native_language = native_language
    await ensure_basic_subscription(user, db)
    await db.flush()
    return await _issue_session(db, user)


def _decode_google_id_token_unverified(id_token: str) -> dict[str, Any]:
    """Local-dev helper: decode JWT payload without signature verification."""
    parts = id_token.split(".")
    if len(parts) != 3:
        raise AppError(
            message="Google token noto'g'ri",
            error_code="INVALID_GOOGLE_TOKEN",
            status_code=401,
        )
    payload_segment = parts[1]
    padding = "=" * (-len(payload_segment) % 4)
    try:
        raw = urlsafe_b64decode(payload_segment + padding)
        return json.loads(raw)
    except (ValueError, json.JSONDecodeError) as exc:
        raise AppError(
            message="Google token noto'g'ri",
            error_code="INVALID_GOOGLE_TOKEN",
            status_code=401,
        ) from exc


def _verify_google_id_token(id_token_str: str) -> dict[str, Any]:
    """
    Verify Google id_token.

    When GOOGLE_CLIENT_IDS is empty (local), the token is decoded without
    signature verification — for testing only. Set GOOGLE_CLIENT_IDS in production.
    """
    settings = get_settings()
    client_ids = settings.google_client_id_list

    if not client_ids:
        if settings.is_production:
            raise AppError(
                message="Google Sign-In sozlanmagan",
                error_code="INVALID_GOOGLE_TOKEN",
                status_code=401,
            )
        logger.warning(
            "GOOGLE_CLIENT_IDS is empty — decoding id_token without verification (local dev only)"
        )
        claims = _decode_google_id_token_unverified(id_token_str)
        if not claims.get("email"):
            raise AppError(
                message="Google token noto'g'ri",
                error_code="INVALID_GOOGLE_TOKEN",
                status_code=401,
            )
        return claims

    from google.auth.transport import requests as google_requests
    from google.oauth2 import id_token as google_id_token

    claims: dict[str, Any] | None = None
    last_error: Exception | None = None
    # Always verify with an explicit audience — never audience=None (aud bypass).
    for client_id in client_ids:
        try:
            claims = google_id_token.verify_oauth2_token(
                id_token_str,
                google_requests.Request(),
                audience=client_id,
            )
            break
        except ValueError as exc:
            last_error = exc

    if claims is None:
        raise AppError(
            message="Google token noto'g'ri",
            error_code="INVALID_GOOGLE_TOKEN",
            status_code=401,
        ) from last_error

    if claims.get("email_verified") is not True:
        raise AppError(
            message="Google email tasdiqlanmagan",
            error_code="INVALID_GOOGLE_TOKEN",
            status_code=401,
        )
    return claims


async def google_sign_in(
    db: AsyncSession,
    *,
    id_token_str: str,
    app_language: str | None = None,
    native_language: str | None = None,
) -> dict[str, Any]:
    claims = _verify_google_id_token(id_token_str)
    email = str(claims.get("email", "")).lower().strip()
    if not email:
        raise AppError(
            message="Google token noto'g'ri",
            error_code="INVALID_GOOGLE_TOKEN",
            status_code=401,
        )

    google_sub = str(claims.get("sub", ""))
    full_name = str(claims.get("name") or claims.get("email", "").split("@")[0])
    avatar_url = claims.get("picture")

    user: User | None = None
    if google_sub:
        by_sub = await db.execute(select(User).where(User.google_sub == google_sub))
        user = by_sub.scalar_one_or_none()

    if user is None:
        result = await db.execute(select(User).where(User.email == email))
        user = result.scalar_one_or_none()
        if user is not None and user.google_sub and user.google_sub != google_sub:
            raise AppError(
                message="Email boshqa Google akkauntga bog'langan",
                error_code="GOOGLE_ACCOUNT_CONFLICT",
                status_code=409,
            )

    if user is None:
        number = await assign_random_standard_number(db)
        user = User(
            email=email,
            password_hash=None,
            full_name=full_name,
            number=number,
            avatar_url=avatar_url,
            app_language=app_language or "uz_UZ",
            native_language=native_language or "uz",
            is_verified=True,
            google_sub=google_sub or None,
        )
        db.add(user)
        await db.flush()

        await db.execute(
            update(NumberAssignment)
            .where(NumberAssignment.number == number)
            .values(user_id=user.id)
        )
        await ensure_basic_subscription(user, db)
    else:
        if user.deleted_at is not None:
            raise AppError(
                message="Akkaunt o'chirilgan — tiklash uchun ariza yuboring",
                error_code="ACCOUNT_DELETED",
                status_code=403,
                # Caller proved Google ownership of this email — needed for restore UX.
                extra={"email": email},
            )
        if not user.is_active:
            raise AppError(
                message="Akkaunt bloklangan",
                error_code="ACCOUNT_DISABLED",
                status_code=403,
            )
        if google_sub and not user.google_sub:
            # Do not auto-link Google onto password accounts (account takeover via email).
            if user.password_hash:
                raise AppError(
                    message=(
                        "Bu email parol bilan ro'yxatdan o'tgan. "
                        "Avval parol bilan kiring — Google bog'lash alohida."
                    ),
                    error_code="ACCOUNT_EXISTS_PASSWORD",
                    status_code=409,
                )
            user.google_sub = google_sub
        if avatar_url and not user.avatar_url:
            user.avatar_url = avatar_url
        # Only treat as verified when this identity is already Google-linked (or OAuth-only).
        if not user.is_verified and user.google_sub:
            user.is_verified = True
        if app_language:
            user.app_language = app_language
        if native_language:
            user.native_language = native_language
        await ensure_basic_subscription(user, db)
        await db.flush()

    return await _issue_session(db, user)


async def refresh_tokens(db: AsyncSession, *, refresh_token: str) -> dict[str, str]:
    try:
        payload = decode_token(refresh_token)
    except jwt.PyJWTError as exc:
        raise AppError(
            message="Refresh token yaroqsiz",
            error_code="INVALID_REFRESH_TOKEN",
            status_code=401,
        ) from exc

    if payload.get("type") != "refresh":
        raise AppError(
            message="Refresh token yaroqsiz",
            error_code="INVALID_REFRESH_TOKEN",
            status_code=401,
        )

    token_hash = _hash_token(refresh_token)
    jti = str(payload.get("jti", ""))
    user_id = int(payload["sub"])
    family = str(payload.get("family") or jti)
    now = datetime.now(UTC)

    result = await db.execute(
        select(RefreshToken)
        .where(
            RefreshToken.jti == jti,
            RefreshToken.token_hash == token_hash,
        )
        .with_for_update()
    )
    stored = result.scalar_one_or_none()
    if stored is None:
        raise AppError(
            message="Refresh token yaroqsiz",
            error_code="INVALID_REFRESH_TOKEN",
            status_code=401,
        )

    # Reuse detection: revoked token presented again → compromise → kill family
    if stored.revoked_at is not None or stored.expires_at <= now:
        await db.execute(
            update(RefreshToken)
            .where(
                RefreshToken.family == family,
                RefreshToken.revoked_at.is_(None),
            )
            .values(revoked_at=now)
        )
        raise AppError(
            message="Refresh token yaroqsiz",
            error_code="INVALID_REFRESH_TOKEN",
            status_code=401,
        )

    user = await db.get(User, user_id)
    if user is None or not user.is_active or user.deleted_at is not None:
        stored.revoked_at = now
        await db.execute(
            update(RefreshToken)
            .where(
                RefreshToken.family == family,
                RefreshToken.revoked_at.is_(None),
            )
            .values(revoked_at=now)
        )
        if user is not None and user.deleted_at is not None:
            raise AppError(
                message="Akkaunt o'chirilgan",
                error_code="ACCOUNT_DELETED",
                status_code=403,
            )
        raise AppError(
            message="Akkaunt bloklangan",
            error_code="ACCOUNT_DISABLED",
            status_code=403,
        )

    stored.revoked_at = now
    new_refresh = create_refresh_token(user_id, token_family=family)
    await _store_refresh_token(db, user_id, new_refresh, family=family)
    access_token = create_access_token(user_id)

    return {"access_token": access_token, "refresh_token": new_refresh}


async def logout(db: AsyncSession, *, user_id: int, refresh_token: str) -> None:
    try:
        payload = decode_token(refresh_token)
    except jwt.PyJWTError:
        return

    if payload.get("type") != "refresh":
        return

    token_hash = _hash_token(refresh_token)
    jti = str(payload.get("jti", ""))
    now = datetime.now(UTC)

    await db.execute(
        update(RefreshToken)
        .where(
            RefreshToken.user_id == user_id,
            RefreshToken.jti == jti,
            RefreshToken.token_hash == token_hash,
            RefreshToken.revoked_at.is_(None),
        )
        .values(revoked_at=now)
    )


async def forgot_password(
    db: AsyncSession,
    redis: Redis,
    *,
    email: str,
    app_language: str,
) -> dict[str, Any]:
    email_norm = email.lower().strip()
    # Identical rate-limit path for existing and unknown emails (anti-enumeration).
    try:
        await check_resend_allowed(redis, email_norm, PURPOSE_RESET_PASSWORD)
    except AppError as exc:
        if exc.error_code == "RESEND_TOO_SOON":
            return {
                "message": "Agar bu email ro'yxatdan o'tgan bo'lsa, tasdiqlash kodi yuborildi",
                "resend_after_seconds": exc.extra.get(
                    "resend_after_seconds", RESEND_COOLDOWN_SECONDS
                ),
            }
        raise

    await _enforce_hourly_limit(redis, email_norm)

    result = await db.execute(
        select(User.id).where(
            User.email == email_norm,
            User.deleted_at.is_(None),
        )
    )
    user_exists = result.scalar_one_or_none() is not None

    resend_after = RESEND_COOLDOWN_SECONDS
    if user_exists:
        _, resend_after, _ = await create_and_send_otp(
            db,
            redis,
            email=email_norm,
            purpose=PURPOSE_RESET_PASSWORD,
            app_language=app_language,
            enforce_cooldown=False,
            enforce_hourly=False,
        )
    else:
        await _set_resend_cooldown(redis, email_norm, PURPOSE_RESET_PASSWORD)

    return {
        "message": "Agar bu email ro'yxatdan o'tgan bo'lsa, tasdiqlash kodi yuborildi",
        "resend_after_seconds": resend_after,
    }


async def reset_password(
    db: AsyncSession,
    *,
    email: str,
    code: str,
    new_password: str,
) -> dict[str, str]:
    email_norm = email.lower().strip()
    await verify_otp(db, email=email_norm, purpose=PURPOSE_RESET_PASSWORD, code=code)

    result = await db.execute(select(User).where(User.email == email_norm))
    user = result.scalar_one_or_none()
    if user is None or user.deleted_at is not None:
        raise AppError(message="Foydalanuvchi topilmadi", error_code="NOT_FOUND", status_code=404)

    user.password_hash = hash_password(new_password)
    now = datetime.now(UTC)
    await db.execute(
        update(RefreshToken)
        .where(RefreshToken.user_id == user.id, RefreshToken.revoked_at.is_(None))
        .values(revoked_at=now)
    )
    await db.flush()

    return {"message": "Parol muvaffaqiyatli yangilandi"}
