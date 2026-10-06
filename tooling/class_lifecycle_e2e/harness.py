#!/usr/bin/env python3
"""Fail-closed harness for Issue #140 class lifecycle E2E.

The final execution composes:
- canonical backend contract tests;
- a disposable HTTPS FastAPI instance with synthetic QA data;
- the real Flutter HTTP adapter on an Android emulator;
- a sanitized evidence manifest.

It never mutates shared staging or production.
"""
from __future__ import annotations

import argparse
import json
import re
import ssl
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from urllib.parse import urlparse
from urllib.request import urlopen

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
PACKAGE_RE = re.compile(
    r"^com\.tutortds_cartilhas\.dev\.dynamicqa\.r[a-f0-9]{32}$"
)
TARGET = (
    "cartilhas_app/integration_test/class_lifecycle_e2e/"
    "class_lifecycle_operational_test.dart"
)
FLUTTER_TARGET = (
    "integration_test/class_lifecycle_e2e/"
    "class_lifecycle_operational_test.dart"
)
QA_SERVER = "tooling/class_lifecycle_e2e/qa_server.py"
MARKER = "CLASS_LIFECYCLE_E2E_RESULT="
FORBIDDEN_HOSTS = {"ead.ipexdesenvolvimento.cloud"}
APPROVED_BUILD_STAGING = "https://tutor-tds-staging.fastapicloud.dev"

BACKEND_CONTRACTS = (
    (
        "capacity_policy_enforced",
        "tests/test_class_lifecycle.py::"
        "test_capacity_30_blocks_operator_and_only_coordinator_override_is_audited",
    ),
    (
        "closed_class_rejects_new_link",
        "tests/test_class_lifecycle.py::"
        "test_closed_class_rejects_new_participant_across_write_paths",
    ),
    (
        "course_version_stable",
        "tests/test_classroom_course_versions.py::"
        "test_class_keeps_snapshot_after_new_publication_and_archive",
    ),
    (
        "close_session_with_explicit_pending",
        "tests/test_presence.py::"
        "test_close_requires_explicit_pending_without_qr_and_preserves_report",
    ),
    (
        "qr_not_official_presence",
        "tests/test_evidence.py::"
        "test_evidence_session_token_import_review_and_auditable_close",
    ),
    (
        "certificate_approval_not_emission",
        "tests/test_certificate_requests.py::"
        "test_requests_do_not_change_existing_certificate_or_allow_issued_status",
    ),
)


class ConfigError(ValueError):
    pass


def _host(base_url: str) -> str:
    parsed = urlparse(base_url)
    return (parsed.hostname or "").lower()


def _port(base_url: str) -> int:
    parsed = urlparse(base_url)
    if parsed.port is None:
        raise ConfigError("base_url must include an explicit port")
    return parsed.port


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
    if executing and parsed.scheme != "https":
        errors.append("mutating E2E loopback must use HTTPS")
    if executing:
        try:
            _port(args.base_url)
        except (ConfigError, ValueError):
            errors.append("executing base_url must include a valid explicit port")
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
            stage: {"status": "NOT_RUN", "evidence": []} for stage in STAGES
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
            errors.append(
                "certificate boundary is not the approved-but-not-emitted contract"
            )

    return errors


def _run_id(package: str) -> str:
    return package.rsplit(".r", 1)[-1]


def build_flutter_command(args: argparse.Namespace) -> list[str]:
    run_id = _run_id(args.package)
    return [
        args.flutter,
        "test",
        FLUTTER_TARGET,
        "-d",
        args.device,
        "--no-pub",
        "--dart-define=TUTOR_ENVIRONMENT=staging",
        f"--dart-define=TUTOR_API_URL={APPROVED_BUILD_STAGING}",
        f"--dart-define=TUTOR_STAGING_API_URL={APPROVED_BUILD_STAGING}",
        "--dart-define=DYNAMIC_QA_ISOLATED_PACKAGE=true",
        f"--dart-define=DYNAMIC_QA_RUN_ID={run_id}",
        f"--dart-define=CLASS_LIFECYCLE_E2E_BASE_URL={args.base_url}",
        f"--dart-define=CLASS_LIFECYCLE_E2E_QA_PACKAGE={args.package}",
        f"--dart-define=CLASS_LIFECYCLE_API_HEAD={args.api_head}",
        f"--dart-define=CLASS_LIFECYCLE_APP_HEAD={args.app_head}",
        f"--dart-define=CLASS_LIFECYCLE_COMPOSE_HEAD={args.compose_head}",
    ]


def build_backend_command(args: argparse.Namespace) -> list[str]:
    return [
        args.api_python,
        "-m",
        "pytest",
        "-q",
        *(nodeid for _, nodeid in BACKEND_CONTRACTS),
    ]


