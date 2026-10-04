from __future__ import annotations

import ast
import textwrap
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github" / "workflows" / "tds-vps-watchdog.yml"

EXPECTED_DIAGNOSTICS = (
    "smtp_connect_timeout",
    "smtp_tls_error",
    "smtp_auth_failed",
    "smtp_protocol_error",
    "smtp_connect_error",
    "smtp_unclassified_error",
)
SENSITIVE_NAMES = (
    "SMTP_HOST",
    "SMTP_USER",
    "SMTP_FROM",
    "SMTP_PASSWORD",
    "TDS_WATCHDOG_SMTP",
)


def embedded_python() -> str:
    source = WORKFLOW.read_text(encoding="utf-8")
    start_marker = "          python3 - <<'PY'\n"
    end_marker = "\n          PY"
    start = source.index(start_marker) + len(start_marker)
    end = source.index(end_marker, start)
    return textwrap.dedent(source[start:end])


class WatchdogSmtpObservabilityTests(unittest.TestCase):
    def setUp(self) -> None:
        self.script = embedded_python()
        self.tree = ast.parse(self.script)

    def test_embedded_python_compiles(self) -> None:
        compile(self.script, str(WORKFLOW), "exec")

    def test_expected_sanitized_categories_and_order(self) -> None:
        ordered_fragments = (
            "except (socket.timeout, TimeoutError):",
            "sys.exit('smtp_connect_timeout')",
            "except ssl.SSLError:",
            "sys.exit('smtp_tls_error')",
            "except smtplib.SMTPAuthenticationError:",
            "sys.exit('smtp_auth_failed')",
            "except smtplib.SMTPException:",
            "sys.exit('smtp_protocol_error')",
            "except OSError:",
            "sys.exit('smtp_connect_error')",
            "except Exception:",
            "sys.exit('smtp_unclassified_error')",
        )
        positions = [self.script.index(fragment) for fragment in ordered_fragments]
        self.assertEqual(positions, sorted(positions))
        for diagnostic in EXPECTED_DIAGNOSTICS:
            self.assertEqual(self.script.count(repr(diagnostic)), 1)

    def test_diagnostic_output_is_static_and_secret_free(self) -> None:
        outputs: list[str] = []
        for node in ast.walk(self.tree):
            if not isinstance(node, ast.Call) or not node.args:
                continue
            is_print = isinstance(node.func, ast.Name) and node.func.id == "print"
            is_exit = (
                isinstance(node.func, ast.Attribute)
                and isinstance(node.func.value, ast.Name)
                and node.func.value.id == "sys"
                and node.func.attr == "exit"
            )
            if not (is_print or is_exit):
                continue
            self.assertIsInstance(node.args[0], ast.Constant)
            self.assertIsInstance(node.args[0].value, str)
            outputs.append(node.args[0].value)

        rendered = "\n".join(outputs)
        for name in SENSITIVE_NAMES:
            self.assertNotIn(name, rendered)
        self.assertNotIn("os.environ", rendered)
        self.assertNotIn("exception", rendered.lower())
        self.assertNotIn("traceback", rendered.lower())

    def test_fallback_remains_fail_closed(self) -> None:
        self.assertIn(
            "except Exception:\n    sys.exit('smtp_unclassified_error')",
            self.script,
        )

    def test_existing_network_timeout_policy_is_preserved(self) -> None:
        self.assertEqual(self.script.count("timeout=15"), 2)
        self.assertIn("if port not in (465, 587):", self.script)
        self.assertIn("message['To'] = 'tdsdados@gmail.com'", self.script)


if __name__ == "__main__":
    unittest.main()
