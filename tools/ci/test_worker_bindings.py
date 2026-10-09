import importlib.util
import unittest
from pathlib import Path

p = Path(__file__).with_name("verify_worker_bindings.py")
spec = importlib.util.spec_from_file_location("verify_worker_bindings", p)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class TestBindingGuard(unittest.TestCase):
    def test_staging_allowed(self):
        mod.validate_bindings("staging", [
            {"name": "ANYTHING_LLM_API_KEY", "type": "secret_text"},
            {"name": "TUTOR_RAG_SCOPE_MAP", "type": "plain_text"},
        ])

    def test_staging_rejects_production_capabilities(self):
        with self.assertRaises(AssertionError):
            mod.validate_bindings("staging", [
                {"name": "ANYTHING_LLM_API_KEY", "type": "secret_text"},
                {"name": "TUTOR_RAG_SCOPE_MAP", "type": "plain_text"},
                {"name": "CERTIFICATES", "type": "kv_namespace"},
            ])

    def test_production_requires_independent_kv(self):
        with self.assertRaises(AssertionError):
            mod.validate_bindings("production", [{"name": "ANYTHING_LLM_API_KEY", "type": "secret_text"}])

    def test_production_valid(self):
        mod.validate_bindings("production", [
            {"name": "ANYTHING_LLM_API_KEY", "type": "secret_text"},
            {"name": "CERTIFICATE_SIGNING_SECRET", "type": "secret_text"},
            {"name": "TUTOR_RAG_SCOPE_MAP", "type": "secret_text"},
            {"name": "CERTIFICATES", "type": "kv_namespace"},
        ])

if __name__ == "__main__":
    unittest.main(verbosity=2)
