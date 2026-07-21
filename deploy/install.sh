#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-$HOME/anylang}"
COMPOSE_FILE="$APP_DIR/deploy/docker-compose.prod.yml"
ENV_FILE="$APP_DIR/deploy/.env"
NGINX_AVAILABLE="/etc/nginx/sites-available/anylang.uz"
NGINX_ENABLED="/etc/nginx/sites-enabled/anylang.uz"
SUDO="${SUDO:-sudo}"

cd "$APP_DIR/deploy"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE — run deploy bootstrap first."
  exit 1
fi

echo "==> Building and starting AnyLang containers (isolated stack)..."
$SUDO docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d --build

echo "==> Installing nginx vhost (anylang.uz only)..."
$SUDO cp "$APP_DIR/deploy/nginx/anylang.uz.conf" "$NGINX_AVAILABLE"
$SUDO ln -sf "$NGINX_AVAILABLE" "$NGINX_ENABLED"
$SUDO nginx -t
$SUDO systemctl reload nginx

if [[ ! -d /etc/letsencrypt/live/anylang.uz ]]; then
  echo "==> Obtaining SSL certificate for anylang.uz..."
  $SUDO certbot --nginx -d anylang.uz -d www.anylang.uz --non-interactive --agree-tos -m admin@anylang.uz || true
fi

echo "==> Deploy complete."
echo "Admin: https://anylang.uz"
echo "API:   https://anylang.uz/api/v1/docs (disabled in prod — use /health)"
