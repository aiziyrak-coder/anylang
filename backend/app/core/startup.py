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
            # Tokens rejected in auth.py when production; login button should stay disabled.
            logger.warning(
                "GOOGLE_CLIENT_IDS empty — Google Sign-In will reject tokens in production"
            )
        if settings.payment_provider == "mock" and not settings.allow_mock_payments:
            errors.append(
                "PAYMENT_PROVIDER=mock is forbidden in production "
                "(set PAYMENT_PROVIDER=click|paddle|stripe or ALLOW_MOCK_PAYMENTS=true explicitly)"
            )
        if settings.payment_provider == "stripe" and not settings.stripe_secret_key:
            errors.append("STRIPE_SECRET_KEY required when PAYMENT_PROVIDER=stripe")
        if settings.payment_provider == "click" and not (
            settings.click_merchant_id
            and settings.click_service_id
            and settings.click_secret_key
        ):
            # Allow boot so Prepare/Complete URLs stay reachable while merchant
            # fills CLICK_MERCHANT_ID / CLICK_SECRET_KEY from merchant.click.uz.
            logger.warning(
                "CLICK_MERCHANT_ID / CLICK_SERVICE_ID / CLICK_SECRET_KEY incomplete — "
                "Click checkout disabled until credentials are set; "
                "SHOP API Prepare/Complete still mounted"
            )
        if settings.payment_provider == "paddle":
            if not (settings.paddle_api_key and settings.paddle_webhook_secret):
                errors.append(
                    "PADDLE_API_KEY / PADDLE_WEBHOOK_SECRET required when PAYMENT_PROVIDER=paddle"
                )
            paddle_prices = (
                settings.paddle_price_premium_monthly,
                settings.paddle_price_premium_yearly,
                settings.paddle_price_business_monthly,
                settings.paddle_price_business_yearly,
            )
            if not all((p or "").strip() for p in paddle_prices):
                errors.append(
                    "PADDLE price IDs (premium/business monthly+yearly) required in production "
                    "when PAYMENT_PROVIDER=paddle"
                )
        if settings.payment_provider == "multicard":
            base = (settings.multicard_base_url or "").lower()
            has_multicard_creds = bool(
                (settings.multicard_application_id or "").strip()
                and (settings.multicard_secret or "").strip()
                and settings.multicard_store_id
            )
            if "dev-mesh" in base and not has_multicard_creds:
                errors.append(
                    "MULTICARD_BASE_URL must not use dev-mesh in production unless "
                    "MULTICARD_APPLICATION_ID / MULTICARD_SECRET / MULTICARD_STORE_ID are set"
                )
        if not (settings.firebase_project_id or "").strip() or not (
            settings.firebase_credentials_json or ""
        ).strip():
            logger.warning(
                "FCM unset — FIREBASE_PROJECT_ID / FIREBASE_CREDENTIALS_JSON not configured; "
                "push notifications disabled"
            )
        if settings.cors_origins.strip() in ("*", ""):
            errors.append("CORS_ORIGINS must be an explicit allow-list in production")
        if not settings.trusted_host_list:
            errors.append("TRUSTED_HOSTS must be set in production")
        if settings.allow_otp_in_response or settings.smtp_fail_open:
            host = (settings.smtp_host or "").strip().lower()
            smtp_ready = bool(host) and host not in {"localhost", "127.0.0.1", "::1"}
            resend_ready = bool((settings.resend_api_key or "").strip())
            mail_ready = resend_ready or smtp_ready
            if mail_ready:
                if settings.allow_otp_in_response:
                    errors.append("ALLOW_OTP_IN_RESPONSE must be false in production")
                if settings.smtp_fail_open:
                    errors.append(
                        "SMTP_FAIL_OPEN must be false in production "
                        "(failed email delivery must not silently continue)"
                    )
            else:
                logger.warning(
                    "Email delivery not configured (set RESEND_API_KEY or SMTP_HOST) — "
                    "ALLOW_OTP_IN_RESPONSE=%s SMTP_FAIL_OPEN=%s "
                    "(bootstrap mode; configure ASAP)",
                    settings.allow_otp_in_response,
                    settings.smtp_fail_open,
                )
        if not (settings.admin_secret_key or "").strip():
            logger.warning(
                "ADMIN_SECRET_KEY empty — admin JWTs share SECRET_KEY; "
                "set a separate ADMIN_SECRET_KEY"
            )
        elif settings.admin_secret_key.strip() == settings.secret_key:
            errors.append("ADMIN_SECRET_KEY must differ from SECRET_KEY in production")
        elif len(settings.admin_secret_key.strip()) < 48:
            errors.append("ADMIN_SECRET_KEY must be at least 48 characters in production")
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
