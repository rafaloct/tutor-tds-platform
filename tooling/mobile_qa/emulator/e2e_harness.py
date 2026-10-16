#!/usr/bin/env python3
"""Fail-closed Android emulator E2E runner for Tutor TDS staging QA."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from urllib.parse import urlparse

TARGET = "integration_test/emulator_e2e/emulator_e2e_scenarios_test.dart"
SCENARIOS = (
    "login_activation",
    "account_switch",
    "participant_flow",
    "offline_reconnect",
    "teacher_dashboard",
    "monitor_projection",
    "creator_surface",
    "operator_flow",
    "certificate",
)
DEFAULT_SCENARIOS = (
    "login_activation",
    "account_switch",
    "participant_flow",
    "teacher_dashboard",
    "monitor_projection",
    "creator_surface",
    "offline_reconnect",
)
PACKAGE_RE = re.compile(
    r"^com\.tutortds_cartilhas\.dev\.dynamicqa\.r([a-f0-9]{32})$"
)
RUN_RE = re.compile(r"^[a-f0-9]{32}$")
CPF_RE = re.compile(r"(?<!\d)\d{3}\.?\d{3}\.?\d{3}[-.]?\d{2}(?!\d)")
JWT_RE = re.compile(r"\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b")
PASSWORD_LINE_RE = re.compile(
    r"(?i)(password|senha|authorization|token)(\s*[:=]\s*)(\S+)"
)

ROLE_ENV = {
    "student": ("STAGING_SEED_STUDENT_CPF", "STAGING_SEED_STUDENT_PASSWORD"),
    "teacher": ("STAGING_SEED_TEACHER_CPF", "STAGING_SEED_TEACHER_PASSWORD"),
    "monitor": ("STAGING_SEED_MONITOR_CPF", "STAGING_SEED_MONITOR_PASSWORD"),
    "admin": ("STAGING_SEED_ADMIN_CPF", "STAGING_SEED_ADMIN_PASSWORD"),
    "operator": ("STAGING_SEED_OPERATOR_CPF", "STAGING_SEED_OPERATOR_PASSWORD"),
}
SCENARIO_ROLES = {
    "login_activation": ("student",),
    "account_switch": ("student", "teacher"),
    "participant_flow": ("student",),
    "offline_reconnect": ("student",),
    "teacher_dashboard": ("teacher",),
    "monitor_projection": ("monitor",),
    "creator_surface": ("admin",),
    "operator_flow": ("operator",),
    "certificate": ("student",),
}
SECRET_ENV = {
    value for pair in ROLE_ENV.values() for value in pair
} | {
    "EMULATOR_E2E_CERTIFICATE_CONTEXT_ID",
}


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--execute", action="store_true")
    parser.add_argument("--base-url")
    parser.add_argument("--package")
    parser.add_argument("--device")
    parser.add_argument("--run-id")
    parser.add_argument("--scenario", action="append", choices=SCENARIOS)
    parser.add_argument("--evidence-dir")
    return parser.parse_args(argv)


def _value(args_value: str | None, env: dict[str, str], key: str) -> str:
    return args_value or env.get(key, "")


def config(args: argparse.Namespace, env: dict[str, str]) -> dict[str, str]:
    package = _value(args.package, env, "EMULATOR_E2E_QA_PACKAGE")
    match = PACKAGE_RE.fullmatch(package)
    inferred = match.group(1) if match else ""
    return {
        "EMULATOR_E2E_BASE_URL": _value(
            args.base_url, env, "EMULATOR_E2E_BASE_URL"
        ),
        "EMULATOR_E2E_QA_PACKAGE": package,
        "EMULATOR_E2E_DEVICE": _value(
            args.device, env, "EMULATOR_E2E_DEVICE"
        ),
        "EMULATOR_E2E_RUN_ID": args.run_id
        or env.get("EMULATOR_E2E_RUN_ID", "")
        or inferred,
    }


def required_credentials(scenarios: list[str] | tuple[str, ...]) -> set[str]:
    keys: set[str] = set()
    for scenario in scenarios:
        for role in SCENARIO_ROLES[scenario]:
            keys.update(ROLE_ENV[role])
        if scenario == "certificate":
            keys.add("EMULATOR_E2E_CERTIFICATE_CONTEXT_ID")
    return keys


def validate(
    values: dict[str, str],
    scenarios: list[str] | tuple[str, ...],
    *,
    require_credentials: bool = False,
    env: dict[str, str] | None = None,
) -> list[str]:
    errors: list[str] = []
    base = values.get("EMULATOR_E2E_BASE_URL", "")
    package = values.get("EMULATOR_E2E_QA_PACKAGE", "")
    device = values.get("EMULATOR_E2E_DEVICE", "")
    run_id = values.get("EMULATOR_E2E_RUN_ID", "")

    parsed = urlparse(base)
    if (
        parsed.scheme != "https"
        or not parsed.netloc
        or "staging" not in (parsed.netloc + parsed.path).lower()
    ):
        errors.append("base URL must be an HTTPS staging endpoint")
    match = PACKAGE_RE.fullmatch(package)
    if not match:
        errors.append("isolated dynamic-QA package is required")
    if not RUN_RE.fullmatch(run_id):
        errors.append("run id must be exactly 32 lowercase hex characters")
    if match and run_id and match.group(1) != run_id:
        errors.append("package suffix and run id must match")
    if not device.startswith("emulator-"):
        errors.append("physical devices are rejected")
    for scenario in scenarios:
        if scenario not in SCENARIOS:
            errors.append(f"unknown scenario: {scenario}")

    if require_credentials:
        source = env or {}
        for key in sorted(required_credentials(scenarios)):
            if not source.get(key):
                errors.append(f"missing synthetic QA credential: {key}")
    return errors


def sanitize(text: str, env: dict[str, str]) -> str:
    safe = text
    for key in SECRET_ENV:
        value = env.get(key)
        if value:
            safe = safe.replace(value, "[REDACTED]")
    safe = JWT_RE.sub("[REDACTED_JWT]", safe)
    safe = CPF_RE.sub("[REDACTED_CPF]", safe)
    safe = PASSWORD_LINE_RE.sub(r"\1\2[REDACTED]", safe)
    return safe


def _secret_define_file(env: dict[str, str]) -> tempfile.NamedTemporaryFile:
    payload = {
        key: env[key]
        for key in sorted(SECRET_ENV)
        if env.get(key)
    }
    handle = tempfile.NamedTemporaryFile(
        mode="w",
        suffix=".json",
        prefix="tds-e2e-",
        delete=False,
        encoding="utf-8",
    )
    json.dump(payload, handle)
    handle.flush()
    handle.close()
    return handle


def flutter_command(
    values: dict[str, str],
    scenario: str,
    secret_file: str,
    offline_phase: str = "",
) -> list[str]:
    command = [
        "flutter",
        "test",
        TARGET,
        "-d",
        values["EMULATOR_E2E_DEVICE"],
        "--no-pub",
        "--dart-define-from-file=config/staging.qa.json",
        f"--dart-define-from-file={secret_file}",
        "--dart-define=DYNAMIC_QA_ISOLATED_PACKAGE=true",
        f"--dart-define=DYNAMIC_QA_RUN_ID={values['EMULATOR_E2E_RUN_ID']}",
        f"--dart-define=EMULATOR_E2E_RUN_ID={values['EMULATOR_E2E_RUN_ID']}",
        f"--dart-define=EMULATOR_E2E_BASE_URL={values['EMULATOR_E2E_BASE_URL']}",
        f"--dart-define=EMULATOR_E2E_QA_PACKAGE={values['EMULATOR_E2E_QA_PACKAGE']}",
        f"--dart-define=EMULATOR_E2E_SCENARIO={scenario}",
    ]
    if offline_phase:
        command.append(
            f"--dart-define=EMULATOR_E2E_OFFLINE_PHASE={offline_phase}"
        )
    return command


def _adb(values: dict[str, str], *args: str, check: bool = True):
    return subprocess.run(
        ["adb", "-s", values["EMULATOR_E2E_DEVICE"], *args],
        check=check,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
    )


def _network(values: dict[str, str], enabled: bool) -> None:
    state = "disable" if enabled else "enable"
    # Android 15 emulator command: disable airplane mode for online, enable for offline.
    _adb(values, "shell", "cmd", "connectivity", "airplane-mode", state)
    time.sleep(2)


def _clear_package(values: dict[str, str]) -> None:
    _adb(
        values,
        "shell",
        "pm",
        "clear",
        values["EMULATOR_E2E_QA_PACKAGE"],
        check=False,
    )


def _screenshot(values: dict[str, str], path: Path) -> None:
    result = _adb(values, "exec-out", "screencap", "-p", check=False)
    if result.returncode == 0 and result.stdout.startswith(b"\x89PNG"):
        path.write_bytes(result.stdout)


def _run_flutter(
    values: dict[str, str],
    scenario: str,
    secret_file: str,
    env: dict[str, str],
    *,
    offline_phase: str = "",
) -> tuple[bool, str]:
    command = flutter_command(values, scenario, secret_file, offline_phase)
    result = subprocess.run(
        command,
        cwd=Path(__file__).parents[3] / "cartilhas_app",
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        env=os.environ.copy(),
    )
    output = sanitize(result.stdout, env)
    return result.returncode == 0, output


def execute(
    values: dict[str, str],
    scenarios: list[str],
    env: dict[str, str],
    evidence_dir: Path,
) -> dict[str, object]:
    evidence_dir.mkdir(parents=True, exist_ok=True)
    secret_file = _secret_define_file(env)
    results: dict[str, object] = {}
    try:
        _network(values, True)
        for scenario in scenarios:
            if scenario == "operator_flow":
                results[scenario] = {
                    "result": "BLOCKED_BY_ISSUE_120",
                    "real_e2e_run": False,
                }
                continue
            if scenario == "certificate":
                results[scenario] = {
                    "result": "OPTIONAL_NOT_IN_PROFILE_ACCEPTANCE",
                    "real_e2e_run": False,
                }
                continue

            _clear_package(values)
            phases = (
                ("prime", "offline", "reconnect")
                if scenario == "offline_reconnect"
                else ("",)
            )
            phase_results: list[dict[str, object]] = []
            scenario_ok = True
            try:
                for phase in phases:
                    if scenario == "offline_reconnect":
                        if phase == "offline":
                            _network(values, False)
                        elif phase == "reconnect":
                            _network(values, True)
                    ok, output = _run_flutter(
                        values,
                        scenario,
                        secret_file.name,
                        env,
                        offline_phase=phase,
                    )
                    phase_results.append(
                        {
                            "phase": phase or "single",
                            "passed": ok,
                            "output_tail": output.splitlines()[-30:],
                        }
                    )
                    if not ok:
                        scenario_ok = False
                        break
                _screenshot(
                    values,
                    evidence_dir / f"{scenario}.png",
                )
            finally:
                _network(values, True)
            results[scenario] = {
                "result": "PASS" if scenario_ok else "FAIL",
                "real_e2e_run": True,
                "phases": phase_results,
            }
            if not scenario_ok:
                break
    finally:
        try:
            os.unlink(secret_file.name)
        except FileNotFoundError:
            pass
        _network(values, True)
    return results


def main(argv: list[str] | None = None, env: dict[str, str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    source = dict(os.environ if env is None else env)
    args = parse_args(argv)
    selected = args.scenario or list(DEFAULT_SCENARIOS)
    values = config(args, source)
    errors = validate(
        values,
        selected,
        require_credentials=args.execute,
        env=source,
    )
    if errors:
        print("CONFIG_REJECTED", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 2

    missing = sorted(
        key for key in required_credentials(selected) if not source.get(key)
    )
    evidence_dir = Path(
        args.evidence_dir
        or source.get(
            "EMULATOR_E2E_EVIDENCE_DIR",
            f"tooling/mobile_qa/emulator/evidence/{values['EMULATOR_E2E_RUN_ID']}",
        )
    )
    if not args.execute:
        print(
            json.dumps(
                {
                    "result": "NOT_RUN",
                    "real_e2e_run": False,
                    "scenarios": selected,
                    "base_url": values["EMULATOR_E2E_BASE_URL"],
                    "package": values["EMULATOR_E2E_QA_PACKAGE"],
                    "device": values["EMULATOR_E2E_DEVICE"],
                    "run_id": values["EMULATOR_E2E_RUN_ID"],
                    "missing_credentials": missing,
                },
                sort_keys=True,
            )
        )
        return 0

    result = execute(values, selected, source, evidence_dir)
    passed = all(
        item.get("result") in {
            "PASS",
            "BLOCKED_BY_ISSUE_120",
            "OPTIONAL_NOT_IN_PROFILE_ACCEPTANCE",
        }
        for item in result.values()
    )
    print(
        json.dumps(
            {
                "result": "PASS" if passed else "FAIL",
                "real_e2e_run": True,
                "run_id": values["EMULATOR_E2E_RUN_ID"],
                "package": values["EMULATOR_E2E_QA_PACKAGE"],
                "device": values["EMULATOR_E2E_DEVICE"],
                "scenarios": result,
            },
            sort_keys=True,
        )
    )
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
