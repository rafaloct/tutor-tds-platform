"""Authorized single-file production promotion; private backups, native rollback."""
import hashlib
import json
import os
from pathlib import Path
import socket
import subprocess
import sys

WP = "compose-program-open-source-monitor-szkpni-wordpress-1"
DB = "compose-program-open-source-monitor-szkpni-mysql-1"
PLUGIN = "tds-learnpress-editorial"
ENTRY = PLUGIN + "/" + PLUGIN + ".php"
REL = "wp-content/plugins/" + PLUGIN + "/includes/class-tds-learnpress-editorial.php"
OLD = "6d6659bd7a4eb78885c852e4d2357941e75625831fa82a60c77e03aeadd5e154"
NEW = "fe83864d4ac082163d493636a88fd044bc54e0529b6e334614986644a8f7ad16"
BACKUP = Path("/opt/tds-institutional-backups/20261020T003715Z")
RUN = Path("/opt/tds-institutional-backups/etag-promotion-0b9e278-20261020")
SOURCE = Path("/opt/tds-issue303-server-etag-9325dfd/wordpress/tds-learnpress-editorial/includes/class-tds-learnpress-editorial.php")


def cmd(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.PIPE).strip()


def wp(*args):
    return cmd("docker", "exec", WP, "wp", "--allow-root", "--skip-themes", *args)


def sha(path):
    with Path(path).open("rb") as f:
        return hashlib.file_digest(f, "sha256").hexdigest()


def plugins():
    value = json.loads(wp("option", "get", "active_plugins", "--format=json"))
    return sorted(value.values() if isinstance(value, dict) else value)


def services():
    return cmd("docker", "inspect", WP, DB, "dokploy-traefik",
               "--format", "{{.Id}} {{.Image}} {{.State.StartedAt}}")


def files(new=False):
    manifest = json.loads((BACKUP / "promotion.json").read_text())
    result = {}
    for group, prefix in (
        ("plugin_hashes", "/var/www/html/wp-content/plugins/" + PLUGIN + "/"),
        ("theme_after", "/var/www/html/wp-content/themes/tds-child-theme/"),
    ):
        for name, expected in manifest[group].items():
            if new and group == "plugin_hashes" and name == "includes/class-tds-learnpress-editorial.php":
                expected = NEW
            actual = cmd("docker", "exec", WP, "sha256sum", prefix + name).split()[0]
            assert actual == expected, "Unexpected file drift: " + name
            result[group + "/" + name] = actual
    return result


def dump(name):
    p = RUN / name
    with p.open("xb") as f:
        subprocess.run(["docker", "exec", DB, "sh", "-c",
                        'MYSQL_PWD="$MYSQL_ROOT_PASSWORD" exec mysqldump -uroot '
                        '--single-transaction --quick --skip-comments --skip-dump-date '
                        '--set-gtid-purged=OFF --column-statistics=0 --order-by-primary wordpress'],
                       stdout=f, stderr=subprocess.PIPE, check=True)
    return sha(p)


def blocks(path):
    result = {}
    with path.open("rb") as f:
        for line in f:
            if line.startswith(b"INSERT INTO `"):
                name = line.split(b"`", 2)[1].decode("ascii")
                result.setdefault(name, hashlib.sha256()).update(line)
    return {k: v.hexdigest() for k, v in result.items()}


def atomic_write(data):
    stat = target.stat()
    temp = target.with_name(target.name + ".etag-promotion.tmp")
    with temp.open("xb") as f:
        f.write(data)
    os.chown(temp, stat.st_uid, stat.st_gid)
    os.chmod(temp, stat.st_mode & 0o777)
    cmd("docker", "exec", WP, "php", "-l", "/var/www/html/" + REL + ".etag-promotion.tmp")
    os.replace(temp, target)


def rollback():
    wp("plugin", "deactivate", PLUGIN)
    assert sha(target) in (OLD, NEW), "Foreign file modification; do not overwrite"
    original = RUN / "original.php"
    assert sha(original) == OLD
    atomic_write(original.read_bytes())
    assert wp("plugin", "get", PLUGIN, "--field=status") == "inactive"
    files()
    print(json.dumps({"rollback": "PASS", "plugin": "inactive", "file_sha256": sha(target)}))


assert socket.gethostname() == "srv1533541"
os.umask(0o077)
mounts = json.loads(cmd("docker", "inspect", WP))[0]["Mounts"]
root = Path(next(m["Source"] for m in mounts if m["Destination"] == "/var/www/html")).resolve()
target = (root / REL).resolve()
assert target.is_relative_to(root) and target.is_file()
action = sys.argv[1]
if action == "promote":
    assert not RUN.exists(), "Promotion already has a receipt; do not repeat"
    assert wp("plugin", "get", PLUGIN, "--field=status") == "inactive"
    assert wp("core", "version") == "6.7.2"
    assert wp("plugin", "get", "learnpress", "--field=version") == "4.3.6"
    subprocess.run(["sha256sum", "-c", str(BACKUP / "SHA256SUMS")],
                   check=True, stdout=subprocess.DEVNULL)
    assert sha(SOURCE) == NEW and sha(target) == OLD
    baseline = {"files": files(), "services": services(), "active_plugins": plugins()}
    assert ENTRY not in baseline["active_plugins"]
    RUN.mkdir(mode=0o700)
    (RUN / "original.php").write_bytes(target.read_bytes())
    baseline["database_sha256"] = dump("before.sql")
    (RUN / "before.json").write_text(json.dumps(baseline, indent=2))
    try:
        assert files() == baseline["files"] and services() == baseline["services"]
        assert plugins() == baseline["active_plugins"]
        atomic_write(SOURCE.read_bytes())
        files(new=True)
        wp("plugin", "activate", PLUGIN)
        assert wp("plugin", "get", PLUGIN, "--field=status") == "active"
        assert plugins() == sorted(baseline["active_plugins"] + [ENTRY])
        print(json.dumps({"status": "ACTIVE_PENDING_ACCEPTANCE", "file_sha256": sha(target),
                          "database_before_sha256": baseline["database_sha256"],
                          "private_backup": str(RUN)}))
    except Exception:
        rollback()
        raise
elif action == "rollback":
    rollback()
elif action == "finalize":
    try:
        before = json.loads((RUN / "before.json").read_text())
        assert wp("plugin", "get", PLUGIN, "--field=status") == "active"
        assert services() == before["services"]
        assert plugins() == sorted(before["active_plugins"] + [ENTRY])
        after_files = files(new=True)
        after_hash = dump("after.sql")
        a, b = blocks(RUN / "before.sql"), blocks(RUN / "after.sql")
        changed = sorted(k for k in a.keys() | b.keys() if a.get(k) != b.get(k))
        result = {"plugin": "active", "database_before_sha256": before["database_sha256"],
                  "database_after_sha256": after_hash, "changed_data_tables": changed,
                  "identical_data_tables": sum(a.get(k) == b.get(k) for k in a),
                  "services_unchanged": True, "file_hashes": after_files}
        (RUN / "integrity.json").write_text(json.dumps(result, indent=2))
        assert set(changed) <= {"wp_options"}, "Unexpected data-table changes"
        print(json.dumps(result))
    except Exception:
        rollback()
        raise
else:
    raise ValueError("Unknown action")
