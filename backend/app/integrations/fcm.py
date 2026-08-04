"""FCM HTTP v1 client (async httpx + google-auth). No firebase-admin."""

from __future__ import annotations

import asyncio
import json
import logging
from pathlib import Path
from typing import Any

import httpx
from google.auth.transport.requests import Request
from google.oauth2 import service_account

from app.core.config import get_settings

logger = logging.getLogger(__name__)

_FCM_SCOPE = "https://www.googleapis.com/auth/firebase.messaging"
_credentials: service_account.Credentials | None = None
_credentials_loaded = False


def _load_credentials() -> service_account.Credentials | None:
    global _credentials, _credentials_loaded
    if _credentials_loaded:
        return _credentials
    _credentials_loaded = True
    settings = get_settings()
    raw = (settings.firebase_credentials_json or "").strip()
    project = (settings.firebase_project_id or "").strip()
    if not raw or not project:
        logger.warning(
            "FCM disabled: FIREBASE_PROJECT_ID / FIREBASE_CREDENTIALS_JSON not set"
        )
        _credentials = None
        return None
    try:
        if raw.startswith("{"):
            info = json.loads(raw)
        else:
            path = Path(raw)
            if not path.is_file():
                logger.warning("FCM credentials file not found: %s", raw)
                _credentials = None
                return None
            info = json.loads(path.read_text(encoding="utf-8"))
        _credentials = service_account.Credentials.from_service_account_info(
            info, scopes=[_FCM_SCOPE]
        )
        return _credentials
    except Exception:
        logger.exception("Failed to load Firebase credentials")
        _credentials = None
        return None


def fcm_configured() -> bool:
    settings = get_settings()
    if not (settings.firebase_project_id or "").strip():
        return False
    return _load_credentials() is not None


async def _access_token() -> str | None:
    creds = _load_credentials()
    if creds is None:
        return None

    def _refresh() -> str:
        if not creds.valid:
            creds.refresh(Request())
        return creds.token

    return await asyncio.to_thread(_refresh)


async def send_fcm_message(
    *,
    token: str,
    title: str,
    body: str,
    data: dict[str, str] | None = None,
    collapse_key: str | None = None,
) -> dict[str, Any]:
    """
    Send one FCM HTTP v1 message.
    Returns {"ok": True} or {"ok": False, "error": "...", "invalid_token": bool}.
    """
    settings = get_settings()
    project = (settings.firebase_project_id or "").strip()
    access = await _access_token()
    if not project or not access:
        logger.warning("FCM send skipped (not configured)")
        return {"ok": False, "error": "not_configured", "invalid_token": False}

    message: dict[str, Any] = {
        "token": token,
        "notification": {"title": title, "body": body},
        "data": {k: str(v) for k, v in (data or {}).items()},
        "android": {
            "priority": "high",
            **({"collapse_key": collapse_key} if collapse_key else {}),
        },
        "apns": {
            "headers": {"apns-collapse-id": collapse_key} if collapse_key else {},
            "payload": {"aps": {"sound": "default"}},
        },
    }
    url = f"https://fcm.googleapis.com/v1/projects/{project}/messages:send"
    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            resp = await client.post(
                url,
                headers={"Authorization": f"Bearer {access}"},
                json={"message": message},
            )
    except Exception as exc:  # noqa: BLE001
        logger.warning("FCM HTTP error: %s", exc)
        return {"ok": False, "error": str(exc), "invalid_token": False}

    if resp.status_code in (200, 201):
        return {"ok": True}

    invalid = False
    err_code = ""
    try:
        payload = resp.json()
        err = payload.get("error") or {}
        err_code = str(err.get("status") or err.get("code") or "")
        details = err.get("details") or []
        for d in details:
            if isinstance(d, dict) and d.get("errorCode") in {
                "UNREGISTERED",
                "INVALID_ARGUMENT",
            }:
                invalid = True
            if isinstance(d, dict) and "UNREGISTERED" in str(d):
                invalid = True
        if err_code in {"NOT_FOUND", "INVALID_ARGUMENT"}:
            invalid = True
        if "UNREGISTERED" in resp.text.upper():
            invalid = True
    except Exception:  # noqa: BLE001
        pass

    logger.warning(
        "FCM send failed status=%s code=%s body=%s",
        resp.status_code,
        err_code,
        resp.text[:300],
    )
    return {
        "ok": False,
        "error": err_code or f"http_{resp.status_code}",
        "invalid_token": invalid,
    }
