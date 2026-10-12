#!/usr/bin/env python3
"""Fail-closed CI ref -> Tutor TDS build configuration. No user-provided toggles.

Production uses an existing, approved Worker address to preserve Play clients.
Staging is a QA APK only. The host application/Gradle gates remain mandatory.
"""
import argparse
import hashlib
import json
import os
import re
import sys
import tomllib
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[2]
CF_CONFIG = ROOT / "cartilhas_app/cloudflare/tutor-tds-gateway/wrangler.ci.toml"
STAGING_API = "https://ead.ipexdesenvolvimento.cloud/tutor-staging-api"
PRODUCTION_API = "https://ead.ipexdesenvolvimento.cloud/tutor-api"
PRODUCTION_WORKER = "https://tutor-tds-gateway.tdsipex.workers.dev"
STAGING_WORKER = "https://tutor-tds-gateway-staging.tdsipex.workers.dev"
STAGING_AI_ORIGIN = "https://ia-tutor-staging.ipexdesenvolvimento.cloud"
PROD_AI_ORIGIN = "https://ia-tutor.ipexdesenvolvimento.cloud"
RELEASE_TAG = re.compile(r"^refs/tags/v[0-9]+\.[0-9]+\.[0-9]+$")
PRODUCTION_BUILD_CONFIG = {
    "TUTOR_ENVIRONMENT": "production",
    "TUTOR_API_URL": PRODUCTION_API,
    "TUTOR_GATEWAY_URL": PRODUCTION_WORKER,
    "PRIVACY_POLICY_URL": "https://cartilhas.ipexdesenvolvimento.cloud/privacy.html",
    "ACCOUNT_DELETION_URL": "https://cartilhas.ipexdesenvolvimento.cloud/account-deletion.html",
    "REMOTE_CATALOG_ENABLED": False,
    "LEARNING_CONTEXT_ENABLED": False,
    "DURABLE_LEARNING_OUTBOX_ENABLED": False,
    "JOURNEY_TRACEABILITY_ENABLED": False,
    "DYNAMIC_ACTIVITY_ENABLED": False,
    "SIGNED_SUPPORT_IDENTITY": False,
    "PUSH_NOTIFICATIONS_ENABLED": False,
}


def environment_for_ref(ref: str) -> str:
    if ref == "refs/heads/staging":
        return "staging"
    if RELEASE_TAG.fullmatch(ref):
        return "production"
    raise ValueError("Unsupported ref: only staging branch or exact vMAJOR.MINOR.PATCH release tags")


def _checked_https(url: str) -> bool:
    parsed = urlsplit(url)
    return parsed.scheme == "https" and bool(parsed.hostname) and not (parsed.username or parsed.password or parsed.query or parsed.fragment)


def assert_environment_integrity(root: Path = ROOT) -> None:
    with (root / CF_CONFIG.relative_to(ROOT)).open("rb") as handle:
        c = tomllib.load(handle)
    prod = c["vars"]
    stage = c["env"]["staging"]
    stage_vars = stage["vars"]
    assert c["name"] == "tutor-tds-gateway"
    assert stage["name"] == "tutor-tds-gateway-staging" and stage["workers_dev"] is True
    assert c["keep_vars"] is True and "keep_vars" not in stage
    assert prod["TUTOR_ENVIRONMENT"] == "production"
    assert prod["ANYTHING_LLM_BASE_URL"] == PROD_AI_ORIGIN
    assert prod["ANYTHING_LLM_WORKSPACE"] == "cartilhas"
    assert "TUTOR_RAG_SCOPE_MAP" not in prod  # Must remain secret in production
    assert stage_vars["TUTOR_ENVIRONMENT"] == "staging"
    assert stage_vars["ANYTHING_LLM_BASE_URL"] == STAGING_AI_ORIGIN
    assert stage_vars["ANYTHING_LLM_BASE_URL"] != prod["ANYTHING_LLM_BASE_URL"]
    assert stage_vars["ANYTHING_LLM_WORKSPACE"].startswith("tds-qa-")
    scope_map = json.loads(stage_vars["TUTOR_RAG_SCOPE_MAP"])
    assert scope_map and all(str(key).startswith("tds-qa-") and str(value).startswith("tds-qa-") for key, value in scope_map.items())
    assert len(set(scope_map.values())) == len(scope_map)
    assert not stage.get("kv_namespaces"), "Staging must never bind the production CERTIFICATES KV"
    assert [kv["binding"] for kv in c["kv_namespaces"]] == ["CERTIFICATES"]
    assert c["kv_namespaces"][0]["id"] == "7d13364e03a44e22ae568ecd50629a65"
    assert set(stage["secrets"]["required"]) == {"ANYTHING_LLM_API_KEY"}
    for field in ["ANYTHING_LLM_BASE_URL"]:
        assert _checked_https(stage_vars[field]) and _checked_https(prod[field])


