"""Create a deterministic, offline-only plan for the CW-3 Chatwoot manifest.

This script deliberately has no network client and no apply mode.  It is a
review aid, not a Chatwoot provisioner.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any


REQUIRED = {"schema_version", "status", "environment", "email", "inboxes", "teams", "labels", "custom_attributes", "quick_replies", "macros", "routing_intents"}
COLLECTIONS = ("inboxes", "teams", "labels", "custom_attributes", "quick_replies", "macros", "routing_intents")


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return value


def item_key(collection: str, item: Any) -> str:
    if collection == "labels":
        if not isinstance(item, str):
            raise ValueError("labels must be strings")
        return item
    if not isinstance(item, dict) or not isinstance(item.get("key"), str):
        raise ValueError(f"{collection} items require a string key")
    return item["key"]


def validate(manifest: dict[str, Any]) -> None:
    missing = REQUIRED - manifest.keys()
    if missing:
        raise ValueError(f"manifest missing keys: {', '.join(sorted(missing))}")
    if manifest["schema_version"] != 1 or manifest["status"] != "TARGET":
        raise ValueError("only schema_version=1 TARGET manifests are accepted")
    if manifest["environment"] != "staging":
        raise ValueError("CW-3 planner accepts staging only")
    address = manifest["email"].get("inbox_address", "")
    if "{{INSTITUTIONAL_DOMAIN}}" not in address:
        raise ValueError("manifest must keep the institutional-domain placeholder")
    for collection in COLLECTIONS:
        values = manifest[collection]
        if not isinstance(values, list):
            raise ValueError(f"{collection} must be a list")
        keys = [item_key(collection, value) for value in values]
        if len(keys) != len(set(keys)):
            raise ValueError(f"duplicate {collection} key")


def plan(manifest: dict[str, Any], inventory: dict[str, Any] | None = None) -> list[dict[str, str]]:
    """Return a stable desired-vs-inventory plan without making any mutation."""
    validate(manifest)
    inventory = inventory or {}
    actions: list[dict[str, str]] = []
    for collection in COLLECTIONS:
        existing = {item_key(collection, item): item for item in inventory.get(collection, [])}
        for desired in manifest[collection]:
            key = item_key(collection, desired)
            action = "unchanged" if existing.get(key) == desired else ("update" if key in existing else "create")
            actions.append({"resource": collection, "key": key, "action": action})
    return actions


def main() -> int:
    parser = argparse.ArgumentParser(description="CW-3 Chatwoot dry-run planner (never applies changes)")
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--inventory", type=Path, help="sanitized JSON inventory; omitted means empty")
    args = parser.parse_args()
    manifest = load_json(args.manifest)
    inventory = load_json(args.inventory) if args.inventory else None
    print(json.dumps({"mode": "dry-run", "actions": plan(manifest, inventory)}, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