def build_server_command(
    args: argparse.Namespace,
    *,
    root: Path,
    database_url: str,
    certfile: Path,
    keyfile: Path,
) -> list[str]:
    return [
        args.api_python,
        str(root / QA_SERVER),
        "--database-url",
        database_url,
        "--host",
        "0.0.0.0",
        "--port",
        str(_port(args.base_url)),
        "--ssl-certfile",
        str(certfile),
        "--ssl-keyfile",
        str(keyfile),
    ]


def _create_certificate(args: argparse.Namespace, directory: Path) -> tuple[Path, Path]:
    certfile = directory / "qa-cert.pem"
    keyfile = directory / "qa-key.pem"
    command = [
        args.openssl,
        "req",
        "-x509",
        "-newkey",
        "rsa:2048",
        "-nodes",
        "-days",
        "1",
        "-subj",
        "/CN=10.0.2.2",
        "-addext",
        "subjectAltName=IP:10.0.2.2,IP:127.0.0.1",
        "-keyout",
        str(keyfile),
        "-out",
        str(certfile),
    ]
    result = subprocess.run(command, text=True, capture_output=True)
    if result.returncode != 0:
        raise RuntimeError(f"openssl failed: {result.stderr.strip()}")
    return certfile, keyfile


def _wait_for_server(
    process: subprocess.Popen,
    *,
    port: int,
    log_path: Path,
    timeout_seconds: float = 40,
) -> None:
    deadline = time.monotonic() + timeout_seconds
    context = ssl._create_unverified_context()
    url = f"https://127.0.0.1:{port}/health"
    while time.monotonic() < deadline:
        if process.poll() is not None:
            detail = log_path.read_text(encoding="utf-8", errors="replace")
            raise RuntimeError(
                f"QA server exited before health check ({process.returncode}): {detail[-3000:]}"
            )
        try:
            with urlopen(url, timeout=1, context=context) as response:
                if response.status == 200:
                    return
        except Exception:
            time.sleep(0.25)
    raise RuntimeError("QA server did not become healthy")


def _parse_flutter_marker(output: str) -> dict:
    candidates = [
        line.split(MARKER, 1)[1].strip()
        for line in output.splitlines()
        if MARKER in line
    ]
    if not candidates:
        raise ValueError("Flutter E2E marker missing")
    try:
        payload = json.loads(candidates[-1])
    except json.JSONDecodeError as error:
        raise ValueError("Flutter E2E marker is not valid JSON") from error
    if not isinstance(payload, dict):
        raise ValueError("Flutter E2E marker must be an object")
    return payload


def _pass_entry(container: dict, key: str, *evidence: str) -> None:
    container[key] = {
        "status": "PASS",
        "evidence": [item for item in evidence if item],
    }


