"""Admin RBAC helpers and audit logging."""

from __future__ import annotations

from typing import Annotated, Any, Callable

from fastapi import Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps_admin import CurrentAdmin, get_current_admin
from app.core.deps import DbSession
from app.core.errors import AppError
from app.models.user import AdminAuditLog, AdminUser


def require_roles(*roles: str) -> Callable[..., Any]:
    """Dependency factory: admin must have one of the given roles."""

    allowed = frozenset(roles)

    async def _dep(admin: CurrentAdmin) -> AdminUser:
        if admin.role not in allowed:
            raise AppError(
                message="Insufficient admin privileges",
                error_code="FORBIDDEN",
                status_code=403,
            )
        return admin

    return _dep


SuperAdmin = Annotated[AdminUser, Depends(require_roles("superadmin"))]
ModeratorPlus = Annotated[AdminUser, Depends(require_roles("superadmin", "moderator"))]
AnyAdminRole = Annotated[
    AdminUser, Depends(require_roles("superadmin", "moderator", "support"))
]


async def write_audit(
    db: AsyncSession,
    *,
    admin: AdminUser | None = None,
    action: str,
    target_type: str | None = None,
    target_id: str | int | None = None,
    meta: dict[str, Any] | None = None,
    ip: str | None = None,
) -> None:
    db.add(
        AdminAuditLog(
            actor_admin_id=admin.id if admin is not None else None,
            action=action,
            target_type=target_type,
            target_id=str(target_id) if target_id is not None else None,
            meta=meta or {},
            ip=ip,
        )
    )
    await db.flush()


def client_ip(request: Request | None) -> str | None:
    if request is None:
        return None
    forwarded = request.headers.get("x-forwarded-for")
    if forwarded:
        return forwarded.split(",")[0].strip()
    if request.client:
        return request.client.host
    return None


# Re-export for convenience
__all__ = [
    "CurrentAdmin",
    "SuperAdmin",
    "ModeratorPlus",
    "AnyAdminRole",
    "get_current_admin",
    "require_roles",
    "write_audit",
    "client_ip",
    "DbSession",
]
