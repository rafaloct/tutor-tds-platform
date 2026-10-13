"""Synthetic release-proof tests; no production, R2 or real age key is contacted."""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from tooling import rehearse_scheduled_postgres_upgrade as upgrade
from tooling import rehearse_scheduled_postgres_backup as restore
from tooling.verify_production_recovery_evidence import verify


DIGEST = "sha256:" + "b" * 64
SCHEMA = "20261007_0030"
TREE = "a" * 40
NOW = datetime(2026, 10, 13, 12, tzinfo=timezone.utc)


class FakeRehearsal(upgrade.Rehearsal):
    def __init__(self, failure: str = "") -> None:
        super().__init__("synthetic-run")
        self.failure = failure
        self.calls: list[tuple] = []
        self.state_reads = 0
        self.fingerprint_reads = 0
        self.cleaned = False

    def docker(self, *args, **kwargs):
        self.calls.append(args)
        if "pg_restore" in args:
            if self.failure == "restore":
                raise restore.DrillError("synthetic_restore_failure")
            if bytes(kwargs["input_bytes"]) != b"PGDMPsynthetic":
                raise AssertionError("The supplied decrypted archive must be restored unchanged")
        if "df" in args:
            return b"Filesystem Type blocks used available capacity mounted\ntmpfs tmpfs 1 1 1 1 /data\n"
        if args[0] == "wait":
            return b"1" if self.failure == "migration" else b"0"
        return b""

    def inspect(self, kind, name):
        if kind == "image":
            return {"Id": DIGEST}
        if kind == "network":
            return {"Internal": self.failure != "egress"}
        return {"Mounts": [], "HostConfig": {"Tmpfs": {"/var/lib/postgresql/data": "rw,size=1024m"},
                                             "NetworkMode": "tds-offsite-upgrade-synthetic-run-net",
                                             "PortBindings": None}}

    def create(self, kind, name, *args):
        self.calls.append(("create", kind, name, *args))
        self.resources.append((kind, name))

    def columns(self, container):
        return {"users": ["id"], "courses": ["id"], "learning_events": ["id"]}

    def fingerprint(self, container, columns):
        self.fingerprint_reads += 1
        return {"users": "1:changed" if self.failure == "data" and self.fingerprint_reads > 1
                else "1:original"}

    def production_state(self):
        self.state_reads += 1
        return {"image_id": DIGEST, "revision": "old",
                "api_id": "changed" if self.failure == "production" and self.state_reads > 1 else "same"}

    def sql(self, container, query):
        if "server_version_num" in query:
            return "160010"
        if self.failure == "revision":
            return "20261005_0028"
        return SCHEMA

    def start_api(self, name, image, network, env_file):
        if self.failure == "rollback" and name.endswith("-old"):
            raise restore.DrillError("rollback_does_not_start")
        # These files are private and use isolated secrets, never the production DSN.
        if env_file.stat().st_mode & 0o077:
            raise AssertionError("Isolated secrets must be private")
        environment = env_file.read_text()
        if "tutor-tds-api-db-1" in environment:
            raise AssertionError("API rehearsal must not point at production")
        return {"status": "ok", "database": "available"}

    def get(self, container, path):
        if path == "/openapi.json":
            return {"paths": {"/courses": {"get": {}}}}
        if self.failure == "catalog" and container.endswith("-new"):
            return {"courses": [{"id": "different"}]}
        return {"courses": [{"id": "preserved"}]}

    def cleanup(self):
        self.cleaned = True


