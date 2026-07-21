import logging
from typing import Any

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException


class AppError(Exception):
    """Domain error → TZ error format: {message, error_code}."""

    def __init__(
        self,
        message: str,
        error_code: str,
        status_code: int = status.HTTP_400_BAD_REQUEST,
        extra: dict[str, Any] | None = None,
    ) -> None:
        self.message = message
        self.error_code = error_code
        self.status_code = status_code
        self.extra = extra or {}
        super().__init__(message)


def error_body(message: str, error_code: str, **extra: Any) -> dict[str, Any]:
    body: dict[str, Any] = {"message": message, "error_code": error_code}
    body.update(extra)
    return body


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(AppError)
    async def app_error_handler(_: Request, exc: AppError) -> JSONResponse:
        return JSONResponse(
            status_code=exc.status_code,
            content=error_body(exc.message, exc.error_code, **exc.extra),
        )

    @app.exception_handler(RequestValidationError)
    async def validation_handler(_: Request, exc: RequestValidationError) -> JSONResponse:
        # Flatten first error for a readable user-facing message
        details = exc.errors()
        msg = "Validation error"
        if details:
            first = details[0]
            loc = ".".join(str(x) for x in first.get("loc", []) if x != "body")
            msg = f"{loc}: {first.get('msg', msg)}" if loc else str(first.get("msg", msg))
        return JSONResponse(
            status_code=status.HTTP_400_BAD_REQUEST,
            content=error_body(msg, "VALIDATION_ERROR"),
        )

    @app.exception_handler(StarletteHTTPException)
    async def http_exception_handler(_: Request, exc: StarletteHTTPException) -> JSONResponse:
        detail = exc.detail
        if isinstance(detail, dict) and "error_code" in detail:
            return JSONResponse(status_code=exc.status_code, content=detail)
        message = detail if isinstance(detail, str) else "Request failed"
        code = {
            401: "UNAUTHORIZED",
            403: "FORBIDDEN",
            404: "NOT_FOUND",
            429: "TOO_MANY_REQUESTS",
        }.get(exc.status_code, "HTTP_ERROR")
        return JSONResponse(
            status_code=exc.status_code,
            content=error_body(message, code),
        )

    @app.exception_handler(Exception)
    async def unhandled_exception_handler(_: Request, exc: Exception) -> JSONResponse:
        logging.getLogger(__name__).exception("Unhandled error: %s", exc)
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content=error_body("Internal server error", "INTERNAL_ERROR"),
        )
