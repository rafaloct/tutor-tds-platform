from __future__ import annotations

import importlib.util
import json
import os
import stat
from pathlib import Path

import pytest


CONTRACT_PATH = Path(__file__).resolve().parents[1] / "ops" / "staging_smoke_contract.py"
CONTRACT_SPEC = importlib.util.spec_from_file_location("staging_smoke_contract", CONTRACT_PATH)
assert CONTRACT_SPEC is not None and CONTRACT_SPEC.loader is not None
smoke_contract = importlib.util.module_from_spec(CONTRACT_SPEC)
CONTRACT_SPEC.loader.exec_module(smoke_contract)


MODULE_PATH = (
    Path(__file__).resolve().parents[1]
    / "ops"
    / "staging_evidence_session_refresh.py"
)
SPEC = importlib.util.spec_from_file_location(
    "staging_evidence_session_refresh", MODULE_PATH
)
assert SPEC is not None and SPEC.loader is not None
refresh_tool = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(refresh_tool)


def seed_env(path: Path, *, duplicate_token: bool = False) -> None:
    lines = [
        "STAGING_SEED_TEACHER_CPF=synthetic-cpf",
        "STAGING_SEED_TEACHER_PASSWORD=synthetic-password",
        "STAGING_SEED_CHECKIN_TOKEN=old-synthetic-token",
    ]
    if duplicate_token:
        lines.append("STAGING_SEED_CHECKIN_TOKEN=duplicate-token")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    os.chmod(path, 0o600)


@pytest.mark.parametrize(
    "url",
    [
        "http://example.test/tutor-staging-api",
        "https://example.test/tutor-api",
        "https://example.test/tutor-staging-api",
        "https://user@example.test/tutor-staging-api",
        "https://ead.ipexdesenvolvimento.cloud/tutor-staging-api?token=forbidden",
        "https://ead.ipexdesenvolvimento.cloud:443/tutor-staging-api",
    ],
)
def test_validate_staging_base_url_fails_closed(url: str) -> None:
    with pytest.raises(RuntimeError, match="non-staging"):
        refresh_tool.validate_staging_base_url(url)


def test_canonical_smoke_target_rejects_legacy_and_production() -> None:
    assert smoke_contract.validate_canonical_staging_base_url(
        "https://tutor-tds-staging.fastapicloud.dev/"
    ) == "https://tutor-tds-staging.fastapicloud.dev"
    for url in (
        "https://ead.ipexdesenvolvimento.cloud/tutor-staging-api",
        "https://ead.ipexdesenvolvimento.cloud/tutor-api",
        "https://tutor-tds-staging.fastapicloud.dev?unsafe=true",
        "http://tutor-tds-staging.fastapicloud.dev",
    ):
        with pytest.raises(RuntimeError, match="non-canonical"):
            smoke_contract.validate_canonical_staging_base_url(url)


def test_fixture_selector_accepts_only_disposable_staging_ids() -> None:
    assert smoke_contract.validate_fixture_class_id("staging-qa-class") == "staging-qa-class"
    for fixture_id in ("production-class", "staging_qa_class", "staging-qa-", ""):
        with pytest.raises(RuntimeError, match="non-disposable"):
            smoke_contract.validate_fixture_class_id(fixture_id)


def test_replace_token_is_atomic_unique_and_keeps_mode_0600(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    env_file = tmp_path / ".staging-seed.env"
    seed_env(env_file)
    real_chmod = refresh_tool.os.chmod
    chmod_modes: list[int] = []

    def tracked_chmod(path: Path, mode: int) -> None:
        chmod_modes.append(mode)
        real_chmod(path, mode)

    monkeypatch.setattr(refresh_tool.os, "chmod", tracked_chmod)

    refresh_tool.replace_token(env_file, "new-synthetic-token-value")

    contents = env_file.read_text(encoding="utf-8")
    assert contents.count("STAGING_SEED_CHECKIN_TOKEN=") == 1
    assert "old-synthetic-token" not in contents
    assert "STAGING_SEED_CHECKIN_TOKEN=new-synthetic-token-value" in contents
    assert chmod_modes == [0o600]
    if os.name == "posix":
        assert stat.S_IMODE(env_file.stat().st_mode) == 0o600
    assert not env_file.with_name(env_file.name + ".token-refresh.tmp").exists()

    duplicate = tmp_path / ".duplicate.env"
    seed_env(duplicate, duplicate_token=True)
    before = duplicate.read_bytes()
    with pytest.raises(RuntimeError, match="exactly one"):
        refresh_tool.replace_token(duplicate, "must-not-be-written")
    assert duplicate.read_bytes() == before


def test_refresh_printable_summary_never_contains_tokens(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    env_file = tmp_path / ".staging-seed.env"
    seed_env(env_file)
    responses = iter(
        [
            {"access_token": "access-secret-must-not-print"},
            {
                "id": "synthetic-session-id",
                "class_id": "staging-qa-class",
                "starts_at": "2026-09-20T20:00:00Z",
                "ends_at": "2026-09-21T04:00:00Z",
                "status": "open",
                "token_expires_at": "2026-09-20T20:10:00Z",
                "token_version": 1,
                "checkin_token": "new-checkin-secret-value",
                "access_token": "unexpected-response-secret",
            },
        ]
    )
    monkeypatch.setattr(refresh_tool, "post", lambda *_args, **_kwargs: next(responses))

    summary = refresh_tool.refresh(
        "https://ead.ipexdesenvolvimento.cloud/tutor-staging-api", env_file
    )
    serialized = json.dumps(summary)

    assert summary["id"] == "synthetic-session-id"
    assert "checkin_token" not in summary
    assert "access_token" not in summary
    assert "secret" not in serialized
    assert "STAGING_SEED_CHECKIN_TOKEN=new-checkin-secret-value" in env_file.read_text(
        encoding="utf-8"
    )
