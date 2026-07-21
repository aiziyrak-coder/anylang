from typing import Annotated

import jwt
from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.core.deps import DbSession
from app.core.errors import AppError
from app.core.security import decode_token
from app.models.user import BusinessProfile, User

_bearer = HTTPBearer(auto_error=False)


async def get_current_user(
    db: DbSession,
    credentials: Annotated[HTTPAuthorizationCredentials | None, Depends(_bearer)],
) -> User:
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

    if payload.get("type") != "access":
        raise AppError(
            message="Invalid token type",
            error_code="UNAUTHORIZED",
            status_code=401,
        )

    user_id = int(payload["sub"])
    result = await db.execute(
        select(User)
        .where(User.id == user_id)
        .options(
            selectinload(User.subscription),
            selectinload(User.business).selectinload(BusinessProfile.factory_images),
        )
    )
    user = result.scalar_one_or_none()

    if user is None:
        raise AppError(
            message="User not found",
            error_code="UNAUTHORIZED",
            status_code=401,
        )

    if not user.is_active:
        raise AppError(
            message="Akkaunt bloklangan",
            error_code="ACCOUNT_DISABLED",
            status_code=403,
        )

    if user.deleted_at is not None:
        raise AppError(
            message="Akkaunt o'chirilgan",
            error_code="ACCOUNT_DELETED",
            status_code=403,
            extra={"email": user.email},
        )

    if not user.is_verified:
        raise AppError(
            message="Email hali tasdiqlanmagan",
            error_code="ACCOUNT_NOT_VERIFIED",
            status_code=403,
        )

    return user


CurrentUser = Annotated[User, Depends(get_current_user)]
