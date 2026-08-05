"""Audit journal: filters, diff, export, anomaly alerts, user timeline."""

from __future__ import annotations

import csv
import hashlib
import io
import json
from datetime import UTC, date, datetime, timedelta
from typing import Any

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import AppError
from app.core.pagination import normalize_page
from app.models.user import AdminActivityAlert, AdminAuditLog, AdminUser
from app.services.admin_list import apply_sort, audit_action_filter

SENSITIVE_ACTIONS = frozenset(
    {
        "user.soft_delete",
        "user.restore",
        "user.ban",
        "users.bulk",
        "user.export",
        "chat.export",
        "chat.view_messages",
        "restore.decide",
        "verification.decide",
        "admin.reset_password",
        "user.reset_password",
        "user.revoke_sessions",
        "audit.export",
    }
)

VOLUME_THRESHOLD = 40  # actions / hour / admin
SENSITIVE_BURST = 5  # sensitive in 15 min
MULTI_IP_THRESHOLD = 3


def _json_canon(value: Any) -> str:
    return json.dumps(value, sort_keys=True, default=str, separators=(",", ":"))


def compute_content_hash(
    *,
    action: str,
    target_type: str | None,
    target_id: str | None,
    meta: dict[str, Any],
    before_state: dict[str, Any] | None,
    after_state: dict[str, Any] | None,
    ip: str | None,
    actor_admin_id: int | None,
) -> str:
    payload = {
        "action": action,
        "target_type": target_type,
        "target_id": target_id,
        "meta": meta or {},
        "before_state": before_state,
        "after_state": after_state,
        "ip": ip,
        "actor_admin_id": actor_admin_id,
    }
    return hashlib.sha256(_json_canon(payload).encode("utf-8")).hexdigest()


def build_diff(
    before: dict[str, Any] | None,
    after: dict[str, Any] | None,
    meta: dict[str, Any] | None = None,
) -> list[dict[str, Any]]:
    """Field-level old → new pairs for UI."""
    b = dict(before or {})
    a = dict(after or {})
    meta = meta if isinstance(meta, dict) else {}

    if not b and not a:
        # Legacy: nested before/after in meta
        if isinstance(meta.get("before"), dict) or isinstance(meta.get("after"), dict):
            b = dict(meta.get("before") or {})
            a = dict(meta.get("after") or {})
        elif meta:
            # Flat meta treated as "after" snapshot
            skip = {"reason", "note", "source", "ip"}
            a = {k: v for k, v in meta.items() if k not in skip and not k.startswith("_")}
            b = {}

    keys = sorted(set(b) | set(a))
    rows: list[dict[str, Any]] = []
    for key in keys:
        old_v = b.get(key, None) if key in b else None
        new_v = a.get(key, None) if key in a else None
        if key not in b:
            old_v = None
        if key not in a:
            new_v = None
        if _json_canon(old_v) == _json_canon(new_v):
            continue
        rows.append({"field": key, "before": old_v, "after": new_v})
    return rows


def verify_integrity(row: AdminAuditLog) -> bool:
    if not row.content_hash:
        # Legacy rows: still "immutable" at DB level; badge = legacy
        return True
    expected = compute_content_hash(
        action=row.action,
        target_type=row.target_type,
        target_id=row.target_id,
        meta=dict(row.meta or {}),
        before_state=dict(row.before_state) if row.before_state else None,
        after_state=dict(row.after_state) if row.after_state else None,
        ip=row.ip,
        actor_admin_id=row.actor_admin_id,
    )
    return expected == row.content_hash