def render_build_config(ref: str, root: Path = ROOT, commit_sha: str | None = None) -> dict:
    env = environment_for_ref(ref)
    # Production signing/configuration is intentionally ignored by Git. CI only
    # renders an ephemeral, public target config from the tracked example.
    path = (root / "tools/ci/config/staging.json" if env == "staging"
            else root / "cartilhas_app/config/production.example.json")
    config = json.loads(path.read_text(encoding="utf-8"))
    if env == "staging":
        commit_sha = commit_sha or os.environ.get("GITHUB_SHA", "")
        if commit_sha and not re.fullmatch(r"[0-9a-f]{40}", commit_sha):
            raise ValueError("Staging build commit SHA must be full lowercase hex")
        qa_run_id = (commit_sha[:32] if commit_sha else hashlib.sha256(ref.encode()).hexdigest()[:32])
        config.update({
            "DYNAMIC_QA_ISOLATED_PACKAGE": True,
            "DYNAMIC_QA_RUN_ID": qa_run_id,
            "TUTOR_ENVIRONMENT": "staging",
            "TUTOR_API_URL": STAGING_API,
            "TUTOR_STAGING_API_URL": STAGING_API,
            "TUTOR_GATEWAY_URL": STAGING_WORKER,
            "TUTOR_STAGING_GATEWAY_URL": STAGING_WORKER,
            # The original contract allows the debugger without an isolated QA package.
            # Re-enabling per-run IDs must wait for the Gradle gate reconciliation (#182).
        })
    else:
        config.update({
            "TUTOR_ENVIRONMENT": "production",
            "TUTOR_API_URL": PRODUCTION_API,
            "TUTOR_GATEWAY_URL": PRODUCTION_WORKER,
        })
        for name in (
            "REMOTE_CATALOG_ENABLED", "LEARNING_CONTEXT_ENABLED", "DURABLE_LEARNING_OUTBOX_ENABLED",
            "JOURNEY_TRACEABILITY_ENABLED", "DYNAMIC_ACTIVITY_ENABLED", "SIGNED_SUPPORT_IDENTITY",
            "PUSH_NOTIFICATIONS_ENABLED",
        ):
            config[name] = False
        for forbidden in ("TUTOR_STAGING_API_URL", "TUTOR_STAGING_GATEWAY_URL", "DYNAMIC_QA_ISOLATED_PACKAGE", "DYNAMIC_QA_RUN_ID"):
            config.pop(forbidden, None)
    # Validate every build target: a disabled gateway would mask a failed upstream.
    assert _checked_https(config["TUTOR_GATEWAY_URL"])
    assert _checked_https(config["TUTOR_API_URL"])
    assert config["TUTOR_GATEWAY_URL"] == (STAGING_WORKER if env == "staging" else PRODUCTION_WORKER)
    assert config["TUTOR_API_URL"] == (STAGING_API if env == "staging" else PRODUCTION_API)
    if env == "production":
        assert not any("staging" in str(value).lower() for value in config.values())
        if config != PRODUCTION_BUILD_CONFIG:
            raise ValueError("Production target differs from approved release configuration")
    return config


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--ref", required=True, help="GITHUB_REF provided by GitHub Actions")
    parser.add_argument("--output", type=Path, help="Optional ephemeral JSON build config path")
    parser.add_argument("--commit-sha", help="CI commit, defaults to GITHUB_SHA")
    parser.add_argument("--validate-only", action="store_true")
    args = parser.parse_args()
    try:
        assert_environment_integrity()
        config = render_build_config(args.ref, commit_sha=args.commit_sha)
        if args.output and not args.validate_only:
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json.dumps(config, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        print("ENVIRONMENT_SELECTION=PASS; target=" + config["TUTOR_ENVIRONMENT"] + "; credentials=none")
        return 0
    except (AssertionError, ValueError, OSError, KeyError, json.JSONDecodeError) as exc:
        print("ENVIRONMENT_SELECTION=FAIL; category=" + type(exc).__name__, file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
