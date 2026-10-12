#!/usr/bin/env python3
"""Offline provenance gate for the production recovery acceptance record.

This checks versioned, sanitized evidence. It cannot prove that an external
backup or restore happened; the release reviewer must inspect the source
receipts and confirm their custody separately.
"""

from __future__ import annotations

import argparse
from datetime import datetime, timedelta, timezone
import hashlib
import json
from pathlib import Path
import re
import sys
from typing import Any


GATES = (
    "offsite_backup",
    "postgres_restore",
    "critical_volumes_restore",
    "upgrade_compatibility",
    "backend_schema_compatibility",
)
SHA256 = re.compile(r"[0-9a-f]{64}\Z")
EVIDENCE_NAME = re.compile(r"[A-Za-z0-9][A-Za-z0-9_-]*\.json\Z")
ALEMBIC_REVISION = re.compile(r"[A-Za-z0-9][A-Za-z0-9_-]*\Z")
GIT_TREE_OID = re.compile(r"[0-9a-f]{40}\Z")
RECEIPT_ID = re.compile(r"\d{8}T\d{6}Z-[0-9a-f]{32}\Z")
UTC_TIMESTAMP = re.compile(r"\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?Z\Z")
MAX_EVIDENCE_BYTES = 1024 * 1024
MAX_DRILL_AGE = timedelta(days=30)
MAX_CLOCK_SKEW = timedelta(minutes=5)


class EvidenceError(ValueError):
    """The acceptance record cannot substantiate the release gate."""


def _unique_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            raise EvidenceError("duplicate JSON field")
        result[key] = value
    return result


def _read_object(path: Path) -> tuple[dict[str, Any], bytes]:
    try:
        if path.stat().st_size > MAX_EVIDENCE_BYTES:
            raise EvidenceError("evidence file is too large")
        raw = path.read_bytes()
        value = json.loads(raw, object_pairs_hook=_unique_object)
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise EvidenceError("evidence file is unreadable or invalid JSON") from error
    if not isinstance(value, dict):
        raise EvidenceError("evidence must be a JSON object")
    return value, raw


def _require(condition: bool, reason: str) -> None:
    if not condition:
        raise EvidenceError(reason)


def _utc_time(value: Any, name: str) -> datetime:
    _require(isinstance(value, str) and UTC_TIMESTAMP.fullmatch(value) is not None,
             f"{name} must be an ISO UTC timestamp")
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as error:
        raise EvidenceError(f"{name} is invalid") from error


def _fresh_drill(when: datetime, now: datetime, name: str) -> None:
    _require(when <= now + MAX_CLOCK_SKEW, f"{name} is in the future")
    _require(now - when <= MAX_DRILL_AGE, f"{name} is older than 30 days")


