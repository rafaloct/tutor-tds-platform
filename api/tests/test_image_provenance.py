from __future__ import annotations

import importlib.util
import sys
from pathlib import Path

import pytest


MODULE_PATH = Path(__file__).resolve().parents[1] / "ops" / "verify_image_provenance.py"
SPEC = importlib.util.spec_from_file_location("verify_image_provenance", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
provenance = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = provenance
SPEC.loader.exec_module(provenance)

REVISION = "a" * 40
SOURCE = "https://github.com/example/tutor-tds"
ARCHIVE_SOURCE = "urn:sha256:" + "a" * 64


def image_document(
    *,
    image_id: str = "sha256:" + "1" * 64,
    revision: str = REVISION,
    source: str = SOURCE,
    created: str = "2026-09-20T20:00:00+00:00",
) -> dict:
    return {
        "Id": image_id,
        "Config": {
            "Labels": {
                provenance.LABEL_REVISION: revision,
                provenance.LABEL_VERSION: revision,
                provenance.LABEL_SOURCE: source,
                provenance.LABEL_CREATED: created,
            }
        },
    }


def test_same_digest_and_revision_pass_for_api_and_worker() -> None:
    result = provenance.verify_images(
        [image_document(), image_document()],
        expected_revision=REVISION,
        expected_source=SOURCE,
    )

    assert result.image_id == "sha256:" + "1" * 64
    assert result.revision == REVISION


def test_content_addressed_local_archive_is_accepted_without_git_remote() -> None:
    result = provenance.verify_images(
        [image_document(source=ARCHIVE_SOURCE)],
        expected_revision=REVISION,
        expected_source=ARCHIVE_SOURCE,
    )
    assert result.source == ARCHIVE_SOURCE
    with pytest.raises(provenance.ProvenanceError, match="source"):
        provenance.parse_provenance(image_document(source="urn:sha256:invalid"))


def test_missing_or_untrusted_oci_labels_fail_closed() -> None:
    missing = image_document()
    del missing["Config"]["Labels"][provenance.LABEL_REVISION]
    with pytest.raises(provenance.ProvenanceError, match="revision"):
        provenance.parse_provenance(missing)
    with pytest.raises(provenance.ProvenanceError, match="source"):
        provenance.parse_provenance(image_document(source="http://example.test/repo"))
    with pytest.raises(provenance.ProvenanceError, match="timezone"):
        provenance.parse_provenance(image_document(created="2026-09-20T20:00:00"))


def test_api_worker_digest_or_revision_divergence_fails() -> None:
    with pytest.raises(provenance.ProvenanceError, match="digests diverge"):
        provenance.verify_images(
            [image_document(), image_document(image_id="sha256:" + "2" * 64)]
        )
    with pytest.raises(provenance.ProvenanceError, match="revisions diverge"):
        provenance.verify_images(
            [image_document(), image_document(revision="b" * 40)]
        )
    with pytest.raises(provenance.ProvenanceError, match="requested commit"):
        provenance.verify_images([image_document()], expected_revision="b" * 40)
    with pytest.raises(provenance.ProvenanceError, match="requested repository"):
        provenance.verify_images(
            [image_document()], expected_revision=REVISION, expected_source="https://github.com/other/repo"
        )


def test_dockerfile_workflow_and_deploy_are_wired_for_provenance() -> None:
    api_root = Path(__file__).resolve().parents[1]
    dockerfile = (api_root / "Dockerfile").read_text(encoding="utf-8")
    workflow = (
        api_root.parent / ".github" / "workflows" / "tutor-api.yml"
    ).read_text(encoding="utf-8")
    deploy = (api_root / "ops" / "deploy_staging.sh").read_text(encoding="utf-8")

    assert "python:3.13-slim@sha256:" in dockerfile
    for label in (
        provenance.LABEL_REVISION,
        provenance.LABEL_SOURCE,
        provenance.LABEL_CREATED,
    ):
        assert label in dockerfile
    assert 'tutor-tds-api:${GITHUB_SHA}' in workflow
    assert '--build-arg "OCI_REVISION=$GITHUB_SHA"' in workflow
    assert "verify_image_provenance.py" in workflow
    assert "EXPECTED_REVISION=${3:?full Git revision required}" in deploy
    assert "EXPECTED_SOURCE=${4:?HTTPS repository or SHA-256 source archive required}" in deploy
    assert deploy.count("verify_image_provenance.py") >= 3
