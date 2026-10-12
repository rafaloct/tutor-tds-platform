from __future__ import annotations

import importlib.util
import json
import os
import stat
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import pytest


MODULE_PATH = (
    Path(__file__).resolve().parents[1]
    / "ops"
    / "staging_dynamic_activity_smoke.py"
)
SPEC = importlib.util.spec_from_file_location(
    "staging_dynamic_activity_smoke", MODULE_PATH
)
assert SPEC is not None and SPEC.loader is not None
smoke = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = smoke
SPEC.loader.exec_module(smoke)


BASE_URL = "https://ead.ipexdesenvolvimento.cloud/tutor-staging-api"
CLOUD_BASE_URL = "https://tutor-tds-staging.fastapicloud.dev"
RUN_ID = "wave2b-20261007123456-abcdef123456"


def fixture() -> dict[str, Any]:
    return {
        "schema_version": "wave2b-staging-fixture-v1",
        "fixture_id": "qa-wave2b-fixture",
        "student_user_id": "qa-wave2b-student",
        "course_id": "qa-wave2b-course",
        "topic": "Interações dinâmicas",
        "lineage": {
            "organization_id": "qa-org",
            "program_id": "qa-program",
            "class_id": "qa-wave2b-class",
            "membership_id": "qa-membership",
            "enrollment_id": "qa-context-enrollment",
            "legacy_enrollment_id": "qa-legacy-enrollment",
            "course_version_id": "qa-version",
            "section_id": "qa-section",
            "section_version_id": "qa-section-version",
        },
        "blocks": {
            "question": {
                "block_id": "qa-question",
                "block_version_id": "qa-question-version",
                "selected_index": 0,
            },
            "multi_correct_quiz": {
                "block_id": "qa-quiz",
                "block_version_id": "qa-quiz-version",
                "selected_index": 1,
                "minimum_correct_options": 2,
            },
        },
    }


def credentials() -> dict[str, str]:
    values: dict[str, str] = {"WAVE2B_STAGING_LANE": "vps"}
    for index, role in enumerate(smoke.ROLES):
        values[f"STAGING_SEED_{role}_CPF"] = f"cpf-secret-{index}"
        values[f"STAGING_SEED_{role}_PASSWORD"] = f"password-secret-{index}"
    return values


