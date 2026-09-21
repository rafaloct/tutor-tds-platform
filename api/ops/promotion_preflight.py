#!/usr/bin/env python3
"""Read-only OpenAPI comparison for a Tutor TDS production promotion."""

from __future__ import annotations

import argparse
import json
import sys
import urllib.request
from typing import Any
from urllib.parse import urlsplit

HTTP_METHODS = {"get", "post", "put", "patch", "delete"}

# Routes called by the 1.4 Flutter client. Certificate issuance is deliberately
# absent: it belongs to the separately configured certificate gateway.
AAB_14_OPERATIONS = {
    "DELETE /auth/me",
    "GET /analytics/usage",
    "GET /assessment-attempts",
    "GET /assessment-attempts/{attempt_id}",
    "GET /assessment-attempts/{attempt_id}/content",
    "GET /assessment-contents/{content_id}",
    "GET /auth/me",
    "GET /classes",
    "GET /classes/{class_id}",
    "GET /classes/{class_id}/dashboard",
    "GET /classes/{class_id}/evidence-imports/{import_id}",
    "GET /classes/{class_id}/exceptions",
    "GET /classes/{class_id}/reports/{report_id}",
    "GET /classes/{class_id}/sessions",
    "GET /classes/{class_id}/sessions/open",
    "GET /classes/{class_id}/sessions/{session_id}",
    "GET /courses",
    "GET /media",
    "GET /media/{media_id}",
    "GET /media/{media_id}/playback/{token}",
    "GET /media/{media_id}/rating",
    "GET /users/{user_id}/hours",
    "POST /admin/classes/{class_id}/sessions",
    "POST /auth/login",
    "POST /auth/refresh",
    "POST /auth/register",
    "POST /classes/{class_id}/evidence-imports",
    "POST /classes/{class_id}/evidence/{evidence_id}/review",
    "POST /classes/{class_id}/sessions/{session_id}/checkins",
    "POST /classes/{class_id}/sessions/{session_id}/close",
    "POST /classes/{class_id}/sessions/{session_id}/token",
    "POST /events",
    "POST /media/{media_id}/playback-authorizations",
    "PUT /assessment-attempts/{attempt_id}",
    "PUT /assessment-contents/{content_id}",
    "PUT /media/{media_id}/rating",
}


def load_openapi(url: str) -> dict[str, Any]:
    parsed = urlsplit(url)
    if (
        parsed.scheme != "https"
        or not parsed.netloc
        or parsed.username
        or parsed.query
        or parsed.fragment
    ):
        raise ValueError("OpenAPI URL must be public HTTPS without credentials")
    with urllib.request.urlopen(url, timeout=15) as response:
        if urlsplit(response.geturl()).scheme != "https":
            raise ValueError("OpenAPI redirect must remain HTTPS")
        document = json.load(response)
    if not isinstance(document, dict) or not isinstance(document.get("paths"), dict):
        raise ValueError(f"Invalid OpenAPI document from {url}")
    return document


def operations(document: dict[str, Any]) -> set[str]:
    return {
        f"{method.upper()} {path}"
        for path, item in document["paths"].items()
        for method in item
        if method.lower() in HTTP_METHODS
    }


def canonical(value: object) -> str:
    return json.dumps(value, sort_keys=True, separators=(",", ":"))


def compare(production: dict[str, Any], candidate: dict[str, Any]) -> dict[str, object]:
    production_ops = operations(production)
    candidate_ops = operations(candidate)
    production_schemas = production.get("components", {}).get("schemas", {})
    candidate_schemas = candidate.get("components", {}).get("schemas", {})
    common_schemas = set(production_schemas) & set(candidate_schemas)
    return {
        "production_operation_count": len(production_ops),
        "candidate_operation_count": len(candidate_ops),
        "only_candidate": sorted(candidate_ops - production_ops),
        "only_production": sorted(production_ops - candidate_ops),
        "aab_14_missing_in_production": sorted(AAB_14_OPERATIONS - production_ops),
        "aab_14_missing_in_candidate": sorted(AAB_14_OPERATIONS - candidate_ops),
        "common_schema_changes": sorted(
            name
            for name in common_schemas
            if canonical(production_schemas[name]) != canonical(candidate_schemas[name])
        ),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("production_openapi")
    parser.add_argument("candidate_openapi")
    parser.add_argument("--fail-if-production-behind", action="store_true")
    args = parser.parse_args()
    result = compare(
        load_openapi(args.production_openapi),
        load_openapi(args.candidate_openapi),
    )
    print(json.dumps(result, indent=2, ensure_ascii=False))
    if result["aab_14_missing_in_candidate"] or result["only_production"]:
        raise SystemExit(2)
    if args.fail_if_production_behind and result["aab_14_missing_in_production"]:
        raise SystemExit(3)


if __name__ == "__main__":
    main()
