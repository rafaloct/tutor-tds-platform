"""Read-only Tier 1 synthetic checks with sanitized structured output."""
from __future__ import annotations

import argparse
import json
import math
import socket
import ssl
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import SplitResult, urlsplit
from urllib.request import HTTPRedirectHandler, HTTPSHandler, ProxyHandler, Request, build_opener

SCHEMA_VERSION = 1
MAX_BODY_BYTES = 64 * 1024
MAX_MANIFEST_BYTES = 256 * 1024
SERVICE_KEYS = {
    "service_id",
    "url",
    "timeout_seconds",
    "expected_status",
    "max_latency_ms",
    "tls_min_days",
    "health_json",
    "content_allowlist",
}
RESULT_STATUSES = {"PASS", "FAIL", "UNKNOWN"}
SAFE_REASONS = {
    "reachable",
    "expected_status",
    "within_latency",
    "valid_health_json",
    "allowlisted_content_present",
    "tls_validity_sufficient",
    "unexpected_status",
    "latency_exceeded",
    "malformed_json",
    "health_shape_mismatch",
    "content_missing",
    "content_decode_error",
    "body_too_large",
    "timeout",
    "tls_invalid",
    "network_error",
    "probe_invalid_observation",
    "tls_expiring",
    "tls_expiry_unavailable",
}


class ManifestError(ValueError):
    """Manifest is invalid or contains unsupported fields."""


class ProbeError(RuntimeError):
    """Sanitized probe failure. Never contains remote exception text."""

    def __init__(self, reason: str, *, status: str = "FAIL"):
        if reason not in SAFE_REASONS or status not in RESULT_STATUSES:
            reason, status = "network_error", "FAIL"
        super().__init__(reason)
        self.reason = reason
        self.status = status


@dataclass(frozen=True)
class HttpObservation:
    status_code: int
    latency_ms: float
    body: bytes
    body_truncated: bool = False


@dataclass(frozen=True)
class TlsObservation:
    remaining_days: float


class _NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def _utc_stamp(value: datetime) -> str:
    if value.tzinfo is None:
        raise ValueError("timezone required")
    return value.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")


def _number(value, *, minimum: float, maximum: float, name: str) -> float:
    if isinstance(value, bool) or not isinstance(value, (int, float)) or not math.isfinite(value):
        raise ManifestError(name)
    if not minimum <= float(value) <= maximum:
        raise ManifestError(name)
    return float(value)


def _validated_url(value: object) -> SplitResult:
    if not isinstance(value, str) or not value or len(value) > 2048:
        raise ManifestError("url")
    if any(ord(char) < 32 for char in value):
        raise ManifestError("url")
    try:
        parsed = urlsplit(value)
        _ = parsed.port
    except ValueError as exc:
        raise ManifestError("url") from exc
    if parsed.scheme != "https" or not parsed.hostname:
        raise ManifestError("url")
    if parsed.username is not None or parsed.password is not None:
        raise ManifestError("url")
    if parsed.query or parsed.fragment:
        raise ManifestError("url")
    return parsed


def _safe_identifier(value: object, *, max_length: int = 64) -> bool:
    if not isinstance(value, str) or not 1 <= len(value) <= max_length:
        return False
    allowed = set("abcdefghijklmnopqrstuvwxyz0123456789_-")
    return value[0].isalnum() and value == value.lower() and all(ch in allowed for ch in value)


def validate_manifest(manifest: object) -> dict:
    if not isinstance(manifest, dict) or set(manifest) != {"schema_version", "services"}:
        raise ManifestError("envelope")
    if manifest["schema_version"] != SCHEMA_VERSION:
        raise ManifestError("schema_version")
    services = manifest["services"]
    if not isinstance(services, list) or not 1 <= len(services) <= 50:
        raise ManifestError("services")

    seen = set()
    for service in services:
        if not isinstance(service, dict) or set(service) - SERVICE_KEYS:
            raise ManifestError("service")
        if "service_id" not in service or "url" not in service:
            raise ManifestError("service")
        service_id = service["service_id"]
        if not _safe_identifier(service_id) or service_id in seen:
            raise ManifestError("service_id")
        seen.add(service_id)
        _validated_url(service["url"])

        timeout = service.get("timeout_seconds", 5)
        _number(timeout, minimum=0.1, maximum=30, name="timeout_seconds")

        status = service.get("expected_status", 200)
        if isinstance(status, bool) or not isinstance(status, int) or not 100 <= status <= 599:
            raise ManifestError("expected_status")

        _number(service.get("max_latency_ms", 2000), minimum=1, maximum=30000, name="max_latency_ms")
        _number(service.get("tls_min_days", 14), minimum=1, maximum=365, name="tls_min_days")

        health = service.get("health_json")
        if health is not None:
            if not isinstance(health, dict) or set(health) != {"required_keys"}:
                raise ManifestError("health_json")
            keys = health["required_keys"]
            if not isinstance(keys, list) or not 1 <= len(keys) <= 16:
                raise ManifestError("health_json")
            if len(set(keys)) != len(keys) or any(not _safe_identifier(key) for key in keys):
                raise ManifestError("health_json")

        markers = service.get("content_allowlist")
        if markers is not None:
            if not isinstance(markers, list) or not 1 <= len(markers) <= 8:
                raise ManifestError("content_allowlist")
            for marker in markers:
                if not isinstance(marker, str) or not 1 <= len(marker) <= 80:
                    raise ManifestError("content_allowlist")
                if any(ord(char) < 32 for char in marker):
                    raise ManifestError("content_allowlist")
    return manifest


