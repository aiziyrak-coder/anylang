"""Admin list helpers: sort whitelist + smart search predicates."""

from __future__ import annotations

from typing import Any

from sqlalchemy import ColumnElement, UnaryExpression, asc, desc, or_


def normalize_order(order: str | None, *, default: str = "desc") -> str:
    value = (order or default).strip().lower()
    return "asc" if value == "asc" else "desc"


def apply_sort(
    columns: dict[str, Any],
    *,
    sort: str | None,
    order: str | None,
    default: str,
) -> UnaryExpression[Any]:
    """Return ORDER BY expression from a whitelist map of column name → SA column."""
    key = (sort or default).strip()
    col = columns.get(key) or columns[default]
    direction = normalize_order(order)
    return asc(col) if direction == "asc" else desc(col)


def smart_user_search(
    term: str,
    *,
    number_col: Any,
    email_col: Any,
    name_col: Any,
) -> ColumnElement[bool]:
    """Smart path: 7-digit → exact number; @ → email exact/prefix; else ILIKE."""
    raw = term.strip()
    compact = raw.replace(" ", "").replace("-", "")
    if compact.isdigit() and len(compact) == 7:
        return number_col == compact
    if compact.isdigit() and 1 <= len(compact) < 7:
        return number_col.ilike(f"{compact}%")
    if "@" in raw:
        lower = raw.lower()
        local, _, domain = lower.partition("@")
        if local and domain and "." in domain and not domain.endswith("."):
            return or_(email_col == lower, email_col.ilike(f"{lower}%"))
        return email_col.ilike(f"{lower}%")
    pattern = f"%{raw}%"
    return or_(
        name_col.ilike(pattern),
        email_col.ilike(pattern),
        number_col.ilike(pattern),
    )


def smart_text_search(term: str, *columns: Any) -> ColumnElement[bool]:
    raw = term.strip()
    if "@" in raw:
        lower = raw.lower()
        return or_(*[c.ilike(f"{lower}%") for c in columns])
    pattern = f"%{raw}%"
    return or_(*[c.ilike(pattern) for c in columns])


def audit_action_filter(action: str, action_col: Any) -> ColumnElement[bool]:
    raw = action.strip()
    known_exact = {
        "chat.list",
        "chat.view_messages",
        "chat.export",
        "user.ban",
        "user.unban",
        "user.soft_delete",
        "user.restore",
        "number.assign",
        "verification.decide",
        "restore.decide",
        "subscription.patch",
        "product.archive",
        "product.pin",
    }
    if raw in known_exact:
        return action_col == raw
    if "." in raw and " " not in raw and "%" not in raw:
        return action_col.ilike(f"{raw}%")
    return action_col.ilike(f"%{raw}%")
