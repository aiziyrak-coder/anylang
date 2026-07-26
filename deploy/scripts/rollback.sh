#!/usr/bin/env bash
# Tag current running image digests and roll back API/worker/admin to a previous tag.
# Usage:
#   ./deploy/scripts/rollback.sh              # list recent tags hint
#   ./deploy/scripts/rollback.sh v1.0.57      # recreate from previously built images if tagged
set -euo pipefail

APP_DIR="${APP_DIR:-/home/admin_root/anylang}"
ENV_FILE="${ENV_FILE:-$APP_DIR/deploy/.env}"
TAG="${1:-}"

cd "$APP_DIR/deploy"

if [[ -z "$TAG" ]]; then
  echo "Usage: $0 <git-tag-or-label>"
  echo "Preferred rollback path:"
  echo "  1) cd $APP_DIR && git fetch && git checkout <previous-sha>"
  echo "  2) docker compose -f docker-compose.prod.yml --env-file .env up -d --build api worker admin"
  echo "  3) curl -fsS http://127.0.0.1:8105/ready"
  exit 1
fi

cd "$APP_DIR"
git fetch origin
git checkout "$TAG"
cd deploy
docker compose -f docker-compose.prod.yml --env-file "$ENV_FILE" up -d --build --force-recreate api worker admin
sleep 10
curl -fsS http://127.0.0.1:8105/ready
echo
echo "Rollback to $TAG applied."
