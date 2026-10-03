"""Evaluate sanitized operational snapshots. No network, credentials or delivery."""
from __future__ import annotations

import argparse
import json
import math
from datetime import datetime, timezone
from pathlib import Path

# service, metric, unhealthy threshold, direction, severity
RULES = {
    "api_http": ("api", "http_status", 200, "ne", "SEV1"),
    "api_latency": ("api", "latency_ms", 2000, "gt", "SEV2"),
    "api_5xx": ("api", "error_ratio", 0.05, "gt", "SEV2"),
    "postgres": ("postgres", "available", 0, "eq", "SEV1"),
    "backup": ("backup", "age_seconds", 93600, "gt", "SEV1"),
    "disk": ("host", "used_ratio", 0.85, "gt", "SEV2"),
    "memory": ("host", "used_ratio", 0.90, "gt", "SEV2"),
    "tls": ("tls", "remaining_days", 14, "lt", "SEV2"),
    "wordpress": ("wordpress", "http_status", 200, "ne", "SEV3"),
    "chatwoot": ("chatwoot", "http_status", 200, "ne", "SEV3"),
    "gateway": ("gateway", "error_ratio", 0.05, "gt", "SEV3"),
    "anythingllm": ("anythingllm", "available", 0, "eq", "SEV3"),
    "sheets_sync": ("sheets", "age_seconds", 7200, "gt", "SEV3"),
    "queue": ("sheets", "age_seconds", 3600, "gt", "SEV3"),
    "media": ("media", "available", 0, "eq", "SEV3"),
}
STATUSES = {"healthy", "firing", "unknown"}


def timestamp(value):
    if not isinstance(value, str):
        raise ValueError("invalid timestamp")
    result = datetime.fromisoformat(value.replace("Z", "+00:00"))
    if result.tzinfo is None:
        raise ValueError("timezone required")
    return result.astimezone(timezone.utc)


def evaluate(snapshot, previous=None, *, now=None):
    """Missing/stale readings stay unknown; unknown never resolves an incident."""
    now = now or datetime.now(timezone.utc)
    if now.tzinfo is None:
        raise ValueError("timezone required")
    if not isinstance(snapshot, dict) or set(snapshot) != {"environment", "checks"}:
        raise ValueError("invalid snapshot envelope")
    environment = snapshot["environment"]
    if environment not in {"local", "staging", "production"}:
        raise ValueError("invalid environment")
    checks = snapshot["checks"]
    if not isinstance(checks, dict) or set(checks) - RULES.keys():
        raise ValueError("invalid checks")
    if previous is None:
        previous = {"environment": environment, "states": {}}
    if (not isinstance(previous, dict) or set(previous) != {"environment", "states"}
            or previous["environment"] != environment
            or not isinstance(previous["states"], dict)
            or set(previous["states"]) - RULES.keys()
            or any(v not in STATUSES for v in previous["states"].values())):
        raise ValueError("invalid previous state")
    states, results = {}, []
    for check_id, (service, metric, limit, direction, severity) in RULES.items():
        reading = checks.get(check_id)
        status, reason = "unknown", "missing"
        if reading is not None:
            fields = {"value", "observed_at"}
            if metric == "error_ratio":
                fields.add("sample_count")
            if not isinstance(reading, dict) or set(reading) != fields:
                raise ValueError("invalid reading")
            if metric == "error_ratio" and (type(reading["sample_count"]) is not int or reading["sample_count"] < 0):
                raise ValueError("invalid sample count")
            value = reading["value"]
            if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
                raise ValueError("invalid numeric value")
            if ((metric != "remaining_days" and value < 0)
                    or (metric in {"used_ratio", "error_ratio"} and value > 1)
                    or (metric == "available" and value not in {0, 1})
                    or (metric == "http_status" and (value != int(value) or not 100 <= value <= 599))):
                raise ValueError("value outside metric range")
            age = (now - timestamp(reading["observed_at"])).total_seconds()
            if not 0 <= age <= 600:
                reason = "stale_or_future"
            elif metric == "error_ratio" and reading["sample_count"] < 100:
                reason = "insufficient_samples"
            else:
                failed = {"gte": value >= limit, "gt": value > limit,
                          "lt": value < limit, "eq": value == limit, "ne": value != limit}[direction]
                status, reason = ("firing", "threshold") if failed else ("healthy", "within_threshold")
        old = previous["states"].get(check_id, "unknown")
        transition = ("opened" if status == "firing" and old != "firing" else
                      "resolved" if status == "healthy" and old == "firing" else
                      "unchanged")
        # Preserve an open incident across monitoring gaps, avoiding false recovery.
        states[check_id] = "firing" if status == "unknown" and old == "firing" else status
        results.append({"check": check_id, "service": service, "metric": metric,
                        "status": status, "reason": reason, "severity": severity,
                        "transition": transition})
    return {"environment": environment, "results": results,
            "next_state": {"environment": environment, "states": states}}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("snapshot", type=Path)
    parser.add_argument("--previous", type=Path)
    args = parser.parse_args()
    try:
        result = evaluate(json.loads(args.snapshot.read_text(encoding="utf-8")),
                          json.loads(args.previous.read_text(encoding="utf-8")) if args.previous else None)
    except (ValueError, TypeError, OverflowError, OSError):
        print('{"error":"invalid_input"}')
        return 2
    print(json.dumps(result, sort_keys=True))
    return 1 if any(r["status"] != "healthy" for r in result["results"]) else 0


if __name__ == "__main__":
    raise SystemExit(main())
