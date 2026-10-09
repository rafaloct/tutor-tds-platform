import importlib.util
import json
import tempfile
import unittest
from pathlib import Path

module_path = Path(__file__).with_name("tds_env.py")
spec = importlib.util.spec_from_file_location("tds_env", module_path)
tds = importlib.util.module_from_spec(spec)
spec.loader.exec_module(tds)


class TestZeroConfig(unittest.TestCase):
    def test_environment_matrix(self):
        self.assertEqual(tds.environment_for_ref("refs/heads/staging"), "staging")
        self.assertEqual(tds.environment_for_ref("refs/tags/v1.4.0"), "production")
        for bad in ["refs/heads/main", "refs/heads/develop", "refs/heads/codex/onda-0-consolidacao", "refs/tags/v1.4.0-rc.1", "refs/pull/1/merge", "staging", ""]:
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                tds.environment_for_ref(bad)

    def test_no_environment_crossover(self):
        tds.assert_environment_integrity()
        stage = tds.render_build_config("refs/heads/staging")
        prod = tds.render_build_config("refs/tags/v1.4.0")
        self.assertEqual(stage["TUTOR_ENVIRONMENT"], "staging")
        self.assertTrue(stage["DYNAMIC_QA_ISOLATED_PACKAGE"])
        self.assertRegex(stage["DYNAMIC_QA_RUN_ID"], r"^[0-9a-f]{32}$")
        self.assertEqual(tds.render_build_config("refs/heads/staging", commit_sha="a"*40)["DYNAMIC_QA_RUN_ID"], "a"*32)
        self.assertEqual(prod["TUTOR_ENVIRONMENT"], "production")
        self.assertNotEqual(stage["TUTOR_API_URL"], prod["TUTOR_API_URL"])
        self.assertNotEqual(stage["TUTOR_GATEWAY_URL"], prod["TUTOR_GATEWAY_URL"])
        self.assertNotIn("DYNAMIC_QA_RUN_ID", prod)
        self.assertFalse(prod["DYNAMIC_ACTIVITY_ENABLED"])

    def test_generated_config_no_sensitive_values(self):
        for ref in ["refs/heads/staging", "refs/tags/v1.4.0"]:
            data = tds.render_build_config(ref)
            keys = json.dumps(data).lower()
            for forbidden in ["anything_llm_api_key", "jwt_secret", "client_secret", "database_url", "cf_api_token", "tailscale_auth_key"]:
                self.assertNotIn(forbidden, keys)


if __name__ == "__main__":
    unittest.main(verbosity=2)
