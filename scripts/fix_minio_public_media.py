#!/usr/bin/env python3
"""Make AnyLang MinIO bucket publicly readable and fix nginx /media/ proxy Host."""

from __future__ import annotations

import os
import subprocess
import tempfile
from pathlib import Path

ENV = Path("/home/admin_root/anylang/deploy/.env")
NGINX = Path("/etc/nginx/sites-enabled/anylang.uz")


def env_get(key: str) -> str:
    for line in ENV.read_text(encoding="utf-8").splitlines():
        if line.startswith(f"{key}="):
            return line.split("=", 1)[1].strip()
    raise SystemExit(f"missing {key}")


def run(cmd: list[str]) -> None:
    print("+", " ".join(cmd[:6]), "...")
    subprocess.check_call(cmd)


def main() -> None:
    ak = env_get("S3_ACCESS_KEY")
    sk = env_get("S3_SECRET_KEY")

    mc = Path("/usr/local/bin/mc")
    if not mc.exists():
        subprocess.check_call(
            [
                "curl",
                "-fsSL",
                "https://dl.min.io/client/mc/release/linux-amd64/mc",
                "-o",
                str(mc),
            ]
        )
        mc.chmod(0o755)

    run(
        [
            str(mc),
            "alias",
            "set",
            "anylanglocal",
            "http://127.0.0.1:19002",
            ak,
            sk,
        ]
    )
    run([str(mc), "anonymous", "set", "download", "anylanglocal/anylang"])
    subprocess.call([str(mc), "anonymous", "get", "anylanglocal/anylang"])

    text = NGINX.read_text(encoding="utf-8")
    needle = "location /media/"
    if needle not in text:
        raise SystemExit("location /media/ not found")

    # Replace Host $host with MinIO host so signature/path-style works.
    lines = text.splitlines(keepends=True)
    out: list[str] = []
    i = 0
    while i < len(lines):
        line = lines[i]
        out.append(line)
        if "location /media/" in line:
            # copy until closing brace, rewriting headers
            i += 1
            block: list[str] = []
            while i < len(lines):
                block.append(lines[i])
                if lines[i].strip() == "}":
                    break
                i += 1
            rewritten = []
            has_host = False
            for b in block:
                if "proxy_set_header Host" in b:
                    rewritten.append("        proxy_set_header Host 127.0.0.1:19002;\n")
                    has_host = True
                else:
                    rewritten.append(b)
            if not has_host:
                # insert before closing brace
                rewritten.insert(-1, "        proxy_set_header Host 127.0.0.1:19002;\n")
            extras = [
                "        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;\n",
                "        proxy_set_header X-Forwarded-Proto $scheme;\n",
                "        proxy_buffering off;\n",
            ]
            # avoid duplicates
            joined = "".join(rewritten)
            for e in extras:
                if e.strip() not in joined:
                    rewritten.insert(-1, e)
            out.extend(rewritten)
        i += 1

    NGINX.write_text("".join(out), encoding="utf-8")
    print("nginx media Host updated")
    run(["nginx", "-t"])
    run(["systemctl", "reload", "nginx"])
    print("DONE")


if __name__ == "__main__":
    main()
