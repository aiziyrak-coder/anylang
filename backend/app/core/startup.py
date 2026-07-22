"""Production-safe startup validation and hardening helpers."""

from __future__ import annotations

import logging
import secrets
import sys

from app.core.config import Settings

logger = logging.getLogger(__name__)

WEAK_SECRET_FRAGMENTS = (
    "change-me",
    "dev-secret",
    "secret_key",
    "your-secret",
    "example",
)


def validate_settings(settings: Settings) -> None:
    """Fail fast on unsafe production configuration."""
    errors: list[str] = []

    if settings.is_production:
        if settings.debug:
            errors.append("DEBUG must be false in production")
        if any(frag in settings.secret_key.lower() for frag in WEAK_SECRET_FRAGMENTS):
            errors.append("SECRET_KEY looks weak / default — set a strong random value")
        if len(settings.secret_key) < 48:
            errors.append("SECRET_KEY must be at least 48 characters in production")
        if not settings.google_client_id_list:
            # Google login will be disabled; warn but don't fail if unused
            logger.warning("GOOGLE_CLIENT_IDS empty — Google Sign-In disabled in production")
        if settings.payment_provider == "mock" and not settings.allow_mock_payments:
            errors.append(
                "PAYMENT_PROVIDER=mock is forbidden in production "
                "(set PAYMENT_PROVIDER=stripe or ALLOW_MOCK_PAYMENTS=true explicitly)"
            )
        if settings.payment_provider == "stripe" and not settings.stripe_secret_key:
            errors.append("STRIPE_SECRET_KEY required when PAYMENT_PROVIDER=stripe")
        if settings.cors_origins.strip() in ("*", ""):
            errors.append("CORS_ORIGINS must be an explicit allow-list in production")
        if not settings.trusted_host_list:
            errors.append("TRUSTED_HOSTS must be set in production")
        provider = (settings.translation_provider or "mock").strip().lower()
        if provider == "openai":
            if not settings.openai_api_key:
                errors.append("OPENAI_API_KEY required when TRANSLATION_PROVIDER=openai")
        elif provider == "deepl":
            if not settings.deepl_api_key:
                errors.append("DEEPL_API_KEY required when TRANSLATION_PROVIDER=deepl")
        elif provider == "mock":
            if not settings.allow_mock_translation:
                errors.append(
                    "TRANSLATION_PROVIDER=mock forbidden in production "
                    "(set TRANSLATION_PROVIDER=openai|deepl or ALLOW_MOCK_TRANSLATION=true)"
                )
        else:
            errors.append(
                f"Unknown TRANSLATION_PROVIDER={settings.translation_provider!r} "
                "(use mock|deepl|openai)"
            )
        if not settings.deepgram_api_key:
            logger.warning("DEEPGRAM_API_KEY empty — Live STT will be unavailable in production")
        if "localhost" in settings.cors_origins:
            logger.warning("CORS_ORIGINS contains localhost in production")

    if errors:
        for err in errors:
            logger.error("CONFIG ERROR: %s", err)
        print("Fatal configuration errors:\n- " + "\n- ".join(errors), file=sys.stderr)
        raise SystemExit(1)


def generate_secret_hint() -> str:
    return secrets.token_urlsafe(48)
