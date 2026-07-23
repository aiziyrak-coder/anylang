from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_name: str = "AnyLang"
    app_env: str = "local"
    debug: bool = False
    api_v1_prefix: str = "/api/v1"

    secret_key: str = Field(..., min_length=32)
    # Separate signing key for admin JWTs (recommended). Falls back to SECRET_KEY if empty.
    admin_secret_key: str = ""
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 60

    database_url: str
    redis_url: str = "redis://localhost:6379/0"

    s3_endpoint_url: str | None = None
    s3_access_key: str = ""
    s3_secret_key: str = ""
    s3_bucket: str = "anylang"
    s3_region: str = "auto"
    s3_public_base_url: str = ""

    smtp_host: str = "localhost"
    smtp_port: int = 1025
    smtp_user: str = ""
    smtp_password: str = ""
    smtp_from: str = "AnyLang <noreply@anylang.local>"
    smtp_tls: bool = False
    # If SMTP is down, still accept register (OTP hashed in DB). Never return OTP in production.
    smtp_fail_open: bool = True
    allow_otp_in_response: bool = False

    google_client_ids: str = ""
    deepl_api_key: str = ""
    openai_api_key: str = ""
    openai_model: str = "gpt-4o-mini"
    deepgram_api_key: str = ""
    elevenlabs_api_key: str = ""
    translation_provider: str = "mock"  # mock | deepl | openai

    payment_provider: str = "mock"  # mock | stripe
    stripe_secret_key: str = ""
    stripe_webhook_secret: str = ""
    stripe_success_url: str = "https://anylang.uz/billing/success"
    stripe_cancel_url: str = "https://anylang.uz/billing/cancel"
    allow_mock_payments: bool = False
    allow_mock_translation: bool = False

    # Admin bootstrap (only used when APP_ENV != production, or when explicitly set)
    admin_email: str = "admin@anylang.com"
    admin_password: str = ""
    admin_seed_in_production: bool = False

    cors_origins: str = "http://localhost:3000"
    sentry_dsn: str = ""
    trusted_hosts: str = ""  # comma-separated; empty = skip TrustedHostMiddleware

    @property
    def cors_origin_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    @property
    def google_client_id_list(self) -> list[str]:
        return [x.strip() for x in self.google_client_ids.split(",") if x.strip()]

    @property
    def trusted_host_list(self) -> list[str]:
        return [h.strip() for h in self.trusted_hosts.split(",") if h.strip()]

    @property
    def is_production(self) -> bool:
        return self.app_env == "production"

    @property
    def admin_signing_key(self) -> str:
        """Admin JWT HMAC key — prefer ADMIN_SECRET_KEY when set."""
        key = (self.admin_secret_key or "").strip()
        return key if key else self.secret_key

    @property
    def mock_payments_allowed(self) -> bool:
        if self.payment_provider != "mock":
            return False
        if not self.is_production:
            return True
        return self.allow_mock_payments


@lru_cache
def get_settings() -> Settings:
    return Settings()
