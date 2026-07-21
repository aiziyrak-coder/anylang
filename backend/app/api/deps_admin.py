from __future__ import annotations

from typing import Annotated

import jwt
from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select

from app.core.deps import DbSession
from app.core.errors import AppError
from app.core.security import decode_token
from app.models.user import AdminUser

_bearer = HTTPBearer(auto_error=False)


async def get_current_admin(
    db: DbSession,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)],
) -> AdminUser:
    if credentials is None or credentials.scheme.lower() != "bearer":
        raise AppError(
            message="Authentication required",
            error_code="UNAUTHORIZED",
            status_code=401,
        )

    try:
        payload = decode_token(credentials.credentials)
    except jwt.PyJWTError as exc:
        raise AppError(
            message="Invalid or expired token",
            error_code="UNAUTHORIZED",
            status_code=401,
        ) from exc

    if payload.get("type") != "admin":
        raise AppError(
            message="Admin access required",
            error_code="FORBIDDEN",
            status_code=403,
        )

    admin_id = int(payload["sub"])
    result = await db.execute(select(AdminUser).where(AdminUser.id == admin_id))
    admin = result.scalar_one_or_none()

    if admin is None or not admin.is_active:
        raise AppError(
            message="Admin not found",
            error_code="UNAUTHORIZED",
            status_code=401,
        )

    return admin


CurrentAdmin = Annotated[AdminUser, Depends(get_current_admin)]
