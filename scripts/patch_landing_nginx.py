#!/usr/bin/env python3
"""Patch only anylang.uz nginx: landing at /, admin at /admin. Preserve SSL/certbot."""
from pathlib import Path
import re
import shutil
from datetime import datetime

PATH = Path("/etc/nginx/sites-available/anylang.uz")
BACKUP = Path(f"/etc/nginx/sites-available/anylang.uz.bak.landing.{datetime.now():%Y%m%d%H%M%S}")

LOCATIONS = r"""
    # Public marketing site
    location / {
        root /home/admin_root/anylang/landing;
        index index.html;
        try_files $uri $uri/ /index.html;
    }

    # Admin panel (Next.js basePath=/admin)
    location /admin {
        proxy_pass http://127.0.0.1:3105;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # Admin BFF — Next.js with basePath=/admin
    location /api/auth/ {
        proxy_pass http://127.0.0.1:3105/admin/api/auth/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /api/proxy/ {
        proxy_pass http://127.0.0.1:3105/admin/api/proxy/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 120s;
    }

    # FastAPI backend
    location /api/ {
        proxy_pass http://127.0.0.1:8105/api/;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 120s;
    }

    # WebSocket
    location /ws/ {
        proxy_pass http://127.0.0.1:8105/ws/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_read_timeout 86400;
    }

    # Health (optional public probe)
    location = /health {
        proxy_pass http://127.0.0.1:8105/health;
        proxy_set_header Host $host;
    }

    # MinIO public media
    location /media/ {
        proxy_pass http://127.0.0.1:19002/anylang/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
"""

text = PATH.read_text(encoding="utf-8")
shutil.copy2(PATH, BACKUP)

# Replace location blocks inside the SSL (443) server only — keep certbot SSL lines.
# Strategy: find first `server {` that has `listen 443` / ssl, replace its location* content
# before certbot-managed listen/ssl lines OR replace from first location to before listen ssl.

ssl_idx = text.find("listen 443")
if ssl_idx < 0:
    ssl_idx = text.find("listen [::]:443")
if ssl_idx < 0:
    raise SystemExit("SSL server block not found")

# Work on the HTTPS server: usually first server block after certbot reorder is HTTPS.
# Find start of HTTPS server block
https_start = text.rfind("server {", 0, ssl_idx)
if https_start < 0:
    raise SystemExit("HTTPS server start not found")

# Find end of HTTPS server — next "server {" after https_start+1 or last brace
next_server = text.find("\nserver {", https_start + 1)
https_block = text[https_start:next_server] if next_server > 0 else text[https_start:]

# Remove existing location blocks inside https_block
cleaned = re.sub(
    r"\n\s*#.*\n\s*location[\s\S]*?(?=\n\s*listen |\n\s*ssl_|\n\s*include |\n\s*# managed)",
    "\n",
    https_block,
    count=1,
)
# If regex failed to strip all locations, do a more aggressive strip of all location { } blocks
def strip_locations(block: str) -> str:
    out = []
    i = 0
    while i < len(block):
        m = re.search(r"\n\s*location\b", block[i:])
        if not m:
            out.append(block[i:])
            break
        start = i + m.start()
        out.append(block[i:start])
        # find matching brace
        brace = block.find("{", start)
        depth = 0
        j = brace
        while j < len(block):
            if block[j] == "{":
                depth += 1
            elif block[j] == "}":
                depth -= 1
                if depth == 0:
                    j += 1
                    break
            j += 1
        i = j
    return "".join(out)

cleaned = strip_locations(https_block)

# Insert locations after server_name / client_max_body_size area
insert_at = None
for marker in ("client_max_body_size 50M;", "server_name anylang.uz www.anylang.uz;"):
    pos = cleaned.find(marker)
    if pos >= 0:
        insert_at = pos + len(marker)
        break
if insert_at is None:
    # after opening brace
    insert_at = cleaned.find("{") + 1

new_https = cleaned[:insert_at] + "\n" + LOCATIONS + cleaned[insert_at:]

if next_server > 0:
    new_text = text[:https_start] + new_https + text[next_server:]
else:
    new_text = text[:https_start] + new_https

PATH.write_text(new_text, encoding="utf-8")
print(f"patched {PATH} (backup {BACKUP})")