def _manifest_from_execution(
    args: argparse.Namespace,
    flutter_payload: dict,
) -> dict:
    manifest = empty_manifest(args)
    observed = flutter_payload.get("observed")
    if not isinstance(observed, dict):
        raise ValueError("Flutter marker missing observed map")
    if flutter_payload.get("production_changed") is not False:
        raise ValueError("Flutter marker does not prove production remained unchanged")
    if flutter_payload.get("shared_staging_changed") is not False:
        raise ValueError("Flutter marker does not prove shared staging remained unchanged")

    expected_heads = {
        "api_head": args.api_head,
        "app_head": args.app_head,
        "compose_head": args.compose_head,
    }
    for label, expected in expected_heads.items():
        if flutter_payload.get(label) != expected:
            raise ValueError(f"Flutter marker {label} does not match executed head")
    if flutter_payload.get("run_id") != _run_id(args.package):
        raise ValueError("Flutter marker run_id does not match isolated package")

    live_stage_keys = {
        "prepare_class": "prepare_class",
        "participant": "participant",
        "enrollment": "enrollment",
        "meeting": "meeting",
        "qr_checkin": "qr_checkin",
        "attendance_evidence": "attendance_evidence",
        "close_meeting": "close_meeting",
        "close_class_readiness": "close_class_readiness",
        "offline_reconnect": "offline_reconnect",
    }
    for stage, observed_key in live_stage_keys.items():
        if observed.get(observed_key) is True:
            _pass_entry(
                manifest["stages"],
                stage,
                f"android-live:{observed_key}",
            )

    boundary = observed.get("certificate_boundary")
    if isinstance(boundary, dict) and boundary == {
        "request_status": "approved",
        "emitted": False,
        "institutional_release": "blocked",
    }:
        _pass_entry(
            manifest["stages"],
            "certificate_boundary",
            "android-live:approved-request-no-certificate-reference",
        )
        manifest["certificate_boundary"] = boundary

    territorial = observed.get("territorial_fixture")
    if (
        isinstance(territorial, dict)
        and territorial.get("offer_municipality")
        and territorial.get("participant_residence_reference")
        and territorial["offer_municipality"]
        != territorial["participant_residence_reference"]
        and territorial.get("residence_reference_persisted_in_classroom") is False
    ):
        _pass_entry(
            manifest["invariants"],
            "offer_municipality_differs_from_residence",
            "android-live:Palmas-offer-vs-external-Itaguatins-residence-fixture",
        )

    direct_invariants = {
        "physical_location_persisted": "physical_location_persisted",
        "teacher_monitor_surfaces_distinct": "teacher_monitor_surfaces_distinct",
        "qr_not_official_presence": "qr_not_official_presence",
        "close_session_with_explicit_pending": "close_session_with_explicit_pending",
        "closed_class_rejects_new_link": "closed_class_rejects_new_link",
        "offline_reconnect_no_duplicate_presence": "offline_reconnect",
    }
    for invariant, observed_key in direct_invariants.items():
        if observed.get(observed_key) is True:
            _pass_entry(
                manifest["invariants"],
                invariant,
                f"android-live:{observed_key}",
            )

    if observed.get("cross_scope_denied") is True:
        for invariant in ("cross_program_denied", "cross_institution_denied"):
            _pass_entry(
                manifest["invariants"],
                invariant,
                "android-live:foreign-program-and-institution-subject-denied",
            )

    if (
        observed.get("course_version_stable_live") is True
        and flutter_payload.get("course_version_id") == "qa-v1"
    ):
        _pass_entry(
            manifest["invariants"],
            "course_version_stable",
            "android-live:qa-v1-start-to-close",
            "backend-contract:test_class_keeps_snapshot_after_new_publication_and_archive",
        )

    _pass_entry(
        manifest["invariants"],
        "capacity_policy_enforced",
        "backend-contract:test_capacity_30_blocks_operator_and_only_coordinator_override_is_audited",
    )

    if isinstance(boundary, dict):
        _pass_entry(
            manifest["invariants"],
            "certificate_approval_not_emission",
            "android-live:approved-request-certificates-empty",
            "backend-contract:test_requests_do_not_change_existing_certificate_or_allow_issued_status",
        )

    # Backend focal tests are executed by this harness before the Android run.
    # Keep their evidence explicit instead of pretending every invariant was
    # observed through the UI/data adapter.
    if manifest["invariants"]["close_session_with_explicit_pending"]["status"] == "PASS":
        manifest["invariants"]["close_session_with_explicit_pending"]["evidence"].append(
            "backend-contract:test_close_requires_explicit_pending_without_qr_and_preserves_report"
        )
    if manifest["invariants"]["qr_not_official_presence"]["status"] == "PASS":
        manifest["invariants"]["qr_not_official_presence"]["evidence"].append(
            "backend-contract:test_evidence_session_token_import_review_and_auditable_close"
        )
    if manifest["invariants"]["closed_class_rejects_new_link"]["status"] == "PASS":
        manifest["invariants"]["closed_class_rejects_new_link"]["evidence"].append(
            "backend-contract:test_closed_class_rejects_new_participant_across_write_paths"
        )

    manifest["notes"] = [
        "Shared staging and production were not mutated.",
        "Backend contract suite: 6/6 PASS before Android execution.",
        "Participant residence is an external synthetic QA fixture because the current relational model intentionally does not persist residence; the E2E proves offer municipality remains a separate classroom field and the residence fixture is not copied into the classroom.",
        "Visual wizard evidence is reused from docs/qa/class-lifecycle-2026-10-05 because PR #144 visual QA already passed and this composition did not change presentation.",
        "Certificate proof stops at approved request with /certificates still empty; no Worker/KV emission is invoked.",
    ]
    return manifest


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
    p.add_argument("--api-python", default=sys.executable)
    p.add_argument("--openssl", default="openssl")
    p.add_argument("--init-evidence")
    p.add_argument("--validate-evidence")
    p.add_argument("--evidence-output")
    p.add_argument("--require-complete", action="store_true")
    p.add_argument("--execute", action="store_true")
    return p