class FakeWave2BServer:
    def __init__(self, data: dict[str, Any], base_url: str = BASE_URL) -> None:
        self.fixture = data
        self.base_url = base_url
        self.tokens = {
            role: f"access-token-secret-{role.lower()}" for role in smoke.ROLES
        }
        self.attempts: dict[str, dict[str, Any]] = {}
        self.calls: list[dict[str, Any]] = []
        self.last_event_payload: dict[str, Any] | None = None

    @staticmethod
    def _role_from_credentials(body: dict[str, Any]) -> str:
        password = str(body["password"])
        return smoke.ROLES[int(password.rsplit("-", 1)[1])]

    def __call__(
        self,
        base_url: str,
        path: str,
        *,
        method: str = "GET",
        body: dict[str, Any] | None = None,
        token: str | None = None,
    ) -> Any:
        assert base_url == self.base_url
        self.calls.append(
            {"path": path, "method": method, "body": body, "token": token}
        )
        if path == "/auth/login":
            assert method == "POST" and body is not None
            role = self._role_from_credentials(body)
            return smoke.HttpResponse(200, {"access_token": self.tokens[role]})

        student = self.tokens["STUDENT"]
        teacher = self.tokens["TEACHER"]
        admin = self.tokens["ADMIN"]
        monitor = self.tokens["MONITOR"]
        outsider = self.tokens["OUTSIDER"]
        question_id = smoke.canonical_attempt_id(
            self.fixture, self.fixture["blocks"]["question"]
        )
        quiz_id = smoke.canonical_attempt_id(
            self.fixture, self.fixture["blocks"]["multi_correct_quiz"]
        )
        tampered_id = f"wave2b-tampered-{RUN_ID}"
        client_content_id = f"wave2b-client-content-{RUN_ID}"

        if method == "PUT" and path.startswith("/assessment-attempts/"):
            assert token == student and body is not None
            attempt_id = path.rsplit("/", 1)[1]
            if attempt_id == tampered_id:
                return smoke.HttpResponse(
                    409,
                    {"detail": {"code": "published_block_snapshot_conflict"}},
                )
            if attempt_id == client_content_id:
                return smoke.HttpResponse(
                    422,
                    {
                        "detail": {
                            "code": "published_block_content_is_server_owned"
                        }
                    },
                )
            existing = self.attempts.get(attempt_id)
            response_body = {
                **body,
                "attempt_id": attempt_id,
                "assessment_content_id": f"published-block:{attempt_id}",
                "score": 1 if body["completed"] else 0,
            }
            if existing is None:
                self.attempts[attempt_id] = response_body
                return smoke.HttpResponse(201, response_body)
            if existing["revision"] == body["revision"]:
                if all(existing.get(key) == value for key, value in response_body.items()):
                    return smoke.HttpResponse(200, existing)
                return smoke.HttpResponse(
                    409,
                    {
                        "detail": {
                            "code": "revision_conflict",
                            "current_revision": existing["revision"],
                        }
                    },
                )
            self.attempts[attempt_id] = response_body
            return smoke.HttpResponse(200, response_body)

        if path.endswith("/content"):
            assert token == student
            return smoke.HttpResponse(
                200,
                {
                    "answer_key": [
                        {
                            "correct_indices": [0, 1],
                            "graded": True,
                            "explanation": "",
                        }
                    ]
                },
            )

        if path.startswith("/classes/") and "/students/" in path:
            if token in {monitor, outsider}:
                return smoke.HttpResponse(403, {"detail": "denied"})
            assert token in {teacher, admin}
            attempt_id = path.rsplit("/", 1)[1]
            return smoke.HttpResponse(200, self.attempts[attempt_id])

        if path.startswith("/classes/") and "/assessment-attempts/" in path:
            assert token == student
            attempt_id = path.rsplit("/", 1)[1]
            if attempt_id == tampered_id:
                return smoke.HttpResponse(404, {"detail": "missing"})
            if attempt_id not in self.attempts:
                return smoke.HttpResponse(404, {"detail": "missing"})
            return smoke.HttpResponse(200, self.attempts[attempt_id])

        if path.startswith("/events?"):
            assert token == student
            quiz = self.attempts[quiz_id]
            payload = {
                "schema_version": "published-block-completion-v1",
                "origin": "published_block",
                "course_id": self.fixture["course_id"],
                "attempt_id": quiz_id,
                "score": 1,
                "graded": True,
                **{
                    field: self.fixture["lineage"][field]
                    for field in smoke.EVENT_CONTEXT_FIELDS
                },
                "block_id": self.fixture["blocks"]["multi_correct_quiz"]["block_id"],
                "block_version_id": self.fixture["blocks"]["multi_correct_quiz"][
                    "block_version_id"
                ],
            }
            self.last_event_payload = payload
            return smoke.HttpResponse(
                200,
                {
                    "events": [
                        {
                            "event_id": "synthetic-event-id",
                            "event_type": "assessment_completed",
                            "course_id": quiz["course_id"],
                            "session_id": "synthetic-session",
                            "occurred_at": quiz["updated_at"],
                            "active_seconds": None,
                            "validated_seconds": 0,
                            "sync_status": "pending",
                            "payload": payload,
                        }
                    ],
                    "offset": 0,
                    "limit": 100,
                },
            )
        raise AssertionError(f"Unexpected fake request: {method} {path}")


