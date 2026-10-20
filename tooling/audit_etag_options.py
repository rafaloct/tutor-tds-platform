"""Read-only private dump comparison; emit option names and hashes, never values."""
import hashlib
import json
from pathlib import Path

ROOT = Path("/opt/tds-institutional-backups/etag-promotion-0b9e278-20261020")


def rows(path):
    result = {}
    for line in path.read_bytes().splitlines():
        if not line.startswith(b"INSERT INTO `wp_options` VALUES "):
            continue
        # mysqldump extended INSERT: split only outside escaped SQL strings.
        quoted = escaped = False
        depth = 0
        start = 0
        for i, char in enumerate(line):
            if escaped:
                escaped = False
                continue
            if quoted and char == 92:
                escaped = True
            elif char == 39:
                quoted = not quoted
            elif not quoted and char == 40:
                depth += 1
                if depth == 1:
                    start = i + 1
            elif not quoted and char == 41:
                depth -= 1
                if depth == 0:
                    row = line[start:i]
                    name = row.split(b",", 2)[1].strip(b"'").decode("ascii")
                    result[name] = hashlib.sha256(row).hexdigest()
    assert result
    return result


a, b = rows(ROOT / "before.sql"), rows(ROOT / "after.sql")
changed = sorted(k for k in a.keys() | b.keys() if a.get(k) != b.get(k))
print(json.dumps({"changed_option_names": changed,
                  "identical_options": sum(a.get(k) == b.get(k) for k in a)}))
