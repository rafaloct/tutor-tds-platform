[Reading 392 lines from start (total: 392 lines, 0 remaining)]

#!/usr/bin/env python3
"""Deterministic path classifier and always-on PR gate helpers."""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import textwrap
import time
import urllib.parse
import urllib.request

ALWAYS_REQUIRED_WORKFLOWS = (
    "Secret scan (new commits)",
    "WordPress legacy quarantine",
)

DOMAIN_WORKFLOWS = {
    "flutter": "Tutor TDS Flutter app checks",
    "api": "Tutor TDS API CI and staging",
    "release": "Tutor TDS release identity gate",
    "backup": "Tutor TDS backup automation contracts",
    "wp_core": "WordPress portal foundation",
}

RELEASE_PATHS = {
    "tooling/build_production.ps1",
    "tooling/Test-ProductionBackendIdentity.ps1",
    "tooling/test_production_backend_identity.ps1",
    "tooling/Test-ProductionRecoveryEvidence.ps1",
    "tooling/test_production_recovery_evidence.ps1",
    ".github/workflows/release-identity.yml",
}

INFRA_EXACT = {
    ".github/workflows/pr-required-gate.yml",
    ".github/workflows/secret-scan.yml",
    ".github/workflows/wp-legacy-quarantine.yml",
    ".github/workflows/tds-vps-watchdog.yml",
    ".gitleaks.toml",
    ".gitignore",
    ".gitattributes",
}


def _doc_like(path: str) -> bool:
    return path.startswith("docs/") or (
        "/" not in path and path.lower().endswith((".md", ".txt"))
    )


def classify_paths(paths: list[str]) -> dict[str, object]:
    normalized = sorted({p.strip().replace("\\", "/") for p in paths if p.strip()})
    if not normalized:
        raise ValueError("pull request has no changed paths")

    flags = {
        "flutter": False,
        "api": False,
        "release": False,
        "backup": False,
        "wp_core": False,
        "wp_child_theme": False,
        "watchdog": False,
        "observability": False,
        "watchdog_workflow": False,
    }
    covered: set[str] = set()

    for path in normalized:
        if path.startswith("cartilhas_app/") or path == ".github/workflows/flutter-app.yml":
            flags["flutter"] = True
            covered.add(path)

        if path.startswith("api/") or path == ".github/workflows/tutor-api.yml":
            flags["api"] = True
            covered.add(path)

        if path in RELEASE_PATHS:
            flags["release"] = True
            covered.add(path)

        if path.startswith("tooling/backup_automation/") or path == ".github/workflows/backup-automation.yml":
            flags["backup"] = True
            covered.add(path)

        if (
            path.startswith("wordpress/tds-portal-core/")
            or path.startswith("wordpress/staging/")
            or path == ".github/workflows/wp-portal-foundation.yml"
        ):
            flags["wp_core"] = True
            covered.add(path)

        if path.startswith("wordpress/tds-child-theme/"):
            flags["wp_child_theme"] = True
            covered.add(path)

        if path.startswith("tools/observability/"):
            flags["watchdog"] = True
            flags["observability"] = True
            covered.add(path)

        if (
            path == ".github/workflows/tds-vps-watchdog.yml"
            or path.startswith("tooling/security/test_watchdog_smtp_observability")
        ):
            flags["watchdog"] = True
            flags["watchdog_workflow"] = True
            covered.add(path)

        if (
            path.startswith("tooling/ci/")
            or path in INFRA_EXACT
            or (
                path.startswith(".github/workflows/")
                and path
                not in {
                    ".github/workflows/flutter-app.yml",
                    ".github/workflows/tutor-api.yml",
                    ".github/workflows/release-identity.yml",
                    ".github/workflows/backup-automation.yml",
                    ".github/workflows/wp-portal-foundation.yml",
                }
            )
        ):
            flags["watchdog"] = True
            covered.add(path)

    docs_only = all(_doc_like(path) for path in normalized) and not any(flags.values())
    if docs_only:
        covered.update(normalized)

    unclassified = [
        path for path in normalized if path not in covered and not _doc_like(path)
    ]

    required = list(ALWAYS_REQUIRED_WORKFLOWS)
    for domain, workflow in DOMAIN_WORKFLOWS.items():
        if flags[domain]:
            required.append(workflow)

    return {
        **flags,
        "docs_only": docs_only,
        "unclassified": unclassified,
        "paths": normalized,
        "required_workflows": required,
    }


