"""Offline regression tests for the production restore evidence gate."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from tooling.verify_production_recovery_evidence import EvidenceError, GATES, verify


SCHEMA = "20261007_0030"
HASH = "a" * 64


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
                "offsite": {"uploaded_sha256": HASH, "downloaded_sha256": HASH},
                "isolated_restore_from_offsite_verified": True,
            },
            "postgres-rehearsal.json": {
                "status": "passed",
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
        verify(self.acceptance_path, self.evidence_dir, SCHEMA)

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
        self.records["scheduled-postgres.json"]["offsite"]["downloaded_sha256"] = "b" * 64
        self.save()
        with self.assertRaisesRegex(EvidenceError, "hashes"):
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
