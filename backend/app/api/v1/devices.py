from fastapi import APIRouter, status

from app.api.deps_auth import CurrentUser
from app.core.deps import DbSession
from app.schemas.common import MessageResponse
from app.schemas.push import PushTokenOut, PushTokenRegisterIn, PushTokenUnregisterIn
from app.services import push as push_service

router = APIRouter()


@router.post(
    "/push-token",
    response_model=PushTokenOut,
    status_code=status.HTTP_200_OK,
)
async def register_push_token(
    body: PushTokenRegisterIn,
    db: DbSession,
    current_user: CurrentUser,
) -> PushTokenOut:
    data = await push_service.register_push_token(
        db,
        user_id=current_user.id,
        token=body.token,
        platform=body.platform,
        device_id=body.device_id,
        app_version=body.app_version,
    )
    return PushTokenOut.model_validate(data)


@router.delete("/push-token", response_model=MessageResponse)
async def unregister_push_token(
    body: PushTokenUnregisterIn,
    db: DbSession,
    current_user: CurrentUser,
) -> MessageResponse:
    data = await push_service.unregister_push_token(
        db,
        user_id=current_user.id,
        token=body.token,
        device_id=body.device_id,
    )
    return MessageResponse.model_validate(data)
