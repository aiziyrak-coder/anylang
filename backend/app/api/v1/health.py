from fastapi import APIRouter

from app.core.config import get_settings

router = APIRouter()


@router.get("/meta")
async def meta() -> dict[str, str]:
    settings = get_settings()
    return {
        "name": settings.app_name,
        "env": settings.app_env,
        "api": "v1",
    }
