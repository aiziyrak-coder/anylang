# Deploy scripts

| Script | Purpose |
|--------|---------|
| `backup_postgres.sh` | Daily `pg_dump` → `/var/backups/anylang/postgres` (gzip, 14d retention) |
| `restore_postgres.sh` | Restore from a dump (`DUMP=...`) — stops api/worker first |
| `rollback.sh` | `git checkout <sha>` + rebuild api/worker/admin |

Make executable on Linux: `chmod +x deploy/scripts/*.sh`

See [`../PRODUCTION_RUNBOOK.md`](../PRODUCTION_RUNBOOK.md).
