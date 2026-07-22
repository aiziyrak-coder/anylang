from datetime import UTC, datetime, timedelta
from typing import Any
from uuid import uuid4

import jwt
from argon2 import PasswordHasher
from argon2.exceptions import VerifyMismatchError

from app.core.config import get_settings

_ph = PasswordHasher()


def hash_password(password: str) -> str:
    return _ph.hash(password)


def verify_password(password: str, password_hash: str) -> bool:
    try:
        return _ph.verify(password_hash, password)
    except VerifyMismatchError:
        return False


_PROTECTED_CLAIMS = frozenset({"sub", "type", "iat", "exp", "jti", "family"})


def create_access_token(subject: str | int, extra: dict[str, Any] | None = None) -> str:
    settings = get_settings()
    now = datetime.now(UTC)
    payload: dict[str, Any] = {
        "sub": str(subject),
        "type": "access",
        "iat": now,
        "exp": now + timedelta(minutes=settings.access_token_expire_minutes),
        "jti": uuid4().hex,
    }
    if extra:
        # Never allow callers to overwrite identity / type claims
        payload.update({k: v for k, v in extra.items() if k not in _PROTECTED_CLAIMS})
    return jwt.encode(payload, settings.secret_key, algorithm="HS256")


def create_refresh_token(subject: str | int, token_family: str | None = None) -> str:
    settings = get_settings()
    now = datetime.now(UTC)
    payload = {
        "sub": str(subject),
        "type": "refresh",
        "iat": now,
        "exp": now + timedelta(days=settings.refresh_token_expire_days),
        "jti": uuid4().hex,
        "family": token_family or uuid4().hex,
    }
    return jwt.encode(payload, settings.secret_key, algorithm="HS256")


def decode_token(token: str) -> dict[str, Any]:
    settings = get_settings()
    return jwt.decode(token, settings.secret_key, algorithms=["HS256"])


def create_admin_access_token(admin_id: int, role: str) -> str:
    settings = get_settings()
    now = datetime.now(UTC)
    payload = {
        "sub": str(admin_id),
        "type": "admin",
        "role": role,
        "iat": now,
        "exp": now + timedelta(hours=8),
        "jti": uuid4().hex,
    }
    return jwt.encode(payload, settings.admin_signing_key, algorithm="HS256")


def decode_admin_token(token: str) -> dict[str, Any]:
    """Decode admin JWT with admin key; fall back to user secret for migration."""
    settings = get_settings()
    try:
        return jwt.decode(token, settings.admin_signing_key, algorithms=["HS256"])
    except jwt.PyJWTError:
        if settings.admin_secret_key:
            # Explicit admin key set — do not accept user-secret-signed tokens
            raise
        return jwt.decode(token, settings.secret_key, algorithms=["HS256"])
