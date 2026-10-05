import argparse
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import harness


SHA_A = "a" * 40
SHA_B = "b" * 40
SHA_C = "c" * 40
PKG = "com.tutortds_cartilhas.dev.dynamicqa.r" + "a1" * 16


def args(**overrides):
    values = {
        "api_head": SHA_A,
        "app_head": SHA_B,
        "compose_head": SHA_C,
        "base_url": "http://10.0.2.2:8000",
        "package": PKG,
        "device": "emulator-5556",
        "repo_root": ".",
        "flutter": "flutter",
        "init_evidence": None,
        "validate_evidence": None,
        "require_complete": False,
        "execute": False,
    }
    values.update(overrides)
    return argparse.Namespace(**values)


class HarnessTests(unittest.TestCase):
    def test_config_accepts_loopback_emulator_isolated_package(self):
        self.assertEqual(harness.validate_config(args(), executing=True), [])

    def test_config_rejects_shared_staging_for_mutating_execute(self):
        value = args(base_url="https://tutor-tds-staging.fastapicloud.dev")
        errors = harness.validate_config(value, executing=True)
        self.assertTrue(any("loopback" in item for item in errors))

    def test_config_rejects_production_physical_and_nonisolated(self):
        value = args(
            base_url="https://ead.ipexdesenvolvimento.cloud",
            package="com.tutortds_cartilhas",
            device="ABC123",
        )
        errors = harness.validate_config(value, executing=True)
        self.assertTrue(any("production" in item for item in errors))
        self.assertTrue(any("isolated" in item for item in errors))
        self.assertTrue(any("emulator" in item for item in errors))

    def test_template_is_never_pass_by_default(self):
        data = harness.empty_manifest(args())
        self.assertTrue(all(v["status"] == "NOT_RUN" for v in data["stages"].values()))
        self.assertTrue(all(v["status"] == "NOT_RUN" for v in data["invariants"].values()))
        self.assertEqual(data["certificate_boundary"]["emitted"], None)

    def test_complete_manifest_requires_every_stage_and_invariant(self):
        data = harness.empty_manifest(args())
        for item in data["stages"].values():
            item.update(status="PASS", evidence=["synthetic-evidence.json"])
        for item in data["invariants"].values():
            item.update(status="PASS", evidence=["synthetic-evidence.json"])
        data["certificate_boundary"] = {
            "request_status": "approved",
            "emitted": False,
            "institutional_release": "blocked",
        }
        self.assertEqual(harness.validate_manifest(data, require_complete=True), [])

    def test_certificate_cannot_be_claimed_emitted(self):
        data = harness.empty_manifest(args())
        data["certificate_boundary"] = {
            "request_status": "approved",
            "emitted": True,
            "institutional_release": "blocked",
        }
        errors = harness.validate_manifest(data, require_complete=False)
        self.assertTrue(any("must not be reported emitted" in item for item in errors))

    def test_complete_rejects_qr_invariant_not_passed(self):
        data = harness.empty_manifest(args())
        for item in data["stages"].values():
            item["status"] = "PASS"
        for item in data["invariants"].values():
            item["status"] = "PASS"
        data["invariants"]["qr_not_official_presence"]["status"] = "FAIL"
        data["certificate_boundary"] = {
            "request_status": "approved",
            "emitted": False,
            "institutional_release": "blocked",
        }
        errors = harness.validate_manifest(data, require_complete=True)
        self.assertIn("invariant not passed: qr_not_official_presence", errors)

    def test_cli_creates_and_validates_template_without_fabricating_pass(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "evidence.json"
            common = [
                "--api-head", SHA_A,
                "--app-head", SHA_B,
                "--compose-head", SHA_C,
                "--base-url", "http://10.0.2.2:8000",
                "--package", PKG,
                "--device", "emulator-5556",
            ]
            self.assertEqual(harness.main(common + ["--init-evidence", str(target)]), 0)
            payload = json.loads(target.read_text())
            self.assertEqual(payload["stages"]["prepare_class"]["status"], "NOT_RUN")
            self.assertEqual(
                harness.main(common + ["--validate-evidence", str(target)]),
                0,
            )
            self.assertEqual(
                harness.main(
                    common
                    + ["--validate-evidence", str(target), "--require-complete"]
                ),
                3,
            )


if __name__ == "__main__":
    unittest.main()
