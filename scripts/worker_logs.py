import os, paramiko
p=os.environ['ANYLANG_SSH_PASS']
c=paramiko.SSHClient();c.set_missing_host_key_policy(paramiko.AutoAddPolicy());c.connect('87.192.230.208',2222,'admin_root',p)
_,o,_=c.exec_command(f"echo '{p}' | sudo -S docker logs anylang-worker-1 --tail 40 2>&1")
print(o.read().decode(errors='replace'))
c.close()