def _transport_reason(exc: BaseException) -> str:
    if isinstance(exc, (socket.timeout, TimeoutError)):
        return "timeout"
    if isinstance(exc, (ssl.SSLError, ssl.CertificateError)):
        return "tls_invalid"
    if isinstance(exc, URLError):
        return _transport_reason(exc.reason)
    return "network_error"


def probe_http(url: str, timeout_seconds: float) -> HttpObservation:
    """GET one HTTPS URL without redirects, credentials, cookies, proxies or request body."""
    context = ssl.create_default_context()
    opener = build_opener(ProxyHandler({}), HTTPSHandler(context=context), _NoRedirect())
    request = Request(
        url,
        method="GET",
        headers={
            "User-Agent": "TutorTDS-Synthetic/1.0",
            "Accept": "application/json,text/plain;q=0.9,*/*;q=0.1",
        },
    )
    start = time.perf_counter()
    response = None
    try:
        try:
            response = opener.open(request, timeout=timeout_seconds)
        except HTTPError as exc:
            response = exc
        body = response.read(MAX_BODY_BYTES + 1)
        latency_ms = (time.perf_counter() - start) * 1000
        return HttpObservation(
            status_code=int(response.getcode()),
            latency_ms=latency_ms,
            body=body[:MAX_BODY_BYTES],
            body_truncated=len(body) > MAX_BODY_BYTES,
        )
    except (URLError, socket.timeout, TimeoutError, ssl.SSLError, ssl.CertificateError, OSError) as exc:
        raise ProbeError(_transport_reason(exc)) from None
    finally:
        if response is not None:
            response.close()


def probe_tls(url: str, timeout_seconds: float, *, now: datetime | None = None) -> TlsObservation:
    """Validate HTTPS certificate and return only its remaining lifetime."""
    parsed = _validated_url(url)
    now = now or datetime.now(timezone.utc)
    context = ssl.create_default_context()
    try:
        with socket.create_connection((parsed.hostname, parsed.port or 443), timeout=timeout_seconds) as raw:
            with context.wrap_socket(raw, server_hostname=parsed.hostname) as tls:
                certificate = tls.getpeercert()
    except (socket.timeout, TimeoutError, ssl.SSLError, ssl.CertificateError, OSError) as exc:
        raise ProbeError(_transport_reason(exc)) from None

    not_after = certificate.get("notAfter") if isinstance(certificate, dict) else None
    if not isinstance(not_after, str):
        raise ProbeError("tls_expiry_unavailable", status="UNKNOWN")
    try:
        expires = datetime.fromtimestamp(ssl.cert_time_to_seconds(not_after), tz=timezone.utc)
    except (ValueError, OverflowError):
        raise ProbeError("tls_expiry_unavailable", status="UNKNOWN") from None
    return TlsObservation((expires - now.astimezone(timezone.utc)).total_seconds() / 86400)


def _result(
    service_id: str,
    check_id: str,
    status: str,
    safe_reason: str,
    observed_at: datetime,
    *,
    latency_ms: float | None = None,
) -> dict:
    if status not in RESULT_STATUSES or safe_reason not in SAFE_REASONS:
        status, safe_reason = "FAIL", "probe_invalid_observation"
    item = {
        "service_id": service_id,
        "check_id": check_id,
        "status": status,
        "observed_at": _utc_stamp(observed_at),
        "safe_reason": safe_reason,
    }
    if latency_ms is not None and math.isfinite(latency_ms) and latency_ms >= 0:
        item["latency_ms"] = round(float(latency_ms), 1)
    return item


def _http_check_ids(service: dict) -> list[str]:
    checks = ["https_reachability", "status_code", "latency"]
    if service.get("health_json") is not None:
        checks.append("health_json")
    if service.get("content_allowlist") is not None:
        checks.append("content_allowlist")
    return checks


def _body_text(observation: HttpObservation) -> str | None:
    try:
        return observation.body.decode("utf-8")
    except UnicodeDecodeError:
        return None


