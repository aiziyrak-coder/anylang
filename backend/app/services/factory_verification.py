"""Factory Verified — Alibaba-style factory trust badges."""

from __future__ import annotations

from app.models.user import BusinessProfile, User


def _certs_lower(business: BusinessProfile) -> list[str]:
    return [str(c or "").strip().lower() for c in (business.certificates or []) if str(c or "").strip()]


def has_iso(certs: list[str]) -> bool:
    return any("iso" in c for c in certs)


def has_ce(certs: list[str]) -> bool:
    return any(c == "ce" or c.startswith("ce ") or c.endswith(" ce") or " ce " in c for c in certs)


def has_fda(certs: list[str]) -> bool:
    return any("fda" in c for c in certs)


def build_factory_verification(
    business: BusinessProfile | None,
    *,
    user: User | None = None,
) -> dict:
    """Structured badges for profiles / product seller cards."""
    if business is None:
        return {
            "factory_verified": False,
            "inspection_passed": False,
            "iso": False,
            "ce": False,
            "fda": False,
            "audit_report_url": None,
            "has_any": False,
        }

    certs = _certs_lower(business)
    iso = has_iso(certs)
    ce = has_ce(certs)
    fda = has_fda(certs)
    inspection = bool(business.inspection_passed)
    # Explicit admin flag; inspection_passed also implies Factory Verified.
    factory_verified = bool(business.factory_verified) or inspection
    audit = (business.audit_report_url or "").strip() or None
    return {
        "factory_verified": factory_verified,
        "inspection_passed": inspection,
        "iso": iso,
        "ce": ce,
        "fda": fda,
        "audit_report_url": audit,
        "has_any": bool(
            factory_verified or inspection or iso or ce or fda or audit
        ),
    }


def _is_premium_seller(user: User | None) -> bool:
    if user is None:
        return False
    sub = getattr(user, "subscription", None)
    if sub is None:
        return False
    return bool(sub.is_active and sub.plan in {"premium", "business"})


def _has_trade_assurance(business: BusinessProfile | None, user: User | None) -> bool:
    """Trade Assurance — hujjat/verified yoki maxsus sertifikat."""
    if business is not None:
        if bool(business.documents_verified):
            return True
        certs = _certs_lower(business)
        if any("assurance" in c or "trade assurance" in c for c in certs):
            return True
    if user is not None and bool(user.verified_badge):
        return True
    return False


def build_product_trust_badges(
    business: BusinessProfile | None,
    *,
    user: User | None = None,
) -> dict:
    """Mahsulot ishonch belgilari: Factory Verified · ISO · Trade Assurance · Premium."""
    factory = build_factory_verification(business, user=user)
    factory_verified = bool(factory["factory_verified"])
    iso = bool(factory["iso"])
    trade_assurance = _has_trade_assurance(business, user)
    premium = _is_premium_seller(user)
    return {
        "factory_verified": factory_verified,
        "iso": iso,
        "trade_assurance": trade_assurance,
        "premium": premium,
        "has_any": bool(factory_verified or iso or trade_assurance or premium),
    }
