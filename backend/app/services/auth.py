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
from app.services.email_guard import is_disposable_email
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
from app.ws.hub import RedisHub

logger = logging.getLogger(__name__)

SESSION_PROTECT_DAYS = 7
ONLINE_WINDOW = timedelta(minutes=5)


def _hash_token(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def _refresh_expires_at() -> datetime:
    settings = get_settings()
    return datetime.now(UTC) + timedelta(days=settings.refresh_token_expire_days)


def _aware(dt: datetime | None) -> datetime | None:
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=UTC)
    return dt


def _session_started(row: RefreshToken) -> datetime:
    return _aware(row.session_started_at) or _aware(row.created_at) or datetime.now(UTC)


def _can_revoke_session(actor: RefreshToken, target: RefreshToken, *, now: datetime) -> bool:
    """Yangi seans 1 hafta ichida eski seanslarni chiqara olmaydi;
    eski seanslar yangisini darhol chiqara oladi; 1 haftadan keyin hammasi.
    """
    if actor.family == target.family:
        return False
    actor_started = _session_started(actor)
    if now - actor_started >= timedelta(days=SESSION_PROTECT_DAYS):
        return True
    target_started = _session_started(target)
    return target_started > actor_started


def _device_fields(
    device: dict[str, Any] | None,
    *,
    ip_address: str | None = None,
    copy_from: RefreshToken | None = None,
) -> dict[str, Any]:
    now = datetime.now(UTC)
    if copy_from is not None:
        return {
            "device_id": copy_from.device_id,
            "device_name": copy_from.device_name,
            "device_type": copy_from.device_type,
            "platform": copy_from.platform,
            "app_version": copy_from.app_version,
            "ip_address": ip_address or copy_from.ip_address,
            "last_active_at": now,
            "session_started_at": _session_started(copy_from),
        }
    device = device or {}
    return {
        "device_id": (device.get("device_id") or None),
        "device_name": (device.get("device_name") or "Mobile")[:120],
        "device_type": (device.get("device_type") or "mobile")[:32],
        "platform": (device.get("platform") or None),
        "app_version": (device.get("app_version") or None),
        "ip_address": ip_address,
        "last_active_at": now,
        "session_started_at": now,
    }


async def _revoke_same_device_sessions(
    db: AsyncSession,
    *,
    user_id: int,
    device_id: str | None,
    except_family: str | None = None,
) -> None:
    if not device_id:
        return
    now = datetime.now(UTC)
    q = (
        update(RefreshToken)
        .where(
            RefreshToken.user_id == user_id,
            RefreshToken.device_id == device_id,
            RefreshToken.revoked_at.is_(None),
        )
        .values(revoked_at=now)
    )
    if except_family:
        q = q.where(RefreshToken.family != except_family)
    await db.execute(q)


async def _store_refresh_token(
    db: AsyncSession,
    user_id: int,
    refresh_token: str,
    *,
    family: str | None = None,
    device: dict[str, Any] | None = None,
    ip_address: str | None = None,
    copy_from: RefreshToken | None = None,
) -> RefreshToken:
    payload = decode_token(refresh_token)
    if payload.get("type") != "refresh":
        raise AppError(message="Token turi noto'g'ri", error_code="INVALID_REFRESH_TOKEN", status_code=401)

    fam = str(payload.get("family") or family or payload["jti"])
    meta = _device_fields(device, ip_address=ip_address, copy_from=copy_from)
    record = RefreshToken(
        user_id=user_id,
        jti=str(payload["jti"]),
        family=fam,
        token_hash=_hash_token(refresh_token),
        expires_at=_refresh_expires_at(),
        **meta,
    )
    db.add(record)
    await db.flush()
    return record


async def _notify_other_devices_new_login(
    *,
    user_id: int,
    new_session: RefreshToken,
    had_other_sessions: bool,
) -> None:
    if not had_other_sessions:
        return
    try:
        await RedisHub().publish(
            user_id,
            "device_login",
            {
                "session_id": new_session.family,
                "device_name": new_session.device_name or "Mobile",
                "device_type": new_session.device_type or "mobile",
                "platform": new_session.platform,
                "app_version": new_session.app_version,
                "session_started_at": (_session_started(new_session)).isoformat(),
            },
        )
    except Exception:
        logger.exception("device_login notify failed user=%s", user_id)