class FakeRevocationHook:
    def __init__(
        self,
        *,
        own_attempt_path: str,
        attempt_id: str,
        attempt_revision: int,
        attempt_context: dict[str, Any],
        effective_restore: bool,
        restored_context_overrides: dict[str, Any] | None = None,
    ) -> None:
        self.own_attempt_path = own_attempt_path
        self.attempt_id = attempt_id
        self.attempt_revision = attempt_revision
        self.attempt_context = attempt_context
        self.effective_restore = effective_restore
        self.restored_context_overrides = restored_context_overrides or {}
        self.revoked = False
        self.paths: list[str] = []

    def __call__(
        self,
        base_url: str,
        path: str,
        *,
        method: str = "GET",
        body: dict[str, Any] | None = None,
        token: str | None = None,
    ) -> Any:
        assert base_url == BASE_URL
        self.paths.append(path)
        if path == "/admin/qa/wave2b/revoke":
            assert method == "POST" and body is not None and token == "admin-token"
            self.revoked = True
            return smoke.HttpResponse(200, {"status": "revoked"})
        if path == "/admin/qa/wave2b/restore":
            assert method == "POST" and body is not None and token == "admin-token"
            if self.effective_restore:
                self.revoked = False
            return smoke.HttpResponse(200, {"status": "restored"})
        if path == self.own_attempt_path:
            assert method == "GET" and token == "student-token"
            if self.revoked:
                return smoke.HttpResponse(403, {"detail": "denied"})
            return smoke.HttpResponse(
                200,
                {
                    **self.attempt_context,
                    **self.restored_context_overrides,
                    "attempt_id": self.attempt_id,
                    "revision": self.attempt_revision,
                    "origin": "published_block",
                },
            )
        raise AssertionError(f"Unexpected fake request: {method} {path}")


def revocation_attempt_context(data: dict[str, Any]) -> dict[str, Any]:
    question = data["blocks"]["question"]
    return {
        "course_id": data["course_id"],
        **data["lineage"],
        "block_id": question["block_id"],
        "block_version_id": question["block_version_id"],
    }


@pytest.mark.parametrize(
    ("url", "lane"),
    [
        ("http://ead.ipexdesenvolvimento.cloud/tutor-staging-api", "vps"),
        ("https://ead.ipexdesenvolvimento.cloud/tutor-api", "vps"),
        ("https://staging.example.test/tutor-staging-api", "vps"),
        ("https://user@ead.ipexdesenvolvimento.cloud/tutor-staging-api", "vps"),
        ("https://ead.ipexdesenvolvimento.cloud:443/tutor-staging-api", "vps"),
        (
            "https://ead.ipexdesenvolvimento.cloud/tutor-staging-api?token=forbidden",
            "vps",
        ),
        (CLOUD_BASE_URL, "vps"),
        (BASE_URL, "cloud"),
        ("https://another.fastapicloud.dev", "cloud"),
        (CLOUD_BASE_URL + "/", "cloud"),
        (BASE_URL + "/", "vps"),
    ],
)
def test_target_guard_refuses_nonallowlisted_or_mismatched_targets(
    url: str, lane: str
) -> None:
    with pytest.raises(smoke.SmokePrecondition, match="staging_lane_url_mismatch"):
        smoke.validate_staging_base_url(url, lane)


@pytest.mark.parametrize(
    ("url", "lane"),
    [(CLOUD_BASE_URL, "cloud"), (BASE_URL, "vps")],
)
def test_target_guard_allows_only_the_two_matching_lanes(url: str, lane: str) -> None:
    assert smoke.validate_staging_base_url(url, lane) == url


def test_target_guard_requires_an_explicit_known_lane() -> None:
    with pytest.raises(smoke.SmokePrecondition, match="invalid_staging_lane"):
        smoke.validate_staging_base_url(CLOUD_BASE_URL, "")
    with pytest.raises(smoke.SmokePrecondition, match="invalid_staging_lane"):
        smoke.validate_staging_base_url(CLOUD_BASE_URL, "production")


def test_run_requires_lane_in_environment_without_fallback() -> None:
    env = credentials()
    env.pop("WAVE2B_STAGING_LANE")

    with pytest.raises(
        smoke.SmokePrecondition, match="missing_env_wave2b_staging_lane"
    ):
        smoke.run_smoke(
            CLOUD_BASE_URL,
            fixture(),
            run_id=RUN_ID,
            env=env,
            transport=FakeWave2BServer(fixture(), CLOUD_BASE_URL),
        )