def serialize_log(
    row: AdminAuditLog,
    *,
    actor: AdminUser | None = None,
) -> dict[str, Any]:
    meta = dict(row.meta or {})
    before = dict(row.before_state) if row.before_state else None
    after = dict(row.after_state) if row.after_state else None
    diff = build_diff(before, after, meta)
    intact = verify_integrity(row)
    return {
        "id": row.id,
        "actor_admin_id": row.actor_admin_id,
        "actor_email": actor.email if actor else None,
        "actor_name": actor.full_name if actor else None,
        "action": row.action,
        "target_type": row.target_type,
        "target_id": row.target_id,
        "meta": meta,
        "before_state": before,
        "after_state": after,
        "diff": diff,
        "ip": row.ip,
        "created_at": row.created_at,
        "content_hash": row.content_hash,
        "immutable": True,
        "integrity_ok": intact,
        "integrity_badge": "verified" if (row.content_hash and intact) else (
            "legacy" if not row.content_hash else "tampered"
        ),
    }


async def list_audit_logs(
    db: AsyncSession,
    *,
    action: str | None = None,
    actor_admin_id: int | None = None,
    target_type: str | None = None,
    target_id: str | None = None,
    ip: str | None = None,
    date_from: date | None = None,
    date_to: date | None = None,
    page: int | None = None,
    limit: int | None = None,
    sort: str | None = None,
    order: str | None = None,
) -> dict[str, Any]:
    params = normalize_page(page, limit, default_size=50, max_size=100)
    query = select(AdminAuditLog, AdminUser).outerjoin(
        AdminUser, AdminUser.id == AdminAuditLog.actor_admin_id
    )
    if action and action.strip():
        query = query.where(audit_action_filter(action, AdminAuditLog.action))
    if actor_admin_id is not None:
        query = query.where(AdminAuditLog.actor_admin_id == actor_admin_id)
    if target_type and target_type.strip():
        query = query.where(AdminAuditLog.target_type == target_type.strip())
    if target_id and target_id.strip():
        query = query.where(AdminAuditLog.target_id == target_id.strip())
    if ip and ip.strip():
        query = query.where(AdminAuditLog.ip.ilike(f"%{ip.strip()}%"))
    if date_from is not None:
        start = datetime(date_from.year, date_from.month, date_from.day, tzinfo=UTC)
        query = query.where(AdminAuditLog.created_at >= start)
    if date_to is not None:
        end = datetime(date_to.year, date_to.month, date_to.day, tzinfo=UTC) + timedelta(days=1)
        query = query.where(AdminAuditLog.created_at < end)

    count_q = select(func.count()).select_from(query.order_by(None).subquery())
    total = int((await db.execute(count_q)).scalar() or 0)

    order_by = apply_sort(
        {
            "id": AdminAuditLog.id,
            "created_at": AdminAuditLog.created_at,
            "action": AdminAuditLog.action,
        },
        sort=sort,
        order=order,
        default="id",
    )
    rows = list(
        (
            await db.execute(
                query.order_by(order_by).offset(params.offset).limit(params.page_size)
            )
        ).all()
    )
    items = [serialize_log(log, actor=admin) for log, admin in rows]
    return {
        "items": items,
        "page": params.page,
        "limit": params.page_size,
        "total": total,
        "has_more": params.offset + len(items) < total,
        "immutable": True,
    }


async def list_audit_actors(db: AsyncSession) -> dict[str, Any]:
    rows = list(
        (
            await db.execute(
                select(AdminUser).where(AdminUser.is_active.is_(True)).order_by(AdminUser.id)
            )
        )
        .scalars()
        .all()
    )
    return {
        "items": [
            {"id": a.id, "email": a.email, "full_name": a.full_name, "role": a.role}
            for a in rows
        ]
    }


