# Environment variables reference
#
# | Variable | Required | Environments | Purpose |
# |---|---|---|---|
# | APP_ENV | yes | all | `local` \| `staging` \| `production` |
# | DEBUG | yes | all | Must be `false` outside local |
# | SECRET_KEY | yes | all | JWT + general HMAC (≥48 chars in prod) |
# | ADMIN_SECRET_KEY | yes (prod) | staging/prod | Separate admin JWT key |
# | DATABASE_URL | yes | all | Async Postgres DSN |
# | REDIS_URL | yes | all | Redis for cache/rate-limit/WS |
# | REDIS_PASSWORD | recommended | staging/prod | Redis AUTH |
# | POSTGRES_PASSWORD | yes | staging/prod | Compose Postgres password |
# | S3_* | yes | all | Object storage (MinIO/R2) |
# | SMTP_* | recommended | staging/prod | OTP email delivery |
# | OPENAI_API_KEY / DEEPL_* | as needed | staging/prod | Translation |
# | STRIPE_* | when payments live | prod | Billing |
# | CORS_ORIGINS | yes | all | Comma-separated allowed origins |
# | TRUSTED_HOSTS | yes | staging/prod | Host header allowlist |
# | SENTRY_DSN | optional | staging/prod | Error tracking |
# | ADMIN_EMAIL / ADMIN_PASSWORD | bootstrap | all | Seed admin (prod seed off) |
#
# Files:
# - backend/.env.example → local
# - deploy/env.staging.template → staging host `deploy/.env`
# - deploy/env.production.template → production host `deploy/.env`
#
# Never commit real `.env` files. They are gitignored.
