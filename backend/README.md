# AnyLang Backend

FastAPI API for the AnyLang global messaging / translation platform.

## Stack

- FastAPI + SQLAlchemy 2 (async) + PostgreSQL 16 + Redis 7 + ARQ
- Object storage: S3-compatible (MinIO local / Cloudflare R2 prod)
- Contract: `../Anylang/anylang_backend.md`
- Architecture: `../ARCHITECTURE.md`

## Quick start

```bash
# from repo root
docker compose up -d

cd backend
python -m venv .venv
# Windows:
.venv\Scripts\activate
# macOS/Linux:
# source .venv/bin/activate

pip install -e ".[dev]"
cp .env.example .env
alembic upgrade head
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

- API: http://localhost:8000  
- OpenAPI: http://localhost:8000/docs  
- Mailpit UI: http://localhost:8025  
- MinIO console: http://localhost:9001  

## Environment

See `.env.example`. Never commit real secrets.
