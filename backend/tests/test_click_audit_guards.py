"""Click signature hardening + prepare_id / cancelled recovery checks."""

from __future__ import annotations

from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.payments.click import (
    CLICK_OK,
    CLICK_REQUEST_ERROR,
    CLICK_SIGN_FAILED,
    complete_sign,
    handle_complete,
)


@pytest.mark.asyncio
async def test_sign_mismatch_is_rejected(monkeypatch: pytest.MonkeyPatch) -> None:
    from app.core import config as config_mod
    from app.payments.click import handle_prepare

    settings = MagicMock()
    settings.click_secret_key = "secret"
    settings.click_service_id = "456"
    monkeypatch.setattr(config_mod, "get_settings", lambda: settings)
    monkeypatch.setattr("app.payments.click.get_settings", lambda: settings)

    db = AsyncMock()
    out = await handle_prepare(
        db,
        {
            "click_trans_id": "1",
            "service_id": "456",
            "merchant_trans_id": "9",
            "amount": "100.00",
            "action": 0,
            "sign_time": "2026-01-01 00:00:00",
            "sign_string": "deadbeefdeadbeefdeadbeefdeadbeef",
        },
    )
    assert out["error"] == CLICK_SIGN_FAILED


@pytest.mark.asyncio
async def test_complete_recovers_cancelled_after_prepare(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from app.core import config as config_mod

    settings = MagicMock()
    settings.click_secret_key = "test-secret"
    settings.click_service_id = "456"
    monkeypatch.setattr(config_mod, "get_settings", lambda: settings)
    monkeypatch.setattr("app.payments.click.get_settings", lambda: settings)

    payment = SimpleNamespace(
        id=1042,
        user_id=42,
        provider="click",
        status="cancelled",
        amount=Decimal("159900.00"),
        kind="subscription",
        plan="premium",
        billing_cycle="12",
        meta={"click_prepare_id": "1042"},
        raw_payload={},
        provider_transaction_id=None,
    )
    user = SimpleNamespace(id=42, subscription=None, business=None)

    pay_result = MagicMock()
    pay_result.scalar_one_or_none.return_value = payment
    user_result = MagicMock()
    user_result.scalar_one_or_none.return_value = user

    db = AsyncMock()

    async def _execute(stmt):
        # First lock payment, then load user.
        text = str(stmt)
        if "users" in text.lower() or "User" in text:
            return user_result
        return pay_result

    db.execute = AsyncMock(side_effect=_execute)
    db.flush = AsyncMock()

    async def _activate(*_a, **_k):
        return None

    monkeypatch.setattr(
        "app.payments.service.activate_subscription",
        _activate,
    )
    monkeypatch.setattr(
        "app.payments.service.mark_payment_paid",
        AsyncMock(),
    )

    sign = complete_sign(
        click_trans_id="123",
        service_id="456",
        secret_key="test-secret",
        merchant_trans_id="1042",
        merchant_prepare_id="1042",
        amount="159900.00",
        action=1,
        sign_time="2026-07-26 10:00:00",
    )
    out = await handle_complete(
        db,
        {
            "click_trans_id": "123",
            "service_id": "456",
            "merchant_trans_id": "1042",
            "merchant_prepare_id": "1042",
            "amount": "159900.00",
            "action": 1,
            "error": 0,
            "sign_time": "2026-07-26 10:00:00",
            "sign_string": sign,
        },
    )
    assert out["error"] == CLICK_OK


@pytest.mark.asyncio
async def test_complete_rejects_prepare_id_mismatch(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    from app.core import config as config_mod

    settings = MagicMock()
    settings.click_secret_key = "test-secret"
    settings.click_service_id = "456"
    monkeypatch.setattr(config_mod, "get_settings", lambda: settings)
    monkeypatch.setattr("app.payments.click.get_settings", lambda: settings)

    payment = SimpleNamespace(
        id=1042,
        user_id=42,
        provider="click",
        status="pending",
        amount=Decimal("159900.00"),
        kind="subscription",
        plan="premium",
        billing_cycle="12",
        meta={"click_prepare_id": "1042"},
        raw_payload={},
        provider_transaction_id=None,
    )
    result = MagicMock()
    result.scalar_one_or_none.return_value = payment
    db = AsyncMock()
    db.execute = AsyncMock(return_value=result)
    db.flush = AsyncMock()

    sign = complete_sign(
        click_trans_id="123",
        service_id="456",
        secret_key="test-secret",
        merchant_trans_id="1042",
        merchant_prepare_id="9999",
        amount="159900.00",
        action=1,
        sign_time="2026-07-26 10:00:00",
    )
    out = await handle_complete(
        db,
        {
            "click_trans_id": "123",
            "service_id": "456",
            "merchant_trans_id": "1042",
            "merchant_prepare_id": "9999",
            "amount": "159900.00",
            "action": 1,
            "error": 0,
            "sign_time": "2026-07-26 10:00:00",
            "sign_string": sign,
        },
    )
    assert out["error"] == CLICK_REQUEST_ERROR
