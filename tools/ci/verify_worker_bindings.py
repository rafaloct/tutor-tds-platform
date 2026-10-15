#!/usr/bin/env python3
"""Read only: verify deployed Worker binding identities without emitting values."""
import argparse
import json
import os
import sys
import urllib.error
import urllib.request

ACCOUNT = "8b1d9dad829dd6927091666a1f186717"
WORKERS = {"production": "tutor-tds-gateway", "staging": "tutor-tds-gateway-staging"}


def validate_bindings(target: str, bindings: list[dict]) -> None:
    mapping = {entry.get("name"): entry.get("type") for entry in bindings}
    assert mapping.get("ANYTHING_LLM_API_KEY") == "secret_text", "Missing upstream authentication secret"
    if target == "staging":
        assert "CERTIFICATES" not in mapping and "CERTIFICATE_SIGNING_SECRET" not in mapping, "Staging carries production certificate capabilities"
        assert mapping.get("TUTOR_RAG_SCOPE_MAP") in ("plain_text", "json"), "Staging QA RAG scope map absent"
    elif target == "production":
        assert mapping.get("CERTIFICATES") == "kv_namespace", "Production certificate KV binding missing"
        assert mapping.get("CERTIFICATE_SIGNING_SECRET") == "secret_text", "Production certificate signing secret missing"
        assert mapping.get("TUTOR_RAG_SCOPE_MAP") == "secret_text", "Production RAG scope must remain a secret"
    else:
        raise ValueError("Unknown target")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("target", choices=["staging", "production"])
    args = parser.parse_args()
    token = os.environ.get("CLOUDFLARE_API_TOKEN", "")
    if not token:
        print("BINDING_AUDIT=BLOCKED; reason=missing_ci_token", file=sys.stderr)
        return 2
    url = f"https://api.cloudflare.com/client/v4/accounts/{ACCOUNT}/workers/scripts/{WORKERS[args.target]}/settings"
    try:
        request = urllib.request.Request(url, headers={"Authorization": "Bearer " + token})
        with urllib.request.urlopen(request, timeout=12) as response:
            payload = json.load(response)
        if not payload.get("success"):
            raise RuntimeError("Unsuccessful response")
        validate_bindings(args.target, payload["result"]["bindings"])
        print("BINDING_AUDIT=PASS; target=" + args.target + "; values_not_disclosed=true")
        return 0
    except (urllib.error.HTTPError, urllib.error.URLError, KeyError, AssertionError, ValueError, RuntimeError) as exc:
        print("BINDING_AUDIT=FAIL; type=" + type(exc).__name__, file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
