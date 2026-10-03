from __future__ import annotations

import hashlib
import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "docs" / "portal" / "WP1_LEGACY_SOURCE_MANIFEST.json"
LEGACY_PREFIX = "wordpress/legacy-runtime/"
ALLOWED_LEGACY_REFERENCES = {
    "wordpress/README.md",
    "tooling/verify_wp_legacy_snapshot.py",
    ".github/workflows/wp-legacy-quarantine.yml",
}


def git_bytes(path: str) -> bytes:
    return subprocess.check_output(
        ["git", "-C", str(ROOT), "show", f"HEAD:{path}"],
        stderr=subprocess.DEVNULL,
    )


def is_allowed_legacy_reference(path: str) -> bool:
    return path.startswith("docs/") or path in ALLOWED_LEGACY_REFERENCES


def verify_legacy_references() -> None:
    tracked = subprocess.check_output(
        ["git", "-C", str(ROOT), "ls-files", "-z"],
    ).split(b"\0")

    for raw_path in tracked:
        if not raw_path:
            continue
        path = raw_path.decode("utf-8", errors="surrogateescape")
        if path.startswith(LEGACY_PREFIX) or is_allowed_legacy_reference(path):
            continue
        data = subprocess.check_output(
            ["git", "-C", str(ROOT), "show", f":{path}"],
            stderr=subprocess.DEVNULL,
        )
        if b"wordpress/legacy-runtime" in data:
            raise SystemExit(
                f"quarantine violation: tracked file references legacy snapshot: {path}"
            )


def main() -> int:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    contract = manifest.get("hash_contract", {})
    if contract.get("algorithm") != "sha256" or contract.get("bytes") != "git_blob":
        raise SystemExit("manifest hash_contract must be sha256 over git_blob bytes")

    expected = {item["path"]: item for item in manifest["files"]}
    tracked = subprocess.check_output(
        ["git", "-C", str(ROOT), "ls-tree", "-r", "--name-only", "HEAD", "wordpress/legacy-runtime"],
        text=True,
    ).splitlines()
    tracked = [path for path in tracked if path.startswith(LEGACY_PREFIX)]

    if set(tracked) != set(expected):
        missing = sorted(set(expected) - set(tracked))
        extra = sorted(set(tracked) - set(expected))
        raise SystemExit(
            f"legacy manifest inventory mismatch missing={missing} extra={extra}"
        )

    for path in sorted(tracked):
        data = git_bytes(path)
        actual = hashlib.sha256(data).hexdigest()
        item = expected[path]
        if actual != item["sha256"] or len(data) != item["bytes"]:
            raise SystemExit(f"legacy manifest mismatch: {path}")

    verify_legacy_references()

    print(f"WP legacy manifest OK: {len(tracked)} files")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
