import json
import unittest
from datetime import datetime, timezone

from evaluate import RULES, evaluate

NOW = datetime(2026, 10, 3, 16, tzinfo=timezone.utc)


def sample(**values):
    return {"environment": "local", "checks": {
        key: {"value": value, "observed_at": NOW.isoformat(),
              **({"sample_count": 100} if RULES[key][1] == "error_ratio" else {})}
        for key, value in values.items()}}


class OperationalTransitions(unittest.TestCase):
    def test_http_failure_backup_sync_and_recovery(self):
        failed = evaluate(sample(api_http=500, backup=100000, sheets_sync=8000), now=NOW)
        for key in ("api_http", "backup", "sheets_sync"):
            self.assertEqual(failed["next_state"]["states"][key], "firing")
        repeated = evaluate(sample(api_http=500), failed["next_state"], now=NOW)
        self.assertEqual(repeated["results"][0]["transition"], "unchanged")
        gap = evaluate(sample(), failed["next_state"], now=NOW)
        self.assertEqual(gap["next_state"]["states"]["api_http"], "firing")
        recovered = evaluate(sample(api_http=200, backup=10, sheets_sync=10), gap["next_state"], now=NOW)
        self.assertEqual(sum(r["transition"] == "resolved" for r in recovered["results"]), 3)

    def test_missing_stale_future_are_not_success(self):
        for date in ("2026-10-03T15:00:00Z", "2026-10-04T16:00:00Z"):
            data = sample(api_http=200)
            data["checks"]["api_http"]["observed_at"] = date
            self.assertEqual(evaluate(data, now=NOW)["results"][0]["status"], "unknown")
        self.assertTrue(all(r["status"] == "unknown" for r in evaluate(sample(), now=NOW)["results"]))

    def test_payload_and_cross_environment_rejected(self):
        data = sample(api_http=500)
        data["checks"]["api_http"]["body"] = "PRIVATE_SENTINEL"
        with self.assertRaises(ValueError):
            evaluate(data, now=NOW)
        with self.assertRaises(ValueError):
            evaluate(sample(), {"environment": "production", "states": {}}, now=NOW)
        self.assertNotIn("PRIVATE_SENTINEL", json.dumps(evaluate(sample(api_http=500), now=NOW)))

    def test_invalid_numeric_and_timestamp(self):
        for value in (True, -1, float("nan"), float("inf"), "500", 600, 200.5):
            with self.subTest(value=value), self.assertRaises(ValueError):
                evaluate(sample(api_http=value), now=NOW)
        data = sample(api_http=200)
        data["checks"]["api_http"]["observed_at"] = "2026-10-03T16:00:00"
        with self.assertRaises(ValueError):
            evaluate(data, now=NOW)

    def test_complete_healthy_snapshot(self):
        values = {key: 0 for key in RULES}
        values.update(api_http=200, wordpress=200, chatwoot=200, postgres=1,
                      anythingllm=1, media=1, tls=30)
        self.assertTrue(all(r["status"] == "healthy" for r in evaluate(sample(**values), now=NOW)["results"]))

    def test_redirect_is_not_health_and_empty_state_is_invalid(self):
        self.assertEqual(evaluate(sample(api_http=302), now=NOW)["results"][0]["status"], "firing")
        with self.assertRaises(ValueError):
            evaluate(sample(), {}, now=NOW)

    def test_low_volume_never_resolves_ratio_incident(self):
        failed = evaluate(sample(api_5xx=0.5), now=NOW)
        insufficient = sample(api_5xx=0)
        insufficient["checks"]["api_5xx"]["sample_count"] = 99
        result = evaluate(insufficient, failed["next_state"], now=NOW)
        self.assertEqual(result["results"][2]["status"], "unknown")
        self.assertEqual(result["next_state"]["states"]["api_5xx"], "firing")
        recovered = evaluate(sample(api_5xx=0), result["next_state"], now=NOW)
        self.assertEqual(recovered["results"][2]["transition"], "resolved")


if __name__ == "__main__":
    unittest.main()
