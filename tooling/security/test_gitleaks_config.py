#!/usr/bin/env python3
"""Executable synthetic regressions for the repository gitleaks policy."""

from __future__ import annotations

import argparse
import json
import re
import secrets
import shutil
import string
import subprocess
import tempfile
from pathlib import Path


def command(args: list[str], cwd: Path) -> subprocess.CompletedProcess[str]:
    return subprocess.run(args, cwd=cwd, capture_output=True, text=True, check=False)


def init_repo(base: Path, files: dict[str, str]) -> Path:
    repo = base / "repo"
    repo.mkdir()
    for relative, content in files.items():
        target = repo / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(content, encoding="utf-8")
    if command(["git", "init", "-q"], repo).returncode != 0:
        raise AssertionError("git init failed")
    if command(["git", "add", "."], repo).returncode != 0:
        raise AssertionError("git add failed")
    commit = command(
        [
            "git",
            "-c",
            "user.name=TDS gitleaks regression",
            "-c",
            "user.email=fixture@example.invalid",
            "commit",
            "-q",
            "-m",
            "synthetic gitleaks regression",
        ],
        repo,
    )
    if commit.returncode != 0:
        raise AssertionError("git commit failed")
    return repo


def redacted_json_field(item: dict[str, object]) -> str | None:
    """Field syntax is retained by --redact; never expose the captured value."""
    match = re.match(r'^([A-Za-z_][A-Za-z0-9_]*)"\s*:', str(item["Match"]))
    return match.group(1) if match else None


def findings_for(
    gitleaks: Path, config: Path, repo: Path, log_opts: str = "HEAD"
) -> tuple[int, list[dict[str, object]]]:
    # Match the existing workflow barrier. Gitleaks 8.28.0 can log a bad
    # git range while returning zero, so the engine exit code is not sufficient.
    preflight = command(["git", "rev-list", "--count", log_opts], repo)
    if preflight.returncode != 0:
        return 2, []
    report = repo.parent / "report.json"
    result = command(
        [
            str(gitleaks),
            "git",
            ".",
            "--config",
            str(config),
            f"--log-opts={log_opts}",
            "--redact=100",
            "--report-format=json",
            f"--report-path={report}",
            "--no-banner",
        ],
        repo,
    )
    items: list[dict[str, object]] = []
    if report.exists() and report.stat().st_size:
        items = json.loads(report.read_text(encoding="utf-8")) or []
    safe = sorted(
        [
            {
                "rule": str(item["RuleID"]),
                "start_line": int(item["StartLine"]),
                "json_field": redacted_json_field(item),
                "path": str(item["File"]),
                "match_starts_at_column": int(item["StartColumn"]),
                "match_ends_at_column": int(item["EndColumn"]),
                "match_length": len(str(item["Match"])),
                "match_is_entire_line": (
                    str(item["Match"])
                    == (repo / str(item["File"])).read_text(encoding="utf-8").splitlines()[
                        int(item["StartLine"]) - 1
                    ]
                ),
            }
            for item in items
        ],
        key=lambda item: (item["path"], item["rule"]),
    )
    return result.returncode, safe


def random_alnum(length: int) -> str:
    alphabet = string.ascii_letters + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(length))


def detected_case(
    tmp_root: Path,
    name: str,
    files: dict[str, str],
    expected_rule: str,
    gitleaks: Path,
    config: Path,
) -> None:
    with tempfile.TemporaryDirectory(prefix=f"{name}-", dir=tmp_root) as temp:
        repo = init_repo(Path(temp), files)
        code, findings = findings_for(gitleaks, config, repo)
        rules = {item["rule"] for item in findings}
        if code != 1 or expected_rule not in rules:
            raise AssertionError(f"{name}: expected {expected_rule} detection")
        paths = ",".join(item["path"] for item in findings)
        print(f"PASS {name} count={len(findings)} rules={','.join(sorted(rules))} paths={paths}")


