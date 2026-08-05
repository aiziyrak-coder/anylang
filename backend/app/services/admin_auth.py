from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.errors import AppError
from app.core.security import create_admin_access_token, hash_password, verify_password
from app.models.user import AdminUser

DEFAULT_ADMIN_EMAIL = "admin@anylang.com"
DEFAULT_ADMIN_PASSWORD = "Admin123!"  # local only — overridden by ADMIN_PASSWORD
DEFAULT_ADMIN_NAME = "AnyLang Admin"


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
    normalized = (email or "").lower().strip()
    result = await db.execute(select(AdminUser).where(AdminUser.email == normalized))
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


async def upsert_admin(
    db: AsyncSession,
    *,
    email: str,
    password: str,
    full_name: str = DEFAULT_ADMIN_NAME,
    role: str = "superadmin",
) -> AdminUser:
    """Create or reset an admin account (ops / bootstrap only)."""
    normalized = (email or "").lower().strip()
    if not normalized or len(password) < 8:
        raise AppError(
            message="Admin email/parol noto'g'ri (parol kamida 8 belgi)",
            error_code="VALIDATION_ERROR",
            status_code=400,
        )
    result = await db.execute(select(AdminUser).where(AdminUser.email == normalized))
    admin = result.scalar_one_or_none()
    pwd_hash = hash_password(password)
    if admin is None:
        admin = AdminUser(
            email=normalized,
            password_hash=pwd_hash,
            full_name=full_name,
            role=role,
            is_active=True,
        )
        db.add(admin)
    else:
        admin.password_hash = pwd_hash
        admin.full_name = full_name or admin.full_name
        admin.role = role
        admin.is_active = True
    await db.flush()
    return admin
