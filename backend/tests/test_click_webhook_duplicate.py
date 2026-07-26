"""Click Prepare/Complete signature + duplicate Complete idempotency."""

from __future__ import annotations

from decimal import Decimal
from types import SimpleNamespace
from unittest.mock import AsyncMock, MagicMock

import pytest

from app.payments.click import (
    CLICK_OK,
    complete_sign,
    handle_complete,
    prepare_sign,
)


def test_prepare_sign_matches_official_formula() -> None:
    expected = prepare_sign(
        click_trans_id="123",
        service_id="456",
        secret_key="secret",
        merchant_trans_id="1042",
        amount="159900.00",
        action=0,
        sign_time="2026-07-26 10:00:00",
    )
    # Recompute independently.
    import hashlib

    raw = "123456secret1042159900.0002026-07-26 10:00:00"
    assert expected == hashlib.md5(raw.encode()).hexdigest()


def test_complete_sign_includes_merchant_prepare_id() -> None:
    import hashlib

    expected = complete_sign(
        click_trans_id="123",
        service_id="456",
        secret_key="secret",
        merchant_trans_id="1042",
        merchant_prepare_id="1042",
        amount="159900.00",
        action=1,
        sign_time="2026-07-26 10:00:00",
    )
    raw = "123456secret10421042159900.0012026-07-26 10:00:00"
    assert expected == hashlib.md5(raw.encode()).hexdigest()


@pytest.mark.asyncio
async def test_click_complete_duplicate_is_idempotent(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("CLICK_SECRET_KEY", "test-secret")
    # Force settings reload path: patch get_settings used inside handle_complete.
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
        status="paid",
        amount=Decimal("159900.00"),
        kind="subscription",
        plan="premium",
        billing_cycle="12",
        meta={"click_prepare_id": "1042"},
        raw_payload={},
        provider_transaction_id="123",
    )

    result_mock = MagicMock()
    result_mock.scalar_one_or_none.return_value = payment

    db = AsyncMock()
    db.execute = AsyncMock(return_value=result_mock)
    db.flush = AsyncMock()

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
    payload = {
        "click_trans_id": "123",
        "service_id": "456",
        "merchant_trans_id": "1042",
        "merchant_prepare_id": "1042",
        "amount": "159900.00",
        "action": 1,
        "error": 0,
        "sign_time": "2026-07-26 10:00:00",
        "sign_string": sign,
    }

    first = await handle_complete(db, payload)
    second = await handle_complete(db, payload)

    assert first["error"] == CLICK_OK
    assert second["error"] == CLICK_OK
    assert first["merchant_confirm_id"] == "1042"
    assert second["merchant_confirm_id"] == "1042"
