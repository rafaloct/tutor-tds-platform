"""Synthetic, offline tests for the opt-in scheduled PostgreSQL restore runner."""

from __future__ import annotations

from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import secrets
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from tooling import rehearse_scheduled_postgres_backup as drill
from tooling.verify_production_recovery_evidence import EvidenceError, _gate_claim


NOW = datetime(2026, 10, 12, 12, tzinfo=timezone.utc)
RECEIPT_ID = "20261011T100000Z-" + "a" * 32
CIPHER = b"age-encryption.org/v1\n" + b"test-ciphertext" * 20
PLAIN = b"PGDMPsynthetic-only"
REVISION = "20261007_0030"


def local_git(root: Path, *args: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(root), *args], stderr=subprocess.DEVNULL)


class ScheduledPostgresDrillTests(unittest.TestCase):
    def setUp(self) -> None:
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.receipt_path = self.root / "receipt.json"
        self.archive_path = self.root / "archive.dump.age"
        self.identity_path = self.root / "age-identity"
        self.output_dir = self.root / "reports"
        self.output_dir.mkdir()
        self.candidate = self.root / "candidate"
        versions = self.candidate / "api" / "migrations" / "versions"
        versions.mkdir(parents=True)
        (versions / "initial.py").write_text(
            f'revision = "{REVISION}"\ndown_revision = None\n', encoding="utf-8"
        )
        local_git(self.candidate, "init", "-q")
        local_git(self.candidate, "add", "api")
        local_git(self.candidate, "-c", "user.name=Test", "-c", "user.email=test@example.invalid",
                  "commit", "-qm", "synthetic candidate")
        self.api_tree = local_git(self.candidate, "rev-parse", "HEAD:api").decode().strip()
        self.archive_path.write_bytes(CIPHER)
        self.identity_path.write_text("fixture-identity-only\n", encoding="ascii")
        self.identity_path.chmod(0o600)
        self.receipt = {
            "schema": 1, "owner": "tutor-tds-issue2-scheduled-v1", "id": RECEIPT_ID,
            "key": f"postgres/scheduled/v1/{RECEIPT_ID}/archive.dump.age",
            "bucket": "tds-backups", "status": "verified",
            "sha256": hashlib.sha256(CIPHER).hexdigest(), "bytes": len(CIPHER),
            "completedAt": "2026-10-11T10:01:00.000Z", "day": "2026-10-11",
            "source": "tutor-tds-api-db-1/tutor_tds", "sourceReadOnly": True,
            "clientEncryption": "age", "privateKeyUsed": False,
            "restoreExecuted": False,
        }
        self.save_receipt()

    def save_receipt(self) -> None:
        self.receipt_path.write_text(json.dumps(self.receipt), encoding="utf-8")

    def test_receipt_cipher_and_candidate_are_bound_to_partial_report(self) -> None:
        result = {"postgres_image_id": "sha256:" + "b" * 64,
                  "postgres_version_num": "160010", "restored_schema_version": REVISION}
        plaintext = bytearray(PLAIN)
        with patch.object(drill, "decrypt_dump", return_value=plaintext), \
                patch.object(drill, "restore_disposable", return_value=result):
            manifest_path = drill.execute(self.receipt_path, self.archive_path,
                                          self.identity_path, self.candidate,
                                          self.output_dir, now=NOW)
        manifest = json.loads(manifest_path.read_text())
        self.assertEqual(manifest["status"], "restore_verified_pending_upgrade")
        self.assertEqual(manifest["candidate_api_tree_oid"], self.api_tree)
        self.assertEqual(manifest["candidate_schema_version"], REVISION)
        self.assertEqual(plaintext, bytearray(len(PLAIN)))
        offsite_ref = manifest["evidence"]["offsite_backup"]
        offsite_file = manifest_path.parent / offsite_ref["file"]
        self.assertEqual(hashlib.sha256(offsite_file.read_bytes()).hexdigest(),
                         offsite_ref["sha256"])
        offsite = json.loads(offsite_file.read_text())
        _gate_claim("offsite_backup", offsite, REVISION, self.api_tree)
        postgres_ref = manifest["evidence"]["postgres_restore_partial"]
        postgres = json.loads((manifest_path.parent / postgres_ref["file"]).read_text())
        self.assertEqual(postgres["source_backup"]["plaintext_sha256"],
                         offsite["restore_drill"]["decrypted_dump_sha256"])
        with self.assertRaisesRegex(EvidenceError, "not passed"):
            _gate_claim("postgres_restore", postgres, REVISION, self.api_tree)
        report_text = "".join(path.read_text() for path in manifest_path.parent.iterdir())
        self.assertNotIn(str(self.identity_path), report_text)
        self.assertNotIn("fixture-identity-only", report_text)
        self.assertNotIn("PGDMP", report_text)

    def test_receipt_duplicate_origin_and_future_are_rejected(self) -> None:
        self.receipt_path.write_text('{"schema":1,"schema":1}', encoding="utf-8")
        with self.assertRaisesRegex(drill.DrillError, "duplicate"):
            drill.load_receipt(self.receipt_path, NOW)
        self.receipt["sourceReadOnly"] = False
        self.save_receipt()
        with self.assertRaisesRegex(drill.DrillError, "origin"):
            drill.load_receipt(self.receipt_path, NOW)
        self.receipt["sourceReadOnly"] = True
        self.receipt["completedAt"] = "2026-10-13T10:01:00.000Z"
        self.receipt["day"] = "2026-10-13"
        self.save_receipt()
        with self.assertRaisesRegex(drill.DrillError, "day_or_clock"):
            drill.load_receipt(self.receipt_path, NOW)
        self.receipt["completedAt"] = "2026-10-11T10:01:00.000Z"
        self.receipt["day"] = "2026-10-11"
        later_id = "20261011T230000Z-" + "b" * 32
        self.receipt["id"] = later_id
        self.receipt["key"] = f"postgres/scheduled/v1/{later_id}/archive.dump.age"
        self.save_receipt()
        with self.assertRaisesRegex(drill.DrillError, "day_or_clock"):
            drill.load_receipt(self.receipt_path, NOW)

    def test_cipher_integrity_age_header_and_identity_permissions(self) -> None:
        receipt = drill.load_receipt(self.receipt_path, NOW)
        self.archive_path.write_bytes(CIPHER[:-1] + b"X")
        with self.assertRaisesRegex(drill.DrillError, "hash_mismatch"):
            drill.load_cipher(self.archive_path, receipt)
        self.archive_path.write_bytes(CIPHER)
        self.receipt["sha256"] = hashlib.sha256(b"different").hexdigest()
        self.save_receipt()
        with self.assertRaisesRegex(drill.DrillError, "hash_mismatch"):
            drill.load_cipher(self.archive_path, drill.load_receipt(self.receipt_path, NOW))
        self.receipt["sha256"] = hashlib.sha256(CIPHER).hexdigest()
        self.save_receipt()
        self.identity_path.chmod(0o644)
        with self.assertRaisesRegex(drill.DrillError, "permissions_invalid"):
            drill.regular_file(self.identity_path, private=True)

    def test_decrypt_requires_pg_custom_dump(self) -> None:
        if os.name != "posix":
            self.skipTest("private age identity requires a POSIX host")
        with patch.object(drill, "command", return_value=b"not-a-pg-dump") as command:
            with self.assertRaisesRegex(drill.DrillError, "not_pg_custom"):
                drill.decrypt_dump(CIPHER, self.identity_path, "age")
        self.assertEqual(command.call_args.args[0],
                         ["age", "--decrypt", "--identity", str(self.identity_path)])
        self.assertEqual(command.call_args.kwargs["input_bytes"], CIPHER)

    def test_failed_restore_emits_no_report_and_zeroes_buffer(self) -> None:
        plaintext = bytearray(PLAIN)
        with patch.object(drill, "decrypt_dump", return_value=plaintext), \
                patch.object(drill, "restore_disposable",
                             side_effect=drill.DrillError("synthetic_restore_failed")):
            with self.assertRaisesRegex(drill.DrillError, "synthetic_restore_failed"):
                drill.execute(self.receipt_path, self.archive_path, self.identity_path,
                              self.candidate, self.output_dir, now=NOW)
        self.assertEqual(plaintext, bytearray(len(PLAIN)))
        self.assertEqual(list(self.output_dir.iterdir()), [])

    def test_dirty_candidate_and_symlink_inputs_are_rejected(self) -> None:
        (self.candidate / "api" / "changed.py").write_text("dirty\n")
        with self.assertRaisesRegex(drill.DrillError, "dirty"):
            drill.candidate_identity(self.candidate)
        link = self.root / "archive-link.age"
        try:
            link.symlink_to(self.archive_path)
        except (OSError, NotImplementedError):
            self.skipTest("symlinks are unavailable")
        with self.assertRaisesRegex(drill.DrillError, "regular_file"):
            drill.load_cipher(link, drill.load_receipt(self.receipt_path, NOW))

    def test_ambiguous_docker_run_output_only_removes_owned_container(self) -> None:
        image_id = "sha256:" + "a" * 64
        container_id = "b" * 64
        commands: list[list[str]] = []

        def fake_command(args: list[str], **_kwargs: object) -> bytes:
            commands.append(args)
            if args[1:3] == ["image", "inspect"]:
                return image_id.encode()
            if args[1] == "run":
                return b"truncated-id"
            if args[1:4] == ["inspect", "--format", "{{.Id}}"]:
                return container_id.encode()
            if args[1:4] == ["inspect", "--format", "{{json .Config.Labels}}"]:
                return json.dumps({"tds.purpose": "scheduled-offsite-restore",
                                   "tds.run": "synthetic-run"}).encode()
            if args[1] == "rm":
                return container_id.encode()
            self.fail(f"unexpected Docker command: {args}")

        with patch.object(drill, "command", side_effect=fake_command):
            with self.assertRaisesRegex(drill.DrillError, "identity_invalid"):
                drill.restore_disposable(bytearray(PLAIN), "docker", "synthetic-run", 256)
        run = next(args for args in commands if args[1] == "run")
        self.assertEqual(run[-1], image_id)
        self.assertIn(["docker", "rm", "--force", container_id], commands)

    def test_cleanup_refuses_container_with_foreign_labels(self) -> None:
        commands: list[list[str]] = []

        def fake_command(args: list[str], **_kwargs: object) -> bytes:
            commands.append(args)
            if args[1:4] == ["inspect", "--format", "{{.Id}}"]:
                return ("b" * 64).encode()
            if args[1:4] == ["inspect", "--format", "{{json .Config.Labels}}"]:
                return b'{"tds.purpose":"scheduled-offsite-restore","tds.run":"someone-else"}'
            self.fail(f"unexpected Docker command: {args}")

        with patch.object(drill, "command", side_effect=fake_command):
            with self.assertRaisesRegex(drill.DrillError, "ownership_unverified"):
                drill.remove_owned_container("docker", "tds-offsite-drill-test", "our-run")
        self.assertFalse(any(args[1] == "rm" for args in commands))

    @unittest.skipUnless(os.environ.get("TDS_RUN_DOCKER_RESTORE_TESTS") == "1",
                         "synthetic Docker integration is opt-in")
    def test_docker_restore_is_networkless_tmpfs_and_cleans_on_success_or_failure(self) -> None:
        docker = "docker"
        source_name = "tds-synthetic-source-" + secrets.token_hex(6)
        source_id = drill.command([
            docker, "run", "--detach", "--pull=never", "--rm", "--name", source_name,
            "--network", "none", "--tmpfs", "/var/lib/postgresql/data:rw,size=256m",
            "--env", "POSTGRES_HOST_AUTH_METHOD=trust", "--env", "POSTGRES_USER=tds_restore",
            "--env", "POSTGRES_DB=tds_restore", drill.POSTGRES_IMAGE,
        ]).decode().strip()
        try:
            for _ in range(40):
                try:
                    drill.command([docker, "exec", source_id, "pg_isready", "-h",
                                   "127.0.0.1", "-U", "tds_restore"], timeout=5)
                    break
                except drill.DrillError:
                    import time
                    time.sleep(1)
            else:
                self.fail("synthetic source PostgreSQL did not start")
            ddl = (
                "CREATE TABLE alembic_version (version_num varchar(32) NOT NULL); "
                f"INSERT INTO alembic_version VALUES ('{REVISION}'); "
                "CREATE TABLE users (id integer); CREATE TABLE courses (id integer); "
                "CREATE TABLE learning_events (id integer);"
            )
            drill.command([docker, "exec", source_id, "psql", "-U", "tds_restore",
                           "-d", "tds_restore", "-v", "ON_ERROR_STOP=1", "-c", ddl])
            dump = bytearray(drill.command([docker, "exec", source_id, "pg_dump", "-U",
                                            "tds_restore", "-d", "tds_restore",
                                            "--format=custom", "--no-owner", "--no-privileges"]))
        finally:
            drill.command([docker, "rm", "--force", source_id])
        self.assertTrue(dump.startswith(b"PGDMP"))
        good_run = secrets.token_hex(8)
        restored = drill.restore_disposable(dump, docker, good_run, 256)
        self.assertEqual(restored["restored_schema_version"], REVISION)
        self.assertFalse(drill.command([docker, "ps", "-aq", "--filter",
                                        f"label=tds.run={good_run}"]).strip())
        bad_run = secrets.token_hex(8)
        with self.assertRaises(drill.DrillError):
            drill.restore_disposable(bytearray(b"PGDMPinvalid"), docker, bad_run, 256)
        self.assertFalse(drill.command([docker, "ps", "-aq", "--filter",
                                        f"label=tds.run={bad_run}"]).strip())


if __name__ == "__main__":
    unittest.main()
