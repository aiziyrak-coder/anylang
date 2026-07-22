from fastapi import APIRouter

from app.core.config import get_settings

router = APIRouter()


@router.get("/meta")
async def meta() -> dict[str, str]:
    settings = get_settings()
    payload = {
        "name": settings.app_name,
        "api": "v1",
    }
    if not settings.is_production:
        payload["env"] = settings.app_env
    return payload
