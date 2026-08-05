"""Admin ops for number groups: inventory, pattern sim, pricing, sales, bulk."""

from __future__ import annotations

import csv
import io
import json
import math
from datetime import UTC, datetime, timedelta
from decimal import Decimal
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.models.payment import Payment
from app.models.user import AdminUser, NumberAssignment, NumberGroup
from app.services.numbers import (
    SPECIAL_PATTERNS,
    _generate_from_mask,
    _load_groups,
    classify_number,
    ensure_seed_groups,
    matches_pattern,
)


def estimate_pattern_size(pattern: str) -> int | None:
    """Estimate how many 7-digit numbers match a pattern (None if unknown/huge-ish)."""
    p = (pattern or "").strip()
    if not p:
        return 0
    if p == "*******":
        return 10_000_000
    if p in SPECIAL_PATTERNS:
        if p == "sequential_asc":
            return 4
        if p == "sequential_desc":
            return 4
        if p == "palindrome":
            return 10_000
        if p == "mirror":
            return 10_000
        return None
    if len(p) != 7:
        return None
    if any(ch != "*" and not ch.isalpha() for ch in p):
        return None

    # Unique letters each get a distinct digit; * is free 0-9
    letters: list[str] = []
    seen: set[str] = set()
    star_count = 0
    for ch in p:
        if ch == "*":
            star_count += 1
        else:
            u = ch.upper()
            if u not in seen:
                seen.add(u)
                letters.append(u)

    # P(10, k) * 10^stars
    k = len(letters)
    if k > 10:
        return 0
    perm = math.perm(10, k)
    return int(perm * (10**star_count))


def estimate_group_capacity(group: NumberGroup) -> int | None:
    sizes = [estimate_pattern_size(str(p)) for p in (group.patterns or [])]
    known = [s for s in sizes if s is not None]
    if not known:
        return None
    # Overlap between patterns ignored (upper bound)
    return sum(known)


def effective_group_price(
    group: NumberGroup,
    *,
    sold_7d: int = 0,
    fill_pct: float = 0.0,
) -> Decimal:
    """Apply demand multipliers from pricing_rules onto base price."""
    base = Decimal(str(group.price or 0))
    rules = group.pricing_rules if isinstance(group.pricing_rules, dict) else {}
    if not rules.get("enabled"):
        return base.quantize(Decimal("0.01"))

    if rules.get("base_price") is not None:
        try:
            base = Decimal(str(rules["base_price"]))
        except Exception:
            pass

    mult = Decimal("1")
    for th in rules.get("demand_thresholds") or []:
        if not isinstance(th, dict):
            continue
        try:
            m = Decimal(str(th.get("multiplier", 1)))
        except Exception:
            continue
        if "min_sold_7d" in th and sold_7d >= int(th["min_sold_7d"]):
            if m > mult:
                mult = m
        if "min_fill_pct" in th and fill_pct >= float(th["min_fill_pct"]):
            if m > mult:
                mult = m

    try:
        max_m = Decimal(str(rules.get("max_multiplier") or 2))
    except Exception:
        max_m = Decimal("2")
    if mult > max_m:
        mult = max_m
    return (base * mult).quantize(Decimal("0.01"))


def simulate_pattern(pattern: str, *, preview_limit: int = 24) -> dict[str, Any]:
    """Preview numbers for AAAA / ABAB / special patterns."""
    p = (pattern or "").strip()
    samples: list[str] = []
    truncated = False
    try:
        for i, num in enumerate(_generate_from_mask(p)):
            if i >= preview_limit:
                truncated = True
                break
            samples.append(num)
    except Exception:
        samples = []

    size = estimate_pattern_size(p)
    return {
        "pattern": p,
        "is_special": p in SPECIAL_PATTERNS,
        "estimated_size": size,
        "preview": samples,
        "preview_count": len(samples),
        "truncated": truncated,
        "valid": bool(samples) or size == 0,
    }


