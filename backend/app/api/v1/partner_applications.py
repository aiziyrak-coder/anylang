"""Public partner application + admin review routes."""

from __future__ import annotations

from fastapi import APIRouter, File, Query, Request, UploadFile

from app.core.deps import DbSession, RedisClient
from app.core.rate_limit import client_ip, enforce_rate_limit
from app.core.uploads import read_upload_limited
from app.schemas.partner_application import (
    EmailCheckOut,
    PartnerAnalyticsOut,
    PartnerApplicationListOut,
    PartnerApplicationOut,
    PartnerApplicationSubmitIn,
    PartnerApplicationSubmitOut,
    PartnerBoardOut,
    PartnerDecideIn,
    PartnerStageIn,
    PartnerUploadOut,
)
from app.services import partner_applications as service
from app.services.admin_ops import ModeratorPlus, client_ip as admin_client_ip

router = APIRouter()
admin_router = APIRouter()


@router.get("/check-email", response_model=EmailCheckOut)
async def check_email(
    request: Request,
    db: DbSession,
    redis: RedisClient,
    email: str = Query(min_length=3, max_length=255),
) -> EmailCheckOut:
    ip = client_ip(request)
    await enforce_rate_limit(
        redis,
        f"partner:email:{ip}",
        limit=30,
        window_seconds=600,
    )
    data = await service.check_email_available(db, email)
    return EmailCheckOut.model_validate(data)


@router.post("/upload", response_model=PartnerUploadOut)
async def upload_media(
    request: Request,
    redis: RedisClient,
    file: UploadFile = File(...),
) -> PartnerUploadOut:
    ip = client_ip(request)
    await enforce_rate_limit(
        redis,
        f"partner:upload:{ip}",
        limit=40,
        window_seconds=3600,
        message="Juda ko‘p fayl yuklandi — keyinroq urinib ko‘ring",
    )
    content = await read_upload_limited(file, max_bytes=25 * 1024 * 1024)
    data = await service.upload_media(
        filename=file.filename or "upload",
        content_type=file.content_type or "application/octet-stream",
        data=content,
    )
    return PartnerUploadOut.model_validate(data)


@router.post("", response_model=PartnerApplicationSubmitOut)
async def submit_application(
    body: PartnerApplicationSubmitIn,
    request: Request,
    db: DbSession,
    redis: RedisClient,
) -> PartnerApplicationSubmitOut:
    ip = client_ip(request)
    await enforce_rate_limit(
        redis,
        f"partner:submit:{ip}",
        limit=8,
        window_seconds=3600,
        message="Juda ko‘p anketa yuborildi — keyinroq urinib ko‘ring",
    )
    data = await service.submit_application(db, body)
    return PartnerApplicationSubmitOut.model_validate(data)


@admin_router.get("/partner-applications", response_model=PartnerApplicationListOut)
async def admin_list(
    db: DbSession,
    _admin: ModeratorPlus,
    status: str = Query(default="pending"),
    q: str | None = Query(default=None, max_length=120),
    page: int = Query(default=1, ge=1),
    limit: int = Query(default=20, ge=1, le=100),
) -> PartnerApplicationListOut:
    data = await service.list_applications(
        db, status=status, q=q, page=page, limit=limit
    )
    return PartnerApplicationListOut.model_validate(data)


@admin_router.get("/partner-applications/board", response_model=PartnerBoardOut)
async def admin_board(
    db: DbSession,
    _admin: ModeratorPlus,
    per_column: int = Query(default=30, ge=5, le=50),
) -> PartnerBoardOut:
    data = await service.board_applications(db, per_column=per_column)
    return PartnerBoardOut.model_validate(data)


@admin_router.get("/partner-applications/analytics", response_model=PartnerAnalyticsOut)
async def admin_analytics(
    db: DbSession,
    _admin: ModeratorPlus,
    days: int = Query(default=30, ge=7, le=90),
) -> PartnerAnalyticsOut:
    data = await service.conversion_analytics(db, days=days)
    return PartnerAnalyticsOut.model_validate(data)


@admin_router.get(
    "/partner-applications/{app_id}", response_model=PartnerApplicationOut
)
async def admin_get(
    app_id: int,
    db: DbSession,
    _admin: ModeratorPlus,
) -> PartnerApplicationOut:
    data = await service.get_application(db, app_id)
    return PartnerApplicationOut.model_validate(data)


@admin_router.post(
    "/partner-applications/{app_id}/stage", response_model=PartnerApplicationOut
)
async def admin_set_stage(
    app_id: int,
    body: PartnerStageIn,
    request: Request,
    db: DbSession,
    admin: ModeratorPlus,
) -> PartnerApplicationOut:
    data = await service.set_application_stage(
        db,
        app_id=app_id,
        stage=body.stage,
        admin=admin,
        ip=admin_client_ip(request),
    )
    return PartnerApplicationOut.model_validate(data)


@admin_router.post(
    "/partner-applications/{app_id}/decide", response_model=PartnerApplicationOut
)
async def admin_decide(
    app_id: int,
    body: PartnerDecideIn,
    request: Request,
    db: DbSession,
    admin: ModeratorPlus,
) -> PartnerApplicationOut:
    data = await service.decide_application(
        db,
        app_id=app_id,
        body=body,
        admin=admin,
        ip=admin_client_ip(request),
    )
    return PartnerApplicationOut.model_validate(data)
