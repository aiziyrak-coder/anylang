#!/usr/bin/env bash
# Daily Postgres backup for AnyLang production compose stack.
# Install (on server):
#   sudo cp deploy/scripts/backup_postgres.sh /usr/local/bin/anylang-backup-pg
#   sudo chmod +x /usr/local/bin/anylang-backup-pg
#   sudo crontab -e
#   15 3 * * * /usr/local/bin/anylang-backup-pg >> /var/log/anylang-backup.log 2>&1
set -euo pipefail

APP_DIR="${APP_DIR:-/home/admin_root/anylang}"
COMPOSE_FILE="${COMPOSE_FILE:-$APP_DIR/deploy/docker-compose.prod.yml}"
ENV_FILE="${ENV_FILE:-$APP_DIR/deploy/.env}"
BACKUP_DIR="${BACKUP_DIR:-/var/backups/anylang/postgres}"
KEEP_DAYS="${KEEP_DAYS:-14}"
CONTAINER="${CONTAINER:-anylang-postgres-1}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$BACKUP_DIR/anylang_${STAMP}.sql.gz"

mkdir -p "$BACKUP_DIR"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing env: $ENV_FILE" >&2
  exit 1
fi

# shellcheck disable=SC1090
set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

echo "[$(date -u +%FT%TZ)] starting backup -> $OUT"
docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" "$CONTAINER" \
  pg_dump -U anylang -d anylang --clean --if-exists \
  | gzip -c > "$OUT"

# Integrity check: gzip readable
gzip -t "$OUT"
ls -lh "$OUT"

# Retention
find "$BACKUP_DIR" -type f -name 'anylang_*.sql.gz' -mtime +"$KEEP_DAYS" -delete
echo "[$(date -u +%FT%TZ)] backup ok (keep ${KEEP_DAYS}d)"
