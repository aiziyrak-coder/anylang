from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from sqlalchemy import text
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response

from app.api.v1.router import api_router
from app.core.config import get_settings
from app.core.errors import register_exception_handlers
from app.core.startup import validate_settings
from app.db.redis import close_redis, get_redis
from app.db.session import get_session_factory
from app.services import admin_auth
from app.services import numbers as numbers_service
from app.ws.endpoint import router as ws_router


class SecurityHeadersMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next) -> Response:
        response = await call_next(request)
        response.headers.setdefault("X-Content-Type-Options", "nosniff")
        response.headers.setdefault("X-Frame-Options", "DENY")
        response.headers.setdefault("Referrer-Policy", "no-referrer")
        response.headers.setdefault("Permissions-Policy", "geolocation=(), microphone=(), camera=()")
        if get_settings().is_production:
            response.headers.setdefault(
                "Strict-Transport-Security",
                "max-age=31536000; includeSubDomains",
            )
        return response


@asynccontextmanager
async def lifespan(_: FastAPI) -> AsyncIterator[None]:
    settings = get_settings()
    validate_settings(settings)
    await get_redis()
    factory = get_session_factory()
    async with factory() as db:
        await admin_auth.seed_admin(db)
        await numbers_service.ensure_seed_groups(db)
        await db.commit()
    yield
    await close_redis()


def create_app() -> FastAPI:
    settings = get_settings()

    docs_url = None if settings.is_production else "/docs"
    redoc_url = None if settings.is_production else "/redoc"

    app = FastAPI(
        title=settings.app_name,
        version="0.1.0",
        lifespan=lifespan,
        docs_url=docs_url,
        redoc_url=redoc_url,
    )

    if settings.sentry_dsn:
        import sentry_sdk

        sentry_sdk.init(
            dsn=settings.sentry_dsn,
            environment=settings.app_env,
            traces_sample_rate=0.05 if settings.is_production else 0.2,
        )

    if settings.trusted_host_list:
        app.add_middleware(TrustedHostMiddleware, allowed_hosts=settings.trusted_host_list)

    app.add_middleware(SecurityHeadersMiddleware)
    app.add_middleware(
        CORSMiddleware,
        allow_origins=settings.cors_origin_list,
        allow_credentials=True,
        allow_methods=["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
        allow_headers=["Authorization", "Content-Type", "Accept", "X-Requested-With"],
    )

    register_exception_handlers(app)
    app.include_router(api_router, prefix=settings.api_v1_prefix)
    app.include_router(ws_router)

    @app.get("/health")
    async def health() -> dict[str, str]:
        return {"status": "ok"}

    @app.get("/ready")
    async def ready() -> JSONResponse:
        try:
            redis = await get_redis()
            await redis.ping()
            factory = get_session_factory()
            async with factory() as db:
                await db.execute(text("SELECT 1"))
        except Exception:
            return JSONResponse(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                content={"status": "not_ready", "error_code": "DEPENDENCY_UNAVAILABLE"},
            )
        return JSONResponse(content={"status": "ready"})

    return app


app = create_app()
