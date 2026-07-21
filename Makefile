.PHONY: up down logs api migrate smoke test lint admin

up:
	docker compose up -d postgres redis minio mailpit createbuckets

down:
	docker compose down

logs:
	docker compose logs -f api

migrate:
	cd backend && .venv/Scripts/alembic upgrade head || (cd backend && alembic upgrade head)

api:
	cd backend && .venv/Scripts/uvicorn app.main:app --reload --host 0.0.0.0 --port 8000

smoke:
	cd backend && .venv/Scripts/python scripts/smoke_test.py

test:
	cd backend && .venv/Scripts/pytest -q

lint:
	cd backend && .venv/Scripts/ruff check app && .venv/Scripts/mypy app || true

admin:
	cd admin && npm run dev

stack:
	docker compose up -d --build
