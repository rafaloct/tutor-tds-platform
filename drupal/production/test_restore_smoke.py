"""Focused regression checks for the isolated rehearsal's HTTP probe."""
import importlib.util
from pathlib import Path
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location('restore_smoke', Path(__file__).with_name('restore-smoke.py'))
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
CONTAINER = 'tds-drupal-restore-210-' + 'a' * 32 + '-web'


class ProbeTests(unittest.TestCase):
    def test_health_body_and_status_are_separated_without_losing_newlines(self):
        body = b'{\n"environment":"production","database":"up"\n}\n'
        with patch.object(module, 'command', return_value=body + b'\n200') as command:
            self.assertEqual(module.request(CONTAINER, '/health'), (200, body))
        argv = command.call_args.args[0]
        self.assertEqual(argv[:4], ['docker', 'exec', CONTAINER, 'curl'])
        self.assertEqual(argv[-1], 'http://127.0.0.1/health')
        self.assertIn('Host: ' + module.HOST, argv)
        self.assertIn('--noproxy', argv)
        self.assertEqual(command.call_args.kwargs['limit'], 1024 * 1024)
        self.assertEqual(command.call_args.kwargs['timeout'], 15)

    def test_server_error_is_available_as_sanitized_numeric_evidence(self):
        with patch.object(module, 'command', return_value=b'potential sensitive error\n503'):
            status, _ = module.request(CONTAINER, '/health')
            self.assertEqual(status, 503)

    def test_malformed_output_never_appears_in_exception(self):
        for raw in (b'secret', b'body\n000', b'body\n200secret'):
            with self.subTest(raw=raw), patch.object(module, 'command', return_value=raw):
                with self.assertRaisesRegex(module.Failure, '^http_probe_response$'):
                    module.request(CONTAINER, '/')

    def test_probe_cannot_target_production_or_an_arbitrary_url(self):
        with patch.object(module, 'command') as command:
            for container, path in [('production-web', '/health'), (CONTAINER, 'https://example.com')]:
                with self.assertRaisesRegex(module.Failure, '^http_probe_target$'):
                    module.request(container, path)
            command.assert_not_called()


if __name__ == '__main__':
    unittest.main()
