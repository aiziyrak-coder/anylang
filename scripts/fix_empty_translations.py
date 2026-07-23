#!/usr/bin/env python3
import os
import paramiko

p = os.environ["ANYLANG_SSH_PASS"]
c = paramiko.SSHClient()
c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
c.connect("87.192.230.208", 2222, "admin_root", p, timeout=25)

sql = r"""
UPDATE message_translations mt
SET text = m.text_original, status = 'failed'
FROM messages m
WHERE m.id = mt.message_id
  AND (mt.text IS NULL OR btrim(mt.text) = '')
  AND coalesce(btrim(m.text_original), '') <> '';

UPDATE users
SET native_language = 'en'
WHERE lower(split_part(native_language, '_', 1)) IN ('us', 'gb', 'eng');

SELECT 'empty_tr' AS k, count(*)::text AS v
FROM message_translations
WHERE text IS NULL OR btrim(text) = ''
UNION ALL
SELECT 'us_users', count(*)::text
FROM users
WHERE lower(split_part(native_language, '_', 1)) IN ('us', 'gb', 'eng');
"""

# write sql to remote temp then execute
sftp = c.open_sftp()
with sftp.file("/tmp/fix_translate.sql", "w") as f:
    f.write(sql)
sftp.close()

cmd = (
    f"echo '{p}' | sudo -S docker cp /tmp/fix_translate.sql anylang-postgres-1:/tmp/fix_translate.sql && "
    f"echo '{p}' | sudo -S docker exec anylang-postgres-1 "
    f"psql -U anylang -d anylang -f /tmp/fix_translate.sql"
)
_, o, e = c.exec_command(cmd, timeout=60)
print(o.read().decode(errors="replace"))
print(e.read().decode(errors="replace"))
c.close()
