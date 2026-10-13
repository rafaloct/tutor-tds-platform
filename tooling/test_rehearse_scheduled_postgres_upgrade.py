"""Synthetic release-proof tests; no production, R2 or real age key is contacted."""
from __future__ import annotations

from datetime import datetime, timedelta, timezone
from copy import deepcopy
import hashlib
import io
import json
import os
from pathlib import Path
import tempfile
import tarfile
import subprocess
import unittest
from unittest.mock import patch

from tooling import rehearse_scheduled_postgres_upgrade as upgrade
from tooling import rehearse_scheduled_postgres_backup as restore
from tooling.verify_production_recovery_evidence import verify


DIGEST = "sha256:" + "b" * 64
SCHEMA = "20261007_0030"
TREE = "a" * 40
NOW = datetime(2026, 10, 13, 12, tzinfo=timezone.utc)


def column(table, name, *, default=None, nullable=True):
    return {"table_name": table, "column_name": name, "position": 1,
            "type": "character varying(36)", "not_null": not nullable,
            "default_expr": default, "collation": "pg_catalog.default",
            "identity": "", "generated": ""}


def schema_fixture():
    return {"columns": {"users.id": column("users", "id", nullable=False)},
            "constraints": {"users.users_pkey": {"table_name": "users", "name": "users_pkey",
                             "type": "p", "definition": "PRIMARY KEY (id)", "validated": True,
                             "deferrable": False, "deferred": False, "match_type": " ",
                             "check_expr": None, "columns": ["id"]}},
            "indexes": {"users.users_pkey": {"table_name": "users", "name": "users_pkey",
                         "definition": "CREATE UNIQUE INDEX users_pkey ON public.users USING btree (id)",
                         "unique_index": True, "primary_index": True, "valid": True, "ready": True,
                         "nulls_not_distinct": False, "expressions": None, "predicate": None,
                         "columns": ["id"]}}}


def source_tar(root, files, *, extra=None):
    payload = io.BytesIO()
    with tarfile.open(fileobj=payload, mode="w") as archive:
        for path, content in files.items():
            if path != root and not path.startswith(root + "/"):
                continue
            info = tarfile.TarInfo(path)
            info.size, info.mode = len(content), 0o644
            archive.addfile(info, io.BytesIO(content))
        if extra is not None:
            archive.addfile(extra)
    return payload.getvalue()


