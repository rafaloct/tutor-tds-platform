#!/usr/bin/env python3
"""Fail-closed OCI provenance verification for API/worker images."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
from dataclasses import dataclass
from datetime import datetime
from urllib.parse import urlsplit

REVISION_PATTERN = re.compile(r"^[0-9a-f]{40}$")
ARCHIVE_SOURCE_PATTERN = re.compile(r"^urn:sha256:[0-9a-f]{64}$")
LABEL_REVISION = "org.opencontainers.image.revision"
LABEL_SOURCE = "org.opencontainers.image.source"
LABEL_CREATED = "org.opencontainers.image.created"
LABEL_VERSION = "org.opencontainers.image.version"


class ProvenanceError(RuntimeError):
    pass


@dataclass(frozen=True)
class ImageProvenance:
    image_id: str
    revision: str
    source: str
    created: str


def inspect_image(reference: str) -> dict:
    result = subprocess.run(
        ["docker", "image", "inspect", reference],
        check=False,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise ProvenanceError(f"Image unavailable: {reference}")
    try:
        documents = json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise ProvenanceError("Docker returned invalid image metadata") from exc
    if not isinstance(documents, list) or len(documents) != 1:
        raise ProvenanceError("Docker returned an unexpected image count")
    return documents[0]


def parse_provenance(document: dict) -> ImageProvenance:
    image_id = document.get("Id")
    labels = document.get("Config", {}).get("Labels") or {}
    revision = labels.get(LABEL_REVISION)
    source = labels.get(LABEL_SOURCE)
    created = labels.get(LABEL_CREATED)
    version = labels.get(LABEL_VERSION)
    if not isinstance(image_id, str) or not image_id.startswith("sha256:"):
        raise ProvenanceError("Image ID is not a sha256 digest")
    if not isinstance(revision, str) or not REVISION_PATTERN.fullmatch(revision):
        raise ProvenanceError("Image revision label must be a full 40-character Git SHA")
    if version != revision:
        raise ProvenanceError("Image version and revision labels diverge")
    parsed_source = urlsplit(source if isinstance(source, str) else "")
    repository_source = (
        parsed_source.scheme == "https"
        and bool(parsed_source.netloc)
        and not parsed_source.username
        and not parsed_source.query
        and not parsed_source.fragment
    )
    archive_source = bool(
        ARCHIVE_SOURCE_PATTERN.fullmatch(source if isinstance(source, str) else "")
    )
    if not repository_source and not archive_source:
        raise ProvenanceError(
            "Image source label must be a public HTTPS repository URL "
            "or a SHA-256 source archive URN"
        )
    try:
        parsed_created = datetime.fromisoformat(
            created.replace("Z", "+00:00") if isinstance(created, str) else ""
        )
    except ValueError as exc:
        raise ProvenanceError("Image created label must be an ISO-8601 timestamp") from exc
    if parsed_created.tzinfo is None or parsed_created.utcoffset() is None:
        raise ProvenanceError("Image created label must include a timezone")
    return ImageProvenance(
        image_id=image_id,
        revision=revision,
        source=source,
        created=created,
    )


def verify_images(
    documents: list[dict],
    expected_revision: str | None = None,
    expected_source: str | None = None,
) -> ImageProvenance:
    if not documents:
        raise ProvenanceError("At least one image is required")
    records = [parse_provenance(document) for document in documents]
    if len({record.image_id for record in records}) != 1:
        raise ProvenanceError("API and worker image digests diverge")
    if len({record.revision for record in records}) != 1:
        raise ProvenanceError("API and worker revisions diverge")
    record = records[0]
    if expected_revision is not None and record.revision != expected_revision:
        raise ProvenanceError("Image revision does not match the requested commit")
    if expected_source is not None and record.source != expected_source:
        raise ProvenanceError("Image source does not match the requested repository")
    return record


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("images", nargs="+")
    parser.add_argument("--expected-revision", required=True)
    parser.add_argument("--expected-source", required=True)
    args = parser.parse_args()
    if not REVISION_PATTERN.fullmatch(args.expected_revision):
        raise SystemExit("Expected revision must be a full 40-character Git SHA")
    try:
        record = verify_images(
            [inspect_image(reference) for reference in args.images],
            expected_revision=args.expected_revision,
            expected_source=args.expected_source,
        )
    except ProvenanceError as exc:
        raise SystemExit(f"Provenance verification failed: {exc}") from exc
    print(
        json.dumps(
            {
                "image_id": record.image_id,
                "revision": record.revision,
                "source": record.source,
                "created": record.created,
                "verified_images": len(args.images),
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