def changed_paths(base: str, head: str) -> list[str]:
    result = subprocess.run(
        ["git", "diff", "--name-only", "--diff-filter=ACMR", base, head, "--"],
        check=True,
        capture_output=True,
        text=True,
    )
    return [line for line in result.stdout.splitlines() if line.strip()]


def _write_outputs(path: str, classification: dict[str, object]) -> None:
    with open(path, "a", encoding="utf-8") as output:
        for name in (
            "flutter",
            "api",
            "release",
            "backup",
            "wp_core",
            "wp_child_theme",
            "watchdog",
            "observability",
            "watchdog_workflow",
            "docs_only",
        ):
            output.write(f"{name}={str(bool(classification[name])).lower()}\n")
        output.write(
            "required_workflows="
            + json.dumps(classification["required_workflows"], separators=(",", ":"))
            + "\n"
        )


def _fetch_runs(repo: str, sha: str, token: str) -> list[dict[str, object]]:
    query = urllib.parse.urlencode(
        {"head_sha": sha, "event": "pull_request", "per_page": 100}
    )
    request = urllib.request.Request(
        f"https://api.github.com/repos/{repo}/actions/runs?{query}",
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "tutor-tds-required-pr-gate",
        },
    )
    with urllib.request.urlopen(request, timeout=20) as response:
        payload = json.load(response)
    runs = payload.get("workflow_runs")
    if not isinstance(runs, list):
        raise RuntimeError("GitHub Actions response missing workflow_runs")
    return runs


def workflow_states(
    runs: list[dict[str, object]], required: list[str]
) -> dict[str, tuple[str, str | None]]:
    latest: dict[str, dict[str, object]] = {}
    for run in runs:
        name = run.get("name")
        if name not in required:
            continue
        current = latest.get(str(name))
        if current is None or int(run.get("id", 0)) > int(current.get("id", 0)):
            latest[str(name)] = run
    return {
        name: (
            str(latest[name].get("status", "unknown")),
            (
                str(latest[name].get("conclusion"))
                if latest[name].get("conclusion") is not None
                else None
            ),
        )
        if name in latest
        else ("missing", None)
        for name in required
    }


def wait_for_workflows(
    repo: str,
    sha: str,
    token: str,
    required: list[str],
    timeout_seconds: int,
    poll_seconds: int,
) -> None:
    deadline = time.monotonic() + timeout_seconds
    last: dict[str, tuple[str, str | None]] | None = None
    while True:
        states = workflow_states(_fetch_runs(repo, sha, token), required)
        if states != last:
            print("WORKFLOW_STATES " + json.dumps(states, sort_keys=True), flush=True)
            last = states

        failed = {
            name: state
            for name, state in states.items()
            if state[0] == "completed" and state[1] != "success"
        }
        if failed:
            raise RuntimeError(
                "required workflow failed: " + ", ".join(sorted(failed))
            )

        if all(state == ("completed", "success") for state in states.values()):
            for name in required:
                print(f"WORKFLOW_PASS {name}")
            return

        if time.monotonic() >= deadline:
            pending = [
                name
                for name, state in states.items()
                if state != ("completed", "success")
            ]
            raise RuntimeError(
                "required workflow timeout/missing: " + ", ".join(sorted(pending))
            )
        time.sleep(poll_seconds)