async def inventory_snapshot(db: AsyncSession) -> dict[str, Any]:
    """Realtime band / bo'sh / reserved per group."""
    await ensure_seed_groups(db)
    now = datetime.now(UTC)
    groups = list(
        (await db.execute(select(NumberGroup).order_by(NumberGroup.priority.desc())))
        .scalars()
        .all()
    )

    assigned_rows = list(
        (
            await db.execute(
                select(NumberAssignment.group_id, func.count())
                .where(NumberAssignment.user_id.is_not(None))
                .group_by(NumberAssignment.group_id)
            )
        ).all()
    )
    reserved_rows = list(
        (
            await db.execute(
                select(NumberAssignment.group_id, func.count())
                .where(
                    NumberAssignment.reserved_until.is_not(None),
                    NumberAssignment.reserved_until > now,
                    NumberAssignment.user_id.is_(None),
                )
                .group_by(NumberAssignment.group_id)
            )
        ).all()
    )
    assigned_map = {int(gid): int(c) for gid, c in assigned_rows if gid is not None}
    reserved_map = {int(gid): int(c) for gid, c in reserved_rows if gid is not None}

    sold_7d_map = await _sold_counts_by_group(db, days=7)

    items = []
    totals = {"assigned": 0, "reserved": 0, "free_est": 0, "capacity_est": 0}
    for g in groups:
        assigned = assigned_map.get(g.id, 0)
        reserved = reserved_map.get(g.id, 0)
        capacity = estimate_group_capacity(g)
        occupied = assigned + reserved
        free = None if capacity is None else max(0, capacity - occupied)
        fill_pct = (
            round(100.0 * occupied / capacity, 1) if capacity and capacity > 0 else 0.0
        )
        sold_7d = sold_7d_map.get(g.id, 0)
        eff = effective_group_price(g, sold_7d=sold_7d, fill_pct=fill_pct)
        items.append(
            {
                "id": g.id,
                "name": g.name,
                "is_active": g.is_active,
                "patterns": list(g.patterns or []),
                "base_price": f"{Decimal(g.price):.2f}",
                "effective_price": f"{eff:.2f}",
                "currency": g.currency,
                "assigned": assigned,
                "reserved": reserved,
                "free_est": free,
                "capacity_est": capacity,
                "fill_pct": fill_pct,
                "sold_7d": sold_7d,
                "pricing_rules": dict(g.pricing_rules or {}),
                "dynamic_pricing": bool((g.pricing_rules or {}).get("enabled")),
            }
        )
        totals["assigned"] += assigned
        totals["reserved"] += reserved
        if free is not None:
            totals["free_est"] += free
        if capacity is not None:
            totals["capacity_est"] += capacity

    return {
        "as_of": now.isoformat(),
        "totals": totals,
        "items": items,
    }


async def _sold_counts_by_group(db: AsyncSession, *, days: int) -> dict[int, int]:
    since = datetime.now(UTC) - timedelta(days=days)
    rows = list(
        (
            await db.execute(
                select(NumberAssignment.group_id, func.count())
                .where(
                    NumberAssignment.purchased_at.is_not(None),
                    NumberAssignment.purchased_at >= since,
                    NumberAssignment.user_id.is_not(None),
                )
                .group_by(NumberAssignment.group_id)
            )
        ).all()
    )
    return {int(gid): int(c) for gid, c in rows if gid is not None}