def test_fake_server_covers_wave2b_contract_without_leaking_secrets() -> None:
    data = fixture()
    env = credentials()
    server = FakeWave2BServer(data)

    report = smoke.run_smoke(
        BASE_URL,
        data,
        run_id=RUN_ID,
        env=env,
        transport=server,
        now=datetime(2026, 10, 7, 12, 34, 56, tzinfo=timezone.utc),
    )

    assert report["status"] == "PASS"
    assert report["target"] == {
        "lane": "vps",
        "host": "ead.ipexdesenvolvimento.cloud",
        "path": "/tutor-staging-api",
        "acceptance": "PREACCEPTANCE_ONLY",
    }
    assert report["evidence"]["matching_event_count"] == 1
    assert report["revocation"] == {
        "status": "SKIPPED",
        "reason": "authorized_fixture_hook_not_provided",
    }
    assert report["secrets_emitted"] is False
    assert len(report["report_sha256"]) == 64
    serialized = json.dumps(report, sort_keys=True)
    credential_values = [
        value
        for key, value in env.items()
        if key.endswith(("_CPF", "_PASSWORD"))
    ]
    for secret in [*credential_values, *server.tokens.values()]:
        assert secret not in serialized
    assert "qa-wave2b-student" not in serialized
    assert f"wave2b-question-{RUN_ID}" not in serialized
    assert f"wave2b-quiz-{RUN_ID}" not in serialized
    statuses = {item["name"]: item["status"] for item in report["checks"]}
    assert statuses["question_mark_create"] == "PASS"
    assert statuses["question_unmark_update"] == "PASS"
    assert statuses["stale_revision_rejected"] == "PASS"
    assert statuses["teacher_context_read"] == "PASS"
    assert statuses["admin_context_read"] == "PASS"
    assert statuses["monitor_context_read_denied"] == "PASS"
    assert statuses["outsider_context_read_denied"] == "PASS"
    assert statuses["server_owned_multi_correct_answer_key"] == "PASS"
    assert statuses["published_content_is_server_owned"] == "PASS"
    assert statuses["zero_credit_completion_evidence"] == "PASS"
    assert server.last_event_payload is not None
    assert not set(smoke.PERSON_SCOPED_EVENT_FIELDS) & set(server.last_event_payload)
    assert all(not call["path"].startswith("/assessment-contents") for call in server.calls)


def test_canonical_ids_and_repeated_smoke_are_stable_and_idempotent() -> None:
    data = fixture()
    server = FakeWave2BServer(data)
    assert smoke.canonical_attempt_id(
        data, data["blocks"]["question"]
    ) == "attempt:published:f678a07826265a3cfc1aaa605c7137f3fc7d766411c119be"
    assert smoke.canonical_attempt_id(
        data, data["blocks"]["multi_correct_quiz"]
    ) == "attempt:published:8917f17578a467532858117020b1fee31671367970bf40a4"

    first = smoke.run_smoke(
        BASE_URL,
        data,
        run_id=RUN_ID,
        env=credentials(),
        transport=server,
        now=datetime(2026, 10, 7, 12, 34, 56, tzinfo=timezone.utc),
    )
    second = smoke.run_smoke(
        BASE_URL,
        data,
        run_id=RUN_ID,
        env=credentials(),
        transport=server,
        now=datetime(2026, 10, 7, 13, 34, 56, tzinfo=timezone.utc),
    )

    assert first["status"] == second["status"] == "PASS"
    statuses = {item["name"]: item["status"] for item in second["checks"]}
    assert statuses["question_mark_resume"] == "PASS"
    question_id = smoke.canonical_attempt_id(data, data["blocks"]["question"])
    quiz_id = smoke.canonical_attempt_id(
        data, data["blocks"]["multi_correct_quiz"]
    )
    assert server.attempts[question_id]["revision"] == 4
    assert server.attempts[quiz_id]["revision"] == 1


def test_missing_evidence_endpoint_is_explicitly_unknown_not_invented() -> None:
    data = fixture()
    env = credentials()
    server = FakeWave2BServer(data)

    def without_evidence(*args, **kwargs):
        path = args[1]
        if path.startswith("/events?"):
            return smoke.HttpResponse(404, {"detail": "route unavailable"})
        return server(*args, **kwargs)

    report = smoke.run_smoke(
        BASE_URL,
        data,
        run_id=RUN_ID,
        env=env,
        transport=without_evidence,
        now=datetime(2026, 10, 7, 12, 34, 56, tzinfo=timezone.utc),
    )

    assert report["status"] == "INCOMPLETE"
    assert report["evidence"] == {
        "status": "UNKNOWN",
        "reason": "authorized_evidence_read_endpoint_unavailable",
    }


