#!/usr/bin/env python3
"""Offline provenance gate for the production recovery acceptance record.

This checks versioned, sanitized evidence. It cannot prove that an external
backup or restore happened; the release reviewer must inspect the source
receipts and confirm their custody separately.
"""

from __future__ import annotations

import argparse
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
MAX_EVIDENCE_BYTES = 1024 * 1024


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


def _gate_claim(gate: str, record: dict[str, Any], schema: str) -> None:
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
        return

    if gate == "critical_volumes_restore":
        _require(record.get("TRACK_B_DRILL") == "PASS" and
                 record.get("CRITICAL_VOLUMES_RESTORE") == "PASS",
                 "critical volume drill did not pass")
        restored = record.get("restore")
        _require(isinstance(restored, dict) and
                 restored.get("decrypted_sha256_equals_snapshot") is True,
                 "critical volume restore checksum is unverified")
        return

    # PostgreSQL restore, upgrade, and schema compatibility may cite the same
    # isolated rehearsal, but its upgraded revision must match this candidate.
    _require(record.get("clone_revision") == schema and
             record.get("production_unchanged") is True,
             "PostgreSQL rehearsal is stale or changed production")
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


def verify(acceptance_path: Path, evidence_dir: Path, expected_schema: str) -> None:
    _require(bool(ALEMBIC_REVISION.fullmatch(expected_schema)), "expected schema is invalid")
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
    references = acceptance.get("evidence")
    _require(isinstance(references, dict) and set(references) == set(GATES),
             "acceptance evidence map is incomplete")

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
        _gate_claim(gate, record, expected_schema)

    _require(references["offsite_backup"]["file"] !=
             references["critical_volumes_restore"]["file"],
             "offsite backup and critical volume drill need distinct evidence")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--acceptance", type=Path, required=True)
    parser.add_argument("--evidence-dir", type=Path, required=True)
    parser.add_argument("--expected-schema", required=True)
    args = parser.parse_args()
    try:
        verify(args.acceptance, args.evidence_dir, args.expected_schema)
    except EvidenceError as error:
        print(f"RECOVERY_EVIDENCE_PROVENANCE=FAIL: {error}", file=sys.stderr)
        return 1
    print("RECOVERY_EVIDENCE_PROVENANCE=PASS (offline, provenance only)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