def run_manifest(
    manifest: object,
    *,
    now: datetime | None = None,
    http_probe=probe_http,
    tls_probe=probe_tls,
) -> dict:
    config = validate_manifest(manifest)
    observed_at = now or datetime.now(timezone.utc)
    if observed_at.tzinfo is None:
        raise ValueError("timezone required")
    results = []

    for service in config["services"]:
        service_id = service["service_id"]
        timeout = float(service.get("timeout_seconds", 5))
        expected_status = service.get("expected_status", 200)
        max_latency = float(service.get("max_latency_ms", 2000))

        try:
            observation = http_probe(service["url"], timeout)
            if (
                not isinstance(observation, HttpObservation)
                or isinstance(observation.status_code, bool)
                or not isinstance(observation.status_code, int)
                or not 100 <= observation.status_code <= 599
                or not isinstance(observation.body, bytes)
                or not isinstance(observation.body_truncated, bool)
                or isinstance(observation.latency_ms, bool)
                or not isinstance(observation.latency_ms, (int, float))
                or not math.isfinite(observation.latency_ms)
                or observation.latency_ms < 0
            ):
                raise ProbeError("probe_invalid_observation")
        except ProbeError as exc:
            for check_id in _http_check_ids(service):
                results.append(_result(service_id, check_id, exc.status, exc.reason, observed_at))
        except Exception:
            for check_id in _http_check_ids(service):
                results.append(_result(service_id, check_id, "FAIL", "network_error", observed_at))
        else:
            latency = float(observation.latency_ms)
            results.append(_result(service_id, "https_reachability", "PASS", "reachable", observed_at, latency_ms=latency))

            status_ok = observation.status_code == expected_status
            results.append(
                _result(
                    service_id,
                    "status_code",
                    "PASS" if status_ok else "FAIL",
                    "expected_status" if status_ok else "unexpected_status",
                    observed_at,
                    latency_ms=latency,
                )
            )
            latency_ok = latency <= max_latency
            results.append(
                _result(
                    service_id,
                    "latency",
                    "PASS" if latency_ok else "FAIL",
                    "within_latency" if latency_ok else "latency_exceeded",
                    observed_at,
                    latency_ms=latency,
                )
            )

            text_body = None if observation.body_truncated else _body_text(observation)
            if service.get("health_json") is not None:
                if not status_ok:
                    results.append(_result(service_id, "health_json", "FAIL", "unexpected_status", observed_at, latency_ms=latency))
                elif observation.body_truncated:
                    results.append(_result(service_id, "health_json", "FAIL", "body_too_large", observed_at, latency_ms=latency))
                elif text_body is None:
                    results.append(_result(service_id, "health_json", "FAIL", "malformed_json", observed_at, latency_ms=latency))
                else:
                    try:
                        payload = json.loads(text_body)
                    except (json.JSONDecodeError, TypeError):
                        payload = None
                    required = service["health_json"]["required_keys"]
                    if not isinstance(payload, dict):
                        results.append(_result(service_id, "health_json", "FAIL", "malformed_json", observed_at, latency_ms=latency))
                    elif not all(key in payload for key in required):
                        results.append(_result(service_id, "health_json", "FAIL", "health_shape_mismatch", observed_at, latency_ms=latency))
                    else:
                        results.append(_result(service_id, "health_json", "PASS", "valid_health_json", observed_at, latency_ms=latency))

            if service.get("content_allowlist") is not None:
                if not status_ok:
                    results.append(_result(service_id, "content_allowlist", "FAIL", "unexpected_status", observed_at, latency_ms=latency))
                elif observation.body_truncated:
                    results.append(_result(service_id, "content_allowlist", "FAIL", "body_too_large", observed_at, latency_ms=latency))
                elif text_body is None:
                    results.append(_result(service_id, "content_allowlist", "FAIL", "content_decode_error", observed_at, latency_ms=latency))
                elif all(marker in text_body for marker in service["content_allowlist"]):
                    results.append(_result(service_id, "content_allowlist", "PASS", "allowlisted_content_present", observed_at, latency_ms=latency))
                else:
                    results.append(_result(service_id, "content_allowlist", "FAIL", "content_missing", observed_at, latency_ms=latency))

        try:
            tls = tls_probe(service["url"], timeout, now=observed_at)
            if (
                not isinstance(tls, TlsObservation)
                or isinstance(tls.remaining_days, bool)
                or not isinstance(tls.remaining_days, (int, float))
                or not math.isfinite(tls.remaining_days)
            ):
                raise ProbeError("probe_invalid_observation")
        except ProbeError as exc:
            results.append(_result(service_id, "tls_expiry", exc.status, exc.reason, observed_at))
        except Exception:
            results.append(_result(service_id, "tls_expiry", "FAIL", "network_error", observed_at))
        else:
            minimum_days = float(service.get("tls_min_days", 14))
            tls_ok = tls.remaining_days >= minimum_days
            results.append(
                _result(
                    service_id,
                    "tls_expiry",
                    "PASS" if tls_ok else "FAIL",
                    "tls_validity_sufficient" if tls_ok else "tls_expiring",
                    observed_at,
                )
            )

    return {"schema_version": SCHEMA_VERSION, "results": results}


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args(argv)
    try:
        raw = args.manifest.read_bytes()
        if len(raw) > MAX_MANIFEST_BYTES:
            raise ManifestError("manifest_size")
        manifest = json.loads(raw.decode("utf-8"))
        output = run_manifest(manifest)
    except (ManifestError, json.JSONDecodeError, UnicodeDecodeError, OSError, ValueError):
        print('{"error":"invalid_manifest"}')
        return 2

    print(json.dumps(output, sort_keys=True, separators=(",", ":")))
    return 0 if all(item["status"] == "PASS" for item in output["results"]) else 1


if __name__ == "__main__":
    raise SystemExit(main())
