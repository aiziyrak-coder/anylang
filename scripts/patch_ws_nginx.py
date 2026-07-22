from pathlib import Path

p = Path("/etc/nginx/sites-available/anylang.uz")
t = p.read_text(encoding="utf-8")
if "location = /ws" in t:
    print("already")
else:
    old = "    # WebSocket\n    location /ws/ {"
    new = (
        "    # WebSocket\n"
        "    location = /ws {\n"
        "        return 301 /ws/;\n"
        "    }\n"
        "    location /ws/ {"
    )
    if old not in t:
        raise SystemExit("marker missing")
    p.write_text(t.replace(old, new, 1), encoding="utf-8")
    print("patched")