def _gate_claim(gate: str, record: dict[str, Any], schema: str,
                api_tree: str) -> None:
    _require(record.get("status") == "passed", "evidence status is not passed")

    if gate == "offsite_backup":
        # A restored scheduled PostgreSQL archive is required. The one-off
        # AnythingLLM volume drill does not cover this backup stream.
        _require(record.get("scope") == "postgres-prod-scheduled", "offsite scope is wrong")
        offsite = record.get("offsite")
        _require(isinstance(offsite, dict), "offsite receipt is missing")
        hashes = [offsite.get(key) for key in ("uploaded_sha256", "downloaded_sha256")]
        _require(
            all(isinstance(value, str) and SHA256.fullmatch(value) for value in hashes)
            and hashes[0] == hashes[1],
            "offsite upload/download hashes do not match",
        )
        _require(record.get("isolated_restore_from_offsite_verified") is True,
                 "offsite archive was not restored in isolation")
        receipt = record.get("scheduled_receipt")
        _require(isinstance(receipt, dict), "scheduled receipt is missing")
        receipt_id = receipt.get("id")
        _require(isinstance(receipt_id, str) and RECEIPT_ID.fullmatch(receipt_id) is not None,
                 "scheduled receipt ID is invalid")
        _require(type(receipt.get("schema")) is int and receipt["schema"] == 1 and
                 receipt.get("owner") == "tutor-tds-issue2-scheduled-v1" and
                 receipt.get("status") == "verified" and
                 receipt.get("bucket") == "tds-backups" and
                 receipt.get("key") == f"postgres/scheduled/v1/{receipt_id}/archive.dump.age" and
                 receipt.get("sha256") == hashes[0] and
                 receipt.get("source") == "tutor-tds-api-db-1/tutor_tds" and
                 receipt.get("sourceReadOnly") is True and
                 receipt.get("clientEncryption") == "age" and
                 receipt.get("privateKeyUsed") is False and
                 receipt.get("restoreExecuted") is False,
                 "scheduled receipt does not match the native backup stream")
        completed = _utc_time(receipt.get("completedAt"), "scheduled receipt completedAt")
        _require(receipt.get("day") == completed.date().isoformat() and
                 receipt_id[:8] == completed.strftime("%Y%m%d"),
                 "scheduled receipt day does not match its ID")
        drill = record.get("restore_drill")
        _require(isinstance(drill, dict) and
                 drill.get("source_receipt_id") == receipt_id and
                 drill.get("source_object_key") == receipt["key"] and
                 drill.get("source_cipher_sha256") == receipt["sha256"] and
                 isinstance(drill.get("decrypted_dump_sha256"), str) and
                 SHA256.fullmatch(drill["decrypted_dump_sha256"]) is not None,
                 "offsite restore drill is not linked to the scheduled receipt")
        _utc_time(drill.get("restored_at"), "offsite restore drill restored_at")
        return

    if gate == "critical_volumes_restore":
        _require(record.get("TRACK_B_DRILL") == "PASS" and
                 record.get("CRITICAL_VOLUMES_RESTORE") == "PASS",
                 "critical volume drill did not pass")
        restored = record.get("restore")
        _require(isinstance(restored, dict) and
                 restored.get("decrypted_sha256_equals_snapshot") is True,
                 "critical volume restore checksum is unverified")
        _utc_time(record.get("executed_at"), "critical volume drill executed_at")
        return

    # PostgreSQL restore, upgrade, and schema compatibility may cite the same
    # isolated rehearsal, but its upgraded revision must match this candidate.
    _require(record.get("clone_revision") == schema and
             record.get("production_unchanged") is True,
             "PostgreSQL rehearsal is stale or changed production")
    _require(record.get("api_tree_oid") == api_tree and
             isinstance(record.get("run_id"), str) and bool(record["run_id"]),
             "PostgreSQL rehearsal is not bound to the candidate API tree")
    _utc_time(record.get("completed_at"), "PostgreSQL rehearsal completed_at")
    source = record.get("source_backup")
    backup = record.get("backup")
    _require(isinstance(source, dict) and isinstance(backup, dict) and
             isinstance(source.get("receipt_id"), str) and
             isinstance(source.get("object_key"), str) and
             isinstance(source.get("plaintext_sha256"), str) and
             SHA256.fullmatch(source["plaintext_sha256"]) is not None and
             backup.get("sha256") == source["plaintext_sha256"],
             "PostgreSQL rehearsal does not identify its restored backup")
    if gate == "postgres_restore":
        _require(record.get("restore_verified") is True,
                 "PostgreSQL restore is unverified")
    elif gate == "upgrade_compatibility":
        _require(record.get("old_image_runs_on_upgraded_database") is True and
                 record.get("public_catalog_compatible") is True,
                 "upgrade or rollback compatibility is unverified")
    elif gate == "backend_schema_compatibility":
        comparison = record.get("openapi_comparison")
        _require(record.get("original_columns_preserved") is True and
                 isinstance(comparison, dict) and
                 comparison.get("only_production") == [] and
                 comparison.get("aab_14_missing_in_candidate") == [],
                 "backend schema or API compatibility is unverified")