class ScheduledUpgradeTests(unittest.TestCase):
    def run_rehearsal(self, fake):
        dump = bytearray(b"PGDMPsynthetic")
        with patch.object(upgrade, "image_identity", return_value=DIGEST), \
                patch.object(upgrade, "required_operations", return_value={"GET /courses"}), \
                patch.object(restore, "candidate_identity", return_value=(TREE, SCHEMA)):
            record, when = upgrade.rehearse(dump, Path("/synthetic"), DIGEST, fake, TREE, SCHEMA, 1024)
        self.assertEqual(dump, bytearray(len(dump)))
        return record, when

    def test_restore_upgrade_and_rollback_use_supplied_archive_and_own_resources(self):
        fake = FakeRehearsal()
        record, _ = self.run_rehearsal(fake)
        self.assertEqual(record["status"], "passed")
        self.assertTrue(record["production_unchanged"])
        self.assertTrue(record["old_image_runs_on_upgraded_database"])
        self.assertTrue(fake.cleaned)
        migrations = [args for args in fake.calls if "alembic" in args]
        self.assertEqual(len(migrations), 1)
        self.assertIn("tds-offsite-upgrade-synthetic-run-net", migrations[0])
        self.assertNotIn("tutor-tds-api-db-1", str(fake.calls))
        self.assertNotIn("pg_dump", str(fake.calls))

    def test_failed_restore_migration_data_rollback_or_production_change_never_pass(self):
        for failure in ("restore", "migration", "revision", "data", "rollback", "production", "catalog", "egress"):
            with self.subTest(failure=failure):
                fake = FakeRehearsal(failure)
                with self.assertRaises(restore.DrillError):
                    self.run_rehearsal(fake)
                self.assertTrue(fake.cleaned)

    def test_routes_missing_from_candidate_or_published_contract_fail(self):
        old = {"paths": {"/courses": {"get": {}}}}
        with self.assertRaisesRegex(restore.DrillError, "routes_incompatible"):
            upgrade.compare_openapi(old, {"paths": {}}, {"GET /courses"})
        with self.assertRaisesRegex(restore.DrillError, "routes_incompatible"):
            upgrade.compare_openapi(old, old, {"GET /courses", "POST /auth/register"})
        result = upgrade.compare_openapi(old, {"paths": {"/courses": {"get": {}, "post": {}}}}, {"GET /courses"})
        self.assertEqual(result["only_candidate"], ["POST /courses"])

    def test_catalog_projection_preserves_values_types_and_list_order(self):
        self.assertTrue(upgrade.legacy_matches({"courses": [{"id": "one"}]},
                                             {"courses": [{"id": "one", "new": True}]}))
        self.assertFalse(upgrade.legacy_matches({"count": 1}, {"count": True}))
        self.assertFalse(upgrade.legacy_matches(["one", "two"], ["two", "one"]))

    def test_production_sql_always_enforces_readonly_transactions(self):
        with patch.object(restore, "command", return_value=b"1\n") as command:
            self.assertEqual(upgrade.Rehearsal("test").sql("tutor-tds-api-db-1", "SELECT 1"), "1")
        self.assertIn("PGOPTIONS=-c default_transaction_read_only=on -c statement_timeout=120000",
                      command.call_args.args[0])

    def test_source_identity_inspection_does_not_read_environment_secrets(self):
        run = upgrade.Rehearsal("test")

        def metadata(*args, **kwargs):
            service = "api" if args[-1].endswith("api-1") else "db"
            return json.dumps({"Id": service, "Image": DIGEST, "State": {"Running": True},
                               "Config": {"Labels": {"com.docker.compose.project": "tutor-tds-api",
                                                       "com.docker.compose.service": service}}}).encode()

        with patch.object(run, "docker", side_effect=metadata) as docker, \
                patch.object(run, "columns", return_value={"users": ["id"]}), \
                patch.object(run, "fingerprint", return_value={"users": "1:hash"}), \
                patch.object(run, "sql", return_value=SCHEMA):
            self.assertEqual(run.production_state()["revision"], SCHEMA)
        self.assertEqual(len(docker.call_args_list), 2)
        for call in docker.call_args_list:
            self.assertIn("--format", call.args)
            self.assertNotIn(".Config.Env", " ".join(call.args))

    def test_cleanup_rejects_foreign_resources(self):
        for labels in ({"tds.run": "foreign"}, None):
            with self.subTest(labels=labels):
                run = upgrade.Rehearsal("my-run")
                run.resources = [("container", "foreign")]
                with patch.object(run, "inspect", return_value={"Config": {"Labels": labels}}), \
                        patch.object(run, "docker", return_value=b"foreign\n") as docker:
                    with self.assertRaisesRegex(restore.DrillError, "cleanup_failed"):
                        run.cleanup()
                    self.assertEqual(len(docker.call_args_list), 1)
                    self.assertEqual(docker.call_args.args[:2], ("container", "ls"))

    def test_cleanup_skips_confirmed_absence_and_still_removes_database_and_network(self):
        run = upgrade.Rehearsal("my-run")
        run.resources = [("network", "net"), ("container", "db"), ("container", "uncreated")]

        def docker(*args, **kwargs):
            if args[1] == "ls":
                name = args[args.index("--filter") + 1].split("=", 1)[1]
                return b"" if name == "uncreated" else (name + "\n").encode()
            return b""

        def inspect(kind, name):
            labels = {"tds.purpose": upgrade.PURPOSE, "tds.run": "my-run"}
            return {"Labels": labels} if kind == "network" else {"Config": {"Labels": labels}}

        with patch.object(run, "docker", side_effect=docker) as commands, \
                patch.object(run, "inspect", side_effect=inspect) as inspections:
            run.cleanup()
        self.assertEqual([call.args for call in inspections.call_args_list], [("container", "db"), ("network", "net")])
        removals = [call.args for call in commands.call_args_list if call.args[1] == "rm"]
        self.assertEqual(removals, [("container", "rm", "--force", "db"), ("network", "rm", "net")])

    def test_cleanup_attempts_other_resources_after_inspection_failure(self):
        run = upgrade.Rehearsal("my-run")
        run.resources = [("network", "net"), ("container", "db")]

        def docker(*args, **kwargs):
            if args[1] == "ls":
                return (args[args.index("--filter") + 1].split("=", 1)[1] + "\n").encode()
            return b""

        def inspect(kind, name):
            if name == "db":
                raise restore.DrillError("synthetic_inspection_failure")
            return {"Labels": {"tds.purpose": upgrade.PURPOSE, "tds.run": "my-run"}}

        with patch.object(run, "docker", side_effect=docker) as commands, \
                patch.object(run, "inspect", side_effect=inspect):
            with self.assertRaisesRegex(restore.DrillError, "cleanup_failed"):
                run.cleanup()
        self.assertIn(("network", "rm", "net"), [call.args for call in commands.call_args_list])

    def test_candidate_image_requires_the_reviewed_commit_source_and_timestamp(self):
        labels = {"org.opencontainers.image.revision": "a" * 40,
                  "org.opencontainers.image.version": "a" * 40,
                  "org.opencontainers.image.source": upgrade.SOURCE,
                  "org.opencontainers.image.created": "2026-10-13T10:00:00+00:00"}
        run = upgrade.Rehearsal("test")
        with patch.object(run, "inspect", return_value={"Id": DIGEST, "Config": {"Labels": labels}}), \
                patch.object(restore, "read_git", side_effect=[b"a" * 40, b"2026-10-13T10:00:00+00:00"]):
            self.assertEqual(upgrade.image_identity(run, DIGEST, Path("/candidate")), DIGEST)
        for key in labels:
            bad = {**labels, key: "wrong"}
            with self.subTest(key=key), \
                    patch.object(run, "inspect", return_value={"Id": DIGEST, "Config": {"Labels": bad}}), \
                    patch.object(restore, "read_git", side_effect=[b"a" * 40, b"2026-10-13T10:00:00+00:00"]):
                with self.assertRaisesRegex(restore.DrillError, "provenance"):
                    upgrade.image_identity(run, DIGEST, Path("/candidate"))

    def test_client_operation_set_is_parsed_as_data_without_executing_source(self):
        source = b'raise RuntimeError("must not execute")\nAAB_14_OPERATIONS={"GET /courses"}\n'
        with patch.object(restore, "read_git", return_value=source):
            self.assertEqual(upgrade.required_operations(Path("/candidate")), {"GET /courses"})
        with patch.object(restore, "read_git", return_value=b'AAB_14_OPERATIONS=evil()'):
            with self.assertRaisesRegex(restore.DrillError, "contract_invalid"):
                upgrade.required_operations(Path("/candidate"))

    def test_real_artifact_provenance_gate_accepts_linked_completed_reports(self):
        # Exercise the real verifier, not a replacement implementation or booleans-only mock.
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            receipt_id = "20261013T100000Z-" + "d" * 32
            cipher = b"age-encryption.org/v1\n" + b"synthetic" * 30
            receipt = {"schema": 1, "owner": "tutor-tds-issue2-scheduled-v1", "id": receipt_id,
                       "key": f"postgres/scheduled/v1/{receipt_id}/archive.dump.age", "bucket": "tds-backups",
                       "status": "verified", "sha256": hashlib.sha256(cipher).hexdigest(), "bytes": len(cipher),
                       "completedAt": "2026-10-13T10:01:00Z", "day": "2026-10-13",
                       "source": "tutor-tds-api-db-1/tutor_tds", "sourceReadOnly": True,
                       "clientEncryption": "age", "privateKeyUsed": False, "restoreExecuted": False}
            receipt_path, archive, identity = root / "receipt.json", root / "archive.age", root / "identity"
            receipt_path.write_text(json.dumps(receipt))
            archive.write_bytes(cipher)
            identity.write_text("synthetic identity")
            identity.chmod(0o600)
            result, restored_at = self.run_rehearsal(FakeRehearsal())
            plaintext = bytearray(b"PGDMPsynthetic")
            with patch.object(restore, "candidate_identity", return_value=(TREE, SCHEMA)), \
                    patch.object(restore, "decrypt_dump", return_value=plaintext), \
                    patch.object(upgrade, "rehearse", return_value=(result, NOW - timedelta(minutes=1))), \
                    patch.object(restore, "utc_now", return_value=NOW):
                path = upgrade.execute(receipt_path, archive, identity, root, DIGEST, root)
            manifest = json.loads(path.read_text())
            self.assertNotEqual(manifest["status"], "passed")
            self.assertEqual(plaintext, bytearray(len(plaintext)))
            report_text = "".join(file.read_text() for file in path.parent.iterdir())
            self.assertNotIn("synthetic identity", report_text)
            self.assertNotIn("PGDMP", report_text)
            critical = {"status": "passed", "TRACK_B_DRILL": "PASS", "CRITICAL_VOLUMES_RESTORE": "PASS",
                        "restore": {"decrypted_sha256_equals_snapshot": True}, "executed_at": "2026-10-12T12:00:00Z"}
            payload = (json.dumps(critical) + "\n").encode()
            (path.parent / "critical.json").write_bytes(payload)
            manifest.update({"status": "passed", "offsite_backup": True, "postgres_restore": True,
                             "critical_volumes_restore": True, "upgrade_compatibility": True,
                             "backend_schema_compatibility": True})
            manifest["evidence"]["critical_volumes_restore"] = {"file": "critical.json", "sha256": hashlib.sha256(payload).hexdigest()}
            acceptance = path.parent / "acceptance.json"
            acceptance.write_text(json.dumps(manifest))
            verify(acceptance, path.parent, SCHEMA, TREE, NOW)

    def test_cli_requires_explicit_execute_before_any_operation(self):
        with patch.object(upgrade, "execute") as execute:
            status = upgrade.main(["--receipt", "r", "--archive", "a", "--identity", "i",
                                   "--candidate-root", "c", "--candidate-image", DIGEST, "--output-dir", "o"])
        self.assertEqual(status, 2)
        execute.assert_not_called()


if __name__ == "__main__":
    unittest.main()
