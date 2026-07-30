from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import HTMLResponse, JSONResponse
from sqlalchemy import text
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
        response.headers.setdefault(
            "Permissions-Policy",
            "geolocation=(), microphone=(), camera=()",
        )
        response.headers.setdefault(
            "Content-Security-Policy",
            "default-src 'none'; frame-ancestors 'none'; base-uri 'none'",
        )
        response.headers.setdefault("X-XSS-Protection", "0")
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
    import logging

    logging.basicConfig(
        level=getattr(logging, settings.log_level.upper(), logging.INFO),
        format="%(asctime)s %(levelname)s [%(name)s] %(message)s",
    )

    docs_url = None if settings.is_production else "/docs"
    redoc_url = None if settings.is_production else "/redoc"
    openapi_url = None if settings.is_production else "/openapi.json"

    app = FastAPI(
        title=settings.app_name,
        version="0.1.0",
        lifespan=lifespan,
        docs_url=docs_url,
        redoc_url=redoc_url,
        openapi_url=openapi_url,
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

    _billing_html = """<!DOCTYPE html>
<html lang="uz">
<head>
  <meta charset="utf-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <meta name="theme-color" content="#040b10"/>
  <title>AnyLang — {title}</title>
  <style>
    :root {{
      --bg: #040b10;
      --ink: #f4faf6;
      --muted: #849990;
      --lime: #b8f25a;
      --teal: #00c4b8;
      --navy: #0b1a14;
      --card: rgba(255,255,255,0.06);
      --line: rgba(244,250,246,0.12);
    }}
    * {{ box-sizing: border-box; }}
    body {{
      margin: 0;
      min-height: 100vh;
      font-family: Figtree, system-ui, -apple-system, Segoe UI, Roboto, sans-serif;
      color: var(--ink);
      background:
        radial-gradient(900px 500px at 10% -10%, rgba(0,196,184,0.28), transparent 55%),
        radial-gradient(800px 480px at 100% 0%, rgba(184,242,90,0.2), transparent 50%),
        linear-gradient(180deg, #06131c 0%, var(--bg) 45%, #02070b 100%);
      display: grid;
      place-items: center;
      padding: 24px;
    }}
    .card {{
      width: min(440px, 100%);
      padding: 28px 24px 24px;
      border-radius: 24px;
      background: linear-gradient(165deg, rgba(255,255,255,0.1), rgba(255,255,255,0.03));
      border: 1px solid var(--line);
      box-shadow: 0 30px 80px rgba(0,0,0,0.45);
      text-align: center;
      backdrop-filter: blur(16px);
    }}
    .mark {{
      width: 56px; height: 56px; margin: 0 auto 16px;
      border-radius: 16px;
      background: linear-gradient(135deg, var(--lime), var(--teal));
      box-shadow: 0 12px 32px rgba(184,242,90,0.35);
      display: grid; place-items: center;
      font-size: 28px; font-weight: 800; color: var(--navy);
    }}
    h1 {{
      margin: 0 0 10px;
      font-size: clamp(1.35rem, 4vw, 1.7rem);
      letter-spacing: -0.03em;
      line-height: 1.2;
    }}
    p {{
      margin: 0 0 22px;
      color: var(--muted);
      font-size: 1rem;
      line-height: 1.5;
    }}
    .btn {{
      display: inline-flex; align-items: center; justify-content: center;
      min-height: 48px; padding: 0 22px; border-radius: 14px;
      background: linear-gradient(135deg, var(--lime), #d4ff7a 45%, var(--teal));
      color: var(--navy); font-weight: 800; text-decoration: none;
      box-shadow: 0 12px 28px rgba(184,242,90,0.35);
    }}
    .hint {{ margin-top: 16px; font-size: 0.85rem; color: var(--muted); }}
  </style>
</head>
<body>
  <main class="card">
    <div class="mark" aria-hidden="true">{icon}</div>
    <h1>{title}</h1>
    <p>{body}</p>
    <a class="btn" href="anylang://billing/done">{cta}</a>
    <p class="hint">AnyLang · Click</p>
  </main>
</body>
</html>"""

    @app.get("/billing/success", response_class=HTMLResponse)
    async def billing_success() -> HTMLResponse:
        return HTMLResponse(
            _billing_html.format(
                icon="✓",
                title="To‘lov qabul qilindi",
                body="Rahmat! Ilovaga qayting — tarif avtomatik yangilanadi.",
                cta="Ilovaga qaytish",
            )
        )

    @app.get("/billing/cancel", response_class=HTMLResponse)
    async def billing_cancel() -> HTMLResponse:
        return HTMLResponse(
            _billing_html.format(
                icon="!",
                title="To‘lov bekor qilindi",
                body="Hech narsa yechilmadi. Ilovaga qaytib qayta urinib ko‘ring.",
                cta="Ilovaga qaytish",
            )
        )

    # Click / legacy return_url aliases
    @app.get("/payment/success", response_class=HTMLResponse)
    async def payment_success() -> HTMLResponse:
        return await billing_success()

    @app.get("/payment/cancel", response_class=HTMLResponse)
    async def payment_cancel() -> HTMLResponse:
        return await billing_cancel()

    @app.get("/health")
    async def health() -> dict[str, str]:
        return {"status": "ok", "service": settings.app_name, "env": settings.app_env}

    @app.get("/ready")
    async def ready() -> JSONResponse:
        checks: dict[str, str] = {}
        try:
            redis = await get_redis()
            await redis.ping()
            checks["redis"] = "ok"
        except Exception:
            checks["redis"] = "fail"
            return JSONResponse(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                content={
                    "status": "not_ready",
                    "error_code": "DEPENDENCY_UNAVAILABLE",
                    "checks": checks,
                },
            )
        try:
            factory = get_session_factory()
            async with factory() as db:
                await db.execute(text("SELECT 1"))
            checks["postgres"] = "ok"
        except Exception:
            checks["postgres"] = "fail"
            return JSONResponse(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                content={
                    "status": "not_ready",
                    "error_code": "DEPENDENCY_UNAVAILABLE",
                    "checks": checks,
                },
            )
        return JSONResponse(
            content={"status": "ready", "checks": checks, "env": settings.app_env}
        )

    @app.get("/metrics/basic")
    async def basic_metrics() -> JSONResponse:
        """Lightweight ops snapshot (no Prometheus required)."""
        import time

        started = time.perf_counter()
        redis_ok = False
        pg_ok = False
        try:
            redis = await get_redis()
            await redis.ping()
            redis_ok = True
        except Exception:
            pass
        try:
            factory = get_session_factory()
            async with factory() as db:
                await db.execute(text("SELECT 1"))
            pg_ok = True
        except Exception:
            pass
        latency_ms = round((time.perf_counter() - started) * 1000, 2)
        code = status.HTTP_200_OK if redis_ok and pg_ok else status.HTTP_503_SERVICE_UNAVAILABLE
        return JSONResponse(
            status_code=code,
            content={
                "postgres": pg_ok,
                "redis": redis_ok,
                "check_latency_ms": latency_ms,
                "env": settings.app_env,
            },
        )

    return app


app = create_app()
