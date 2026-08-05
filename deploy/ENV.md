# Environment variables reference
#
# | Variable | Required | Environments | Purpose |
# |---|---|---|---|
# | APP_ENV | yes | all | `local` \| `development` \| `staging` \| `production` |
# | DEBUG | yes | all | Must be `false` on production |
# | SECRET_KEY | yes | all | JWT + general HMAC (≥48 chars in prod) |
# | ADMIN_SECRET_KEY | yes (prod) | staging/prod | Separate admin JWT key |
# | DATABASE_URL | yes | all | Async Postgres DSN |
# | REDIS_URL | yes | all | Redis for cache/rate-limit/WS |
# | REDIS_PASSWORD | recommended | staging/prod | Redis AUTH |
# | POSTGRES_PASSWORD | yes | staging/prod | Compose Postgres password |
# | S3_* | yes | all | Object storage (MinIO/R2) |
# | SMTP_* | recommended | staging/prod | OTP email delivery |
# | OPENAI_API_KEY / DEEPL_* | as needed | staging/prod | Translation |
# | STRIPE_* | legacy optional | prod | Legacy Stripe checkout |
# | CLICK_* | when UZ payments live | staging/prod | Click.uz (UZS) |
# | PADDLE_* | when intl payments live | staging/prod | Paddle MoR (USD) |
# | USD_UZS_RATE | when Click live | staging/prod | USD→UZS conversion |
# | PUBLIC_API_BASE_URL | yes (payments) | staging/prod | return_url / webhook base |
# | CORS_ORIGINS | yes | all | Comma-separated allowed origins |
# | TRUSTED_HOSTS | yes | staging/prod | Host header allowlist |
# | SENTRY_DSN | optional | staging/prod | Error tracking |
# | ADMIN_EMAIL / ADMIN_PASSWORD | bootstrap | all | Seed admin (prod seed off) |
#
# Files:
# - backend/.env.example → local
# - deploy/env.dev.template → same VPS `deploy/.env.dev` (https://dev.anylang.uz)
# - deploy/env.staging.template → optional separate staging host
# - deploy/env.production.template → production host `deploy/.env`
#
# Workflow: see docs/ENVIRONMENTS.md
# Never commit real `.env` / `.env.dev` files. They are gitignored.
