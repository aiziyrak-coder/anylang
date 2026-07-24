import os
import paramiko

PASS = os.environ["ANYLANG_SSH_PASS"]
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect("87.192.230.208", 2222, "admin_root", PASS)

remote = (
    "grep -nE 'ssl_certificate|server_name|listen|location = /ws|proxy_pass.*8105' "
    "/etc/nginx/sites-available/anylang.uz | head -60; "
    "echo ---; "
    "curl -sk -o /dev/null -w 'local_health:%{http_code}\\n' https://127.0.0.1/health "
    "-H 'Host: anylang.uz'; "
    "curl -sk https://127.0.0.1/health -H 'Host: anylang.uz'; echo; "
    "curl -sk -o /dev/null -w 'local_ws:%{http_code}\\n' "
    "-H 'Host: anylang.uz' -H 'Connection: Upgrade' -H 'Upgrade: websocket' "
    "-H 'Sec-WebSocket-Version: 13' -H 'Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==' "
    "https://127.0.0.1/ws/"
)
cmd = f"echo {PASS!r} | sudo -S bash -lc {remote!r}"
_, out, err = c.exec_command(cmd, timeout=60)
print((out.read() + err.read()).decode(errors="replace"))
c.close()
