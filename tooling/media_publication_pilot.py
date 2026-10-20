"""Run on confirmed VPS only. One pinned lesson, private backup, no core/vendor edits."""
import base64
import hashlib
import json
import os
from pathlib import Path
import socket
import subprocess
import sys

WP = "compose-program-open-source-monitor-szkpni-wordpress-1"
DB = "compose-program-open-source-monitor-szkpni-mysql-1"
RUN = Path("/opt/tds-institutional-backups/media-pilot-308-20261020")
SCRIPT = "/tmp/tds-issue308-pilot.php"


def command(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.PIPE).strip()


def wp(*args):
    return command("docker", "exec", WP, "wp", "--allow-root", "--skip-themes", "--user=1", *args)


def sha(path):
    with Path(path).open("rb") as f:
        return hashlib.file_digest(f, "sha256").hexdigest()


def dump(name):
    with (RUN / name).open("xb") as out:
        subprocess.run(["docker", "exec", DB, "sh", "-c",
                        'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysqldump -uroot '
                        '--single-transaction --quick --skip-comments --skip-dump-date '
                        '--set-gtid-purged=OFF --column-statistics=0 --order-by-primary wordpress'],
                       stdout=out, stderr=subprocess.PIPE, check=True)
    return sha(RUN / name)


def blocks(path):
    result = {}
    with path.open("rb") as f:
        for line in f:
            if line.startswith(b"INSERT INTO `"):
                result.setdefault(line.split(b"`", 2)[1].decode(), hashlib.sha256()).update(line)
    return {k: v.hexdigest() for k, v in result.items()}


def services():
    return command("docker", "inspect", WP, DB, "dokploy-traefik",
                   "--format", "{{.Id}} {{.Image}} {{.State.StartedAt}}")


assert socket.gethostname() == "srv1533541"
os.umask(0o077)
assert wp("core", "version") == "6.7.2"
assert wp("plugin", "get", "learnpress", "--field=version") == "4.3.6"
assert wp("plugin", "get", "tds-learnpress-editorial", "--field=status") == "active"
assert command("docker", "exec", WP, "sha256sum",
               "/var/www/html/wp-content/plugins/tds-learnpress-editorial/includes/class-tds-learnpress-editorial.php").split()[0] == "fe83864d4ac082163d493636a88fd044bc54e0529b6e334614986644a8f7ad16"
if sys.argv[1] == "publish":
    assert not RUN.exists(), "Existing receipt: do not repeat"
    # Check exact media bytes against the restored, previously reviewed inventory.
    prefix = "/var/www/html/wp-content/uploads/tutor-tds/v2-20261016/agricultura_sustentavel/"
    for name, expected in (
        ("01_agroecologia_cerrado_v2_acessivel_FHD.mp4", "8bfcae0f98cd18175399fe5861c96b23b0ad6d523891823adf87fd455d021431"),
        ("01_agroecologia_cerrado.vtt", "515119b65c4e3c86b00345d075f40efcc54e114157320e1356b8e7254fb9fb42"),
    ):
        assert command("docker", "exec", WP, "sha256sum", prefix + name).split()[0] == expected
    command("sha256sum", "-c", "/opt/tds-institutional-backups/20261020T003715Z/SHA256SUMS")
    before = {"services": services(), "snapshot": json.loads(wp("eval-file", SCRIPT, "snapshot"))}
    RUN.mkdir(mode=0o700)
    before["database_sha256"] = dump("before.sql")
    (RUN / "before.json").write_text(json.dumps(before, indent=2))
    encoded = base64.b64encode(json.dumps(before["snapshot"]).encode()).decode()
    result = json.loads(wp("eval-file", SCRIPT, "publish", encoded))
    (RUN / "publication.json").write_text(json.dumps(result, indent=2))
    result["database_before_sha256"] = before["database_sha256"]
    result["private_backup"] = str(RUN)
    print(json.dumps(result))
elif sys.argv[1] in ("finalize", "verify-rollback"):
    before = json.loads((RUN / "before.json").read_text())
    suffix = "rollback" if sys.argv[1] == "verify-rollback" else "after"
    after = dump(suffix + ".sql")
    a, b = blocks(RUN / "before.sql"), blocks(RUN / (suffix + ".sql"))
    changed = sorted(k for k in a.keys() | b.keys() if a.get(k) != b.get(k))
    result = {"changed_tables": changed, "unchanged_populated_tables": sum(a.get(k) == b.get(k) for k in a),
              "database_before_sha256": before["database_sha256"], "database_after_sha256": after,
              "services_unchanged": services() == before["services"],
              "after": json.loads(wp("eval-file", SCRIPT, "snapshot"))}
    (RUN / (suffix + "-integrity.json")).write_text(json.dumps(result, indent=2))
    allowed = {"wp_options"} if suffix == "rollback" else {"wp_postmeta", "wp_options"}
    assert set(changed) <= allowed and result["services_unchanged"]
    if suffix == "rollback":
        assert result["after"] == before["snapshot"]
    print(json.dumps(result))
elif sys.argv[1] == "rollback":
    before = json.loads((RUN / "before.json").read_text())
    encoded = base64.b64encode(json.dumps(before["snapshot"]).encode()).decode()
    print(wp("eval-file", SCRIPT, "rollback", encoded))
elif sys.argv[1] == "compare-rollback":
    a = (RUN / "before.sql").read_bytes().splitlines()
    b = (RUN / "rollback.sql").read_bytes().splitlines()
    different = [(x, y) for x, y in zip(a, b) if x != y]
    import re
    result = {"same_line_count": len(a) == len(b), "changed_lines": len(different),
              "only_auto_increment": all(
                  b"AUTO_INCREMENT=" in x and b"AUTO_INCREMENT=" in y
                  and re.sub(rb"AUTO_INCREMENT=\d+", b"AUTO_INCREMENT", x)
                  == re.sub(rb"AUTO_INCREMENT=\d+", b"AUTO_INCREMENT", y)
                  for x, y in different)}
    assert result["same_line_count"] and result["only_auto_increment"]
    print(json.dumps(result))
else:
    raise ValueError("Unsupported mode")