async def export_audit_logs(
    db: AsyncSession,
    *,
    admin: AdminUser,
    action: str | None = None,
    actor_admin_id: int | None = None,
    target_type: str | None = None,
    target_id: str | None = None,
    ip: str | None = None,
    date_from: date | None = None,
    date_to: date | None = None,
    fmt: str = "csv",
    ip_addr: str | None = None,
) -> tuple[str, str, bytes]:
    from app.services.admin_ops import write_audit

    data = await list_audit_logs(
        db,
        action=action,
        actor_admin_id=actor_admin_id,
        target_type=target_type,
        target_id=target_id,
        ip=ip,
        date_from=date_from,
        date_to=date_to,
        page=1,
        limit=5000,
        sort="created_at",
        order="desc",
    )
    items = data["items"]
    stamp = datetime.now(UTC).strftime("%Y%m%d-%H%M%S")

    await write_audit(
        db,
        admin=admin,
        action="audit.export",
        target_type="audit",
        target_id="bulk",
        meta={"count": len(items), "format": fmt, "filters": {
            "action": action,
            "actor_admin_id": actor_admin_id,
            "target_type": target_type,
            "target_id": target_id,
            "ip": ip,
            "date_from": str(date_from) if date_from else None,
            "date_to": str(date_to) if date_to else None,
        }},
        ip=ip_addr,
    )

    if fmt == "json":
        payload = {
            "exported_at": datetime.now(UTC).isoformat(),
            "immutable": True,
            "count": len(items),
            "items": items,
        }
        body = json.dumps(payload, ensure_ascii=False, default=str, indent=2).encode("utf-8")
        return f"audit-export-{stamp}.json", "application/json", body

    buf = io.StringIO()
    writer = csv.writer(buf)
    writer.writerow(
        [
            "id",
            "created_at",
            "actor_admin_id",
            "actor_email",
            "action",
            "target_type",
            "target_id",
            "ip",
            "diff",
            "meta",
            "content_hash",
            "integrity_badge",
        ]
    )
    for row in items:
        writer.writerow(
            [
                row["id"],
                row["created_at"],
                row["actor_admin_id"],
                row["actor_email"] or "",
                row["action"],
                row["target_type"] or "",
                row["target_id"] or "",
                row["ip"] or "",
                _json_canon(row["diff"]),
                _json_canon(row["meta"]),
                row["content_hash"] or "",
                row["integrity_badge"],
            ]
        )
    return (
        f"audit-export-{stamp}.csv",
        "text/csv",
        buf.getvalue().encode("utf-8-sig"),
    )


async def user_change_timeline(
    db: AsyncSession,
    *,
    user_id: int,
    limit: int = 50,
) -> list[dict[str, Any]]:
    """What changed on a user card — audit timeline."""
    uid = str(user_id)
    rows = list(
        (
            await db.execute(
                select(AdminAuditLog, AdminUser)
                .outerjoin(AdminUser, AdminUser.id == AdminAuditLog.actor_admin_id)
                .where(
                    AdminAuditLog.target_type == "user",
                    AdminAuditLog.target_id == uid,
                )
                .order_by(AdminAuditLog.created_at.desc())
                .limit(limit)
            )
        ).all()
    )
    out: list[dict[str, Any]] = []
    for log, actor in rows:
        ser = serialize_log(log, actor=actor)
        summary = _timeline_summary(ser)
        out.append(
            {
                "id": ser["id"],
                "at": ser["created_at"],
                "action": ser["action"],
                "actor_name": ser["actor_name"] or ser["actor_email"] or f"#{ser['actor_admin_id']}",
                "ip": ser["ip"],
                "diff": ser["diff"],
                "summary": summary,
                "integrity_badge": ser["integrity_badge"],
            }
        )
    return out


def _timeline_summary(ser: dict[str, Any]) -> str:
    diff = ser.get("diff") or []
    if diff:
        parts = []
        for d in diff[:4]:
            parts.append(f"{d['field']}: {d['before']!r} → {d['after']!r}")
        more = f" (+{len(diff) - 4})" if len(diff) > 4 else ""
        return "; ".join(parts) + more
    meta = ser.get("meta") or {}
    if meta:
        keys = [f"{k}={v}" for k, v in list(meta.items())[:4]]
        return ", ".join(keys)
    return ser.get("action") or ""


