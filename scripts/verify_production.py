import os
import paramiko
import urllib.request
import ssl

p = os.environ["ANYLANG_SSH_PASS"]
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect("87.192.230.208", 2222, "admin_root", p)

checks = [
    "docker ps --filter name=anylang --format 'table {{.Names}}\t{{.Status}}'",
    "curl -sS -o /dev/null -w '%{http_code}' http://127.0.0.1:8105/health",
    "curl -sS http://127.0.0.1:8105/health",
    "curl -sS -o /dev/null -w '%{http_code}' http://127.0.0.1:3105/login",
    "docker logs anylang-worker-1 --tail 15 2>&1",
    "ls -la /etc/nginx/sites-enabled/ | grep -E 'anylang|ishifo|fermi' || true",
]

for cmd in checks:
    _, o, e = c.exec_command(f"echo '{p}' | sudo -S bash -lc {repr(cmd)}", timeout=60)
    out = o.read().decode(errors="replace")
    err = e.read().decode(errors="replace")
    print(f"\n=== {cmd[:70]} ===")
    print(out or err)

c.close()

ctx = ssl.create_default_context()
for url in [
    "https://anylang.uz/health",
    "https://anylang.uz/api/v1/health",
    "https://anylang.uz/login",
]:
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "AnyLangDeployCheck/1.0"})
        with urllib.request.urlopen(req, context=ctx, timeout=20) as r:
            body = r.read(500).decode(errors="replace")
            print(f"\n=== HTTPS {url} => {r.status} ===")
            print(body[:300])
    except Exception as ex:
        print(f"\n=== HTTPS {url} FAILED ===")
        print(ex)
