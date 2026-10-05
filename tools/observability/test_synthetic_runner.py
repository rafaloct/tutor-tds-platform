import io
import json
import tempfile
import unittest
from contextlib import redirect_stdout
from datetime import datetime, timezone
from pathlib import Path

from synthetic_runner import (
    HttpObservation,
    ManifestError,
    ProbeError,
    TlsObservation,
    main,
    run_manifest,
    validate_manifest,
)

NOW = datetime(2026, 10, 4, 19, 0, tzinfo=timezone.utc)


def manifest(**overrides):
    service = {
        "service_id": "api",
        "url": "https://api.example.invalid/health",
        "expected_status": 200,
        "timeout_seconds": 3,
        "max_latency_ms": 2000,
        "tls_min_days": 14,
        "health_json": {"required_keys": ["status"]},
        "content_allowlist": ["ready"],
    }
    service.update(overrides)
    return {"schema_version": 1, "services": [service]}


def http_ok(url, timeout):
    return HttpObservation(
        status_code=200,
        latency_ms=125.4,
        body=b'{"status":"ok","message":"ready"}',
    )


def tls_ok(url, timeout, *, now=None):
    return TlsObservation(remaining_days=30)


class SyntheticRunnerContract(unittest.TestCase):
    def test_all_minimum_checks_pass_with_sanitized_shape(self):
        output = run_manifest(manifest(), now=NOW, http_probe=http_ok, tls_probe=tls_ok)
        expected = {
            "https_reachability",
            "status_code",
            "latency",
            "health_json",
            "content_allowlist",
            "tls_expiry",
        }
        self.assertEqual({item["check_id"] for item in output["results"]}, expected)
        self.assertTrue(all(item["status"] == "PASS" for item in output["results"]))
        for item in output["results"]:
            self.assertEqual(item["service_id"], "api")
            self.assertEqual(item["observed_at"], "2026-10-04T19:00:00Z")
            self.assertLessEqual(
                set(item),
                {"service_id", "check_id", "status", "observed_at", "latency_ms", "safe_reason"},
            )

    def test_unexpected_http_fails_status_and_body_dependent_checks(self):
        def http_503(url, timeout):
            return HttpObservation(503, 40, b'{"status":"ok","message":"ready"}')

        output = run_manifest(manifest(), now=NOW, http_probe=http_503, tls_probe=tls_ok)
        by_id = {item["check_id"]: item for item in output["results"]}
        self.assertEqual(by_id["https_reachability"]["status"], "PASS")
        self.assertEqual(by_id["status_code"]["safe_reason"], "unexpected_status")
        self.assertEqual(by_id["health_json"]["safe_reason"], "unexpected_status")
        self.assertEqual(by_id["content_allowlist"]["safe_reason"], "unexpected_status")
        self.assertEqual(by_id["status_code"]["status"], "FAIL")

    def test_timeout_fails_closed_without_remote_text(self):
        def http_timeout(url, timeout):
            raise ProbeError("timeout")

        output = run_manifest(manifest(), now=NOW, http_probe=http_timeout, tls_probe=tls_ok)
        http_results = [item for item in output["results"] if item["check_id"] != "tls_expiry"]
        self.assertTrue(http_results)
        self.assertTrue(all(item["status"] == "FAIL" for item in http_results))
        self.assertTrue(all(item["safe_reason"] == "timeout" for item in http_results))

    def test_malformed_json_is_fail_closed(self):
        def malformed(url, timeout):
            return HttpObservation(200, 10, b"not-json")

        output = run_manifest(manifest(content_allowlist=None), now=NOW, http_probe=malformed, tls_probe=tls_ok)
        health = next(item for item in output["results"] if item["check_id"] == "health_json")
        self.assertEqual((health["status"], health["safe_reason"]), ("FAIL", "malformed_json"))

    def test_tls_expiry_and_unavailable_metadata_are_not_success(self):
        def expiring(url, timeout, *, now=None):
            return TlsObservation(remaining_days=3)

        output = run_manifest(manifest(), now=NOW, http_probe=http_ok, tls_probe=expiring)
        tls = next(item for item in output["results"] if item["check_id"] == "tls_expiry")
        self.assertEqual((tls["status"], tls["safe_reason"]), ("FAIL", "tls_expiring"))

        def unavailable(url, timeout, *, now=None):
            raise ProbeError("tls_expiry_unavailable", status="UNKNOWN")

        output = run_manifest(manifest(), now=NOW, http_probe=http_ok, tls_probe=unavailable)
        tls = next(item for item in output["results"] if item["check_id"] == "tls_expiry")
        self.assertEqual((tls["status"], tls["safe_reason"]), ("UNKNOWN", "tls_expiry_unavailable"))

    def test_truncated_or_missing_content_never_passes_body_checks(self):
        def truncated(url, timeout):
            return HttpObservation(200, 15, b'{"status":"ok"}', body_truncated=True)

        output = run_manifest(manifest(), now=NOW, http_probe=truncated, tls_probe=tls_ok)
        by_id = {item["check_id"]: item for item in output["results"]}
        self.assertEqual(by_id["health_json"]["safe_reason"], "body_too_large")
        self.assertEqual(by_id["content_allowlist"]["safe_reason"], "body_too_large")

        def missing(url, timeout):
            return HttpObservation(200, 15, b'{"status":"ok"}')

        output = run_manifest(manifest(), now=NOW, http_probe=missing, tls_probe=tls_ok)
        content = next(item for item in output["results"] if item["check_id"] == "content_allowlist")
        self.assertEqual((content["status"], content["safe_reason"]), ("FAIL", "content_missing"))

    def test_output_never_echoes_url_body_or_exception_text(self):
        sentinel = "PRIVATE_SENTINEL_DO_NOT_LOG"

        def sensitive_http(url, timeout):
            return HttpObservation(200, 22, ('{"status":"ok","message":"' + sentinel + '"}').encode())

        def sensitive_tls(url, timeout, *, now=None):
            raise RuntimeError(sentinel)

        output = run_manifest(
            manifest(content_allowlist=["public-marker"]),
            now=NOW,
            http_probe=sensitive_http,
            tls_probe=sensitive_tls,
        )
        encoded = json.dumps(output)
        self.assertNotIn(sentinel, encoded)
        self.assertNotIn("api.example.invalid", encoded)
        tls = next(item for item in output["results"] if item["check_id"] == "tls_expiry")
        self.assertEqual(tls["safe_reason"], "network_error")

    def test_manifest_rejects_secret_capable_or_unsafe_transport_fields(self):
        cases = [
            manifest(url="http://api.example.invalid/health"),
            manifest(url="https://user:pass@api.example.invalid/health"),
            manifest(url="https://api.example.invalid/health?token=value"),
            manifest(headers={"Authorization": "secret"}),
        ]
        for case in cases:
            with self.subTest(case=case), self.assertRaises(ManifestError):
                validate_manifest(case)

    def test_manifest_rejects_duplicate_service_ids(self):
        data = manifest()
        data["services"].append(dict(data["services"][0]))
        with self.assertRaises(ManifestError):
            validate_manifest(data)

    def test_cli_invalid_manifest_is_fixed_and_sanitized(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "manifest.json"
            path.write_text('{"token":"PRIVATE_SENTINEL"}', encoding="utf-8")
            stdout = io.StringIO()
            with redirect_stdout(stdout):
                exit_code = main([str(path)])
        self.assertEqual(exit_code, 2)
        self.assertEqual(stdout.getvalue().strip(), '{"error":"invalid_manifest"}')


if __name__ == "__main__":
    unittest.main()
