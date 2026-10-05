import io
import json
import re
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path

import e2e_harness as h

GOOD = {
    "EMULATOR_E2E_BASE_URL": "https://tutor-tds-staging.example.dev",
    "EMULATOR_E2E_QA_PACKAGE": "com.tutortds_cartilhas.dev",
    "EMULATOR_E2E_DEVICE": "emulator-5556",
}
ALL = list(h.SCENARIOS)


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

    def test_rejects_production_package_and_host(self):
        e = dict(GOOD, EMULATOR_E2E_QA_PACKAGE="com.tutortds_cartilhas")
        self.assertTrue(h.validate(e, ["login_activation"]))
        e = dict(GOOD, EMULATOR_E2E_BASE_URL="https://ead.ipexdesenvolvimento.cloud")
        self.assertTrue(h.validate(e, ["login_activation"]))
        e = dict(GOOD, EMULATOR_E2E_BASE_URL="http://tutor-tds-staging.example.dev")
        self.assertTrue(h.validate(e, ["login_activation"]))

    def test_rejects_physical_device(self):
        self.assertTrue(h.validate(dict(GOOD, EMULATOR_E2E_DEVICE="ABC123"), ["login_activation"]))

    def test_certificate_requires_context(self):
        self.assertTrue(h.validate(GOOD, ["certificate"]))
        e = dict(GOOD, EMULATOR_E2E_CERTIFICATE_CONTEXT_ID="ctx")
        self.assertEqual(h.validate(e, ["certificate"]), [])

    def test_dry_run_never_passes_and_hides_secrets(self):
        env = dict(GOOD, QA_ACCOUNT_B_ID="b", QA_ACCOUNT_A_ID="12345678901", QA_ACCOUNT_A_SECRET="s3cr3t-value")
        code, out, _ = self.run_main([], env)
        self.assertEqual(code, 0)
        data = json.loads(out)
        self.assertFalse(data["real_e2e_run"])
        self.assertEqual(data["result"], "NOT_RUN")
        self.assertNotIn("s3cr3t-value", out)
        self.assertNotIn("12345678901", out)

    def test_args_override_env(self):
        code, out, _ = self.run_main(
            ["--base-url", GOOD["EMULATOR_E2E_BASE_URL"], "--scenario", "login_activation"],
            {k: v for k, v in GOOD.items() if k != "EMULATOR_E2E_BASE_URL"})
        self.assertEqual(code, 0)

    def test_sanitize(self):
        raw = "Authorization: ****** ****** cpf 123.456.789-01"
        t = h.sanitize(raw, {})
        for leak in ("abc.def", "hunter2", "123.456.789-01"):
            self.assertNotIn(leak, t)

    def test_no_hardcoded_production_or_secrets_in_sources(self):
        root = Path(__file__).parent
        text = (root / "e2e_harness.py").read_text()
        self.assertFalse(re.search(r"https://[a-z0-9.-]+\.[a-z]{2,}", text.replace("ead.ipexdesenvolvimento.cloud", "")))

    def test_dart_scenarios_are_fail_closed(self):
        dart = Path(__file__).parents[3] / "cartilhas_app" / h.TARGET
        text = dart.read_text()
        self.assertIn("TUTOR_ENVIRONMENT", text)
        for s in ALL:
            self.assertIn(f"'{s}'", text)


if __name__ == "__main__":
    unittest.main()