async def scan_anomalous_activity(db: AsyncSession) -> int:
    """Detect anomalous admin patterns and open alerts (deduped)."""
    now = datetime.now(UTC)
    created = 0

    # 1) Volume spike per admin (last hour)
    hour_ago = now - timedelta(hours=1)
    volume_rows = list(
        (
            await db.execute(
                select(
                    AdminAuditLog.actor_admin_id,
                    func.count(AdminAuditLog.id),
                    func.array_agg(AdminAuditLog.id),
                )
                .where(
                    AdminAuditLog.created_at >= hour_ago,
                    AdminAuditLog.actor_admin_id.is_not(None),
                )
                .group_by(AdminAuditLog.actor_admin_id)
                .having(func.count(AdminAuditLog.id) >= VOLUME_THRESHOLD)
            )
        ).all()
    )
    for admin_id, count, ids in volume_rows:
        created += await _maybe_alert(
            db,
            alert_type="volume_spike",
            severity="high",
            actor_admin_id=int(admin_id),
            title=f"Admin #{admin_id}: {count} amal / soat",
            detail={"count": int(count), "window_hours": 1, "threshold": VOLUME_THRESHOLD},
            sample_log_ids=list(ids or [])[:20],
            dedupe_hours=2,
        )

    # 2) Sensitive burst (15 min)
    burst_ago = now - timedelta(minutes=15)
    burst_rows = list(
        (
            await db.execute(
                select(
                    AdminAuditLog.actor_admin_id,
                    func.count(AdminAuditLog.id),
                    func.array_agg(AdminAuditLog.id),
                )
                .where(
                    AdminAuditLog.created_at >= burst_ago,
                    AdminAuditLog.actor_admin_id.is_not(None),
                    AdminAuditLog.action.in_(list(SENSITIVE_ACTIONS)),
                )
                .group_by(AdminAuditLog.actor_admin_id)
                .having(func.count(AdminAuditLog.id) >= SENSITIVE_BURST)
            )
        ).all()
    )
    for admin_id, count, ids in burst_rows:
        created += await _maybe_alert(
            db,
            alert_type="sensitive_burst",
            severity="critical",
            actor_admin_id=int(admin_id),
            title=f"Admin #{admin_id}: sezgir amallar ({count}/15daq)",
            detail={"count": int(count), "window_minutes": 15, "threshold": SENSITIVE_BURST},
            sample_log_ids=list(ids or [])[:20],
            dedupe_hours=1,
        )

    # 3) Multi-IP same admin
    ip_rows = list(
        (
            await db.execute(
                select(
                    AdminAuditLog.actor_admin_id,
                    func.count(func.distinct(AdminAuditLog.ip)),
                    func.array_agg(func.distinct(AdminAuditLog.ip)),
                )
                .where(
                    AdminAuditLog.created_at >= hour_ago,
                    AdminAuditLog.actor_admin_id.is_not(None),
                    AdminAuditLog.ip.is_not(None),
                )
                .group_by(AdminAuditLog.actor_admin_id)
                .having(func.count(func.distinct(AdminAuditLog.ip)) >= MULTI_IP_THRESHOLD)
            )
        ).all()
    )
    for admin_id, ip_count, ips in ip_rows:
        created += await _maybe_alert(
            db,
            alert_type="multi_ip",
            severity="high",
            actor_admin_id=int(admin_id),
            title=f"Admin #{admin_id}: {ip_count} turli IP / soat",
            detail={"ip_count": int(ip_count), "ips": list(ips or [])[:10]},
            sample_log_ids=[],
            dedupe_hours=4,
        )

    # 4) Off-hours sensitive (last 2h, hour in 22–05 UTC)
    off_ago = now - timedelta(hours=2)
    off_logs = list(
        (
            await db.execute(
                select(AdminAuditLog)
                .where(
                    AdminAuditLog.created_at >= off_ago,
                    AdminAuditLog.action.in_(list(SENSITIVE_ACTIONS)),
                )
                .order_by(AdminAuditLog.created_at.desc())
                .limit(100)
            )
        )
        .scalars()
        .all()
    )
    by_admin: dict[int, list[AdminAuditLog]] = {}
    for log in off_logs:
        if log.actor_admin_id is None or log.created_at is None:
            continue
        hour = log.created_at.astimezone(UTC).hour
        if not (hour >= 22 or hour < 5):
            continue
        by_admin.setdefault(int(log.actor_admin_id), []).append(log)
    for admin_id, logs in by_admin.items():
        created += await _maybe_alert(
            db,
            alert_type="off_hours",
            severity="medium",
            actor_admin_id=admin_id,
            title=f"Admin #{admin_id}: tungi sezgir amal ({len(logs)})",
            detail={"count": len(logs), "utc_window": "22:00–05:00"},
            sample_log_ids=[l.id for l in logs[:20]],
            dedupe_hours=6,
        )

    await db.flush()
    return created


