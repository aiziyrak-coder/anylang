#!/usr/bin/env bash
# Daily Postgres backup for AnyLang production compose stack.
# Does NOT source deploy/.env (dotenv values often break bash).
# Install (on server):
#   sudo cp deploy/scripts/backup_postgres.sh /usr/local/bin/anylang-backup-pg
#   sudo chmod +x /usr/local/bin/anylang-backup-pg
#   # cron: 15 3 * * * root /usr/local/bin/anylang-backup-pg >> /var/log/anylang-backup.log 2>&1
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-/var/backups/anylang/postgres}"
KEEP_DAYS="${KEEP_DAYS:-14}"
CONTAINER="${CONTAINER:-anylang-postgres-1}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="$BACKUP_DIR/anylang_${STAMP}.sql.gz"

mkdir -p "$BACKUP_DIR"

if ! docker inspect "$CONTAINER" >/dev/null 2>&1; then
  echo "Container not found: $CONTAINER" >&2
  exit 1
fi

echo "[$(date -u +%FT%TZ)] starting backup -> $OUT"
# Local socket inside the container does not need PGPASSWORD.
docker exec "$CONTAINER" \
  pg_dump -U anylang -d anylang --clean --if-exists \
  | gzip -c > "$OUT"

gzip -t "$OUT"
ls -lh "$OUT"

find "$BACKUP_DIR" -type f -name 'anylang_*.sql.gz' -mtime +"$KEEP_DAYS" -delete
echo "[$(date -u +%FT%TZ)] backup ok (keep ${KEEP_DAYS}d)"