def _write_manifest(path_value: str | None, manifest: dict) -> None:
    if not path_value:
        return
    path = Path(path_value)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def _execute(args: argparse.Namespace, root: Path) -> int:
    target = root / TARGET
    qa_server = root / QA_SERVER
    if not target.is_file() or not qa_server.is_file():
        missing = [
            str(path.relative_to(root))
            for path in (target, qa_server)
            if not path.is_file()
        ]
        print(
            json.dumps(
                {
                    "result": "DEPENDENCY_BLOCKED",
                    "reason": "missing composed E2E files",
                    "missing": missing,
                },
                indent=2,
            ),
            file=sys.stderr,
        )
        return 4

    backend = subprocess.run(
        build_backend_command(args),
        cwd=root / "api",
        text=True,
        capture_output=True,
    )
    sys.stdout.write(backend.stdout)
    sys.stderr.write(backend.stderr)
    if backend.returncode != 0:
        print(
            json.dumps(
                {
                    "result": "BACKEND_CONTRACT_FAIL",
                    "returncode": backend.returncode,
                }
            ),
            file=sys.stderr,
        )
        return backend.returncode or 5

    with tempfile.TemporaryDirectory(prefix="tds-class-lifecycle-e2e-") as temp:
        temp_path = Path(temp)
        certfile, keyfile = _create_certificate(args, temp_path)
        database_path = temp_path / "qa.db"
        database_url = f"sqlite+pysqlite:///{database_path}"
        server_log = temp_path / "qa-server.log"

        with server_log.open("w", encoding="utf-8") as log:
            server = subprocess.Popen(
                build_server_command(
                    args,
                    root=root,
                    database_url=database_url,
                    certfile=certfile,
                    keyfile=keyfile,
                ),
                cwd=root,
                stdout=log,
                stderr=subprocess.STDOUT,
                text=True,
            )
            try:
                _wait_for_server(
                    server,
                    port=_port(args.base_url),
                    log_path=server_log,
                )
                flutter = subprocess.run(
                    build_flutter_command(args),
                    cwd=root / "cartilhas_app",
                    text=True,
                    capture_output=True,
                )
                sys.stdout.write(flutter.stdout)
                sys.stderr.write(flutter.stderr)
                if flutter.returncode != 0:
                    server_tail = server_log.read_text(
                        encoding="utf-8",
                        errors="replace",
                    )[-4000:]
                    print(
                        json.dumps(
                            {
                                "result": "FLUTTER_E2E_FAIL",
                                "returncode": flutter.returncode,
                                "qa_server_log_tail": server_tail,
                            }
                        ),
                        file=sys.stderr,
                    )
                    return flutter.returncode or 6

                payload = _parse_flutter_marker(
                    (flutter.stdout or "") + "\n" + (flutter.stderr or "")
                )
                manifest = _manifest_from_execution(args, payload)
                evidence_errors = validate_manifest(
                    manifest,
                    require_complete=True,
                )
                _write_manifest(args.evidence_output, manifest)
                if evidence_errors:
                    print(
                        json.dumps(
                            {
                                "result": "EVIDENCE_REJECTED",
                                "errors": evidence_errors,
                            },
                            indent=2,
                        ),
                        file=sys.stderr,
                    )
                    return 7

                print(
                    json.dumps(
                        {
                            "result": "PASS",
                            "real_e2e_run": True,
                            "backend_contracts": len(BACKEND_CONTRACTS),
                            "manifest_complete": True,
                            "evidence_output": args.evidence_output,
                        }
                    )
                )
                return 0
            finally:
                server.terminate()
                try:
                    server.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    server.kill()
                    server.wait(timeout=5)


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    errors = validate_config(args, executing=args.execute)
    if errors:
        print(
            json.dumps({"result": "CONFIG_REJECTED", "errors": errors}, indent=2),
            file=sys.stderr,
        )
        return 2

    if args.init_evidence:
        path = Path(args.init_evidence)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps(empty_manifest(args), indent=2) + "\n",
            encoding="utf-8",
        )
        print(json.dumps({"result": "EVIDENCE_TEMPLATE_CREATED", "path": str(path)}))
        return 0

    if args.validate_evidence:
        path = Path(args.validate_evidence)
        data = json.loads(path.read_text(encoding="utf-8"))
        evidence_errors = validate_manifest(
            data,
            require_complete=args.require_complete,
        )
        if evidence_errors:
            print(
                json.dumps(
                    {"result": "EVIDENCE_REJECTED", "errors": evidence_errors},
                    indent=2,
                ),
                file=sys.stderr,
            )
            return 3
        print(
            json.dumps(
                {
                    "result": "EVIDENCE_VALID",
                    "complete_required": args.require_complete,
                }
            )
        )
        return 0

    plan = {
        "result": "NOT_RUN",
        "real_e2e_run": False,
        "target": TARGET,
        "qa_server": QA_SERVER,
        "backend_contracts": [nodeid for _, nodeid in BACKEND_CONTRACTS],
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

    return _execute(args, Path(args.repo_root).resolve())


if __name__ == "__main__":
    sys.exit(main())