def embedded_python_blocks(path: Path) -> list[str]:
    lines = path.read_text(encoding="utf-8").splitlines()
    blocks: list[str] = []
    index = 0
    while index < len(lines):
        line = lines[index]
        if "python3" not in line or "<<'PY'" not in line:
            index += 1
            continue
        indent = len(line) - len(line.lstrip())
        index += 1
        block: list[str] = []
        while index < len(lines):
            current = lines[index]
            if (
                current.strip() == "PY"
                and len(current) - len(current.lstrip()) == indent
            ):
                break
            block.append(current[indent:])
            index += 1
        else:
            raise ValueError("unterminated Python heredoc in watchdog workflow")
        blocks.append(textwrap.dedent("\n".join(block)))
        index += 1
    return blocks


def validate_watchdog(path: Path) -> None:
    blocks = embedded_python_blocks(path)
    if not blocks:
        raise ValueError("watchdog workflow has no embedded Python validation block")
    for index, block in enumerate(blocks, start=1):
        compile(block, f"{path}#python-block-{index}", "exec")
    print(f"WATCHDOG_STATIC_PASS python_blocks={len(blocks)}")


def summary(classification: dict[str, object]) -> None:
    domains = (
        ("docs-only", bool(classification["docs_only"])),
        ("flutter", bool(classification["flutter"])),
        ("api", bool(classification["api"])),
        ("release", bool(classification["release"])),
        ("backup", bool(classification["backup"])),
        ("wp-core", bool(classification["wp_core"])),
        ("wp-child-theme", bool(classification["wp_child_theme"])),
        ("watchdog-infra", bool(classification["watchdog"])),
    )
    for name, applicable in domains:
        print(("APPLICABLE " if applicable else "NEUTRAL_PASS ") + name)


def main() -> None:
    parser = argparse.ArgumentParser()
    sub = parser.add_subparsers(dest="command", required=True)

    classify = sub.add_parser("classify")
    classify.add_argument("--base", required=True)
    classify.add_argument("--head", required=True)
    classify.add_argument("--github-output")
    classify.add_argument("--json-output", required=True)

    wait = sub.add_parser("wait-workflows")
    wait.add_argument("--repo", required=True)
    wait.add_argument("--sha", required=True)
    wait.add_argument("--token", required=True)
    wait.add_argument("--required-json", required=True)
    wait.add_argument("--timeout-seconds", type=int, default=1380)
    wait.add_argument("--poll-seconds", type=int, default=10)

    watchdog = sub.add_parser("validate-watchdog")
    watchdog.add_argument(
        "--path", default=".github/workflows/tds-vps-watchdog.yml"
    )

    report = sub.add_parser("summary")
    report.add_argument("--json-input", required=True)

    args = parser.parse_args()

    if args.command == "classify":
        result = classify_paths(changed_paths(args.base, args.head))
        Path(args.json_output).write_text(
            json.dumps(result, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
        if args.github_output:
            _write_outputs(args.github_output, result)
        print(json.dumps(result, indent=2, sort_keys=True))
        if result["unclassified"]:
            raise SystemExit(
                "unclassified non-documentation paths: "
                + ", ".join(result["unclassified"])
            )
    elif args.command == "wait-workflows":
        required = json.loads(args.required_json)
        if not isinstance(required, list) or not all(
            isinstance(item, str) for item in required
        ):
            raise SystemExit("required workflow list is invalid")
        wait_for_workflows(
            args.repo,
            args.sha,
            args.token,
            required,
            args.timeout_seconds,
            args.poll_seconds,
        )
    elif args.command == "validate-watchdog":
        validate_watchdog(Path(args.path))
    elif args.command == "summary":
        summary(json.loads(Path(args.json_input).read_text(encoding="utf-8")))


if __name__ == "__main__":
    main()

[executed on device: avellaria (50b7ca2d-9d90-4e32-ab9d-7f5d2869d5eb)]