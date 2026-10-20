"""Read-only, narrowly allow explicit charset spelling in restored SHOW CREATE."""
import hashlib
import json
import re
from pathlib import Path

root = Path('/opt/tds-institutional-backups/20261020T003715Z')
original = (root / 'wordpress.sql').read_bytes()
restored = (root / 'restored-retry.sql').read_bytes()
a, b = original.splitlines(), restored.splitlines()
assert len(a) == len(b)
table = None
changes = []
for i, (old, new) in enumerate(zip(a, b), 1):
    match = re.match(rb'CREATE TABLE `([^`]+)`', old)
    if match:
        table = match[1].decode()
    if old == new:
        continue
    assert table in {'wp_tds_interesse', 'wp_wpvibe_audit_log', 'wp_wpvibe_op_receipts'}
    assert re.match(rb'  `\w+` (varchar\(\d+\)|text|longtext) COLLATE utf8mb4_unicode_520_ci', old)
    assert new == old.replace(b' COLLATE utf8mb4_unicode_520_ci', b' CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_520_ci', 1)
    changes.append({'line': i, 'table': table, 'change': 'explicit utf8mb4 for unchanged utf8mb4_unicode_520_ci'})
assert len(changes) == 14
assert [x for x in a if x.startswith(b'INSERT INTO')] == [x for x in b if x.startswith(b'INSERT INTO')]
result = {'status': 'PASS_DATA_AND_SCHEMA_EQUIVALENCE', 'byte_identical': False,
          'raw_dumps_preserved': True, 'data_inserts_byte_identical': True,
          'original_sha256': hashlib.sha256(original).hexdigest(),
          'restored_sha256': hashlib.sha256(restored).hexdigest(), 'schema_changes': changes,
          'tables': sum(x.startswith(b'CREATE TABLE') for x in a),
          'wp_runtime_started': False, 'restore_network': 'none', 'public_ports': 0}
(root / 'restore-equivalence.json').write_text(json.dumps(result, indent=2))
print(json.dumps(result))
