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

    # SQLAlchemy pool (override via env in prod under load)
    db_pool_size: int = 10
    db_max_overflow: int = 20
    log_level: str = "INFO"

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
    # Chat auto-translate: stronger model for grammar/spelling (falls back to openai_model).
    openai_translation_model: str = "gpt-4o"
    # Live STT — gpt-4o-mini-transcribe is faster/stronger; falls back to whisper-1.
    openai_stt_model: str = "gpt-4o-mini-transcribe"
    deepgram_api_key: str = ""
    elevenlabs_api_key: str = ""
    # Optional overrides for Jonli TTS gender voices (ElevenLabs voice IDs).
    elevenlabs_voice_female: str = ""
    elevenlabs_voice_male: str = ""
    translation_provider: str = "mock"  # mock | deepl | openai

    payment_provider: str = "mock"  # mock | stripe | click | paddle | multicard
    stripe_secret_key: str = ""
    stripe_webhook_secret: str = ""
    stripe_success_url: str = "https://anylang.uz/billing/success"
    stripe_cancel_url: str = "https://anylang.uz/billing/cancel"
    allow_mock_payments: bool = False
    allow_mock_translation: bool = False

    # Click (UZS) — placeholders until merchant credentials are set.
    click_merchant_id: str = ""
    click_service_id: str = ""
    click_secret_key: str = ""
    click_merchant_user_id: str = ""
    click_pay_base_url: str = "https://my.click.uz/services/pay"
    click_merchant_api_base: str = "https://api.click.uz/v2/merchant"
    # OFD / fiscalization (single IKPU). Required when >1 IKPU; still recommended always.
    click_ofd_spic: str = ""  # IKPU / SPIC code
    click_ofd_package_code: str = ""
    click_ofd_units: int = 1
    click_ofd_item_name: str = "AnyLang"
    click_ofd_inn: str = ""  # merchant TIN (ИНН), informational / future OFD fields
    click_ofd_vat_percent: int = 0
    # Temporary flat UZS charge while Click is being activated (e.g. "1000"). Empty = off.
    payment_test_amount_uzs: str = ""
    # Public backend URL used in return_url (set via env in prod).
    public_api_base_url: str = "https://anylang.uz"

    # Multicard / Rahmat Pay (UZS tiyin) — card + Payme + Click + Uzum + Visa/MC.
    multicard_base_url: str = "https://dev-mesh.multicard.uz"
    multicard_application_id: str = ""
    multicard_secret: str = ""
    multicard_store_id: int = 0

    # Paddle MoR (USD) — placeholders until vendor credentials are set.
    paddle_api_key: str = ""
    paddle_webhook_secret: str = ""
    paddle_vendor_id: str = ""
    paddle_api_base_url: str = "https://api.paddle.com"  # sandbox: https://sandbox-api.paddle.com
    # Price IDs from Paddle dashboard (TODO if empty).
    paddle_price_premium_monthly: str = ""
    paddle_price_premium_yearly: str = ""
    paddle_price_business_monthly: str = ""
    paddle_price_business_yearly: str = ""

    # USD→UZS rate for Click amounts (manual / CB update). Override via USD_UZS_RATE.
    usd_uzs_rate: str = "12500"
    # cancel_and_recreate | return_existing
    payment_pending_policy: str = "cancel_and_recreate"

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
