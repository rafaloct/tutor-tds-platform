#!/usr/bin/env python3
"""Emulator E2E harness (preparation only).

Validates QA configuration fail-closed, prints a sanitized plan (dry-run) and,
only with --execute, runs the Flutter integration scenarios on an emulator.
It never reports PASS without a real execution and never touches app code.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from urllib.parse import urlparse

SCENARIOS = {
    "login_activation": {"requires": []},
    "account_switch": {"requires": ["QA_ACCOUNT_B_ID"]},
    "participant_flow": {"requires": []},
    "offline_reconnect": {"requires": []},
    "certificate": {"requires": ["EMULATOR_E2E_CERTIFICATE_CONTEXT_ID"]},
}
REQUIRED_ENV = ("EMULATOR_E2E_BASE_URL", "EMULATOR_E2E_QA_PACKAGE", "EMULATOR_E2E_DEVICE")
SECRET_ENV = ("QA_ACCOUNT_A_ID", "QA_ACCOUNT_A_SECRET", "QA_ACCOUNT_B_ID", "QA_ACCOUNT_B_SECRET")
FORBIDDEN_PACKAGES = {"com.tutortds_cartilhas"}
FORBIDDEN_HOST_PARTS = ("ead.ipexdesenvolvimento.cloud",)
TARGET = "integration_test/emulator_e2e/emulator_e2e_scenarios_test.dart"


class ConfigError(Exception):
    pass


def validate(env, scenarios):
    errors = []
    for name in REQUIRED_ENV:
        if not env.get(name, "").strip():
            errors.append(f"missing {name}")
    for s in scenarios:
        if s not in SCENARIOS:
            errors.append(f"unknown scenario {s}")
    url = env.get("EMULATOR_E2E_BASE_URL", "").strip()
    if url:
        p = urlparse(url)
        host = (p.hostname or "").lower()
        if p.scheme != "https" and host not in ("10.0.2.2", "localhost"):
            errors.append("base url must be https (or emulator loopback)")
        if p.username or p.password or p.query or p.fragment:
            errors.append("base url must not carry credentials/query")
        if "staging" not in host and host not in ("10.0.2.2", "localhost"):
            errors.append("base url must be a staging host")
        if any(x in host for x in FORBIDDEN_HOST_PARTS):
            errors.append("production host refused")
    pkg = env.get("EMULATOR_E2E_QA_PACKAGE", "").strip()
    if pkg and (pkg in FORBIDDEN_PACKAGES or not pkg.endswith(".dev") and ".dev." not in pkg):
        errors.append("QA package must be an isolated .dev package, never production")
    dev = env.get("EMULATOR_E2E_DEVICE", "").strip()
    if dev and not dev.startswith("emulator-"):
        errors.append("device must be an emulator (emulator-<port>)")
    for s in scenarios:
        for r in SCENARIOS.get(s, {}).get("requires", []):
            if not env.get(r, "").strip():
                errors.append(f"scenario {s} requires {r}")
    return errors


def sanitize(text, env=None):
    env = env if env is not None else os.environ
    for name in SECRET_ENV:
        v = env.get(name, "")
        if v:
            text = text.replace(v, "<redacted>")
    text = re.sub(r"(?i)(bearer\s+)[A-Za-z0-9._~+/=-]+", r"\1<redacted>", text)
    text = re.sub(r"\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]*", "<jwt>", text)
    text = re.sub(r"\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b", "<cpf>", text)
    text = re.sub(r"(?i)\b(password|senha|token|secret)(\s*[=:]\s*)\S+", r"\1\2<redacted>", text)
    return text


def build_command(env, scenario, flutter="flutter"):
    cmd = [flutter, "test", TARGET, "-d", env["EMULATOR_E2E_DEVICE"], "--no-pub",
           "--dart-define=TUTOR_ENVIRONMENT=staging",
           f"--dart-define=EMULATOR_E2E_BASE_URL={env['EMULATOR_E2E_BASE_URL']}",
           f"--dart-define=EMULATOR_E2E_QA_PACKAGE={env['EMULATOR_E2E_QA_PACKAGE']}",
           f"--dart-define=EMULATOR_E2E_SCENARIO={scenario}"]
    for name in SECRET_ENV + ("EMULATOR_E2E_CERTIFICATE_CONTEXT_ID",):
        if env.get(name):
            cmd.append(f"--dart-define={name}={env[name]}")
    return cmd


def plan(env, scenarios):
    return {
        "mode": "DRY_RUN",
        "real_e2e_run": False,
        "base_url": env.get("EMULATOR_E2E_BASE_URL"),
        "package": env.get("EMULATOR_E2E_QA_PACKAGE"),
        "device": env.get("EMULATOR_E2E_DEVICE"),
        "scenarios": list(scenarios),
        "credentials_present": {n: bool(env.get(n)) for n in SECRET_ENV},
        "result": "NOT_RUN",
    }


def main(argv=None, env=None):
    env = dict(os.environ if env is None else env)
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--base-url")
    ap.add_argument("--package")
    ap.add_argument("--device")
    ap.add_argument("--scenario", action="append", help="repeatable; default: all but certificate")
    ap.add_argument("--flutter", default=env.get("FLUTTER_BIN", "flutter"))
    ap.add_argument("--execute", action="store_true", help="run on a real emulator")
    a = ap.parse_args(argv)
    for arg, name in ((a.base_url, "EMULATOR_E2E_BASE_URL"), (a.package, "EMULATOR_E2E_QA_PACKAGE"),
                      (a.device, "EMULATOR_E2E_DEVICE")):
        if arg:
            env[name] = arg
    scenarios = a.scenario or [s for s in SCENARIOS if s != "certificate"]
    errors = validate(env, scenarios)
    if errors:
        print(json.dumps({"result": "CONFIG_REJECTED", "errors": errors}), file=sys.stderr)
        return 2
    if not a.execute:
        print(sanitize(json.dumps(plan(env, scenarios), indent=2), env))
        return 0
    results = {}
    for s in scenarios:
        proc = subprocess.run(build_command(env, s, a.flutter), capture_output=True, text=True)
        print(sanitize(proc.stdout + proc.stderr, env))
        results[s] = "PASS" if proc.returncode == 0 else "FAIL"
    print(json.dumps({"mode": "EXECUTED", "real_e2e_run": True, "results": results}))
    return 0 if all(v == "PASS" for v in results.values()) else 1


if __name__ == "__main__":
    sys.exit(main())
