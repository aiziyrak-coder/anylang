#!/usr/bin/env python3
from pathlib import Path

path = Path("/etc/nginx/sites-available/anylang.uz")
cur = path.read_text(encoding="utf-8")
if "/api/auth/" in cur:
    print("already patched")
    raise SystemExit(0)

marker = "    # FastAPI backend"
bff = """    # Admin BFF routes (must be before /api/ backend block)
    location /api/auth/ {
        proxy_pass http://127.0.0.1:3105;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /api/proxy/ {
        proxy_pass http://127.0.0.1:3105;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 120s;
    }

"""
if marker not in cur:
    raise SystemExit("marker not found")
path.write_text(cur.replace(marker, bff + marker), encoding="utf-8")
print("patched")
