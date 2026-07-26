#!/usr/bin/env bash
# Restore Postgres from a gzipped dump created by backup_postgres.sh
# WARNING: overwrites the anylang database. Run only after intentional downtime window.
#
# Usage:
#   APP_DIR=/home/admin_root/anylang \
#   DUMP=/var/backups/anylang/postgres/anylang_YYYYMMDDTHHMMSSZ.sql.gz \
#   ./deploy/scripts/restore_postgres.sh
set -euo pipefail

APP_DIR="${APP_DIR:-/home/admin_root/anylang}"
ENV_FILE="${ENV_FILE:-$APP_DIR/deploy/.env}"
CONTAINER="${CONTAINER:-anylang-postgres-1}"
DUMP="${DUMP:?Set DUMP=/path/to/anylang_....sql.gz}"

if [[ ! -f "$DUMP" ]]; then
  echo "Dump not found: $DUMP" >&2
  exit 1
fi
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing env: $ENV_FILE" >&2
  exit 1
fi

echo "Stopping API/worker to avoid writes..."
cd "$APP_DIR/deploy"
docker compose -f docker-compose.prod.yml --env-file "$ENV_FILE" stop api worker admin || true

echo "Restoring $DUMP into $CONTAINER ..."
# Local socket inside container — no need to source .env for password.
gunzip -c "$DUMP" | docker exec -i "$CONTAINER" \
  psql -U anylang -d anylang -v ON_ERROR_STOP=1

echo "Starting services..."
docker compose -f docker-compose.prod.yml --env-file "$ENV_FILE" up -d api worker admin

echo "Waiting for /ready ..."
sleep 8
curl -fsS http://127.0.0.1:8105/ready || true
echo
echo "Restore complete. Verify app flows manually."