def test_cloud_lane_is_recorded_as_canonical_acceptance() -> None:
    data = fixture()
    env = credentials() | {"WAVE2B_STAGING_LANE": "cloud"}
    server = FakeWave2BServer(data, CLOUD_BASE_URL)

    report = smoke.run_smoke(
        CLOUD_BASE_URL,
        data,
        run_id=RUN_ID,
        env=env,
        transport=server,
        now=datetime(2026, 10, 7, 12, 34, 56, tzinfo=timezone.utc),
    )

    assert report["status"] == "PASS"
    assert report["target"] == {
        "lane": "cloud",
        "host": "tutor-tds-staging.fastapicloud.dev",
        "path": "/",
        "acceptance": "CANONICAL_ACCEPTANCE",
    }


def test_fixture_rejects_secret_fields_and_revocation_never_runs_without_guard() -> None:
    unsafe = fixture() | {"student_password": "must-not-be-here"}
    with pytest.raises(smoke.SmokePrecondition, match="fixture_contains_secret_field"):
        smoke.validate_fixture(unsafe)

    data = fixture() | {
        "revocation_hook": {
            "revoke_path": "/admin/qa/wave2b/revoke",
            "restore_path": "/admin/qa/wave2b/restore",
        }
    }
    env = credentials()
    server = FakeWave2BServer(data)
    report = smoke.run_smoke(
        BASE_URL,
        data,
        run_id=RUN_ID,
        env=env,
        transport=server,
        now=datetime(2026, 10, 7, 12, 34, 56, tzinfo=timezone.utc),
    )

    assert report["revocation"] == {
        "status": "SKIPPED",
        "reason": "separate_mutation_authorization_missing",
    }
    assert all("/admin/qa/" not in call["path"] for call in server.calls)


def test_revocation_restore_must_restore_student_attempt_access() -> None:
    data = fixture() | {
        "revocation_hook": {
            "revoke_path": "/admin/qa/wave2b/revoke",
            "restore_path": "/admin/qa/wave2b/restore",
        }
    }
    attempt_id = smoke.canonical_attempt_id(data, data["blocks"]["question"])
    own_attempt_path = f"/classes/qa-wave2b-class/assessment-attempts/{attempt_id}"
    transport = FakeRevocationHook(
        own_attempt_path=own_attempt_path,
        attempt_id=attempt_id,
        attempt_revision=2,
        attempt_context=revocation_attempt_context(data),
        effective_restore=True,
    )
    checks: list[dict[str, object]] = []

    result = smoke._run_revocation_check(
        fixture=data,
        run_id=RUN_ID,
        base_url=BASE_URL,
        own_attempt_path=own_attempt_path,
        attempt_id=attempt_id,
        attempt_revision=2,
        attempt_block=data["blocks"]["question"],
        tokens={"ADMIN": "admin-token", "STUDENT": "student-token"},
        env={"WAVE2B_REVOCATION_MUTATION_GUARD": smoke.REVOCATION_GUARD},
        transport=transport,
        checks=checks,
    )

    assert result["status"] == "PASS"
    assert transport.paths == [
        "/admin/qa/wave2b/revoke",
        own_attempt_path,
        "/admin/qa/wave2b/restore",
        own_attempt_path,
    ]
    assert [item["name"] for item in checks] == [
        "revocation",
        "revocation_restore_effective",
    ]


