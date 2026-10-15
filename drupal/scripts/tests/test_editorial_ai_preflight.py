"""Policy failures and release separation, using only local synthetic files."""

import copy
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "editorial-ai-preflight.py"
spec = importlib.util.spec_from_file_location("preflight", SCRIPT)
preflight = importlib.util.module_from_spec(spec)
spec.loader.exec_module(preflight)

PLAN = {
    "schema_version": 1, "enabled": False, "environment": "local",
    "provider": {"id": "openrouter", "base_url": "https://openrouter.ai/api/v1",
                 "model": "google/gemini-2.5-flash-lite", "key_env": "TDS_EDITORIAL_OPENROUTER_API_KEY"},
    "actions": ["summarize", "spell_fix", "tone"], "allowed_bundles": ["tds_news", "tds_faq"],
    "limits": dict(preflight.LIMITS), "behavior": dict(preflight.BEHAVIOR),
    "packages": dict(preflight.PACKAGES), "readiness": dict.fromkeys(preflight.READINESS, False),
}


class PreparationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.plan = self.root / "plan.json"
        self.plan.write_text(json.dumps(PLAN))
        config = self.root / "config/sync"
        config.mkdir(parents=True)
        self.workflow = config / "workflows.workflow.tds_editorial.yml"
        self.workflow.write_text((SCRIPT.parents[1] / "config/sync/workflows.workflow.tds_editorial.yml").read_text())
        (self.root / "composer.lock").write_text('{"packages": []}')

    def inspect(self):
        return preflight.inspect(self.root, self.plan)

    def test_missing_dependencies_are_pending_not_activation(self):
        result = self.inspect()
        self.assertTrue(result["prepared"])
        self.assertFalse(result["activation_ready"])
        self.assertEqual(set(result["missing_packages"]), set(preflight.PACKAGES))
        self.assertIn("dependency_resolution_pending", result["blockers"])

    def test_exact_dependency_lock_still_never_approves_activation(self):
        (self.root / "composer.lock").write_text(json.dumps({"packages": [
            {"name": name, "version": version} for name, version in preflight.PACKAGES.items()
        ]}))
        result = self.inspect()
        self.assertTrue(result["prepared"])
        self.assertFalse(result["activation_ready"])
        self.assertEqual(result["missing_packages"], [])
        self.assertIn("real_staging_test_pending", result["blockers"])

    def test_mismatched_versions_do_not_echo_lock_values(self):
        (self.root / "composer.lock").write_text(json.dumps({"packages": [
            {"name": "drupal/ai", "version": "sensitive-unexpected-value"}
        ]}))
        result = self.inspect()
        self.assertEqual(result["version_mismatches"], ["drupal/ai"])
        self.assertNotIn("sensitive-unexpected-value", json.dumps(result))

    def test_composer_patch_zero_is_equivalent_to_two_part_pin(self):
        (self.root / "composer.lock").write_text(json.dumps({"packages": [
            {"name": "drupal/key", "version": "v1.22.0"}
        ]}))
        self.assertNotIn("drupal/key", self.inspect()["version_mismatches"])

    def test_unsafe_plan_variations_fail_closed(self):
        variants = [
            ("enabled", None, True), ("environment", None, "production"),
            ("schema_version", None, True),
            ("provider", "base_url", "https://openrouter.ai.evil.example/api/v1"),
            ("provider", "base_url", "https://user:secret@openrouter.ai/api/v1"),
            ("provider", "model", "deepseek/model"),
            ("provider", "key_env", "ANYTHING_LLM_API_KEY"),
            ("behavior", "log_payloads", True), ("behavior", "auto_publish", True),
            ("behavior", "manual_only", 1), ("readiness", "real_staging_test", True),
            ("limits", "output_tokens", 0), ("limits", "output_tokens", 513),
            ("limits", "concurrency", True), ("limits", "concurrency", 1.0),
            ("actions", None, ["publish"]), ("allowed_bundles", None, ["student"]),
        ]
        for field, key, value in variants:
            with self.subTest(field=field, key=key, value=value):
                plan = copy.deepcopy(PLAN)
                if key:
                    plan[field][key] = value
                else:
                    plan[field] = value
                self.plan.write_text(json.dumps(plan))
                self.assertEqual(self.inspect()["blockers"], ["unsafe_or_unsupported_plan"])

    def test_malformed_input_sanitized(self):
        self.plan.write_text('{"secret": "never-echo-this"')
        result = self.inspect()
        self.assertFalse(result["prepared"])
        self.assertNotIn("never-echo-this", json.dumps(result))
        self.assertNotIn(str(self.root), json.dumps(result))

    def test_unknown_fields_and_missing_lock_rejected(self):
        plan = copy.deepcopy(PLAN)
        plan["api_key"] = "never-echo-this"
        self.plan.write_text(json.dumps(plan))
        self.assertFalse(self.inspect()["prepared"])
        self.plan.write_text(json.dumps(PLAN))
        (self.root / "composer.lock").unlink()
        self.assertEqual(self.inspect()["blockers"], ["dependency_lock_unreadable_or_invalid"])

    def test_workflow_cannot_skip_review(self):
        import yaml
        workflow = yaml.safe_load(self.workflow.read_text())
        workflow["type_settings"]["transitions"]["publish"]["from"].append("draft")
        self.workflow.write_text(yaml.safe_dump(workflow))
        self.assertEqual(self.inspect()["blockers"], ["editorial_workflow_unverified"])

    def test_cli_exit_status_distinguishes_preparation_from_dependencies(self):
        command = [sys.executable, str(SCRIPT), "--root", str(self.root), "--plan", str(self.plan)]
        normal = subprocess.run(command, capture_output=True, text=True)
        required = subprocess.run(command + ["--require-dependencies"], capture_output=True, text=True)
        self.assertEqual(normal.returncode, 0)
        self.assertEqual(required.returncode, 2)
        self.assertFalse(json.loads(required.stdout)["activation_ready"])


if __name__ == "__main__":
    unittest.main()