def clean_case(
    tmp_root: Path,
    name: str,
    files: dict[str, str],
    gitleaks: Path,
    config: Path,
    default_config: Path | None = None,
) -> None:
    with tempfile.TemporaryDirectory(prefix=f"{name}-", dir=tmp_root) as temp:
        repo = init_repo(Path(temp), files)
        if default_config is not None:
            before_code, before_findings = findings_for(gitleaks, default_config, repo)
            if before_code != 1 or not before_findings:
                raise AssertionError(f"{name}: fixture did not exercise default rule")
        code, findings = findings_for(gitleaks, config, repo)
        if code != 0 or findings:
            diagnostic = ";".join(
                f"{item['rule']}@column{item['match_starts_at_column']}"
                f"-{item['match_ends_at_column']}"
                f"/length={item['match_length']}"
                f"/entire_line={item['match_is_entire_line']}"
                for item in findings
            )
            raise AssertionError(f"{name}: unexpected finding ({diagnostic})")
        print(f"PASS {name} count=0 rules=none paths=none")


def sha256_context_cases(tmp_root: Path, gitleaks: Path, config: Path) -> None:
    """Check exact finding positions, not merely the presence of a rule."""
    digest = secrets.token_hex(32)
    other = secrets.token_hex(32)
    hash_field = "secret_access_key_sha256"
    secret_field = "secret_access_key"
    evidence = "docs/production/evidence/context.json"
    cases = []
    for name, payload, indent in (
        ("matching_digest_before_secret", {hash_field: digest, secret_field: other}, None),
        ("matching_digest_after_secret", {secret_field: other, hash_field: digest}, None),
        ("matching_digest_multiline", {hash_field: digest, secret_field: other}, 2),
    ):
        cases.append((name, evidence, json.dumps(payload, indent=indent), secret_field))
    for name, field, value, path in (
        ("sha256_63_hex_not_exempt", hash_field, digest[:-1], evidence),
        ("sha256_65_hex_not_exempt", hash_field, digest + "a", evidence),
        ("sha256_nonhex_not_exempt", hash_field, digest[:-1] + "g", evidence),
        ("sha256_wrong_suffix_not_exempt", hash_field + "_extra", digest, evidence),
        ("sha256_outside_evidence_not_exempt", hash_field, digest, "api/tests/hash.json"),
    ):
        cases.append((name, path, json.dumps({field: value}), field))
    for name, path, text, detected_field in cases:
        with tempfile.TemporaryDirectory(prefix=f"{name}-", dir=tmp_root) as temp:
            repo = init_repo(Path(temp), {path: text + "\n"})
            code, findings = findings_for(gitleaks, config, repo)
            actual = [(f["rule"], f["path"], f["json_field"]) for f in findings]
            expected = [("generic-api-key", path, detected_field)]
            if code != 1 or actual != expected:
                raise AssertionError(f"{name}: expected only the exact protected field; got {actual}")
            print(f"PASS {name} count=1 rules=generic-api-key paths={path}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--gitleaks", required=True)
    parser.add_argument("--config", default=".gitleaks.toml")
    parser.add_argument("--tmp-root")
    args = parser.parse_args()

    gitleaks = Path(args.gitleaks).resolve()
    config = Path(args.config).resolve()
    if not gitleaks.is_file() or not config.is_file():
        raise SystemExit("gitleaks binary or config not found")

    version = command([str(gitleaks), "version"], config.parent)
    if version.returncode != 0 or version.stdout.strip() != "8.28.0":
        raise SystemExit("gitleaks 8.28.0 is required")

    tmp_root = Path(args.tmp_root).resolve() if args.tmp_root else Path(tempfile.mkdtemp())
    tmp_root.mkdir(parents=True, exist_ok=True)
    cleanup_tmp_root = args.tmp_root is None

    try:
        default_config = tmp_root / "default.toml"
        default_config.write_text("[extend]\nuseDefault = true\n", encoding="utf-8")

        detected_case(
            tmp_root,
            "evidence_secret_access_key",
            {"docs/production/evidence/transport.json": json.dumps({"secret_access_key": secrets.token_hex(32)}) + "\n"},
            "generic-api-key",
            gitleaks,
            config,
        )
        detected_case(
            tmp_root,
            "evidence_digest_does_not_hide_neighbor_secret",
            {
                "docs/production/evidence/transport.json": (
                    json.dumps(
                        {
                            "reviewed_sha256": secrets.token_hex(32),
                            "secret_access_key": secrets.token_hex(32),
                        },
                        separators=(",", ":"),
                    )
                    + "\n"
                )
            },
            "generic-api-key",
            gitleaks,
            config,
        )
        detected_case(
            tmp_root,
            "api_test_secret_access_key",
            {"api/tests/test_smtp_config.py": f'secret_access_key = "{secrets.token_hex(32)}"\n'},
            "generic-api-key",
            gitleaks,
            config,
        )
        detected_case(
            tmp_root,
            "flutter_test_secret_access_key",
            {"cartilhas_app/test/secret_scan_test.dart": f"const secret_access_key = '{secrets.token_hex(32)}';\n"},
            "generic-api-key",
            gitleaks,
            config,
        )
        detected_case(
            tmp_root,
            "normal_code_generic_api_key",
            {"api/app/example_config.py": f'api_key = "{secrets.token_urlsafe(32)}"\n'},
            "generic-api-key",
            gitleaks,
            config,
        )
        detected_case(
            tmp_root,
            "github_pat",
            {"api/app/example_token.py": f'github_token = "ghp_{random_alnum(36)}"\n'},
            "github-pat",
            gitleaks,
            config,
        )
        private_begin = "-----BEGIN " + "PRIVATE KEY-----"
        private_end = "-----END " + "PRIVATE KEY-----"
        detected_case(
            tmp_root,
            "private_key_marker",
            {
                "api/app/example_key.py": (
                    f'key = """{private_begin}\n{random_alnum(80)}\n{private_end}"""\n'
                )
            },
            "private-key",
            gitleaks,
            config,
        )

        clean_case(
            tmp_root,
            "reviewed_sha256_field",
            {"docs/production/evidence/digest.json": json.dumps({"secret_access_key_sha256": secrets.token_hex(32)}) + "\n"},
            gitleaks,
            config,
            default_config,
        )
        git_sha = "1dea14ae741bd0ba141f43b22296c7e297b6e320"
        clean_case(
            tmp_root,
            "issue_140_evidence_git_sha",
            {
                "docs/production/evidence/"
                "class-lifecycle-e2e-14000000000000000000000000000001.json": (
                    json.dumps({"api_head": git_sha}, indent=2) + "\n"
                )
            },
            gitleaks,
            config,
            default_config,
        )
        clean_case(
            tmp_root,
            "issue_140_runbook_git_sha",
            {
                "docs/production/CLASS_LIFECYCLE_E2E_RUNBOOK.md": (
                    f"API_HEAD={git_sha}\n"
                )
            },
            gitleaks,
            config,
            default_config,
        )
        detected_case(
            tmp_root,
            "issue_140_git_sha_outside_allowlisted_path",
            {"docs/production/evidence/other.json": json.dumps({"api_head": git_sha}) + "\n"},
            "generic-api-key",
            gitleaks,
            config,
        )
        fixture_value = f"tds_gitleaks_fixture_{random_alnum(24)}"
        clean_case(
            tmp_root,
            "approved_api_fixture",
            {"api/tests/test_fixture.py": f'synthetic_fixture_api_key = "{fixture_value}"  # gitleaks:synthetic-fixture\n'},
            gitleaks,
            config,
            default_config,
        )
        fixture_value = f"tds_gitleaks_fixture_{random_alnum(24)}"
        clean_case(
            tmp_root,
            "approved_flutter_fixture",
            {"cartilhas_app/test/fixture_test.dart": f"const syntheticFixtureApiKey = '{fixture_value}'; // gitleaks:synthetic-fixture\n"},
            gitleaks,
            config,
            default_config,
        )
        fixture_like = f"tds_gitleaks_fixture_{random_alnum(24)}"
        detected_case(
            tmp_root,
            "fixture_like_without_context",
            {"api/tests/test_fixture_like.py": f'secret_access_key = "{fixture_like}"\n'},
            "generic-api-key",
            gitleaks,
            config,
        )

        with tempfile.TemporaryDirectory(prefix="invalid-range-", dir=tmp_root) as temp:
            repo = init_repo(Path(temp), {"safe.txt": "synthetic safe fixture\n"})
            git_range = command(["git", "rev-list", "--count", "not-a-real-ref..HEAD"], repo)
            leak_code, _ = findings_for(gitleaks, config, repo, "not-a-real-ref..HEAD")
            if git_range.returncode == 0 or leak_code != 2:
                raise AssertionError("invalid scan range returned false success")
            if (repo.parent / "report.json").exists():
                raise AssertionError("scanner ran despite invalid range")
            print("PASS invalid_scan_range count=0 rules=none paths=none status=failed_as_required")

        sha256_context_cases(tmp_root, gitleaks, config)
        print("PASS all_gitleaks_policy_regressions")
        return 0
    finally:
        if cleanup_tmp_root:
            shutil.rmtree(tmp_root, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