async def _issue_session(
    db: AsyncSession,
    user: User,
    *,
    device: dict[str, Any] | None = None,
    ip_address: str | None = None,
    notify_others: bool = True,
) -> dict[str, Any]:
    access_token = create_access_token(user.id)
    refresh_token = create_refresh_token(user.id)
    payload = decode_token(refresh_token)
    family = str(payload.get("family") or payload["jti"])
    device_id = (device or {}).get("device_id") if device else None

    had_others = False
    if notify_others:
        now = datetime.now(UTC)
        q = select(RefreshToken.id).where(
            RefreshToken.user_id == user.id,
            RefreshToken.revoked_at.is_(None),
            RefreshToken.expires_at > now,
        )
        if device_id:
            q = q.where(
                (RefreshToken.device_id.is_(None))
                | (RefreshToken.device_id != device_id)
            )
        others = await db.execute(q)
        had_others = others.first() is not None

    await _revoke_same_device_sessions(
        db, user_id=user.id, device_id=device_id, except_family=family
    )
    record = await _store_refresh_token(
        db,
        user.id,
        refresh_token,
        family=family,
        device=device,
        ip_address=ip_address,
    )
    loaded = await load_user_for_response(db, user.id)
    assert loaded is not None
    if notify_others:
        await _notify_other_devices_new_login(
            user_id=user.id,
            new_session=record,
            had_other_sessions=had_others,
        )
    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "session_id": family,
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

    if is_disposable_email(email_norm):
        raise AppError(
            message="Vaqtinchalik email qabul qilinmaydi — haqiqiy pochta kiriting",
            error_code="EMAIL_DISPOSABLE",
            status_code=400,
        )

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
        "emailed": emailed,
    }
    # When enabled, always return OTP so the mobile app can finish signup
    # even if SMTP is misconfigured or "succeeds" without delivery.
    if settings.allow_otp_in_response:
        out["debug_otp"] = code
    return out


