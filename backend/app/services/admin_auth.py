from __future__ import annotations

from datetime import UTC, datetime, timedelta
from uuid import uuid4

import jwt
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.errors import AppError
from app.core.security import hash_password, verify_password
from app.models.user import AdminUser

DEFAULT_ADMIN_EMAIL = "admin@anylang.com"
DEFAULT_ADMIN_PASSWORD = "Admin123!"  # local only — overridden by ADMIN_PASSWORD
DEFAULT_ADMIN_NAME = "AnyLang Admin"


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
    return jwt.encode(payload, settings.secret_key, algorithm="HS256")


async def seed_admin(db: AsyncSession) -> None:
    settings = get_settings()

    if settings.is_production and not settings.admin_seed_in_production:
        # Never auto-create default admin in production unless explicitly enabled.
        return

    email = (settings.admin_email or DEFAULT_ADMIN_EMAIL).lower().strip()
    password = settings.admin_password or (
        None if settings.is_production else DEFAULT_ADMIN_PASSWORD
    )
    if not password:
        logger = __import__("logging").getLogger(__name__)
        logger.warning("Admin seed skipped: ADMIN_PASSWORD not set")
        return

    if settings.is_production and password == DEFAULT_ADMIN_PASSWORD:
        raise RuntimeError("Refuse to seed default Admin123! password in production")

    result = await db.execute(select(AdminUser).where(AdminUser.email == email))
    existing = result.scalar_one_or_none()
    if existing is not None:
        return

    admin = AdminUser(
        email=email,
        password_hash=hash_password(password),
        full_name=DEFAULT_ADMIN_NAME,
        role="superadmin",
        is_active=True,
    )
    db.add(admin)
    await db.flush()


async def login_admin(db: AsyncSession, *, email: str, password: str) -> dict:
    result = await db.execute(select(AdminUser).where(AdminUser.email == email))
    admin = result.scalar_one_or_none()

    if admin is None or not admin.is_active or not verify_password(password, admin.password_hash):
        raise AppError(
            message="Email yoki parol noto'g'ri",
            error_code="INVALID_CREDENTIALS",
            status_code=401,
        )

    token = create_admin_access_token(admin.id, admin.role)
    return {
        "access_token": token,
        "token_type": "bearer",
        "expires_in": 8 * 3600,
        "admin": {
            "id": admin.id,
            "email": admin.email,
            "full_name": admin.full_name,
            "role": admin.role,
        },
    }
