[Reading 177 lines from start (total: 177 lines, 0 remaining)]

from __future__ import annotations

import unittest

from pathlib import Path

from pr_gate import (
    ALWAYS_REQUIRED_WORKFLOWS,
    classify_paths,
    embedded_python_blocks,
    workflow_states,
)


class PathClassifierTests(unittest.TestCase):
    def assert_domains(self, paths, **expected):
        result = classify_paths(paths)
        self.assertEqual(result["unclassified"], [])
        for key, value in expected.items():
            self.assertEqual(result[key], value, key)
        return result

    def test_docs_only_is_neutral(self):
        result = self.assert_domains(
            ["docs/production/README.md", "docs/operations/runbook.md"],
            docs_only=True,
            flutter=False,
            api=False,
            release=False,
            backup=False,
            wp_core=False,
            wp_child_theme=False,
            watchdog=False,
        )
        self.assertEqual(result["required_workflows"], list(ALWAYS_REQUIRED_WORKFLOWS))

    def test_pr82_api(self):
        result = self.assert_domains(
            [
                "api/app/auth.py",
                "api/app/config.py",
                "api/migrations/versions/20261003_0025_cpf_activation.py",
                "api/tests/test_auth_activation_recovery.py",
            ],
            api=True,
            flutter=False,
            release=False,
        )
        self.assertIn("Tutor TDS API CI and staging", result["required_workflows"])

    def test_pr83_flutter(self):
        result = self.assert_domains(
            [
                "cartilhas_app/tool/verify_release_readiness.dart",
                "cartilhas_app/test/release_readiness_verifier_test.dart",
            ],
            flutter=True,
            api=False,
            release=False,
        )
        self.assertIn("Tutor TDS Flutter app checks", result["required_workflows"])

    def test_pr84_child_theme(self):
        result = self.assert_domains(
            [
                "docs/portal/WP3B_CURATED_STORIES_2026-10-04.md",
                "wordpress/tds-child-theme/front-page.php",
                "wordpress/tds-child-theme/inc/home-components.php",
            ],
            docs_only=False,
            wp_child_theme=True,
            wp_core=False,
        )
        self.assertNotIn("WordPress portal foundation", result["required_workflows"])

    def test_pr85_watchdog(self):
        self.assert_domains(
            [
                ".github/workflows/tds-vps-watchdog.yml",
                "tooling/security/test_watchdog_smtp_observability.py",
            ],
            watchdog=True,
            watchdog_workflow=True,
            observability=False,
        )

    def test_pr86_api_and_release(self):
        result = self.assert_domains(
            [
                "api/ops/rehearse_production_upgrade.py",
                "api/tests/test_rehearse_production_upgrade.py",
                "tooling/Test-ProductionBackendIdentity.ps1",
                "tooling/build_production.ps1",
            ],
            api=True,
            release=True,
        )
        self.assertIn("Tutor TDS API CI and staging", result["required_workflows"])
        self.assertIn("Tutor TDS release identity gate", result["required_workflows"])

    def test_pr88_observability(self):
        self.assert_domains(
            [
                "docs/operations/OBSERVABILITY_MATRIX.md",
                "tools/observability/synthetic_runner.py",
                "tools/observability/test_synthetic_runner.py",
            ],
            docs_only=False,
            watchdog=True,
            observability=True,
        )

    def test_backup_domain(self):
        result = self.assert_domains(
            ["tooling/backup_automation/backup.mjs"],
            backup=True,
        )
        self.assertIn(
            "Tutor TDS backup automation contracts", result["required_workflows"]
        )

    def test_wp_core_domain(self):
        result = self.assert_domains(
            ["wordpress/tds-portal-core/tds-portal-core.php"],
            wp_core=True,
        )
        self.assertIn("WordPress portal foundation", result["required_workflows"])

    def test_gate_self_change_is_infra(self):
        self.assert_domains(
            [
                ".github/workflows/pr-required-gate.yml",
                "tooling/ci/pr_gate.py",
                "tooling/ci/test_pr_gate.py",
            ],
            watchdog=True,
        )

    def test_unknown_code_fails_closed(self):
        result = classify_paths(["new_product/runtime.bin"])
        self.assertEqual(result["unclassified"], ["new_product/runtime.bin"])


class WatchdogStaticTests(unittest.TestCase):
    def test_canonical_watchdog_embedded_python_blocks_compile(self):
        workflow = Path(__file__).resolve().parents[2] / ".github" / "workflows" / "tds-vps-watchdog.yml"
        blocks = embedded_python_blocks(workflow)
        self.assertEqual(len(blocks), 2)
        for index, block in enumerate(blocks, start=1):
            compile(block, f"watchdog-block-{index}", "exec")


class WorkflowStateTests(unittest.TestCase):
    def test_latest_pull_request_run_wins(self):
        required = ["A", "B"]
        runs = [
            {"id": 1, "name": "A", "status": "completed", "conclusion": "failure"},
            {"id": 2, "name": "A", "status": "completed", "conclusion": "success"},
            {"id": 3, "name": "B", "status": "in_progress", "conclusion": None},
        ]
        self.assertEqual(
            workflow_states(runs, required),
            {
                "A": ("completed", "success"),
                "B": ("in_progress", None),
            },
        )

    def test_missing_workflow_is_explicit(self):
        self.assertEqual(
            workflow_states([], ["Required"]),
            {"Required": ("missing", None)},
        )


if __name__ == "__main__":
    unittest.main()

[executed on device: avellaria (50b7ca2d-9d90-4e32-ab9d-7f5d2869d5eb)]