async def _maybe_alert(
    db: AsyncSession,
    *,
    alert_type: str,
    severity: str,
    actor_admin_id: int,
    title: str,
    detail: dict[str, Any],
    sample_log_ids: list[int],
    dedupe_hours: int,
) -> int:
    since = datetime.now(UTC) - timedelta(hours=dedupe_hours)
    existing = (
        await db.execute(
            select(AdminActivityAlert.id)
            .where(
                AdminActivityAlert.alert_type == alert_type,
                AdminActivityAlert.actor_admin_id == actor_admin_id,
                AdminActivityAlert.status == "open",
                AdminActivityAlert.created_at >= since,
            )
            .limit(1)
        )
    ).scalar_one_or_none()
    if existing is not None:
        return 0
    db.add(
        AdminActivityAlert(
            alert_type=alert_type,
            severity=severity,
            actor_admin_id=actor_admin_id,
            title=title[:255],
            detail=detail,
            sample_log_ids=[int(x) for x in sample_log_ids if x is not None][:30],
            status="open",
        )
    )
    return 1


async def list_activity_alerts(
    db: AsyncSession,
    *,
    status: str | None = "open",
    page: int | None = None,
    limit: int | None = None,
) -> dict[str, Any]:
    params = normalize_page(page, limit, default_size=30, max_size=100)
    query = select(AdminActivityAlert, AdminUser).outerjoin(
        AdminUser, AdminUser.id == AdminActivityAlert.actor_admin_id
    )
    if status:
        query = query.where(AdminActivityAlert.status == status)
    total = int(
        (await db.execute(select(func.count()).select_from(query.order_by(None).subquery()))).scalar()
        or 0
    )
    rows = list(
        (
            await db.execute(
                query.order_by(AdminActivityAlert.created_at.desc())
                .offset(params.offset)
                .limit(params.page_size)
            )
        ).all()
    )
    items = []
    for alert, actor in rows:
        items.append(
            {
                "id": alert.id,
                "alert_type": alert.alert_type,
                "severity": alert.severity,
                "actor_admin_id": alert.actor_admin_id,
                "actor_email": actor.email if actor else None,
                "actor_name": actor.full_name if actor else None,
                "title": alert.title,
                "detail": dict(alert.detail or {}),
                "sample_log_ids": list(alert.sample_log_ids or []),
                "status": alert.status,
                "created_at": alert.created_at,
                "acked_at": alert.acked_at,
            }
        )
    return {
        "items": items,
        "page": params.page,
        "limit": params.page_size,
        "total": total,
        "has_more": params.offset + len(items) < total,
        "open_count": total if status == "open" else None,
    }


async def ack_activity_alert(
    db: AsyncSession,
    *,
    alert_id: int,
    admin: AdminUser,
) -> dict[str, Any]:
    alert = await db.get(AdminActivityAlert, alert_id)
    if alert is None:
        raise AppError(message="Alert not found", error_code="NOT_FOUND", status_code=404)
    alert.status = "acked"
    alert.acked_at = datetime.now(UTC)
    alert.acked_by_admin_id = admin.id
    await db.flush()
    return {"id": alert.id, "status": alert.status}
