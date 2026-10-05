import io
import json
import re
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest.mock import patch

import e2e_harness as h

RUN = "a1" * 16
GOOD = {
    "EMULATOR_E2E_BASE_URL": "https://example.dev/tutor-staging-api",
    "EMULATOR_E2E_QA_PACKAGE":
        "com.tutortds_cartilhas.dev.dynamicqa.r" + RUN,
    "EMULATOR_E2E_DEVICE": "emulator-5556",
    "EMULATOR_E2E_RUN_ID": RUN,
}


class HarnessTest(unittest.TestCase):
    def run_main(self, argv, env):
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            code = h.main(argv, env)
        return code, out.getvalue(), err.getvalue()

    def test_valid_config(self):
        self.assertEqual(h.validate(GOOD, ["login_activation"]), [])

    def test_fail_closed_when_missing(self):
        code, _, err = self.run_main([], {})
        self.assertEqual(code, 2)
        self.assertIn("CONFIG_REJECTED", err)

    def test_rejects_production_or_non_staging_target(self):
        for base in (
            "https://ead.ipexdesenvolvimento.cloud/tutor-api",
            "https://example.dev/api",
            "http://example.dev/tutor-staging-api",
        ):
            values = dict(GOOD, EMULATOR_E2E_BASE_URL=base)
            self.assertTrue(h.validate(values, ["login_activation"]), base)

    def test_rejects_legacy_dev_and_malformed_isolated_package(self):
        for package in (
            "com.tutortds_cartilhas.dev",
            "com.tutortds_cartilhas.dev.dynamicqa.rXYZ",
            "com.tutortds_cartilhas.dev.dynamicqa.r" + "A1" * 16,
            "com.tutortds_cartilhas.dev.dynamicqa.r" + "a1" * 15,
        ):
            values = dict(GOOD, EMULATOR_E2E_QA_PACKAGE=package)
            self.assertTrue(h.validate(values, ["login_activation"]), package)

    def test_rejects_package_run_id_mismatch(self):
        values = dict(GOOD, EMULATOR_E2E_RUN_ID="b2" * 16)
        self.assertTrue(h.validate(values, ["login_activation"]))

    def test_rejects_physical_device(self):
        values = dict(GOOD, EMULATOR_E2E_DEVICE="ABC123")
        self.assertTrue(h.validate(values, ["login_activation"]))

    def test_execute_requires_only_selected_role_credentials(self):
        env = {
            "STAGING_SEED_STUDENT_CPF": "12345678909",
            "STAGING_SEED_STUDENT_PASSWORD": "synthetic-password",
        }
        self.assertEqual(
            h.validate(
                GOOD,
                ["participant_flow"],
                require_credentials=True,
                env=env,
            ),
            [],
        )
        errors = h.validate(
            GOOD,
            ["account_switch"],
            require_credentials=True,
            env=env,
        )
        self.assertTrue(any("TEACHER" in error for error in errors))

    def test_default_profile_run_excludes_operator_and_certificate(self):
        self.assertNotIn("operator_flow", h.DEFAULT_SCENARIOS)
        self.assertNotIn("certificate", h.DEFAULT_SCENARIOS)
        self.assertIn("monitor_projection", h.DEFAULT_SCENARIOS)
        self.assertIn("creator_surface", h.DEFAULT_SCENARIOS)

    def test_dry_run_never_passes_and_hides_secrets(self):
        env = dict(
            GOOD,
            STAGING_SEED_STUDENT_CPF="12345678909",
            STAGING_SEED_STUDENT_PASSWORD="s3cr3t-value",
        )
        code, out, _ = self.run_main([], env)
        self.assertEqual(code, 0)
        data = json.loads(out)
        self.assertFalse(data["real_e2e_run"])
        self.assertEqual(data["result"], "NOT_RUN")
        self.assertNotIn("s3cr3t-value", out)
        self.assertNotIn("12345678909", out)

    def test_args_override_env(self):
        code, out, _ = self.run_main(
            [
                "--base-url",
                GOOD["EMULATOR_E2E_BASE_URL"],
                "--package",
                GOOD["EMULATOR_E2E_QA_PACKAGE"],
                "--device",
                GOOD["EMULATOR_E2E_DEVICE"],
                "--run-id",
                GOOD["EMULATOR_E2E_RUN_ID"],
                "--scenario",
                "login_activation",
            ],
            {},
        )
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(out)["scenarios"], ["login_activation"])

    def test_flutter_command_pins_staging_dynamic_qa(self):
        command = h.flutter_command(
            GOOD,
            "monitor_projection",
            "/tmp/qa-secrets.json",
        )
        joined = " ".join(command)
        self.assertIn("--dart-define-from-file=config/staging.qa.json", joined)
        self.assertIn("DYNAMIC_QA_ISOLATED_PACKAGE=true", joined)
        self.assertIn(f"DYNAMIC_QA_RUN_ID={RUN}", joined)
        self.assertIn("EMULATOR_E2E_SCENARIO=monitor_projection", joined)
        self.assertIn("/tmp/qa-secrets.json", joined)

    def test_host_signals_toggle_network_and_capture_in_app(self):
        with tempfile.TemporaryDirectory() as temp:
            evidence = Path(temp)
            with patch.object(h, "_network") as network, patch.object(
                h, "_screenshot", return_value=True
            ) as screenshot:
                self.assertEqual(
                    h._handle_host_signal(
                        GOOD,
                        "offline_reconnect",
                        h.HOST_SIGNAL_PREFIX + "NETWORK_OFFLINE",
                        evidence,
                    ),
                    "NETWORK_OFFLINE",
                )
                network.assert_called_once_with(GOOD, False)
                network.reset_mock()
                self.assertEqual(
                    h._handle_host_signal(
                        GOOD,
                        "offline_reconnect",
                        h.HOST_SIGNAL_PREFIX + "NETWORK_ONLINE",
                        evidence,
                    ),
                    "NETWORK_ONLINE",
                )
                network.assert_called_once_with(GOOD, True)
                self.assertEqual(
                    h._handle_host_signal(
                        GOOD,
                        "participant_flow",
                        h.HOST_SIGNAL_PREFIX + "SCREENSHOT",
                        evidence,
                    ),
                    "SCREENSHOT",
                )
                screenshot.assert_called_with(
                    GOOD, evidence / "participant_flow.png"
                )
                self.assertEqual(
                    h._handle_host_signal(
                        GOOD,
                        "offline_reconnect",
                        h.HOST_SIGNAL_PREFIX + "SCREENSHOT_OFFLINE",
                        evidence,
                    ),
                    "SCREENSHOT_OFFLINE",
                )
                screenshot.assert_called_with(
                    GOOD, evidence / "offline_reconnect-offline.png"
                )

    def test_unknown_host_signal_fails_closed(self):
        with tempfile.TemporaryDirectory() as temp:
            with self.assertRaisesRegex(RuntimeError, "unknown E2E host signal"):
                h._handle_host_signal(
                    GOOD,
                    "participant_flow",
                    h.HOST_SIGNAL_PREFIX + "UNKNOWN",
                    Path(temp),
                )

    def test_sanitize(self):
        env = {
            "STAGING_SEED_STUDENT_PASSWORD": "hunter2-value",
            "STAGING_SEED_STUDENT_CPF": "123.456.789-09",
        }
        raw = (
            "Authorization: bearer-token password=hunter2-value "
            "cpf 123.456.789-09 eyJabc.def.ghi"
        )
        text = h.sanitize(raw, env)
        for leak in ("hunter2-value", "123.456.789-09", "eyJabc.def.ghi"):
            self.assertNotIn(leak, text)

    def test_no_hardcoded_external_url_or_secret_in_sources(self):
        root = Path(__file__).parent
        text = (root / "e2e_harness.py").read_text()
        self.assertFalse(re.search(r"https://[a-z0-9.-]+", text))
        self.assertNotIn("STAGING_SEED_STUDENT_PASSWORD =", text)

    def test_dart_scenarios_are_implemented_or_explicitly_blocked(self):
        dart = Path(__file__).parents[3] / "cartilhas_app" / h.TARGET
        text = dart.read_text()
        self.assertIn("TUTOR_ENVIRONMENT", text)
        self.assertNotIn("not implemented in the fail-closed harness", text)
        for scenario in h.SCENARIOS:
            self.assertIn(f"'{scenario}'", text)
        self.assertIn("Blocked by Issue #120", text)
        self.assertIn("TDS_E2E_HOST:", text)
        self.assertIn("NETWORK_OFFLINE", text)
        self.assertIn("NETWORK_ONLINE", text)
        self.assertIn("SCREENSHOT_OFFLINE", text)
        self.assertNotIn("EMULATOR_E2E_OFFLINE_PHASE", text)


if __name__ == "__main__":
    unittest.main()
