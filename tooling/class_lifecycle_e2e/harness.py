#!/usr/bin/env python3
"""Fail-closed harness for Issue #140 class lifecycle E2E.

This module prepares and validates the evidence envelope for the composed
backend + Flutter journey. It intentionally refuses production, physical
devices and mutating shared staging. A real execution is allowed only against
emulator loopback with an isolated QA package.

The harness does not implement business rules. It validates that the composed
application proves the rules owned by #138/#139 and records evidence without
turning TARGET into OBSERVED.
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlparse

STAGES = (
    "prepare_class",
    "participant",
    "enrollment",
    "meeting",
    "qr_checkin",
    "attendance_evidence",
    "close_meeting",
    "close_class_readiness",
    "certificate_boundary",
    "offline_reconnect",
)

INVARIANTS = (
    "offer_municipality_differs_from_residence",
    "physical_location_persisted",
    "cross_program_denied",
    "cross_institution_denied",
    "course_version_stable",
    "capacity_policy_enforced",
    "teacher_monitor_surfaces_distinct",
    "qr_not_official_presence",
    "close_session_with_explicit_pending",
    "closed_class_rejects_new_link",
    "offline_reconnect_no_duplicate_presence",
    "certificate_approval_not_emission",
)

STATUS = {"NOT_RUN", "PASS", "FAIL", "BLOCKED"}
SHA_RE = re.compile(r"^[a-f0-9]{40}$")
PACKAGE_RE = re.compile(r"^com\.tutortds_cartilhas\.dev\.dynamicqa\.r[a-f0-9]{32}$")
TARGET = "cartilhas_app/integration_test/class_lifecycle_e2e/class_lifecycle_operational_test.dart"
FORBIDDEN_HOSTS = {"ead.ipexdesenvolvimento.cloud"}


class ConfigError(ValueError):
    pass


def _host(base_url: str) -> str:
    parsed = urlparse(base_url)
    return (parsed.hostname or "").lower()


def validate_config(args: argparse.Namespace, *, executing: bool) -> list[str]:
    errors: list[str] = []
    for label, value in (
        ("api_head", args.api_head),
        ("app_head", args.app_head),
        ("compose_head", args.compose_head),
    ):
        if not SHA_RE.fullmatch(value or ""):
            errors.append(f"{label} must be a full 40-char lowercase SHA")

    if not PACKAGE_RE.fullmatch(args.package or ""):
        errors.append("package must be an isolated dynamic QA package")
    if not (args.device or "").startswith("emulator-"):
        errors.append("device must be emulator-<port>")

    parsed = urlparse(args.base_url or "")
    host = _host(args.base_url or "")
    if parsed.username or parsed.password or parsed.query or parsed.fragment:
        errors.append("base_url must not contain credentials/query/fragment")
    if host in FORBIDDEN_HOSTS:
        errors.append("production host refused")
    if not host:
        errors.append("base_url host is required")

    loopback = host in {"10.0.2.2", "localhost", "127.0.0.1"}
    if executing and not loopback:
        errors.append("mutating E2E execution is restricted to emulator loopback")
    if executing and parsed.scheme not in {"http", "https"}:
        errors.append("loopback base_url must use http or https")
    if not executing and not loopback and "staging" not in host:
        errors.append("non-loopback planning host must be an explicit staging host")

    return errors


def empty_manifest(args: argparse.Namespace) -> dict:
    return {
        "front": "CLASS_LIFECYCLE_E2E",
        "issue": 140,
        "environment": "local-emulator",
        "device": args.device,
        "package": args.package,
        "base_url": args.base_url,
        "api_head": args.api_head,
        "app_head": args.app_head,
        "compose_head": args.compose_head,
        "stages": {
            stage: {"status": "NOT_RUN", "evidence": []}
            for stage in STAGES
        },
        "invariants": {
            invariant: {"status": "NOT_RUN", "evidence": []}
            for invariant in INVARIANTS
        },
        "certificate_boundary": {
            "request_status": None,
            "emitted": None,
            "institutional_release": None,
        },
        "notes": [],
    }


def _entry_status(container: dict, key: str, errors: list[str], prefix: str) -> None:
    value = container.get(key)
    if not isinstance(value, dict):
        errors.append(f"{prefix}.{key} missing")
        return
    status = value.get("status")
    if status not in STATUS:
        errors.append(f"{prefix}.{key}.status invalid")
    evidence = value.get("evidence")
    if not isinstance(evidence, list):
        errors.append(f"{prefix}.{key}.evidence must be a list")


def validate_manifest(data: dict, *, require_complete: bool) -> list[str]:
    errors: list[str] = []
    if data.get("front") != "CLASS_LIFECYCLE_E2E" or data.get("issue") != 140:
        errors.append("manifest identity mismatch")

    for label in ("api_head", "app_head", "compose_head"):
        if not SHA_RE.fullmatch(str(data.get(label) or "")):
            errors.append(f"{label} invalid")

    stages = data.get("stages")
    invariants = data.get("invariants")
    if not isinstance(stages, dict):
        errors.append("stages missing")
        stages = {}
    if not isinstance(invariants, dict):
        errors.append("invariants missing")
        invariants = {}

    for stage in STAGES:
        _entry_status(stages, stage, errors, "stages")
    for invariant in INVARIANTS:
        _entry_status(invariants, invariant, errors, "invariants")

    boundary = data.get("certificate_boundary")
    if not isinstance(boundary, dict):
        errors.append("certificate_boundary missing")
    else:
        request_status = boundary.get("request_status")
        emitted = boundary.get("emitted")
        institutional_release = boundary.get("institutional_release")
        if request_status not in {None, "pending", "approved", "rejected"}:
            errors.append("certificate request_status invalid")
        if emitted not in {None, False}:
            errors.append("certificate must not be reported emitted in #140")
        if institutional_release not in {None, "blocked"}:
            errors.append("institutional_release must remain blocked")

    if require_complete:
        for stage in STAGES:
            if stages.get(stage, {}).get("status") != "PASS":
                errors.append(f"stage not passed: {stage}")
        for invariant in INVARIANTS:
            if invariants.get(invariant, {}).get("status") != "PASS":
                errors.append(f"invariant not passed: {invariant}")
        if boundary != {
            "request_status": "approved",
            "emitted": False,
            "institutional_release": "blocked",
        }:
            errors.append("certificate boundary is not the approved-but-not-emitted contract")

    return errors


def build_flutter_command(args: argparse.Namespace) -> list[str]:
    return [
        args.flutter,
        "test",
        TARGET,
        "-d",
        args.device,
        "--no-pub",
        "--dart-define=TUTOR_ENVIRONMENT=staging",
        f"--dart-define=CLASS_LIFECYCLE_E2E_BASE_URL={args.base_url}",
        f"--dart-define=CLASS_LIFECYCLE_E2E_QA_PACKAGE={args.package}",
        f"--dart-define=CLASS_LIFECYCLE_API_HEAD={args.api_head}",
        f"--dart-define=CLASS_LIFECYCLE_APP_HEAD={args.app_head}",
        f"--dart-define=CLASS_LIFECYCLE_COMPOSE_HEAD={args.compose_head}",
    ]


def parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--api-head", required=True)
    p.add_argument("--app-head", required=True)
    p.add_argument("--compose-head", required=True)
    p.add_argument("--base-url", required=True)
    p.add_argument("--package", required=True)
    p.add_argument("--device", required=True)
    p.add_argument("--repo-root", default=".")
    p.add_argument("--flutter", default="flutter")
    p.add_argument("--init-evidence")
    p.add_argument("--validate-evidence")
    p.add_argument("--require-complete", action="store_true")
    p.add_argument("--execute", action="store_true")
    return p


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    errors = validate_config(args, executing=args.execute)
    if errors:
        print(json.dumps({"result": "CONFIG_REJECTED", "errors": errors}, indent=2), file=sys.stderr)
        return 2

    if args.init_evidence:
        path = Path(args.init_evidence)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(json.dumps(empty_manifest(args), indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"result": "EVIDENCE_TEMPLATE_CREATED", "path": str(path)}))
        return 0

    if args.validate_evidence:
        path = Path(args.validate_evidence)
        data = json.loads(path.read_text(encoding="utf-8"))
        evidence_errors = validate_manifest(data, require_complete=args.require_complete)
        if evidence_errors:
            print(json.dumps({"result": "EVIDENCE_REJECTED", "errors": evidence_errors}, indent=2), file=sys.stderr)
            return 3
        print(json.dumps({"result": "EVIDENCE_VALID", "complete_required": args.require_complete}))
        return 0

    plan = {
        "result": "NOT_RUN",
        "real_e2e_run": False,
        "target": TARGET,
        "stages": list(STAGES),
        "invariants": list(INVARIANTS),
        "api_head": args.api_head,
        "app_head": args.app_head,
        "compose_head": args.compose_head,
        "base_url": args.base_url,
        "package": args.package,
        "device": args.device,
    }
    if not args.execute:
        print(json.dumps(plan, indent=2))
        return 0

    root = Path(args.repo_root).resolve()
    target = root / TARGET
    if not target.is_file():
        print(
            json.dumps(
                {
                    "result": "DEPENDENCY_BLOCKED",
                    "reason": f"missing composed Flutter E2E target: {TARGET}",
                },
                indent=2,
            ),
            file=sys.stderr,
        )
        return 4

    command = build_flutter_command(args)
    proc = subprocess.run(command, cwd=root, text=True)
    print(
        json.dumps(
            {
                "result": "PASS" if proc.returncode == 0 else "FAIL",
                "real_e2e_run": True,
                "returncode": proc.returncode,
            }
        )
    )
    return proc.returncode


if __name__ == "__main__":
    sys.exit(main())