async def verify_email(
    db: AsyncSession,
    redis: Redis,
    *,
    email: str,
    code: str,
    device: dict[str, Any] | None = None,
    ip_address: str | None = None,
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
    return await _issue_session(
        db, user, device=device, ip_address=ip_address, notify_others=True
    )


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

    code, resend_after, emailed = await create_and_send_otp(
        db,
        redis,
        email=email_norm,
        purpose=PURPOSE_VERIFY_EMAIL,
        app_language=app_language,
        enforce_cooldown=True,
    )
    out: dict[str, Any] = {
        "message": "Kod emailingizga yuborildi" if emailed else "Kod yuborilmadi — qayta urinib ko‘ring",
        "resend_after_seconds": resend_after,
        "emailed": emailed,
    }
    settings = get_settings()
    if settings.allow_otp_in_response:
        out["debug_otp"] = code
    return out


async def login(
    db: AsyncSession,
    redis: Redis,
    *,
    email: str,
    password: str,
    app_language: str | None = None,
    native_language: str | None = None,
    device: dict[str, Any] | None = None,
    ip_address: str | None = None,
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
    return await _issue_session(
        db, user, device=device, ip_address=ip_address, notify_others=True
    )


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
            "GOOGLE_CLIENT_IDS is empty — decoding id_token without verification "
            "(bootstrap; set GOOGLE_CLIENT_IDS for real Google Sign-In)"
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
    device: dict[str, Any] | None = None,
    ip_address: str | None = None,
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

    return await _issue_session(
        db, user, device=device, ip_address=ip_address, notify_others=True
    )


async def refresh_tokens(
    db: AsyncSession,
    *,
    refresh_token: str,
    device: dict[str, Any] | None = None,
    ip_address: str | None = None,
) -> dict[str, str]:
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
    # Device meta yangilanishi (ixtiyoriy) — session_started saqlanadi.
    if device:
        if device.get("device_name"):
            stored.device_name = str(device["device_name"])[:120]
        if device.get("device_type"):
            stored.device_type = str(device["device_type"])[:32]
        if device.get("platform"):
            stored.platform = str(device["platform"])[:64]
        if device.get("app_version"):
            stored.app_version = str(device["app_version"])[:32]
        if device.get("device_id") and not stored.device_id:
            stored.device_id = str(device["device_id"])[:64]
    new_refresh = create_refresh_token(user_id, token_family=family)
    await _store_refresh_token(
        db,
        user_id,
        new_refresh,
        family=family,
        device=device,
        ip_address=ip_address,
        copy_from=stored,
    )
    access_token = create_access_token(user_id)

    return {
        "access_token": access_token,
        "refresh_token": new_refresh,
        "session_id": family,
    }


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


async def _active_sessions(db: AsyncSession, user_id: int) -> list[RefreshToken]:
    now = datetime.now(UTC)
    result = await db.execute(
        select(RefreshToken)
        .where(
            RefreshToken.user_id == user_id,
            RefreshToken.revoked_at.is_(None),
            RefreshToken.expires_at > now,
        )
        .order_by(RefreshToken.last_active_at.desc().nullslast(), RefreshToken.id.desc())
    )
    rows = list(result.scalars().all())
    # Bir family — bitta seans (eng yangi qator).
    by_family: dict[str, RefreshToken] = {}
    for row in rows:
        if row.family not in by_family:
            by_family[row.family] = row
    return list(by_family.values())


async def _resolve_current_session(
    db: AsyncSession,
    *,
    user_id: int,
    refresh_token: str | None,
    session_id: str | None = None,
) -> RefreshToken | None:
    if refresh_token:
        try:
            payload = decode_token(refresh_token)
        except jwt.PyJWTError:
            payload = None
        if payload and payload.get("type") == "refresh":
            jti = str(payload.get("jti", ""))
            token_hash = _hash_token(refresh_token)
            result = await db.execute(
                select(RefreshToken).where(
                    RefreshToken.user_id == user_id,
                    RefreshToken.jti == jti,
                    RefreshToken.token_hash == token_hash,
                    RefreshToken.revoked_at.is_(None),
                )
            )
            row = result.scalar_one_or_none()
            if row is not None:
                return row
            fam = str(payload.get("family") or jti)
            result = await db.execute(
                select(RefreshToken)
                .where(
                    RefreshToken.user_id == user_id,
                    RefreshToken.family == fam,
                    RefreshToken.revoked_at.is_(None),
                )
                .order_by(RefreshToken.id.desc())
                .limit(1)
            )
            return result.scalar_one_or_none()
    if session_id:
        result = await db.execute(
            select(RefreshToken)
            .where(
                RefreshToken.user_id == user_id,
                RefreshToken.family == session_id,
                RefreshToken.revoked_at.is_(None),
            )
            .order_by(RefreshToken.id.desc())
            .limit(1)
        )
        return result.scalar_one_or_none()
    return None


def _serialize_session(
    row: RefreshToken,
    *,
    current: RefreshToken | None,
    now: datetime,
) -> dict[str, Any]:
    last = _aware(row.last_active_at) or _session_started(row)
    is_current = current is not None and row.family == current.family
    can_revoke = False
    if current is not None and not is_current:
        can_revoke = _can_revoke_session(current, row, now=now)
    return {
        "id": row.family,
        "device_name": row.device_name or "Mobile",
        "device_type": row.device_type or "mobile",
        "platform": row.platform,
        "app_version": row.app_version,
        "ip_address": row.ip_address,
        "is_current": is_current,
        "is_online": bool(last and now - last <= ONLINE_WINDOW),
        "last_active_at": last,
        "session_started_at": _session_started(row),
        "can_revoke": can_revoke,
    }


async def list_device_sessions(
    db: AsyncSession,
    *,
    user_id: int,
    refresh_token: str | None,
) -> dict[str, Any]:
    now = datetime.now(UTC)
    current = await _resolve_current_session(
        db, user_id=user_id, refresh_token=refresh_token
    )
    sessions = await _active_sessions(db, user_id)
    # Joriy seansni boshqa ro‘yxatdan ajratish.
    others = [s for s in sessions if current is None or s.family != current.family]
    others.sort(
        key=lambda s: _aware(s.last_active_at) or _session_started(s),
        reverse=True,
    )
    current_out = (
        _serialize_session(current, current=current, now=now) if current else None
    )
    can_revoke_others = False
    if current is not None:
        can_revoke_others = any(
            _can_revoke_session(current, s, now=now) for s in others
        )
    return {
        "current": current_out,
        "sessions": [
            _serialize_session(s, current=current, now=now) for s in others
        ],
        "can_revoke_others": can_revoke_others,
    }


async def revoke_device_session(
    db: AsyncSession,
    *,
    user_id: int,
    session_id: str,
    refresh_token: str | None,
) -> dict[str, Any]:
    now = datetime.now(UTC)
    current = await _resolve_current_session(
        db, user_id=user_id, refresh_token=refresh_token
    )
    if current is None:
        raise AppError(
            message="Joriy seans topilmadi",
            error_code="SESSION_NOT_FOUND",
            status_code=401,
        )
    if current.family == session_id:
        raise AppError(
            message="Joriy seansni shu yerda tugata olmaysiz — chiqishdan foydalaning",
            error_code="CANNOT_REVOKE_CURRENT",
            status_code=400,
        )
    result = await db.execute(
        select(RefreshToken)
        .where(
            RefreshToken.user_id == user_id,
            RefreshToken.family == session_id,
            RefreshToken.revoked_at.is_(None),
            RefreshToken.expires_at > now,
        )
        .order_by(RefreshToken.id.desc())
        .limit(1)
    )
    target = result.scalar_one_or_none()
    if target is None:
        raise AppError(
            message="Seans topilmadi",
            error_code="SESSION_NOT_FOUND",
            status_code=404,
        )
    if not _can_revoke_session(current, target, now=now):
        raise AppError(
            message="Yangi qurilma 1 hafta ichida boshqa seanslarni tugata olmaydi",
            error_code="SESSION_PROTECT_WEEK",
            status_code=403,
        )
    await db.execute(
        update(RefreshToken)
        .where(
            RefreshToken.user_id == user_id,
            RefreshToken.family == session_id,
            RefreshToken.revoked_at.is_(None),
        )
        .values(revoked_at=now)
    )
    try:
        await RedisHub().publish(
            user_id,
            "session_revoked",
            {"session_id": session_id, "by_session_id": current.family},
        )
    except Exception:
        logger.exception("session_revoked notify failed")
    return {"message": "Seans tugatildi"}


async def revoke_other_device_sessions(
    db: AsyncSession,
    *,
    user_id: int,
    refresh_token: str,
) -> dict[str, Any]:
    now = datetime.now(UTC)
    current = await _resolve_current_session(
        db, user_id=user_id, refresh_token=refresh_token
    )
    if current is None:
        raise AppError(
            message="Joriy seans topilmadi",
            error_code="SESSION_NOT_FOUND",
            status_code=401,
        )
    sessions = await _active_sessions(db, user_id)
    revoked_ids: list[str] = []
    for s in sessions:
        if s.family == current.family:
            continue
        if not _can_revoke_session(current, s, now=now):
            continue
        await db.execute(
            update(RefreshToken)
            .where(
                RefreshToken.user_id == user_id,
                RefreshToken.family == s.family,
                RefreshToken.revoked_at.is_(None),
            )
            .values(revoked_at=now)
        )
        revoked_ids.append(s.family)
    for sid in revoked_ids:
        try:
            await RedisHub().publish(
                user_id,
                "session_revoked",
                {"session_id": sid, "by_session_id": current.family},
            )
        except Exception:
            logger.exception("session_revoked notify failed")
    skipped = len(sessions) - 1 - len(revoked_ids)
    return {
        "message": "Boshqa seanslar tugatildi",
        "revoked_count": len(revoked_ids),
        "skipped_protected": max(0, skipped),
    }


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