class FakeRehearsal(upgrade.Rehearsal):
    def __init__(self, failure: str = "") -> None:
        super().__init__("synthetic-run")
        self.failure = failure
        self.calls: list[tuple] = []
        self.state_reads = 0
        self.fingerprint_reads = 0
        self.metadata_reads = 0
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
            return {"Id": name if name.startswith("sha256:") else DIGEST}
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

    def schema_metadata(self, container):
        self.metadata_reads += 1
        metadata = schema_fixture()
        if self.failure == "metadata" and self.metadata_reads > 1:
            metadata["columns"]["users.id"]["type"] = "character varying(4)"
        return metadata

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
        self.calls.append(("start_api", name, image))
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
    def run_rehearsal(self, fake, rollback_image=None):
        dump = bytearray(b"PGDMPsynthetic")
        with patch.object(upgrade, "image_identity", return_value={"image_id": DIGEST, "api_tree_oid": TREE}), \
                patch.object(upgrade, "required_operations", return_value={"GET /courses"}), \
                patch.object(restore, "candidate_identity", return_value=(TREE, SCHEMA)):
            record, when = upgrade.rehearse(dump, Path("/synthetic"), DIGEST, fake, TREE, SCHEMA, 1024, rollback_image)
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
        for failure in ("restore", "migration", "revision", "data", "metadata", "rollback", "production", "catalog", "egress"):
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
                patch.object(restore, "read_git", side_effect=[b"a" * 40, b"2026-10-13T10:00:00+00:00"]), \
                patch.object(upgrade, "materialized_source_identity", return_value={"image_id": DIGEST}):
            self.assertEqual(upgrade.image_identity(run, DIGEST, Path("/candidate"))["image_id"], DIGEST)
        for key in labels:
            bad = {**labels, key: "wrong"}
            with self.subTest(key=key), \
                    patch.object(run, "inspect", return_value={"Id": DIGEST, "Config": {"Labels": bad}}), \
                    patch.object(restore, "read_git", side_effect=[b"a" * 40, b"2026-10-13T10:00:00+00:00"]):
                with self.assertRaisesRegex(restore.DrillError, "provenance"):
                    upgrade.image_identity(run, DIGEST, Path("/candidate"))

    def test_matching_oci_labels_do_not_authorize_stale_or_extra_image_source(self):
        files = {"app/main.py": b"reviewed API", "migrations/env.py": b"reviewed migration",
                 "alembic.ini": b"reviewed configuration", "pyproject.toml": b"reviewed dependencies",
                 "uv.lock": b"reviewed dependency lock"}
        expected = {name: {"sha256": hashlib.sha256(data).hexdigest(), "executable": False}
                    for name, data in files.items()}
        labels = {"org.opencontainers.image.revision": TREE, "org.opencontainers.image.version": TREE,
                  "org.opencontainers.image.source": upgrade.SOURCE,
                  "org.opencontainers.image.created": "2026-10-13T10:00:00+00:00"}
        for change in ("none", "stale", "extra", "missing"):
            actual = dict(files)
            if change == "stale":
                actual["app/main.py"] = b"uncommitted API with matching labels"
            elif change == "extra":
                actual["app/untracked.py"] = b"unreviewed module"
            elif change == "missing":
                actual.pop("app/main.py")
            run = upgrade.Rehearsal("source-proof")
            name = "tds-offsite-upgrade-source-proof-source"

            def docker(*args, **kwargs):
                if args[0] == "cp":
                    return source_tar(args[1].rsplit("/", 1)[1], actual)
                if args[:2] == ("container", "ls"):
                    return (name + "\n").encode()
                return b""

            def inspect(kind, target):
                return {"Id": DIGEST, "Config": {"Labels": labels}} if kind == "image" else \
                    {"Config": {"Labels": {"tds.purpose": upgrade.PURPOSE, "tds.run": run.run_id}}}

            with self.subTest(change=change), patch.object(run, "docker", side_effect=docker) as calls, \
                    patch.object(run, "inspect", side_effect=inspect), \
                    patch.object(upgrade, "committed_image_sources", return_value=expected), \
                    patch.object(restore, "read_git", side_effect=[TREE.encode(), b"2026-10-13T10:00:00+00:00", TREE.encode()]):
                if change == "none":
                    proof = upgrade.image_identity(run, DIGEST, Path("/candidate"))
                    self.assertTrue(proof["tracked_source_bytes_verified"])
                    self.assertEqual(proof["source_file_count"], len(files))
                    self.assertEqual(proof["materialized_sources_sha256"], upgrade.canonical_sha256(expected))
                else:
                    with self.assertRaises(restore.DrillError):
                        upgrade.image_identity(run, DIGEST, Path("/candidate"))
            commands = [call.args for call in calls.call_args_list]
            self.assertTrue(any(args[:2] == ("container", "rm") for args in commands))
            self.assertFalse(any(args[0] in {"run", "start", "exec"} for args in commands))

    def test_image_source_archive_rejects_links_traversal_and_duplicate_paths(self):
        for name, kind in (("app/main.py", tarfile.SYMTYPE), ("app/../escape", tarfile.REGTYPE),
                           ("app/main.py", tarfile.REGTYPE), ("other/main.py", tarfile.REGTYPE)):
            extra = tarfile.TarInfo(name)
            extra.type, extra.linkname = kind, "/outside"
            with self.subTest(name=name, kind=kind), self.assertRaises(restore.DrillError):
                upgrade.archive_sources(source_tar("app", {"app/main.py": b"reviewed"}, extra=extra), "app")

    def test_committed_source_manifest_reads_git_blobs_instead_of_working_files(self):
        paths = ["app/main.py", "migrations/env.py", "alembic.ini", "pyproject.toml", "uv.lock"]
        oids = {f"{index:040x}": path for index, path in enumerate(paths, 1)}
        listing = b"".join(f"100644 blob {oid}\tapi/{path}\0".encode() for oid, path in oids.items())

        def git(candidate, *args):
            if args[0] == "ls-tree":
                return listing
            self.assertEqual(args[:2], ("cat-file", "blob"))
            return ("committed " + oids[args[2]]).encode()

        with patch.object(restore, "read_git", side_effect=git):
            actual = upgrade.committed_image_sources(Path("/dirty-worktree"))
        self.assertEqual(set(actual), set(paths))
        self.assertEqual(actual["app/main.py"]["sha256"], hashlib.sha256(b"committed app/main.py").hexdigest())

    def test_column_constraint_and_index_changes_fail_even_when_rows_are_unchanged(self):
        before = schema_fixture()
        for kind, field, value in (
            ("columns", "type", "character varying(4)"), ("columns", "not_null", False),
            ("columns", "default_expr", "'different'::text"), ("columns", "collation", "pg_catalog.C"),
            ("columns", "identity", "a"), ("columns", "generated", "s"),
            ("constraints", "definition", "UNIQUE (id)"), ("constraints", "validated", False),
            ("constraints", "deferrable", True), ("indexes", "definition", "different index"),
            ("indexes", "nulls_not_distinct", True),
        ):
            after = deepcopy(before)
            first = next(iter(after[kind].values()))
            first[field] = value
            with self.subTest(kind=kind, field=field), self.assertRaisesRegex(restore.DrillError, "existing_schema_metadata"):
                upgrade.compare_schema_metadata(before, after, upgrade.Rehearsal("schema"), "clone")
        for kind in before:
            after = deepcopy(before)
            after[kind].clear()
            with self.subTest(removed=kind), self.assertRaises(restore.DrillError):
                upgrade.compare_schema_metadata(before, after, upgrade.Rehearsal("schema"), "clone")

    def test_added_legacy_defaults_and_nullable_context_constraints_are_checked(self):
        before = {"columns": {"attempts.owner_id": column("attempts", "owner_id", nullable=False)},
                  "constraints": {}, "indexes": {}}
        after = deepcopy(before)
        after["columns"].update({"attempts.origin": column("attempts", "origin", default="'practice'", nullable=False),
                                 "attempts.version_id": column("attempts", "version_id")})
        after["constraints"] = {
            "attempts.origin_check": {"table_name": "attempts", "name": "origin_check", "type": "c",
                                       "columns": ["origin"], "check_expr": "origin IN ('practice','published_block')"},
            "attempts.context_fk": {"table_name": "attempts", "name": "context_fk", "type": "f",
                                     "columns": ["owner_id", "version_id"], "match_type": "s"},
        }
        after["indexes"] = {"attempts.context_unique": {"table_name": "attempts", "name": "context_unique",
                                                        "columns": ["owner_id", "version_id"], "unique_index": True,
                                                        "valid": True, "ready": True, "expressions": None,
                                                        "nulls_not_distinct": False}}
        run = upgrade.Rehearsal("schema")
        with patch.object(run, "sql", return_value="t") as queries:
            comparison = upgrade.compare_schema_metadata(before, after, run, "clone")
        self.assertTrue(comparison["existing_objects_preserved"])
        self.assertTrue(comparison["legacy_omitted_fields_accepted"])
        self.assertEqual(len(queries.call_args_list), 2)
        self.assertIn("IS NOT FALSE", queries.call_args.args[1])
        for change in ("missing_default", "check_old_column", "fk_old_columns", "fk_match_full", "unique_old_columns", "nulls_not_distinct"):
            bad = deepcopy(after)
            if change == "missing_default":
                bad["columns"]["attempts.origin"]["default_expr"] = None
            elif change == "check_old_column":
                bad["constraints"]["attempts.origin_check"]["columns"] = ["owner_id"]
            elif change == "fk_old_columns":
                bad["constraints"]["attempts.context_fk"]["columns"] = ["owner_id"]
            elif change == "fk_match_full":
                bad["constraints"]["attempts.context_fk"]["match_type"] = "f"
            elif change == "unique_old_columns":
                bad["indexes"]["attempts.context_unique"]["columns"] = ["owner_id"]
            else:
                bad["indexes"]["attempts.context_unique"]["nulls_not_distinct"] = True
            with self.subTest(change=change), patch.object(run, "sql", return_value="t"), \
                    self.assertRaises(restore.DrillError):
                upgrade.compare_schema_metadata(before, bad, run, "clone")
        with patch.object(run, "sql", side_effect=["t", "f"]), self.assertRaisesRegex(restore.DrillError, "constraint_breaks"):
            upgrade.compare_schema_metadata(before, after, run, "clone")
        nullable_default = deepcopy(after)
        nullable_default["columns"]["attempts.version_id"]["default_expr"] = "failing_function()"

        def default_probe(database, query):
            if "failing_function()" in query:
                raise restore.DrillError("synthetic_default_failure")
            return "t"

        with patch.object(run, "sql", side_effect=default_probe), self.assertRaisesRegex(restore.DrillError, "default_failure"):
            upgrade.compare_schema_metadata(before, nullable_default, run, "clone")

    def test_explicit_prior_image_is_tested_after_production_was_promoted(self):
        prior = "sha256:" + "c" * 64
        fake = FakeRehearsal()
        record, _ = self.run_rehearsal(fake, prior)
        self.assertEqual(record["production_image_id"], DIGEST)
        self.assertEqual(record["rollback_image_id"], prior)
        self.assertTrue(any(args[0] == "start_api" and args[1].endswith("-old") and args[2] == prior
                            for args in fake.calls))
        with self.assertRaisesRegex(restore.DrillError, "rollback_image_invalid"):
            self.run_rehearsal(FakeRehearsal(), "mutable-image:latest")

    def test_runbook_stops_before_sudo_if_reviewed_source_was_modified(self):
        text = (Path(__file__).resolve().parents[1] / "docs/production/SCHEDULED_POSTGRES_RESTORE_DRILL.md").read_text()
        block = text.split("Instalar **ambos**", 1)[1].split("```sh\n", 1)[1].split("```", 1)[0]
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "tooling").mkdir()
            for script in ("rehearse_scheduled_postgres_backup.py", "rehearse_scheduled_postgres_upgrade.py"):
                (root / "tooling" / script).write_text("print('reviewed')\n")
            subprocess.run(["git", "init", "-q"], cwd=root, check=True)
            subprocess.run(["git", "add", "tooling"], cwd=root, check=True)
            subprocess.run(["git", "-c", "user.name=Synthetic", "-c", "user.email=fixture@example.invalid",
                            "commit", "-qm", "reviewed fixture"], cwd=root, check=True)
            (root / "tooling/rehearse_scheduled_postgres_backup.py").write_text("print('unreviewed')\n")
            bin_dir = root / "bin"
            bin_dir.mkdir()
            marker = root / "sudo-called"
            fake_sudo = bin_dir / "sudo"
            fake_sudo.write_text('#!/bin/sh\nprintf called > "$TDS_SUDO_MARKER"\nexit 91\n')
            fake_sudo.chmod(0o755)
            env = {**os.environ, "PATH": str(bin_dir) + os.pathsep + os.environ["PATH"],
                   "TDS_SUDO_MARKER": str(marker)}
            result = subprocess.run(["sh", "-c", block], cwd=root, env=env, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(marker.exists())

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