def verify(acceptance_path: Path, evidence_dir: Path, expected_schema: str,
           expected_api_tree: str, now: datetime | None = None) -> None:
    _require(bool(ALEMBIC_REVISION.fullmatch(expected_schema)), "expected schema is invalid")
    _require(bool(GIT_TREE_OID.fullmatch(expected_api_tree)), "expected API tree is invalid")
    now = now or datetime.now(timezone.utc)
    _require(now.tzinfo is not None and now.utcoffset() == timedelta(0),
             "verification clock must be UTC")
    _require(evidence_dir.is_dir() and not evidence_dir.is_symlink(),
             "evidence directory is unavailable")
    _require(acceptance_path.is_file() and not acceptance_path.is_symlink(),
             "acceptance file is unavailable")
    acceptance, _ = _read_object(acceptance_path)
    _require(acceptance.get("status") == "passed", "acceptance status is not passed")
    for gate in GATES:
        _require(acceptance.get(gate) is True, "acceptance field is missing or false")
    _require(acceptance.get("candidate_schema_version") == expected_schema,
             "acceptance schema does not match the candidate")
    _require(acceptance.get("candidate_api_tree_oid") == expected_api_tree,
             "acceptance API tree does not match the candidate")
    references = acceptance.get("evidence")
    _require(isinstance(references, dict) and set(references) == set(GATES),
             "acceptance evidence map is incomplete")

    records: dict[str, dict[str, Any]] = {}
    for gate in GATES:
        reference = references[gate]
        _require(isinstance(reference, dict) and set(reference) == {"file", "sha256"},
                 "evidence reference is invalid")
        name, digest = reference["file"], reference["sha256"]
        _require(isinstance(name, str) and EVIDENCE_NAME.fullmatch(name) is not None,
                 "evidence filename is invalid")
        _require(isinstance(digest, str) and SHA256.fullmatch(digest) is not None,
                 "evidence hash is invalid")
        path = evidence_dir / name
        _require(path.is_file() and not path.is_symlink() and
                 path.resolve().parent == evidence_dir.resolve(),
                 "evidence file is missing or outside its directory")
        record, raw = _read_object(path)
        _require(hashlib.sha256(raw).hexdigest() == digest, "evidence hash does not match")
        _gate_claim(gate, record, expected_schema, expected_api_tree)
        records[gate] = record

    _require(references["offsite_backup"]["file"] !=
             references["critical_volumes_restore"]["file"],
             "offsite backup and critical volume drill need distinct evidence")
    postgres_ref = references["postgres_restore"]
    _require(references["upgrade_compatibility"] == postgres_ref and
             references["backend_schema_compatibility"] == postgres_ref,
             "PostgreSQL restore, upgrade, and schema claims need one rehearsal")

    offsite = records["offsite_backup"]
    receipt = offsite["scheduled_receipt"]
    drill = offsite["restore_drill"]
    postgres = records["postgres_restore"]
    source = postgres["source_backup"]
    _require(source["receipt_id"] == receipt["id"] and
             source["object_key"] == receipt["key"] and
             source["plaintext_sha256"] == drill["decrypted_dump_sha256"],
             "PostgreSQL rehearsal backup differs from the offsite restore drill")
    receipt_time = _utc_time(receipt["completedAt"], "scheduled receipt completedAt")
    drill_time = _utc_time(drill["restored_at"], "offsite restore drill restored_at")
    rehearsal_time = _utc_time(postgres["completed_at"], "PostgreSQL rehearsal completed_at")
    _require(receipt_time <= drill_time <= rehearsal_time,
             "receipt, offsite restore, and PostgreSQL rehearsal are out of order")
    _fresh_drill(drill_time, now, "offsite restore drill")
    _fresh_drill(rehearsal_time, now, "PostgreSQL rehearsal")
    _fresh_drill(_utc_time(records["critical_volumes_restore"]["executed_at"],
                           "critical volume drill executed_at"), now, "critical volume drill")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--acceptance", type=Path, required=True)
    parser.add_argument("--evidence-dir", type=Path, required=True)
    parser.add_argument("--expected-schema", required=True)
    parser.add_argument("--expected-api-tree", required=True)
    args = parser.parse_args()
    try:
        verify(args.acceptance, args.evidence_dir, args.expected_schema,
               args.expected_api_tree)
    except EvidenceError as error:
        print(f"RECOVERY_EVIDENCE_PROVENANCE=FAIL: {error}", file=sys.stderr)
        return 1
    print("RECOVERY_EVIDENCE_PROVENANCE=PASS (offline, provenance only)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
