"""Admin RBAC helpers and audit logging."""

from __future__ import annotations

from typing import Annotated, Any, Callable

from fastapi import Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps_admin import CurrentAdmin, get_current_admin
from app.core.deps import DbSession
from app.core.errors import AppError
from app.models.user import AdminAuditLog, AdminUser

# Roles: superadmin | moderator | support | finance
ALL_ROLES = ("superadmin", "moderator", "support", "finance")


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
# Content / marketplace moderation
ModeratorPlus = Annotated[AdminUser, Depends(require_roles("superadmin", "moderator"))]
# Payments / subscriptions / promos
FinancePlus = Annotated[AdminUser, Depends(require_roles("superadmin", "finance"))]
# User support: chats, restore
SupportPlus = Annotated[AdminUser, Depends(require_roles("superadmin", "support"))]
# Users + verification shared by support & moderators
SupportOrModerator = Annotated[
    AdminUser, Depends(require_roles("superadmin", "moderator", "support"))
]
# Any signed-in admin (all roles)
AnyAdminRole = Annotated[AdminUser, Depends(require_roles(*ALL_ROLES))]


async def write_audit(
    db: AsyncSession,
    *,
    admin: AdminUser | None = None,
    action: str,
    target_type: str | None = None,
    target_id: str | int | None = None,
    meta: dict[str, Any] | None = None,
    ip: str | None = None,
    before: dict[str, Any] | None = None,
    after: dict[str, Any] | None = None,
) -> None:
    from app.services.audit_admin import compute_content_hash

    meta_d = dict(meta or {})
    before_d = dict(before) if before else None
    after_d = dict(after) if after else None
    if before_d is None and isinstance(meta_d.get("before"), dict):
        before_d = dict(meta_d.pop("before"))
    if after_d is None and isinstance(meta_d.get("after"), dict):
        after_d = dict(meta_d.pop("after"))

    actor_id = admin.id if admin is not None else None
    tid = str(target_id) if target_id is not None else None
    content_hash = compute_content_hash(
        action=action,
        target_type=target_type,
        target_id=tid,
        meta=meta_d,
        before_state=before_d,
        after_state=after_d,
        ip=ip,
        actor_admin_id=actor_id,
    )
    db.add(
        AdminAuditLog(
            actor_admin_id=actor_id,
            action=action,
            target_type=target_type,
            target_id=tid,
            meta=meta_d,
            ip=ip,
            before_state=before_d,
            after_state=after_d,
            content_hash=content_hash,
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


__all__ = [
    "ALL_ROLES",
    "SuperAdmin",
    "ModeratorPlus",
    "FinancePlus",
    "SupportPlus",
    "SupportOrModerator",
    "AnyAdminRole",
    "write_audit",
    "client_ip",
    "require_roles",
    "get_current_admin",
    "DbSession",
]
