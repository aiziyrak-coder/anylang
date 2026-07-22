import os
import paramiko

p = os.environ["ANYLANG_SSH_PASS"]
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect("87.192.230.208", 2222, "admin_root", p)
sftp = c.open_sftp()
sftp.put(r"E:\Anylang\scripts\patch_ws_nginx.py", "/tmp/patch_ws_nginx.py")
sftp.put(r"E:\Anylang\scripts\openai_smoke.py", "/tmp/openai_smoke.py")
sftp.close()


def sudo(cmd, timeout=120):
    _, o, e = c.exec_command(f"echo {p!r} | sudo -S bash -lc {cmd!r}", timeout=timeout)
    text = (o.read() + e.read()).decode(errors="replace")
    print(text[-2000:].encode("ascii", "replace").decode("ascii"))


sudo("python3 /tmp/patch_ws_nginx.py")
sudo("nginx -t && systemctl reload nginx")
sudo(
    "docker cp /tmp/openai_smoke.py anylang-api-1:/tmp/openai_smoke.py && "
    "docker exec anylang-api-1 python /tmp/openai_smoke.py",
    timeout=90,
)
sudo("docker logs anylang-api-1 --tail 8 2>&1")
c.close()
