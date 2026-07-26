"""Subscription activate: stack same-plan renew vs restart on plan change."""

from __future__ import annotations

from datetime import UTC, datetime, timedelta
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest

from app.services.subscription import activate_paid_subscription


@pytest.mark.asyncio
async def test_same_plan_renew_stacks_remaining_days(monkeypatch: pytest.MonkeyPatch) -> None:
    now = datetime(2026, 7, 1, 12, 0, tzinfo=UTC)
    monkeypatch.setattr(
        "app.services.subscription.datetime",
        SimpleNamespace(now=lambda tz=None: now),
    )

    expires = now + timedelta(days=10)
    sub = SimpleNamespace(
        plan="premium",
        billing_cycle="1",
        started_at=now - timedelta(days=20),
        expires_at=expires,
        is_active=True,
        auto_renew=False,
        source="purchase",
    )
    user = SimpleNamespace(id=1, subscription=sub, business=None)
    db = AsyncMock()
    db.flush = AsyncMock()

    async def _ensure(u, d):
        return sub

    monkeypatch.setattr(
        "app.services.subscription.ensure_basic_subscription",
        _ensure,
    )

    await activate_paid_subscription(db, user, plan="premium", billing_cycle="monthly")

    assert sub.expires_at == expires + timedelta(days=30)
    assert sub.started_at == now - timedelta(days=20)  # unchanged on stack
    assert sub.plan == "premium"


@pytest.mark.asyncio
async def test_plan_change_restarts_from_now(monkeypatch: pytest.MonkeyPatch) -> None:
    now = datetime(2026, 7, 1, 12, 0, tzinfo=UTC)
    monkeypatch.setattr(
        "app.services.subscription.datetime",
        SimpleNamespace(now=lambda tz=None: now),
    )

    sub = SimpleNamespace(
        plan="premium",
        billing_cycle="1",
        started_at=now - timedelta(days=5),
        expires_at=now + timedelta(days=25),
        is_active=True,
        auto_renew=False,
        source="purchase",
    )
    user = SimpleNamespace(id=1, subscription=sub, business=object())
    db = AsyncMock()
    db.flush = AsyncMock()

    async def _ensure(u, d):
        return sub

    monkeypatch.setattr(
        "app.services.subscription.ensure_basic_subscription",
        _ensure,
    )
    monkeypatch.setattr(
        "app.services.subscription._ensure_business_profile",
        AsyncMock(),
    )

    await activate_paid_subscription(
        db, user, plan="business", billing_cycle="yearly", auto_renew=True
    )

    assert sub.plan == "business"
    assert sub.started_at == now
    assert sub.expires_at == now + timedelta(days=360)  # 12 * 30
    assert sub.auto_renew is True