def test_revocation_restore_200_without_access_recovery_fails_closed() -> None:
    data = fixture() | {
        "revocation_hook": {
            "revoke_path": "/admin/qa/wave2b/revoke",
            "restore_path": "/admin/qa/wave2b/restore",
        }
    }
    attempt_id = smoke.canonical_attempt_id(data, data["blocks"]["question"])
    own_attempt_path = f"/classes/qa-wave2b-class/assessment-attempts/{attempt_id}"
    transport = FakeRevocationHook(
        own_attempt_path=own_attempt_path,
        attempt_id=attempt_id,
        attempt_revision=2,
        attempt_context=revocation_attempt_context(data),
        effective_restore=False,
    )

    with pytest.raises(
        smoke.SmokeFailure,
        match="revocation_restore_not_effective",
    ):
        smoke._run_revocation_check(
            fixture=data,
            run_id=RUN_ID,
            base_url=BASE_URL,
            own_attempt_path=own_attempt_path,
            attempt_id=attempt_id,
            attempt_revision=2,
            attempt_block=data["blocks"]["question"],
            tokens={"ADMIN": "admin-token", "STUDENT": "student-token"},
            env={"WAVE2B_REVOCATION_MUTATION_GUARD": smoke.REVOCATION_GUARD},
            transport=transport,
            checks=[],
        )
    assert transport.paths[-2:] == [
        "/admin/qa/wave2b/restore",
        own_attempt_path,
    ]


def test_revocation_restore_rejects_attempt_with_tampered_context() -> None:
    data = fixture() | {
        "revocation_hook": {
            "revoke_path": "/admin/qa/wave2b/revoke",
            "restore_path": "/admin/qa/wave2b/restore",
        }
    }
    attempt_id = smoke.canonical_attempt_id(data, data["blocks"]["question"])
    own_attempt_path = f"/classes/qa-wave2b-class/assessment-attempts/{attempt_id}"
    transport = FakeRevocationHook(
        own_attempt_path=own_attempt_path,
        attempt_id=attempt_id,
        attempt_revision=2,
        attempt_context=revocation_attempt_context(data),
        effective_restore=True,
        restored_context_overrides={"class_id": "tampered-class"},
    )

    with pytest.raises(
        smoke.SmokeFailure,
        match="revocation_restore_not_effective",
    ):
        smoke._run_revocation_check(
            fixture=data,
            run_id=RUN_ID,
            base_url=BASE_URL,
            own_attempt_path=own_attempt_path,
            attempt_id=attempt_id,
            attempt_revision=2,
            attempt_block=data["blocks"]["question"],
            tokens={"ADMIN": "admin-token", "STUDENT": "student-token"},
            env={"WAVE2B_REVOCATION_MUTATION_GUARD": smoke.REVOCATION_GUARD},
            transport=transport,
            checks=[],
        )
    assert transport.paths[-2:] == [
        "/admin/qa/wave2b/restore",
        own_attempt_path,
    ]


def test_report_is_exclusive_and_private(tmp_path: Path) -> None:
    report = {
        "schema_version": smoke.REPORT_SCHEMA,
        "status": "PASS",
        "run_id": RUN_ID,
        "secrets_emitted": False,
    }
    report["report_sha256"] = smoke.sha256(report)

    artifact = smoke.write_report(report, tmp_path)

    assert json.loads(artifact.read_text(encoding="utf-8")) == report
    if os.name == "posix":
        assert stat.S_IMODE(artifact.stat().st_mode) == 0o600
    with pytest.raises(smoke.SmokePrecondition, match="output_artifact_create_failed"):
        smoke.write_report(report, tmp_path)


def test_source_has_no_credential_literals_and_only_prints_sanitized_report() -> None:
    source = MODULE_PATH.read_text(encoding="utf-8")

    assert "STAGING_SEED_STUDENT_PASSWORD=" not in source
    assert "STAGING_SEED_TEACHER_PASSWORD=" not in source
    assert "Authorization\"]" in source
    assert source.count("print(") == 1
    assert "print(canonical_json(report)" in source


def test_example_fixture_is_sanitized_and_schema_valid() -> None:
    example = MODULE_PATH.with_name("staging_dynamic_activity_fixture.example.json")

    validated = smoke.load_fixture(example)

    assert validated["schema_version"] == smoke.FIXTURE_SCHEMA
    serialized = json.dumps(validated).lower()
    assert "password" not in serialized
    assert "token" not in serialized
    assert "cpf" not in serialized