async def sales_analytics(db: AsyncSession, *, days: int = 90) -> dict[str, Any]:
    """Sold history + top revenue patterns/groups."""
    since = datetime.now(UTC) - timedelta(days=days)
    payments = list(
        (
            await db.execute(
                select(Payment)
                .where(
                    Payment.kind == "number",
                    Payment.status.in_(("paid", "succeeded", "completed")),
                    Payment.paid_at.is_not(None),
                    Payment.paid_at >= since,
                )
                .order_by(Payment.paid_at.desc())
                .limit(500)
            )
        )
        .scalars()
        .all()
    )
    # Fallback status if only "paid" is used
    if not payments:
        payments = list(
            (
                await db.execute(
                    select(Payment)
                    .where(
                        Payment.kind == "number",
                        Payment.status == "paid",
                        Payment.created_at >= since,
                    )
                    .order_by(Payment.created_at.desc())
                    .limit(500)
                )
            )
            .scalars()
            .all()
        )

    groups = await _load_groups(db)
    by_group: dict[int, dict[str, Any]] = {}
    by_pattern: dict[str, dict[str, Any]] = {}
    history: list[dict[str, Any]] = []

    for pay in payments:
        num = (pay.number or "").strip()
        amount = Decimal(str(pay.amount or 0))
        group = classify_number(num, groups) if num and len(num) == 7 else None
        matched_pattern = None
        if group and num:
            for pat in group.patterns or []:
                if matches_pattern(num, str(pat)):
                    matched_pattern = str(pat)
                    break

        history.append(
            {
                "payment_id": pay.id,
                "number": num or None,
                "amount": f"{amount:.2f}",
                "currency": pay.currency,
                "paid_at": pay.paid_at or pay.created_at,
                "user_id": pay.user_id,
                "group_id": group.id if group else None,
                "group_name": group.name if group else None,
                "pattern": matched_pattern,
            }
        )

        if group:
            slot = by_group.setdefault(
                group.id,
                {
                    "group_id": group.id,
                    "group_name": group.name,
                    "sold": 0,
                    "revenue": Decimal("0"),
                },
            )
            slot["sold"] += 1
            slot["revenue"] += amount

        if matched_pattern:
            pslot = by_pattern.setdefault(
                matched_pattern,
                {"pattern": matched_pattern, "sold": 0, "revenue": Decimal("0")},
            )
            pslot["sold"] += 1
            pslot["revenue"] += amount

    top_groups = sorted(
        by_group.values(), key=lambda x: x["revenue"], reverse=True
    )[:15]
    top_patterns = sorted(
        by_pattern.values(), key=lambda x: x["revenue"], reverse=True
    )[:20]

    return {
        "days": days,
        "history": history[:100],
        "top_groups": [
            {**g, "revenue": f"{g['revenue']:.2f}"} for g in top_groups
        ],
        "top_patterns": [
            {**p, "revenue": f"{p['revenue']:.2f}"} for p in top_patterns
        ],
        "total_sold": len(history),
        "total_revenue": f"{sum((Decimal(h['amount']) for h in history), Decimal('0')):.2f}",
    }


async def patch_pricing_rules(
    db: AsyncSession,
    *,
    group_id: int,
    pricing_rules: dict[str, Any],
    admin: AdminUser,
    ip: str | None = None,
) -> dict[str, Any]:
    from app.services.admin_ops import write_audit

    group = await db.get(NumberGroup, group_id)
    if group is None:
        raise AppError(message="Guruh topilmadi", error_code="NOT_FOUND", status_code=404)

    cleaned = _normalize_pricing_rules(pricing_rules)
    before = dict(group.pricing_rules or {})
    group.pricing_rules = cleaned
    await db.flush()
    await write_audit(
        db,
        admin=admin,
        action="number_group.pricing",
        target_type="number_group",
        target_id=group.id,
        before=before,
        after=cleaned,
        ip=ip,
    )
    return serialize_group_rich(group, sold_7d=0, fill_pct=0)


def _normalize_pricing_rules(raw: dict[str, Any]) -> dict[str, Any]:
    enabled = bool(raw.get("enabled"))
    thresholds = []
    for th in raw.get("demand_thresholds") or []:
        if not isinstance(th, dict):
            continue
        item: dict[str, Any] = {}
        if "min_sold_7d" in th:
            item["min_sold_7d"] = max(0, int(th["min_sold_7d"]))
        if "min_fill_pct" in th:
            item["min_fill_pct"] = max(0.0, min(100.0, float(th["min_fill_pct"])))
        item["multiplier"] = max(0.1, min(10.0, float(th.get("multiplier", 1))))
        if "min_sold_7d" in item or "min_fill_pct" in item:
            thresholds.append(item)
    out: dict[str, Any] = {
        "enabled": enabled,
        "demand_thresholds": thresholds,
        "max_multiplier": max(1.0, min(10.0, float(raw.get("max_multiplier") or 2))),
    }
    if raw.get("base_price") is not None:
        out["base_price"] = float(raw["base_price"])
    return out


