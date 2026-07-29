"""Click + Paddle webhook routes (no JWT — signature auth only)."""

from __future__ import annotations

import json
import logging
from typing import Any
from urllib.parse import parse_qs

from fastapi import APIRouter, Form, Request
from fastapi.responses import JSONResponse

from app.core.deps import DbSession
from app.core.errors import AppError
from app.payments import click as click_mod
from app.payments import multicard as multicard_mod
from app.payments import paddle as paddle_mod

router = APIRouter()
logger = logging.getLogger(__name__)


async def _parse_click_payload(request: Request) -> dict[str, Any]:
    """Click may send form-urlencoded, multipart, or JSON."""
    content_type = (request.headers.get("content-type") or "").lower()
    if "application/json" in content_type:
        try:
            data = await request.json()
            return data if isinstance(data, dict) else {}
        except Exception:
            return {}

    # Prefer Starlette form parser (urlencoded / multipart).
    try:
        form = await request.form()
        if form:
            return {k: form.get(k) for k in form.keys()}
    except Exception:
        pass

    # Fallback: raw body as query-string (some Click clients omit Content-Type).
    try:
        raw = await request.body()
        if raw:
            parsed = parse_qs(raw.decode("utf-8", errors="replace"), keep_blank_values=True)
            return {k: (v[0] if v else "") for k, v in parsed.items()}
    except Exception:
        pass
    return {}


def _client_ip(request: Request) -> str:
    forwarded = (request.headers.get("x-forwarded-for") or "").split(",")[0].strip()
    if forwarded:
        return forwarded
    if request.client:
        return request.client.host
    return ""


async def _handle_prepare(request: Request, db: DbSession) -> JSONResponse:
    payload = await _parse_click_payload(request)
    logger.info(
        "Click PREPARE ip=%s keys=%s merchant_trans_id=%s amount=%s service_id=%s",
        _client_ip(request),
        sorted(payload.keys()),
        payload.get("merchant_trans_id"),
        payload.get("amount"),
        payload.get("service_id"),
    )
    result = await click_mod.handle_prepare(db, payload)
    await db.commit()
    logger.info(
        "Click PREPARE result error=%s merchant_trans_id=%s",
        result.get("error"),
        result.get("merchant_trans_id"),
    )
    return JSONResponse(result)


async def _handle_complete(request: Request, db: DbSession) -> JSONResponse:
    payload = await _parse_click_payload(request)
    logger.info(
        "Click COMPLETE ip=%s keys=%s merchant_trans_id=%s amount=%s error=%s",
        _client_ip(request),
        sorted(payload.keys()),
        payload.get("merchant_trans_id"),
        payload.get("amount"),
        payload.get("error"),
    )
    result = await click_mod.handle_complete(db, payload)
    await db.commit()
    logger.info(
        "Click COMPLETE result error=%s merchant_trans_id=%s",
        result.get("error"),
        result.get("merchant_trans_id"),
    )
    return JSONResponse(result)


# With and without trailing slash — Click must not hit a 307 redirect on POST.
@router.post("/click/prepare")
@router.post("/click/prepare/")
async def click_prepare(request: Request, db: DbSession) -> JSONResponse:
    return await _handle_prepare(request, db)


@router.post("/click/complete")
@router.post("/click/complete/")
async def click_complete(request: Request, db: DbSession) -> JSONResponse:
    return await _handle_complete(request, db)


# Optional form-only aliases (some Click setups POST as form fields).
@router.post("/click/prepare-form")
@router.post("/click/prepare-form/")
async def click_prepare_form(
    db: DbSession,
    click_trans_id: str = Form(...),
    service_id: str = Form(...),
    merchant_trans_id: str = Form(...),
    amount: str = Form(...),
    action: int = Form(0),
    sign_time: str = Form(...),
    sign_string: str = Form(...),
) -> JSONResponse:
    payload = {
        "click_trans_id": click_trans_id,
        "service_id": service_id,
        "merchant_trans_id": merchant_trans_id,
        "amount": amount,
        "action": action,
        "sign_time": sign_time,
        "sign_string": sign_string,
    }
    result = await click_mod.handle_prepare(db, payload)
    await db.commit()
    return JSONResponse(result)


@router.post("/click/complete-form")
@router.post("/click/complete-form/")
async def click_complete_form(
    db: DbSession,
    click_trans_id: str = Form(...),
    service_id: str = Form(...),
    merchant_trans_id: str = Form(...),
    merchant_prepare_id: str = Form(...),
    amount: str = Form(...),
    action: int = Form(1),
    sign_time: str = Form(...),
    sign_string: str = Form(...),
    error: int = Form(0),
    error_note: str = Form(""),
) -> JSONResponse:
    payload = {
        "click_trans_id": click_trans_id,
        "service_id": service_id,
        "merchant_trans_id": merchant_trans_id,
        "merchant_prepare_id": merchant_prepare_id,
        "amount": amount,
        "action": action,
        "sign_time": sign_time,
        "sign_string": sign_string,
        "error": error,
        "error_note": error_note,
    }
    result = await click_mod.handle_complete(db, payload)
    await db.commit()
    return JSONResponse(result)


@router.post("/paddle/webhook")
async def paddle_webhook(request: Request, db: DbSession) -> dict[str, str]:
    raw = await request.body()
    signature = request.headers.get("Paddle-Signature") or request.headers.get(
        "paddle-signature", ""
    )
    try:
        event = json.loads(raw.decode("utf-8"))
    except Exception as exc:
        raise AppError(
            message="Paddle payload noto'g'ri",
            error_code="PAYMENT_INVALID",
            status_code=400,
        ) from exc
    if not isinstance(event, dict):
        raise AppError(
            message="Paddle payload noto'g'ri",
            error_code="PAYMENT_INVALID",
            status_code=400,
        )
    result = await paddle_mod.handle_webhook(
        db,
        raw_body=raw,
        signature_header=signature,
        event=event,
    )
    await db.commit()
    return result


@router.post("/multicard/callback")
async def multicard_callback(request: Request, db: DbSession) -> JSONResponse:
    """Multicard / Rahmat invoice webhook (no JWT — sign or IP)."""
    content_type = (request.headers.get("content-type") or "").lower()
    payload: dict[str, Any] = {}
    if "application/json" in content_type:
        try:
            data = await request.json()
            payload = data if isinstance(data, dict) else {}
        except Exception:
            payload = {}
    else:
        form = await request.form()
        payload = {k: form.get(k) for k in form.keys()}
    # Nested payment object sometimes wraps fields.
    if isinstance(payload.get("data"), dict) and "uuid" not in payload:
        payload = {**payload, **payload["data"]}
    result = await multicard_mod.handle_callback(db, payload)
    await db.commit()
    return JSONResponse(result)
