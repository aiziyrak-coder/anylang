from __future__ import annotations

import hashlib
import secrets
from datetime import UTC, datetime, timedelta

from redis.asyncio import Redis
from sqlalchemy import select, update
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.integrations.email import send_otp_email
from app.models.user import OtpCode

OTP_LENGTH = 6
OTP_TTL_MINUTES = 5
MAX_ATTEMPTS = 5
RESEND_COOLDOWN_SECONDS = 60
HOURLY_LIMIT = 5

PURPOSE_VERIFY_EMAIL = "verify_email"
PURPOSE_RESET_PASSWORD = "reset_password"


def _hash_code(code: str) -> str:
    return hashlib.sha256(code.encode()).hexdigest()


def _generate_code() -> str:
    return f"{secrets.randbelow(10**OTP_LENGTH):06d}"


def _cooldown_key(email: str, purpose: str) -> str:
    return f"otp:resend:{purpose}:{email.lower()}"


def _hourly_key(email: str) -> str:
    return f"otp:hourly:{email.lower()}"


async def _resend_remaining(redis: Redis, email: str, purpose: str) -> int:
    ttl = await redis.ttl(_cooldown_key(email, purpose))
    return max(int(ttl), 0)


async def check_resend_allowed(redis: Redis, email: str, purpose: str) -> int:
    """Return remaining cooldown seconds; raise if resend blocked."""
    remaining = await _resend_remaining(redis, email, purpose)
    if remaining > 0:
        raise AppError(
            message="Qayta yuborish uchun biroz kuting",
            error_code="RESEND_TOO_SOON",
            status_code=429,
            extra={"resend_after_seconds": remaining},
        )
    return 0


async def _enforce_hourly_limit(redis: Redis, email: str) -> None:
    key = _hourly_key(email)
    count = await redis.incr(key)
    if count == 1:
        await redis.expire(key, 3600)
    if count > HOURLY_LIMIT:
        raise AppError(
            message="Soatlik OTP limiti oshdi",
            error_code="TOO_MANY_REQUESTS",
            status_code=429,
        )


async def _set_resend_cooldown(redis: Redis, email: str, purpose: str) -> None:
    await redis.set(_cooldown_key(email, purpose), "1", ex=RESEND_COOLDOWN_SECONDS)


async def create_and_send_otp(
    db: AsyncSession,
    redis: Redis,
    *,
    email: str,
    purpose: str,
    app_language: str = "uz_UZ",
    enforce_cooldown: bool = True,
) -> tuple[str, int]:
    """Create OTP record, send email, apply rate limits. Returns (code, resend_after_seconds)."""
    email_norm = email.lower().strip()

    if enforce_cooldown:
        await check_resend_allowed(redis, email_norm, purpose)

    await _enforce_hourly_limit(redis, email_norm)

    now = datetime.now(UTC)
    await db.execute(
        update(OtpCode)
        .where(
            OtpCode.email == email_norm,
            OtpCode.purpose == purpose,
            OtpCode.consumed_at.is_(None),
            OtpCode.expires_at > now,
        )
        .values(consumed_at=now)
    )

    code = _generate_code()
    otp = OtpCode(
        email=email_norm,
        purpose=purpose,
        code_hash=_hash_code(code),
        attempts=0,
        expires_at=now + timedelta(minutes=OTP_TTL_MINUTES),
    )
    db.add(otp)
    await db.flush()

    await send_otp_email(email_norm, code, app_language)
    await _set_resend_cooldown(redis, email_norm, purpose)

    return code, RESEND_COOLDOWN_SECONDS


async def verify_otp(
    db: AsyncSession,
    *,
    email: str,
    purpose: str,
    code: str,
) -> None:
    email_norm = email.lower().strip()
    now = datetime.now(UTC)

    result = await db.execute(
        select(OtpCode)
        .where(
            OtpCode.email == email_norm,
            OtpCode.purpose == purpose,
            OtpCode.consumed_at.is_(None),
        )
        .order_by(OtpCode.created_at.desc())
        .limit(1)
    )
    otp = result.scalar_one_or_none()

    if otp is None:
        raise AppError(message="Kod noto'g'ri", error_code="INVALID_CODE", status_code=400)

    if otp.expires_at <= now:
        raise AppError(message="Kod muddati tugagan", error_code="CODE_EXPIRED", status_code=400)

    if otp.attempts >= MAX_ATTEMPTS:
        otp.consumed_at = now
        await db.flush()
        raise AppError(
            message="Juda ko'p noto'g'ri urinish",
            error_code="TOO_MANY_ATTEMPTS",
            status_code=429,
        )

    if otp.code_hash != _hash_code(code):
        otp.attempts += 1
        await db.flush()
        if otp.attempts >= MAX_ATTEMPTS:
            otp.consumed_at = now
            await db.flush()
            raise AppError(
                message="Juda ko'p noto'g'ri urinish",
                error_code="TOO_MANY_ATTEMPTS",
                status_code=429,
            )
        raise AppError(message="Kod noto'g'ri", error_code="INVALID_CODE", status_code=400)

    otp.consumed_at = now
    await db.flush()


async def get_resend_after_seconds(redis: Redis, email: str, purpose: str) -> int:
    remaining = await _resend_remaining(redis, email.lower(), purpose)
    return remaining if remaining > 0 else RESEND_COOLDOWN_SECONDS