def serialize_group_rich(
    group: NumberGroup,
    *,
    sold_7d: int = 0,
    fill_pct: float = 0.0,
    assigned: int | None = None,
    reserved: int | None = None,
) -> dict[str, Any]:
    eff = effective_group_price(group, sold_7d=sold_7d, fill_pct=fill_pct)
    return {
        "id": group.id,
        "name": group.name,
        "patterns": list(group.patterns or []),
        "price": f"{Decimal(group.price):.2f}",
        "effective_price": f"{eff:.2f}",
        "currency": group.currency,
        "bonus_plan": group.bonus_plan,
        "bonus_duration_months": group.bonus_duration_months,
        "priority": group.priority,
        "is_active": group.is_active,
        "pricing_rules": dict(group.pricing_rules or {}),
        "capacity_est": estimate_group_capacity(group),
        "assigned": assigned,
        "reserved": reserved,
        "sold_7d": sold_7d,
        "fill_pct": fill_pct,
    }


async def export_groups(
    db: AsyncSession,
    *,
    admin: AdminUser,
    fmt: str = "csv",
    ip: str | None = None,
) -> tuple[str, str, bytes]:
    from app.services.admin_ops import write_audit

    await ensure_seed_groups(db)
    groups = list(
        (await db.execute(select(NumberGroup).order_by(NumberGroup.priority.desc())))
        .scalars()
        .all()
    )
    stamp = datetime.now(UTC).strftime("%Y%m%d-%H%M%S")
    await write_audit(
        db,
        admin=admin,
        action="number_group.export",
        target_type="number_group",
        target_id="bulk",
        meta={"count": len(groups), "format": fmt},
        ip=ip,
    )

    if fmt == "json":
        payload = {
            "exported_at": datetime.now(UTC).isoformat(),
            "items": [serialize_group_rich(g) for g in groups],
        }
        body = json.dumps(payload, ensure_ascii=False, default=str, indent=2).encode("utf-8")
        return f"number-groups-{stamp}.json", "application/json", body

    buf = io.StringIO()
    w = csv.writer(buf)
    w.writerow(
        [
            "name",
            "patterns",
            "price",
            "currency",
            "bonus_plan",
            "bonus_duration_months",
            "priority",
            "is_active",
            "pricing_rules",
        ]
    )
    for g in groups:
        w.writerow(
            [
                g.name,
                "|".join(str(p) for p in (g.patterns or [])),
                f"{Decimal(g.price):.2f}",
                g.currency,
                g.bonus_plan or "",
                g.bonus_duration_months or "",
                g.priority,
                "1" if g.is_active else "0",
                json.dumps(g.pricing_rules or {}, ensure_ascii=False),
            ]
        )
    return f"number-groups-{stamp}.csv", "text/csv", buf.getvalue().encode("utf-8-sig")


