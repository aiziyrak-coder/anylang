"""Paddle webhook HMAC-SHA256 signature verification."""

from __future__ import annotations

import hashlib
import hmac
import json
import time

import pytest

from app.core.errors import AppError
from app.payments.paddle import handle_webhook, verify_paddle_signature


def _sign(body: bytes, secret: str, ts: int | None = None) -> str:
    ts_val = int(time.time()) if ts is None else ts
    digest = hmac.new(
        secret.encode("utf-8"),
        f"{ts_val}:".encode("utf-8") + body,
        hashlib.sha256,
    ).hexdigest()
    return f"ts={ts_val};h1={digest}"


def test_paddle_signature_valid() -> None:
    body = b'{"event_type":"transaction.completed","data":{}}'
    secret = "pdl_ntfset_test_secret"
    header = _sign(body, secret)
    assert verify_paddle_signature(
        raw_body=body,
        signature_header=header,
        secret=secret,
    )


def test_paddle_signature_invalid_rejects() -> None:
    body = b'{"event_type":"transaction.completed"}'
    secret = "pdl_ntfset_test_secret"
    header = _sign(body, secret)
    assert not verify_paddle_signature(
        raw_body=body,
        signature_header=header,
        secret="wrong-secret",
    )


def test_paddle_signature_stale_timestamp_rejects() -> None:
    body = b"{}"
    secret = "secret"
    header = _sign(body, secret, ts=int(time.time()) - 10_000)
    assert not verify_paddle_signature(
        raw_body=body,
        signature_header=header,
        secret=secret,
        max_age_seconds=300,
    )


@pytest.mark.asyncio
async def test_paddle_webhook_rejects_bad_signature(monkeypatch: pytest.MonkeyPatch) -> None:
    from app.core import config as config_mod

    settings = type("S", (), {"paddle_webhook_secret": "real-secret"})()
    monkeypatch.setattr(config_mod, "get_settings", lambda: settings)
    monkeypatch.setattr("app.payments.paddle.get_settings", lambda: settings)

    body = json.dumps({"event_type": "transaction.completed", "data": {}}).encode()
    with pytest.raises(AppError) as exc:
        await handle_webhook(
            AsyncDummy(),
            raw_body=body,
            signature_header=_sign(body, "wrong"),
            event={"event_type": "transaction.completed", "data": {}},
        )
    assert exc.value.error_code == "SIGNATURE_INVALID"


class AsyncDummy:
    pass
