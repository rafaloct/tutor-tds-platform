"""Compare published OpenAPI path sets without authenticating or mutating data."""

from __future__ import annotations

import argparse
import json
from urllib.request import urlopen


def paths(url: str) -> set[str]:
    with urlopen(url, timeout=20) as response:  # noqa: S310 - URLs are operator supplied.
        document = json.load(response)
    return set(document.get("paths", {}))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("staging_url")
    parser.add_argument("production_url")
    args = parser.parse_args()
    staging = paths(args.staging_url)
    production = paths(args.production_url)
    missing = sorted(staging - production)
    print(json.dumps({
        "staging_paths": len(staging),
        "production_paths": len(production),
        "missing_in_production": missing,
    }, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