async def import_groups(
    db: AsyncSession,
    *,
    admin: AdminUser,
    rows: list[dict[str, Any]],
    upsert: bool = True,
    ip: str | None = None,
) -> dict[str, Any]:
    from app.services.admin_ops import write_audit

    if not rows:
        raise AppError(message="Bo'sh import", error_code="VALIDATION_ERROR", status_code=400)
    if len(rows) > 200:
        raise AppError(message="Max 200 guruh", error_code="VALIDATION_ERROR", status_code=400)

    created = 0
    updated = 0
    errors: list[str] = []

    for i, row in enumerate(rows):
        try:
            name = str(row.get("name") or "").strip()
            if not name:
                raise ValueError("name required")
            patterns_raw = row.get("patterns")
            if isinstance(patterns_raw, str):
                patterns = [p.strip() for p in patterns_raw.replace(",", "|").split("|") if p.strip()]
            elif isinstance(patterns_raw, list):
                patterns = [str(p).strip() for p in patterns_raw if str(p).strip()]
            else:
                patterns = []
            if not patterns:
                raise ValueError("patterns required")
            price = Decimal(str(row.get("price") or 0))
            currency = str(row.get("currency") or "USD")[:8]
            bonus_plan = (str(row.get("bonus_plan")).strip() if row.get("bonus_plan") else None) or None
            bdm = row.get("bonus_duration_months")
            bonus_duration = int(bdm) if bdm not in (None, "") else None
            priority = int(row.get("priority") or 0)
            is_active_raw = row.get("is_active", True)
            is_active = str(is_active_raw).lower() not in ("0", "false", "no", "off")
            rules_raw = row.get("pricing_rules") or {}
            if isinstance(rules_raw, str) and rules_raw.strip():
                rules_raw = json.loads(rules_raw)
            pricing_rules = (
                _normalize_pricing_rules(rules_raw) if isinstance(rules_raw, dict) else {}
            )

            existing = (
                await db.execute(select(NumberGroup).where(NumberGroup.name == name))
            ).scalar_one_or_none()
            if existing is None:
                db.add(
                    NumberGroup(
                        name=name,
                        patterns=patterns,
                        price=price,
                        currency=currency,
                        bonus_plan=bonus_plan,
                        bonus_duration_months=bonus_duration,
                        priority=priority,
                        is_active=is_active,
                        pricing_rules=pricing_rules,
                    )
                )
                created += 1
            elif upsert:
                existing.patterns = patterns
                existing.price = price
                existing.currency = currency
                existing.bonus_plan = bonus_plan
                existing.bonus_duration_months = bonus_duration
                existing.priority = priority
                existing.is_active = is_active
                existing.pricing_rules = pricing_rules
                updated += 1
            else:
                errors.append(f"row {i + 1}: {name} exists")
        except Exception as exc:
            errors.append(f"row {i + 1}: {exc}")

    await db.flush()
    await write_audit(
        db,
        admin=admin,
        action="number_group.import",
        target_type="number_group",
        target_id="bulk",
        meta={"created": created, "updated": updated, "errors": len(errors)},
        ip=ip,
    )
    return {"created": created, "updated": updated, "errors": errors}


async def demand_context_for_groups(
    db: AsyncSession, groups: list[NumberGroup]
) -> dict[int, dict[str, Any]]:
    """Batch sold_7d + fill for effective pricing in catalog."""
    sold_map = await _sold_counts_by_group(db, days=7)
    now = datetime.now(UTC)
    assigned_rows = list(
        (
            await db.execute(
                select(NumberAssignment.group_id, func.count())
                .where(NumberAssignment.user_id.is_not(None))
                .group_by(NumberAssignment.group_id)
            )
        ).all()
    )
    reserved_rows = list(
        (
            await db.execute(
                select(NumberAssignment.group_id, func.count())
                .where(
                    NumberAssignment.reserved_until.is_not(None),
                    NumberAssignment.reserved_until > now,
                    NumberAssignment.user_id.is_(None),
                )
                .group_by(NumberAssignment.group_id)
            )
        ).all()
    )
    assigned_map = {int(g): int(c) for g, c in assigned_rows if g is not None}
    reserved_map = {int(g): int(c) for g, c in reserved_rows if g is not None}
    out: dict[int, dict[str, Any]] = {}
    for g in groups:
        assigned = assigned_map.get(g.id, 0)
        reserved = reserved_map.get(g.id, 0)
        capacity = estimate_group_capacity(g)
        fill = (
            100.0 * (assigned + reserved) / capacity
            if capacity and capacity > 0
            else 0.0
        )
        out[g.id] = {
            "sold_7d": sold_map.get(g.id, 0),
            "fill_pct": fill,
        }
    return out
