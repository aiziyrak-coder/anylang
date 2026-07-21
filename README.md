# AnyLang (monorepo)

Global messaging + live translation platform.

| Package | Path | Stack |
|---|---|---|
| Mobile | [`Anylang/`](Anylang/) | Flutter (UI ready) |
| API | [`backend/`](backend/) | FastAPI · PostgreSQL · Redis |
| Admin | [`admin/`](admin/) | Next.js 15 |
| Spec | [`Anylang/anylang_backend.md`](Anylang/anylang_backend.md) |
| Architecture | [`ARCHITECTURE.md`](ARCHITECTURE.md) |

## Quick start

```bash
# 1) Infrastructure
docker compose up -d

# 2) API
cd backend
python -m venv .venv
.\.venv\Scripts\activate          # Windows
pip install -e ".[dev]"
copy .env.example .env            # already uses ports 15432 / 16379 / 19000
alembic upgrade head
uvicorn app.main:app --reload --port 8000

# 3) Admin
cd ../admin
npm install
npm run dev
```

- API docs: http://127.0.0.1:8000/docs  
- Admin: http://localhost:3000 — `admin@anylang.com` / `Admin123!`  
- Mailpit: http://127.0.0.1:8025  

Smoke test (API must be running):

```bash
cd backend
python scripts/smoke_test.py
```

## Implemented API modules

Auth · Users/Business · Subscription · Numbers · Products · Chats (+ WSS `/ws`) · Friends · Live · Admin

Payment providers and real STT/TTS/DeepL activate when API keys are set in `.env` (mock mode otherwise).
