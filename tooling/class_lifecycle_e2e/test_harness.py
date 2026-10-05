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
        "base_url": "https://10.0.2.2:18040",
        "package": PKG,
        "device": "emulator-5556",
        "repo_root": ".",
        "flutter": "flutter",
        "api_python": "python3",
        "openssl": "openssl",
        "init_evidence": None,
        "validate_evidence": None,
        "evidence_output": None,
        "require_complete": False,
        "execute": False,
    }
    values.update(overrides)
    return argparse.Namespace(**values)


class HarnessTests(unittest.TestCase):
    def test_config_accepts_https_loopback_emulator_isolated_package(self):
        self.assertEqual(harness.validate_config(args(), executing=True), [])

    def test_config_rejects_http_loopback_for_execute(self):
        errors = harness.validate_config(
            args(base_url="http://10.0.2.2:18040"),
            executing=True,
        )
        self.assertTrue(any("HTTPS" in item for item in errors))

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

    def test_flutter_command_enforces_real_isolated_debug_package(self):
        command = harness.build_flutter_command(args())
        joined = "\n".join(command)
        self.assertIn("--dart-define=DYNAMIC_QA_ISOLATED_PACKAGE=true", command)
        self.assertIn(
            "--dart-define=DYNAMIC_QA_RUN_ID=" + "a1" * 16,
            command,
        )
        self.assertIn(
            "--dart-define=TUTOR_API_URL=" + harness.APPROVED_BUILD_STAGING,
            command,
        )
        self.assertIn(
            "--dart-define=CLASS_LIFECYCLE_E2E_BASE_URL=https://10.0.2.2:18040",
            command,
        )
        self.assertNotIn("ead.ipexdesenvolvimento.cloud/tutor-api", joined)

    def test_template_is_never_pass_by_default(self):
        data = harness.empty_manifest(args())
        self.assertTrue(
            all(v["status"] == "NOT_RUN" for v in data["stages"].values())
        )
        self.assertTrue(
            all(v["status"] == "NOT_RUN" for v in data["invariants"].values())
        )
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
        self.assertEqual(
            harness.validate_manifest(data, require_complete=True),
            [],
        )

    def test_certificate_cannot_be_claimed_emitted(self):
        data = harness.empty_manifest(args())
        data["certificate_boundary"] = {
            "request_status": "approved",
            "emitted": True,
            "institutional_release": "blocked",
        }
        errors = harness.validate_manifest(data, require_complete=False)
        self.assertTrue(
            any("must not be reported emitted" in item for item in errors)
        )

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
        self.assertIn(
            "invariant not passed: qr_not_official_presence",
            errors,
        )

    def test_execution_marker_consolidates_live_and_backend_proofs(self):
        payload = {
            "front": "CLASS_LIFECYCLE_E2E",
            "run_id": "a1" * 16,
            "api_head": SHA_A,
            "app_head": SHA_B,
            "compose_head": SHA_C,
            "class_id": "synthetic-class",
            "course_version_id": "qa-v1",
            "production_changed": False,
            "shared_staging_changed": False,
            "observed": {
                "prepare_class": True,
                "participant": True,
                "enrollment": True,
                "meeting": True,
                "qr_checkin": True,
                "attendance_evidence": True,
                "close_meeting": True,
                "close_class_readiness": True,
                "offline_reconnect": True,
                "territorial_fixture": {
                    "offer_municipality": "Palmas",
                    "participant_residence_reference": "Itaguatins",
                    "residence_reference_persisted_in_classroom": False,
                },
                "physical_location_persisted": True,
                "cross_scope_denied": True,
                "teacher_monitor_surfaces_distinct": True,
                "qr_not_official_presence": True,
                "close_session_with_explicit_pending": True,
                "closed_class_rejects_new_link": True,
                "course_version_stable_live": True,
                "certificate_boundary": {
                    "request_status": "approved",
                    "emitted": False,
                    "institutional_release": "blocked",
                },
            },
        }
        manifest = harness._manifest_from_execution(args(), payload)
        self.assertEqual(
            harness.validate_manifest(manifest, require_complete=True),
            [],
        )
        self.assertIn(
            "backend-contract:"
            "test_capacity_30_blocks_operator_and_only_coordinator_override_is_audited",
            manifest["invariants"]["capacity_policy_enforced"]["evidence"],
        )

    def test_execution_marker_rejects_mismatched_heads_and_run_id(self):
        base_payload = {
            "front": "CLASS_LIFECYCLE_E2E",
            "run_id": "a1" * 16,
            "api_head": SHA_A,
            "app_head": SHA_B,
            "compose_head": SHA_C,
            "production_changed": False,
            "shared_staging_changed": False,
            "observed": {},
        }
        for key, bad_value in (
            ("api_head", "d" * 40),
            ("app_head", "d" * 40),
            ("compose_head", "d" * 40),
            ("run_id", "b2" * 16),
        ):
            payload = dict(base_payload)
            payload[key] = bad_value
            with self.subTest(key=key):
                with self.assertRaises(ValueError):
                    harness._manifest_from_execution(args(), payload)

    def test_marker_parser_rejects_missing_or_malformed_result(self):
        with self.assertRaises(ValueError):
            harness._parse_flutter_marker("All tests passed")
        with self.assertRaises(ValueError):
            harness._parse_flutter_marker(
                "CLASS_LIFECYCLE_E2E_RESULT={not-json}"
            )

    def test_cli_creates_and_validates_template_without_fabricating_pass(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / "evidence.json"
            common = [
                "--api-head",
                SHA_A,
                "--app-head",
                SHA_B,
                "--compose-head",
                SHA_C,
                "--base-url",
                "https://10.0.2.2:18040",
                "--package",
                PKG,
                "--device",
                "emulator-5556",
            ]
            self.assertEqual(
                harness.main(common + ["--init-evidence", str(target)]),
                0,
            )
            payload = json.loads(target.read_text())
            self.assertEqual(
                payload["stages"]["prepare_class"]["status"],
                "NOT_RUN",
            )
            self.assertEqual(
                harness.main(
                    common + ["--validate-evidence", str(target)]
                ),
                0,
            )
            self.assertEqual(
                harness.main(
                    common
                    + [
                        "--validate-evidence",
                        str(target),
                        "--require-complete",
                    ]
                ),
                3,
            )


if __name__ == "__main__":
    unittest.main()
