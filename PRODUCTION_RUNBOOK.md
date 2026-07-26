# AnyLang Production Runbook

**Host:** VPS `87.192.230.208:2222` (SSH)  
**Public:** https://anylang.uz  
**Stack:** Docker Compose (`deploy/docker-compose.prod.yml`) + Nginx + Certbot TLS  
**Ship script (Windows):** `scripts/ship_full_release.py` (requires `ANYLANG_SSH_PASS`)

This is **not** Kubernetes (ARCHITECTURE.md describes the target; current production is Compose on a single VPS).

---

## 1. Environments

| Env | Purpose | Config |
|-----|---------|--------|
| `local` | Developer machine | `backend/.env.example` → `backend/.env` + root `docker-compose.yml` |
| `staging` | Pre-prod (recommended separate host/DB) | `deploy/env.staging.template` |
| `production` | Live users | `deploy/env.production.template` → `deploy/.env` on server |

Rules:
- Never mix DBs between envs.
- `DEBUG=false` and `APP_ENV=production` on live.
- Secrets only via env files (gitignored). See `deploy/ENV.md`.

---

## 2. Start / stop / status

```bash
cd /home/admin_root/anylang/deploy
sudo docker compose -f docker-compose.prod.yml --env-file .env ps
sudo docker compose -f docker-compose.prod.yml --env-file .env logs -f --tail=200 api
curl -fsS http://127.0.0.1:8105/health
curl -fsS http://127.0.0.1:8105/ready
curl -fsS http://127.0.0.1:8105/metrics/basic
```

Containers use `restart: unless-stopped`. Docker log rotation: `max-size` / `max-file` in compose.

---

## 3. Deploy (repeatable)

Preferred from developer workstation:

```powershell
$env:ANYLANG_SSH_PASS="..."
python scripts/ship_full_release.py
```

On server (fallback):

```bash
cd /home/admin_root/anylang
git fetch origin && git reset --hard origin/main
cd deploy
sudo docker compose -f docker-compose.prod.yml --env-file .env up -d --build --force-recreate api worker admin
# API container runs: alembic upgrade head
curl -fsS http://127.0.0.1:8105/ready
```

Nginx/landing:

```bash
sudo bash deploy/install.sh   # or rsync landing + nginx reload
sudo nginx -t && sudo systemctl reload nginx
```

---

## 4. Rollback

```bash
sudo bash deploy/scripts/rollback.sh <git-sha-or-tag>
# or manually:
cd /home/admin_root/anylang
git checkout <previous-sha>
cd deploy && sudo docker compose -f docker-compose.prod.yml --env-file .env up -d --build api worker admin
```

Always verify `/ready` and a smoke login after rollback.

---

## 5. Database backup & restore

Install cron (once):

```bash
sudo mkdir -p /var/backups/anylang/postgres
sudo cp /home/admin_root/anylang/deploy/scripts/backup_postgres.sh /usr/local/bin/anylang-backup-pg
sudo chmod +x /usr/local/bin/anylang-backup-pg
# cron: 03:15 UTC daily
echo '15 3 * * * /usr/local/bin/anylang-backup-pg >> /var/log/anylang-backup.log 2>&1' | sudo tee /etc/cron.d/anylang-backup
```

Manual backup:

```bash
sudo /usr/local/bin/anylang-backup-pg
```

Restore (downtime):

```bash
DUMP=/var/backups/anylang/postgres/anylang_YYYYMMDDTHHMMSSZ.sql.gz \
  sudo bash /home/admin_root/anylang/deploy/scripts/restore_postgres.sh
```

**Must** test restore on staging once before relying on backups.

---

## 6. Common incidents

| Symptom | Check | Fix |
|---------|-------|-----|
| 502 on `/api` | `docker ps`, api healthy? | `compose up -d api`, check logs |
| `/ready` 503 | `checks.redis` / `checks.postgres` | restart redis/postgres; disk full? |
| OTP not arriving | SMTP_* in `.env`, api logs | fix SMTP; `SMTP_FAIL_OPEN` must stay false in prod |
| WS disconnects | nginx `/ws` timeouts | already 86400s; check Redis |
| Disk full | `df -h`, docker logs, backups | prune old images; `docker system prune` carefully |
| SSL expiry | `sudo certbot certificates` | `sudo certbot renew` |

---

## 7. Security minimum (prod)

- HTTPS (Certbot) + HSTS on API middleware
- CORS limited to `anylang.uz`
- Auth rate limits (Redis) on login/OTP
- Security headers (nginx + FastAPI)
- `ALLOW_MOCK_PAYMENTS=false`, `ALLOW_OTP_IN_RESPONSE=false`
- Separate `ADMIN_SECRET_KEY`
- Optional: set `SENTRY_DSN` for error alerts

Full pentest is a separate cybersecurity engagement.

---

## 8. Monitoring (budget-friendly)

1. Uptime: free UptimeRobot / Better Stack probe on `https://anylang.uz/health` and `/ready`
2. Errors: set `SENTRY_DSN` (already wired in `app/main.py`)
3. Host: `htop`, `df`, Docker `json-file` log rotation (configured)
4. App: `GET /metrics/basic` for dependency latency

Prometheus/Grafana is optional later when traffic justifies it.

---

## 10. Performance & scale notes

- API runs **2 gunicorn/uvicorn workers** (async) — heavy I/O should not block the whole process; avoid CPU-bound work in request path.
- Redis already used for rate limits, WS presence, FAQ cooling — good shared cache for multi-instance later.
- Nginx **gzip** + `/media/` **7d cache** headers configured.
- CDN (optional, when traffic grows): put Cloudflare in front of `anylang.uz` (orange-cloud) for static/landing/media; keep WebSocket path compatible.
- Horizontal scale: add more `api` replicas behind nginx upstream **only after** sticky/shared Redis for WS and a single Postgres (or managed PG). Sticky sessions or Redis pub/sub for WS fan-out required.

## 11. Zero-downtime deploy (single VPS)

Compose recreate has brief connection blips. Mitigations:
1. Ship during low traffic.
2. Keep nginx up while only recreating `api`/`worker` (`up -d --no-deps --build api worker`).
3. Healthcheck + `start_period` lets nginx retry until `/ready`.
4. True zero-downtime needs a second instance + load balancer (future).

---

## 12. Pre-release checklist

- [ ] HTTPS works (no cert warnings)
- [ ] Backup ran and **restore tested** on staging/copy
- [ ] `/health` and `/ready` return OK publicly
- [ ] Intentional 500 is logged (Sentry or docker logs) without leaking stack to client
- [ ] Smoke: login → chat → product list
- [ ] Rollback path practiced once
- [ ] `DEBUG=false`, mock payments off
