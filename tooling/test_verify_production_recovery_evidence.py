"""Offline regression tests for the production restore evidence gate."""

from __future__ import annotations

import hashlib
from datetime import datetime, timezone
import json
from pathlib import Path
import tempfile
import unittest

from tooling.verify_production_recovery_evidence import EvidenceError, GATES, verify


SCHEMA = "20261007_0030"
API_TREE = "b" * 40
CIPHER_HASH = "a" * 64
PLAINTEXT_HASH = "b" * 64
RECEIPT_ID = "20261010T100000Z-" + "c" * 32
OBJECT_KEY = f"postgres/scheduled/v1/{RECEIPT_ID}/archive.dump.age"
NOW = datetime(2026, 10, 12, 12, tzinfo=timezone.utc)


class RecoveryProvenanceTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.evidence_dir = Path(self.temporary.name) / "docs" / "production" / "evidence"
        self.evidence_dir.mkdir(parents=True)
        self.acceptance_path = self.evidence_dir / "production-restore-acceptance.json"
        self.records = {
            "scheduled-postgres.json": {
                "status": "passed",
                "scope": "postgres-prod-scheduled",
                "offsite": {
                    "uploaded_sha256": CIPHER_HASH,
                    "downloaded_sha256": CIPHER_HASH,
                },
                "isolated_restore_from_offsite_verified": True,
                "scheduled_receipt": {
                    "schema": 1,
                    "owner": "tutor-tds-issue2-scheduled-v1",
                    "id": RECEIPT_ID,
                    "key": OBJECT_KEY,
                    "bucket": "tds-backups",
                    "status": "verified",
                    "sha256": CIPHER_HASH,
                    "completedAt": "2026-10-10T10:00:00.000Z",
                    "day": "2026-10-10",
                    "source": "tutor-tds-api-db-1/tutor_tds",
                    "sourceReadOnly": True,
                    "clientEncryption": "age",
                    "privateKeyUsed": False,
                    "restoreExecuted": False,
                },
                "restore_drill": {
                    "source_receipt_id": RECEIPT_ID,
                    "source_object_key": OBJECT_KEY,
                    "source_cipher_sha256": CIPHER_HASH,
                    "decrypted_dump_sha256": PLAINTEXT_HASH,
                    "restored_at": "2026-10-11T11:00:00Z",
                },
            },
            "postgres-rehearsal.json": {
                "status": "passed",
                "run_id": "rehearsal-20261011",
                "completed_at": "2026-10-11T11:30:00Z",
                "api_tree_oid": API_TREE,
                "source_backup": {
                    "receipt_id": RECEIPT_ID,
                    "object_key": OBJECT_KEY,
                    "plaintext_sha256": PLAINTEXT_HASH,
                },
                "backup": {"sha256": PLAINTEXT_HASH},
                "restore_verified": True,
                "clone_revision": SCHEMA,
                "production_unchanged": True,
                "old_image_runs_on_upgraded_database": True,
                "public_catalog_compatible": True,
                "original_columns_preserved": True,
                "openapi_comparison": {
                    "only_production": [], "aab_14_missing_in_candidate": []
                },
            },
            "anythingllm-drill.json": {
                "status": "passed",
                "executed_at": "2026-10-06T03:15:00Z",
                "TRACK_B_DRILL": "PASS",
                "CRITICAL_VOLUMES_RESTORE": "PASS",
                "restore": {"decrypted_sha256_equals_snapshot": True},
            },
        }
        filenames = {
            "offsite_backup": "scheduled-postgres.json",
            "postgres_restore": "postgres-rehearsal.json",
            "critical_volumes_restore": "anythingllm-drill.json",
            "upgrade_compatibility": "postgres-rehearsal.json",
            "backend_schema_compatibility": "postgres-rehearsal.json",
        }
        self.acceptance = {
            "status": "passed",
            **{gate: True for gate in GATES},
            "candidate_schema_version": SCHEMA,
            "candidate_api_tree_oid": API_TREE,
            "evidence": {gate: {"file": name} for gate, name in filenames.items()},
        }
        self.save()

    def save(self) -> None:
        for name, record in self.records.items():
            (self.evidence_dir / name).write_text(
                json.dumps(record, sort_keys=True), encoding="utf-8"
            )
        for reference in self.acceptance["evidence"].values():
            raw = (self.evidence_dir / reference["file"]).read_bytes()
            reference["sha256"] = hashlib.sha256(raw).hexdigest()
        self.acceptance_path.write_text(
            json.dumps(self.acceptance, sort_keys=True), encoding="utf-8"
        )

    def check(self) -> None:
        verify(self.acceptance_path, self.evidence_dir, SCHEMA, API_TREE, now=NOW)

    def test_versioned_evidence_can_support_each_gate(self) -> None:
        self.check()

    def test_current_bare_boolean_acceptance_fails_closed(self) -> None:
        bare = {"status": "passed", **{gate: True for gate in GATES}}
        self.acceptance_path.write_text(json.dumps(bare), encoding="utf-8")
        with self.assertRaisesRegex(EvidenceError, "schema"):
            self.check()

    def test_stale_candidate_or_rehearsal_schema_fails(self) -> None:
        self.acceptance["candidate_schema_version"] = "20261006_0029"
        self.save()
        with self.assertRaisesRegex(EvidenceError, "schema"):
            self.check()
        self.acceptance["candidate_schema_version"] = SCHEMA
        self.records["postgres-rehearsal.json"]["clone_revision"] = "20261006_0029"
        self.save()
        with self.assertRaisesRegex(EvidenceError, "stale"):
            self.check()

    def test_changed_or_missing_evidence_fails(self) -> None:
        path = self.evidence_dir / "postgres-rehearsal.json"
        path.write_bytes(path.read_bytes() + b" ")
        with self.assertRaisesRegex(EvidenceError, "hash"):
            self.check()
        path.unlink()
        with self.assertRaisesRegex(EvidenceError, "missing"):
            self.check()

    def test_track_b_alone_cannot_claim_postgres_backup(self) -> None:
        for gate in GATES:
            self.acceptance["evidence"][gate]["file"] = "anythingllm-drill.json"
        self.save()
        with self.assertRaisesRegex(EvidenceError, "offsite scope"):
            self.check()

    def test_scheduled_backup_must_be_restored_from_offsite(self) -> None:
        self.records["scheduled-postgres.json"]["isolated_restore_from_offsite_verified"] = False
        self.save()
        with self.assertRaisesRegex(EvidenceError, "not restored"):
            self.check()
        self.records["scheduled-postgres.json"]["isolated_restore_from_offsite_verified"] = True
        self.records["scheduled-postgres.json"]["offsite"]["downloaded_sha256"] = "d" * 64
        self.save()
        with self.assertRaisesRegex(EvidenceError, "hashes"):
            self.check()

    def test_native_receipt_identity_and_cipher_hash_are_required(self) -> None:
        receipt = self.records["scheduled-postgres.json"]["scheduled_receipt"]
        receipt["key"] = "postgres/scheduled/v1/unrelated/archive.dump.age"
        self.save()
        with self.assertRaisesRegex(EvidenceError, "native backup stream"):
            self.check()
        receipt["key"] = OBJECT_KEY
        receipt["sha256"] = PLAINTEXT_HASH
        self.save()
        with self.assertRaisesRegex(EvidenceError, "native backup stream"):
            self.check()

    def test_postgres_rehearsal_must_use_restored_offsite_dump(self) -> None:
        source = self.records["postgres-rehearsal.json"]["source_backup"]
        source["receipt_id"] = "20261010T100000Z-" + "d" * 32
        self.save()
        with self.assertRaisesRegex(EvidenceError, "differs from the offsite"):
            self.check()
        source["receipt_id"] = RECEIPT_ID
        source["plaintext_sha256"] = CIPHER_HASH
        self.records["postgres-rehearsal.json"]["backup"]["sha256"] = CIPHER_HASH
        self.save()
        with self.assertRaisesRegex(EvidenceError, "differs from the offsite"):
            self.check()

    def test_postgres_claims_must_use_one_rehearsal(self) -> None:
        self.records["other-rehearsal.json"] = {
            **self.records["postgres-rehearsal.json"], "run_id": "unrelated-run"
        }
        self.acceptance["evidence"]["upgrade_compatibility"]["file"] = "other-rehearsal.json"
        self.save()
        with self.assertRaisesRegex(EvidenceError, "one rehearsal"):
            self.check()

    def test_candidate_api_tree_is_bound_to_rehearsal(self) -> None:
        self.acceptance["candidate_api_tree_oid"] = "c" * 40
        self.save()
        with self.assertRaisesRegex(EvidenceError, "acceptance API tree"):
            self.check()
        self.acceptance["candidate_api_tree_oid"] = API_TREE
        self.records["postgres-rehearsal.json"]["api_tree_oid"] = "c" * 40
        self.save()
        with self.assertRaisesRegex(EvidenceError, "candidate API tree"):
            self.check()

    def test_drills_older_than_30_days_are_rejected(self) -> None:
        verify_time = datetime(2026, 11, 11, 12, tzinfo=timezone.utc)
        with self.assertRaisesRegex(EvidenceError, "older than 30 days"):
            verify(self.acceptance_path, self.evidence_dir, SCHEMA, API_TREE,
                   now=verify_time)
        self.records["anythingllm-drill.json"]["executed_at"] = "2026-09-10T03:15:00Z"
        self.save()
        with self.assertRaisesRegex(EvidenceError, "critical volume drill is older"):
            self.check()

    def test_future_or_out_of_order_drills_are_rejected(self) -> None:
        drill = self.records["scheduled-postgres.json"]["restore_drill"]
        drill["restored_at"] = "2026-10-09T11:00:00Z"
        self.save()
        with self.assertRaisesRegex(EvidenceError, "out of order"):
            self.check()
        drill["restored_at"] = "2026-10-13T11:00:00Z"
        self.records["postgres-rehearsal.json"]["completed_at"] = "2026-10-13T11:30:00Z"
        self.save()
        with self.assertRaisesRegex(EvidenceError, "future"):
            self.check()

    def test_clock_skew_allows_only_five_minutes(self) -> None:
        volume = self.records["anythingllm-drill.json"]
        volume["executed_at"] = "2026-10-12T12:05:00Z"
        self.save()
        self.check()
        volume["executed_at"] = "2026-10-12T12:05:01Z"
        self.save()
        with self.assertRaisesRegex(EvidenceError, "critical volume drill is in the future"):
            self.check()

    def test_false_compatibility_claim_fails(self) -> None:
        self.records["postgres-rehearsal.json"]["old_image_runs_on_upgraded_database"] = False
        self.save()
        with self.assertRaisesRegex(EvidenceError, "compatibility"):
            self.check()

    def test_path_traversal_is_rejected(self) -> None:
        reference = self.acceptance["evidence"]["postgres_restore"]
        reference["file"] = "../postgres-rehearsal.json"
        self.acceptance_path.write_text(json.dumps(self.acceptance), encoding="utf-8")
        with self.assertRaisesRegex(EvidenceError, "filename"):
            self.check()

    def test_symlink_is_rejected(self) -> None:
        self.acceptance["evidence"]["postgres_restore"]["file"] = "linked-rehearsal.json"
        try:
            (self.evidence_dir / "linked-rehearsal.json").symlink_to(
                self.evidence_dir / "postgres-rehearsal.json"
            )
        except OSError:
            self.skipTest("symlinks unavailable on this host")
        self.save()
        with self.assertRaisesRegex(EvidenceError, "outside"):
            self.check()

    def test_duplicate_json_fields_are_rejected(self) -> None:
        raw = self.acceptance_path.read_text(encoding="utf-8")
        self.acceptance_path.write_text(raw[:-1] + ',"status":"passed"}', encoding="utf-8")
        with self.assertRaisesRegex(EvidenceError, "duplicate"):
            self.check()


if __name__ == "__main__":
    unittest.main()
