#!/usr/bin/env python3
"""Offline validation of an editorial AI preparation plan, never activation."""

import argparse
import json
from pathlib import Path


PACKAGES = {
    "drupal/ai": "1.5.1",
    "drupal/ai_ckeditor": "1.4.3",
    "drupal/key": "1.22",
    "drupal/ai_provider_openrouter": "1.1.6",
}
BEHAVIOR = {
    "manual_only": True,
    "auto_publish": False,
    "tools": False,
    "academic_context": False,
    "log_payloads": False,
}
LIMITS = {
    "input_characters": 4000,
    "output_tokens": 512,
    "requests_per_user_per_hour": 10,
    "concurrency": 1,
}
READINESS = {
    "dependency_resolution", "provider_code_review", "quota_enforcement",
    "privacy_browser_test", "real_staging_test",
}


def load_json(path):
    """Do not echo input, paths, exception text or credentials on failures."""
    return json.loads(path.read_text(encoding="utf-8"))


def normalized_version(version):
    """Accept Composer's optional patch zero for a two-component release pin."""
    parts = version.removeprefix("v").split(".")
    if len(parts) == 2 and all(part.isdecimal() for part in parts):
        parts.append("0")
    return ".".join(parts)


def safe_plan(plan):
    if not isinstance(plan, dict) or set(plan) != {
        "schema_version", "enabled", "environment", "provider", "actions",
        "allowed_bundles", "limits", "behavior", "packages", "readiness",
    }:
        return False
    if type(plan["schema_version"]) is not int or plan["schema_version"] != 1:
        return False
    if plan["enabled"] is not False or plan["environment"] != "local":
        return False
    if plan["provider"] != {
        "id": "openrouter",
        "base_url": "https://openrouter.ai/api/v1",
        "model": "google/gemini-2.5-flash-lite",
        "key_env": "TDS_EDITORIAL_OPENROUTER_API_KEY",
    }:
        return False
    if plan["actions"] != ["summarize", "spell_fix", "tone"]:
        return False
    if plan["allowed_bundles"] != ["tds_news", "tds_faq"]:
        return False
    behavior = plan["behavior"]
    if not isinstance(behavior, dict) or set(behavior) != set(BEHAVIOR):
        return False
    if any(behavior[key] is not value for key, value in BEHAVIOR.items()):
        return False
    limits = plan["limits"]
    if not isinstance(limits, dict) or set(limits) != set(LIMITS):
        return False
    if any(type(limits[key]) is not int or not 1 <= limits[key] <= cap
           for key, cap in LIMITS.items()):
        return False
    readiness = plan["readiness"]
    return (
        plan["packages"] == PACKAGES
        and isinstance(readiness, dict)
        and set(readiness) == READINESS
        and all(value is False for value in readiness.values())
    )


def check_workflow(root):
    try:
        import yaml
        workflow = yaml.safe_load((root / "config/sync/workflows.workflow.tds_editorial.yml").read_text())
        settings = workflow["type_settings"]
        states = settings["states"]
        transitions = settings["transitions"]
        return (
            workflow["status"] is True
            and workflow["type"] == "content_moderation"
            and settings["default_moderation_state"] == "draft"
            and states["draft"]["published"] is False
            and states["review"]["published"] is False
            and states["published"]["published"] is True
            and {"tds_news", "tds_faq"}.issubset(settings["entity_types"]["node"])
            and any(t["to"] == "review" and "draft" in t["from"] for t in transitions.values())
            and any(t["to"] == "published" and "review" in t["from"] for t in transitions.values())
            and all("draft" not in t["from"] for t in transitions.values() if t["to"] == "published")
        )
    except Exception:
        return False


def inspect(root, plan_path, audit_lock=None):
    result = {"prepared": False, "activation_ready": False, "blockers": [],
              "missing_packages": [], "version_mismatches": [],
              "dependency_scope": "audit_lock" if audit_lock else "runtime_lock"}
    try:
        plan = load_json(plan_path)
    except Exception:
        result["blockers"].append("plan_unreadable_or_invalid_json")
        return result
    if not safe_plan(plan):
        result["blockers"].append("unsafe_or_unsupported_plan")
        return result
    if not check_workflow(root):
        result["blockers"].append("editorial_workflow_unverified")
        return result
    try:
        lock = load_json(audit_lock if audit_lock is not None else root / "composer.lock")
        packages = lock["packages"] + lock.get("packages-dev", [])
        installed = {p["name"]: p["version"].removeprefix("v") for p in packages}
    except Exception:
        result["blockers"].append("dependency_lock_unreadable_or_invalid")
        return result
    for name, version in PACKAGES.items():
        if name not in installed:
            result["missing_packages"].append(name)
        elif normalized_version(installed[name]) != normalized_version(version):
            # Only print known package names, never arbitrary lock content.
            result["version_mismatches"].append(name)
    if result["missing_packages"] or result["version_mismatches"]:
        result["blockers"].append("dependency_resolution_pending")
    if audit_lock is not None:
        result["blockers"].append("isolated_dependencies_not_installed_in_runtime")
    result["blockers"].extend([
        "provider_code_review_pending", "quota_enforcement_pending",
        "privacy_browser_test_pending", "real_staging_test_pending",
        "activation_requires_separate_review",
    ])
    result["prepared"] = True
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--plan", type=Path)
    parser.add_argument("--require-dependencies", action="store_true")
    parser.add_argument("--audit-lock", type=Path, help="Inspect an isolated audit lock; never implies runtime installation")
    args = parser.parse_args()
    result = inspect(args.root, args.plan or args.root / "pilots/editorial-ai/pilot-plan.json", args.audit_lock)
    print(json.dumps(result, sort_keys=True))
    if not result["prepared"]:
        return 1
    if args.require_dependencies and (result["missing_packages"] or result["version_mismatches"]):
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
