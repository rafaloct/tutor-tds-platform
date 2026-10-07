#!/usr/bin/env python3
"""Fail-closed synthetic smoke for Wave 2B published activities.

The runner operates only against one of two explicitly selected HTTPS staging
lanes: FastAPI Cloud is the canonical acceptance lane, while the VPS is a
preacceptance lane only. ``WAVE2B_STAGING_LANE`` is mandatory and must match the
allowlisted URL; there is no default or fallback. It consumes synthetic
credentials from environment variables and a non-secret fixture descriptor
from ``WAVE2B_FIXTURE_DESCRIPTOR``. Neither credentials nor access tokens are
written to stdout or to the optional evidence artifact.

``STAGING_SEED_OUTSIDER_CPF`` and ``STAGING_SEED_OUTSIDER_PASSWORD`` must be
confirmed first. Create that pair only if the fixture lacks an existing,
separate teacher account that can safely act as the outsider persona.

The fixture is provisioned separately.  This runner never creates courses,
versions, classes, memberships, or enrollment bindings.  A revocation check is
skipped unless the descriptor supplies disposable QA hook paths *and* the
separate mutation guard is explicitly present.
"""

from __future__ import annotations

import hashlib
import json
import os
import re
import sys
import urllib.error
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Callable, Mapping
from uuid import uuid4


STAGING_LANES: dict[str, dict[str, str]] = {
    "cloud": {
        "base_url": "https://tutor-tds-staging.fastapicloud.dev",
        "host": "tutor-tds-staging.fastapicloud.dev",
        "path": "",
        "acceptance": "CANONICAL_ACCEPTANCE",
    },
    "vps": {
        "base_url": "https://ead.ipexdesenvolvimento.cloud/tutor-staging-api",
        "host": "ead.ipexdesenvolvimento.cloud",
        "path": "/tutor-staging-api",
        "acceptance": "PREACCEPTANCE_ONLY",
    },
}
FIXTURE_SCHEMA = "wave2b-staging-fixture-v1"
REPORT_SCHEMA = "wave2b-staging-smoke-v1"
REVOCATION_GUARD = "AUTHORIZED_DISPOSABLE_WAVE2B_FIXTURE"
IDENTIFIER = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.:-]{0,179}$")
RUN_ID = re.compile(r"^wave2b-[a-z0-9-]{12,64}$")
CONTEXT_FIELDS = (
    "organization_id",
    "program_id",
    "class_id",
    "membership_id",
    "enrollment_id",
    "legacy_enrollment_id",
    "course_version_id",
    "section_id",
    "section_version_id",
)
PERSON_SCOPED_EVENT_FIELDS = (
    "owner_id",
    "membership_id",
    "enrollment_id",
    "legacy_enrollment_id",
)
EVENT_CONTEXT_FIELDS = (
    "organization_id",
    "program_id",
    "class_id",
    "course_version_id",
    "section_id",
    "section_version_id",
)
ROLES = ("STUDENT", "TEACHER", "ADMIN", "OUTSIDER", "MONITOR")
FORBIDDEN_FIXTURE_KEY_PARTS = (
    "password",
    "secret",
    "token",
    "private_key",
    "cpf",
)


class SmokeFailure(RuntimeError):
    """A sanitized, stable failure code safe for the output artifact."""

    def __init__(self, code: str) -> None:
        super().__init__(code)
        self.code = code


class SmokePrecondition(SmokeFailure):
    """A missing external prerequisite, not evidence of product behavior."""


def canonical_attempt_id(
    fixture: Mapping[str, object],
    block: Mapping[str, object],
) -> str:
    lineage = fixture["lineage"]
    if not isinstance(lineage, Mapping):
        raise SmokeFailure("fixture_lineage_invalid")
    identity = [
        "published_block",
        fixture["student_user_id"],
        lineage["organization_id"],
        lineage["program_id"],
        lineage["class_id"],
        lineage["membership_id"],
        lineage["enrollment_id"],
        lineage["legacy_enrollment_id"],
        fixture["course_id"],
        lineage["course_version_id"],
        lineage["section_id"],
        lineage["section_version_id"],
        block["block_id"],
        block["block_version_id"],
    ]
    digest = hashlib.sha256(
        json.dumps(
            identity,
            ensure_ascii=False,
            separators=(",", ":"),
        ).encode()
    ).hexdigest()
    return f"attempt:published:{digest[:48]}"


@dataclass(frozen=True)
class HttpResponse:
    status: int
    body: object


Transport = Callable[..., HttpResponse]


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):  # noqa: ANN001
        return None


def canonical_json(value: object) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")


def sha256(value: object) -> str:
    return hashlib.sha256(canonical_json(value)).hexdigest()


def new_run_id(now: datetime | None = None) -> str:
    current = (now or datetime.now(timezone.utc)).astimezone(timezone.utc)
    return f"wave2b-{current:%Y%m%d%H%M%S}-{uuid4().hex[:12]}"


def validate_run_id(value: str) -> str:
    if not RUN_ID.fullmatch(value):
        raise SmokePrecondition("invalid_run_id")
    return value


def validate_staging_base_url(value: str, lane: str) -> str:
    selected = STAGING_LANES.get(lane)
    if selected is None:
        raise SmokePrecondition("invalid_staging_lane")
    base_url = value
    parsed = urllib.parse.urlsplit(base_url)
    try:
        port = parsed.port
    except ValueError as exc:
        raise SmokePrecondition("non_staging_target") from exc
    if (
        parsed.scheme != "https"
        or parsed.hostname != selected["host"]
        or parsed.path != selected["path"]
        or parsed.username is not None
        or parsed.password is not None
        or port is not None
        or parsed.query
        or parsed.fragment
        or base_url != selected["base_url"]
    ):
        raise SmokePrecondition("staging_lane_url_mismatch")
    return base_url


def _safe_relative_path(value: object, *, qa_hook: bool = False) -> str:
    if not isinstance(value, str) or not value.startswith("/") or value.startswith("//"):
        raise SmokePrecondition("invalid_fixture_path")
    parsed = urllib.parse.urlsplit(value)
    if parsed.scheme or parsed.netloc or parsed.fragment or "\r" in value or "\n" in value:
        raise SmokePrecondition("invalid_fixture_path")
    if qa_hook:
        if parsed.query or not parsed.path.startswith(("/admin/qa/", "/ops/qa/")):
            raise SmokePrecondition("unsafe_revocation_hook")
    return value


def request_json(
    base_url: str,
    path: str,
    *,
    method: str = "GET",
    body: dict[str, object] | None = None,
    token: str | None = None,
) -> HttpResponse:
    _safe_relative_path(path)
    headers = {"Accept": "application/json", "User-Agent": "TutorTDS-Wave2B-Smoke/1"}
    data = None
    if body is not None:
        headers["Content-Type"] = "application/json"
        data = canonical_json(body)
    if token is not None:
        headers["Authorization"] = f"Bearer {token}"
    request = urllib.request.Request(
        base_url + path,
        data=data,
        headers=headers,
        method=method,
    )
    opener = urllib.request.build_opener(_NoRedirect())
    try:
        with opener.open(request, timeout=20) as response:
            payload = response.read()
            return HttpResponse(
                response.status,
                json.loads(payload) if payload else None,
            )
    except urllib.error.HTTPError as exc:
        payload = exc.read()
        try:
            parsed: object = json.loads(payload) if payload else None
        except (json.JSONDecodeError, UnicodeDecodeError):
            parsed = None
        return HttpResponse(exc.code, parsed)
    except (OSError, urllib.error.URLError) as exc:
        raise SmokeFailure("staging_transport_error") from exc


def _required_env(env: Mapping[str, str], name: str) -> str:
    value = env.get(name, "").strip()
    if not value:
        raise SmokePrecondition(f"missing_env_{name.lower()}")
    return value


def _reject_secret_keys(value: object) -> None:
    if isinstance(value, dict):
        for key, child in value.items():
            normalized = str(key).lower()
            if any(part in normalized for part in FORBIDDEN_FIXTURE_KEY_PARTS):
                raise SmokePrecondition("fixture_contains_secret_field")
            _reject_secret_keys(child)
    elif isinstance(value, list):
        for child in value:
            _reject_secret_keys(child)


def _identifier(value: object, field: str) -> str:
    if not isinstance(value, str) or not IDENTIFIER.fullmatch(value):
        raise SmokePrecondition(f"invalid_fixture_{field}")
    return value


def _block(value: object, name: str) -> dict[str, object]:
    if not isinstance(value, dict):
        raise SmokePrecondition(f"invalid_fixture_{name}")
    result: dict[str, object] = {
        "block_id": _identifier(value.get("block_id"), f"{name}_block_id"),
        "block_version_id": _identifier(
            value.get("block_version_id"), f"{name}_block_version_id"
        ),
    }
    selected = value.get("selected_index")
    if not isinstance(selected, int) or isinstance(selected, bool) or not 0 <= selected <= 999:
        raise SmokePrecondition(f"invalid_fixture_{name}_selected_index")
    result["selected_index"] = selected
    if name == "multi_correct_quiz":
        minimum = value.get("minimum_correct_options", 2)
        if not isinstance(minimum, int) or isinstance(minimum, bool) or minimum < 2:
            raise SmokePrecondition("invalid_fixture_multi_correct_minimum")
        result["minimum_correct_options"] = minimum
    return result


def validate_fixture(value: object) -> dict[str, object]:
    if not isinstance(value, dict):
        raise SmokePrecondition("invalid_fixture_document")
    _reject_secret_keys(value)
    if value.get("schema_version") != FIXTURE_SCHEMA:
        raise SmokePrecondition("unsupported_fixture_schema")
    lineage_source = value.get("lineage")
    blocks_source = value.get("blocks")
    if not isinstance(lineage_source, dict) or not isinstance(blocks_source, dict):
        raise SmokePrecondition("invalid_fixture_document")
    lineage = {
        field: _identifier(lineage_source.get(field), field)
        for field in CONTEXT_FIELDS
    }
    topic = value.get("topic")
    if not isinstance(topic, str) or not topic.strip() or len(topic) > 240:
        raise SmokePrecondition("invalid_fixture_topic")
    fixture: dict[str, object] = {
        "schema_version": FIXTURE_SCHEMA,
        "fixture_id": _identifier(value.get("fixture_id"), "fixture_id"),
        "student_user_id": _identifier(
            value.get("student_user_id"), "student_user_id"
        ),
        "course_id": _identifier(value.get("course_id"), "course_id"),
        "topic": topic.strip(),
        "lineage": lineage,
        "blocks": {
            "question": _block(blocks_source.get("question"), "question"),
            "multi_correct_quiz": _block(
                blocks_source.get("multi_correct_quiz"), "multi_correct_quiz"
            ),
        },
    }
    if fixture["course_id"] != lineage_source.get("course_id", fixture["course_id"]):
        # course_id is intentionally top-level because it is also a first-class
        # API field; an optional duplicate in lineage must never disagree.
        raise SmokePrecondition("fixture_course_lineage_conflict")
    if blocks_source["question"].get("block_id") == blocks_source[
        "multi_correct_quiz"
    ].get("block_id"):
        raise SmokePrecondition("fixture_blocks_not_distinct")
    hook = value.get("revocation_hook")
    if hook is not None:
        if not isinstance(hook, dict):
            raise SmokePrecondition("invalid_revocation_hook")
        fixture["revocation_hook"] = {
            "revoke_path": _safe_relative_path(hook.get("revoke_path"), qa_hook=True),
            "restore_path": _safe_relative_path(hook.get("restore_path"), qa_hook=True),
        }
    return fixture


def load_fixture(path: str | Path) -> dict[str, object]:
    fixture_path = Path(path).resolve()
    if not fixture_path.is_file() or fixture_path.stat().st_size > 64 * 1024:
        raise SmokePrecondition("fixture_file_unavailable")
    try:
        value = json.loads(fixture_path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise SmokePrecondition("fixture_file_invalid_json") from exc
    return validate_fixture(value)


def _expect(response: HttpResponse, status: int, code: str) -> object:
    if response.status != status:
        raise SmokeFailure(code)
    return response.body


def _expect_object(response: HttpResponse, status: int, code: str) -> dict[str, object]:
    body = _expect(response, status, code)
    if not isinstance(body, dict):
        raise SmokeFailure(code)
    return body


def _detail_code(body: object) -> str | None:
    if not isinstance(body, dict):
        return None
    detail = body.get("detail")
    return detail.get("code") if isinstance(detail, dict) else None


def _check(
    checks: list[dict[str, object]],
    name: str,
    response: HttpResponse | None = None,
    *,
    status: str = "PASS",
    reason: str | None = None,
) -> None:
    item: dict[str, object] = {"name": name, "status": status}
    if response is not None:
        item["http_status"] = response.status
        item["response_sha256"] = sha256(response.body)
    if reason is not None:
        item["reason"] = reason
    checks.append(item)


def _login(
    base_url: str,
    role: str,
    env: Mapping[str, str],
    transport: Transport,
) -> str:
    response = transport(
        base_url,
        "/auth/login",
        method="POST",
        body={
            "cpf": _required_env(env, f"STAGING_SEED_{role}_CPF"),
            "password": _required_env(env, f"STAGING_SEED_{role}_PASSWORD"),
        },
    )
    result = _expect_object(response, 200, f"{role.lower()}_login_failed")
    token = result.get("access_token")
    if not isinstance(token, str) or not token:
        raise SmokeFailure(f"{role.lower()}_login_invalid")
    return token


def _attempt_payload(
    fixture: dict[str, object],
    block: dict[str, object],
    *,
    revision: int,
    marked: list[int],
    completed: bool,
    updated_at: datetime,
) -> dict[str, object]:
    return {
        "course_id": fixture["course_id"],
        "origin": "published_block",
        **fixture["lineage"],
        "block_id": block["block_id"],
        "block_version_id": block["block_version_id"],
        "topic": fixture["topic"],
        "mode": "quiz",
        "revision": revision,
        "answers": {"0": block["selected_index"]},
        "marked": marked,
        "current_index": 0,
        "remaining_seconds": 0,
        "completed": completed,
        "score": 0,
        "updated_at": updated_at.astimezone(timezone.utc).isoformat().replace(
            "+00:00", "Z"
        ),
    }


def _attempt_replay_payload(attempt: Mapping[str, object]) -> dict[str, object]:
    """Rebuild the exact client-owned state for an immutable completion replay."""
    fields = (
        "course_id",
        "origin",
        *CONTEXT_FIELDS,
        "block_id",
        "block_version_id",
        "topic",
        "mode",
        "revision",
        "answers",
        "marked",
        "current_index",
        "remaining_seconds",
        "completed",
        "updated_at",
    )
    if any(field not in attempt for field in fields):
        raise SmokeFailure("attempt_response_mismatch")
    return {field: attempt[field] for field in fields} | {"score": 0}


def _quoted(value: object) -> str:
    return urllib.parse.quote(str(value), safe="")


def _verify_attempt(body: object, attempt_id: str, *, revision: int) -> dict[str, object]:
    if (
        not isinstance(body, dict)
        or body.get("attempt_id") != attempt_id
        or body.get("revision") != revision
        or body.get("origin") != "published_block"
    ):
        raise SmokeFailure("attempt_response_mismatch")
    return body


def _verify_fixture_attempt(
    body: object,
    attempt_id: str,
    *,
    revision: int,
    fixture: Mapping[str, object],
    block: Mapping[str, object],
) -> dict[str, object]:
    attempt = _verify_attempt(body, attempt_id, revision=revision)
    lineage = fixture.get("lineage")
    if (
        not isinstance(lineage, Mapping)
        or attempt.get("course_id") != fixture.get("course_id")
        or any(attempt.get(field) != lineage.get(field) for field in CONTEXT_FIELDS)
        or attempt.get("block_id") != block.get("block_id")
        or attempt.get("block_version_id") != block.get("block_version_id")
    ):
        raise SmokeFailure("attempt_response_mismatch")
    return attempt


def _run_revocation_check(
    *,
    fixture: dict[str, object],
    run_id: str,
    base_url: str,
    own_attempt_path: str,
    attempt_id: str,
    attempt_revision: int,
    attempt_block: Mapping[str, object],
    tokens: dict[str, str],
    env: Mapping[str, str],
    transport: Transport,
    checks: list[dict[str, object]],
) -> dict[str, object]:
    hook = fixture.get("revocation_hook")
    if hook is None:
        _check(
            checks,
            "revocation",
            status="SKIPPED",
            reason="authorized_fixture_hook_not_provided",
        )
        return {"status": "SKIPPED", "reason": "authorized_fixture_hook_not_provided"}
    if env.get("WAVE2B_REVOCATION_MUTATION_GUARD") != REVOCATION_GUARD:
        _check(
            checks,
            "revocation",
            status="SKIPPED",
            reason="separate_mutation_authorization_missing",
        )
        return {"status": "SKIPPED", "reason": "separate_mutation_authorization_missing"}

    assert isinstance(hook, dict)
    hook_body = {"fixture_id": fixture["fixture_id"], "run_id": run_id}
    revoke_response: HttpResponse | None = None
    restore_response: HttpResponse | None = None
    restored_access_response: HttpResponse | None = None
    denied_response: HttpResponse | None = None
    try:
        revoke_response = transport(
            base_url,
            str(hook["revoke_path"]),
            method="POST",
            body=hook_body,
            token=tokens["ADMIN"],
        )
        if revoke_response.status != 200:
            raise SmokeFailure("revocation_hook_failed")
        denied_response = transport(
            base_url,
            own_attempt_path,
            token=tokens["STUDENT"],
        )
        if denied_response.status != 403:
            raise SmokeFailure("revoked_context_not_denied")
    finally:
        restore_response = transport(
            base_url,
            str(hook["restore_path"]),
            method="POST",
            body=hook_body,
            token=tokens["ADMIN"],
        )
        if restore_response.status != 200:
            raise SmokeFailure("revocation_restore_failed")
        restored_access_response = transport(
            base_url,
            own_attempt_path,
            token=tokens["STUDENT"],
        )
        try:
            restored_attempt = _expect_object(
                restored_access_response,
                200,
                "revocation_restore_not_effective",
            )
            _verify_fixture_attempt(
                restored_attempt,
                attempt_id,
                revision=attempt_revision,
                fixture=fixture,
                block=attempt_block,
            )
        except SmokeFailure as exc:
            raise SmokeFailure("revocation_restore_not_effective") from exc
    _check(checks, "revocation", denied_response)
    _check(checks, "revocation_restore_effective", restored_access_response)
    return {
        "status": "PASS",
        "revoke_response_sha256": sha256(revoke_response.body),
        "restore_response_sha256": sha256(restore_response.body),
    }


def run_smoke(
    base_url: str,
    fixture: dict[str, object],
    *,
    run_id: str,
    env: Mapping[str, str],
    transport: Transport = request_json,
    now: datetime | None = None,
) -> dict[str, object]:
    lane = _required_env(env, "WAVE2B_STAGING_LANE")
    base_url = validate_staging_base_url(base_url, lane)
    run_id = validate_run_id(run_id)
    fixture = validate_fixture(fixture)
    started = (now or datetime.now(timezone.utc)).astimezone(timezone.utc)
    checks: list[dict[str, object]] = []

    tokens = {
        role: _login(base_url, role, env, transport)
        for role in ROLES
    }
    for role in ROLES:
        _check(checks, f"authenticate_{role.lower()}")

    blocks = fixture["blocks"]
    assert isinstance(blocks, dict)
    question = blocks["question"]
    quiz = blocks["multi_correct_quiz"]
    assert isinstance(question, dict) and isinstance(quiz, dict)
    class_id = _quoted(fixture["lineage"]["class_id"])
    owner_id = _quoted(fixture["student_user_id"])
    question_id = canonical_attempt_id(fixture, question)
    quiz_id = canonical_attempt_id(fixture, quiz)
    tampered_id = f"wave2b-tampered-{run_id}"
    question_put_path = f"/assessment-attempts/{question_id}"
    question_get_path = f"/classes/{class_id}/assessment-attempts/{question_id}"

    question_preflight_response = transport(
        base_url,
        question_get_path,
        token=tokens["STUDENT"],
    )
    if question_preflight_response.status == 404:
        question_base_revision = 0
        question_write_status = 201
        question_check_name = "question_mark_create"
    else:
        question_preflight = _expect_object(
            question_preflight_response,
            200,
            "question_preflight_failed",
        )
        question_base_revision = question_preflight.get("revision")
        if not isinstance(question_base_revision, int) or question_base_revision < 1:
            raise SmokeFailure("question_preflight_invalid")
        _verify_attempt(
            question_preflight,
            question_id,
            revision=question_base_revision,
        )
        if question_preflight.get("completed") is not False:
            raise SmokeFailure("question_fixture_already_completed")
        question_write_status = 200
        question_check_name = "question_mark_resume"

    question_mark_revision = question_base_revision + 1
    question_mark_payload = _attempt_payload(
        fixture,
        question,
        revision=question_mark_revision,
        marked=[0],
        completed=False,
        updated_at=started,
    )
    created_question_response = transport(
        base_url,
        question_put_path,
        method="PUT",
        body=question_mark_payload,
        token=tokens["STUDENT"],
    )
    created_question = _verify_attempt(
        _expect(
            created_question_response,
            question_write_status,
            "question_mark_write_failed",
        ),
        question_id,
        revision=question_mark_revision,
    )
    if created_question.get("marked") != [0] or created_question.get("completed") is not False:
        raise SmokeFailure("question_mark_not_persisted")
    _check(checks, question_check_name, created_question_response)

    question_retry_response = transport(
        base_url,
        question_put_path,
        method="PUT",
        body=question_mark_payload,
        token=tokens["STUDENT"],
    )
    question_retry = _expect_object(
        question_retry_response, 200, "question_identical_replay_failed"
    )
    if question_retry != created_question:
        raise SmokeFailure("question_identical_replay_diverged")
    _check(checks, "question_identical_replay", question_retry_response)

    marked_read_response = transport(
        base_url,
        question_get_path,
        token=tokens["STUDENT"],
    )
    marked_read = _verify_attempt(
        _expect(marked_read_response, 200, "question_context_read_failed"),
        question_id,
        revision=question_mark_revision,
    )
    if marked_read.get("marked") != [0]:
        raise SmokeFailure("question_mark_read_diverged")
    _check(checks, "question_context_read_marked", marked_read_response)

    question_unmark_revision = question_mark_revision + 1
    question_unmark_payload = _attempt_payload(
        fixture,
        question,
        revision=question_unmark_revision,
        marked=[],
        completed=False,
        updated_at=started + timedelta(seconds=1),
    )
    unmarked_response = transport(
        base_url,
        question_put_path,
        method="PUT",
        body=question_unmark_payload,
        token=tokens["STUDENT"],
    )
    unmarked = _verify_attempt(
        _expect(unmarked_response, 200, "question_unmark_failed"),
        question_id,
        revision=question_unmark_revision,
    )
    if unmarked.get("marked") != []:
        raise SmokeFailure("question_unmark_not_persisted")
    _check(checks, "question_unmark_update", unmarked_response)

    stale_response = transport(
        base_url,
        question_put_path,
        method="PUT",
        body={**question_unmark_payload, "marked": [0]},
        token=tokens["STUDENT"],
    )
    if stale_response.status != 409 or _detail_code(stale_response.body) != "revision_conflict":
        raise SmokeFailure("stale_revision_not_rejected")
    _check(checks, "stale_revision_rejected", stale_response)

    unmarked_read_response = transport(
        base_url,
        question_get_path,
        token=tokens["STUDENT"],
    )
    unmarked_read = _verify_attempt(
        _expect(unmarked_read_response, 200, "question_unmark_read_failed"),
        question_id,
        revision=question_unmark_revision,
    )
    if unmarked_read.get("marked") != []:
        raise SmokeFailure("question_unmark_read_diverged")
    _check(checks, "question_context_read_unmarked", unmarked_read_response)

    staff_path = (
        f"/classes/{class_id}/students/{owner_id}/assessment-attempts/{question_id}"
    )
    for role in ("TEACHER", "ADMIN"):
        response = transport(base_url, staff_path, token=tokens[role])
        body = _verify_attempt(
            _expect(response, 200, f"{role.lower()}_context_read_failed"),
            question_id,
            revision=question_unmark_revision,
        )
        if body.get("class_id") != fixture["lineage"]["class_id"]:
            raise SmokeFailure(f"{role.lower()}_context_read_diverged")
        _check(checks, f"{role.lower()}_context_read", response)
    for role in ("MONITOR", "OUTSIDER"):
        response = transport(base_url, staff_path, token=tokens[role])
        if response.status != 403:
            raise SmokeFailure(f"{role.lower()}_context_read_not_denied")
        _check(checks, f"{role.lower()}_context_read_denied", response)

    quiz_put_path = f"/assessment-attempts/{quiz_id}"
    quiz_get_path = f"/classes/{class_id}/assessment-attempts/{quiz_id}"
    quiz_preflight_response = transport(
        base_url,
        quiz_get_path,
        token=tokens["STUDENT"],
    )
    if quiz_preflight_response.status == 404:
        quiz_revision = 1
        quiz_write_status = 201
        quiz_payload = _attempt_payload(
            fixture,
            quiz,
            revision=quiz_revision,
            marked=[],
            completed=True,
            updated_at=started + timedelta(seconds=2),
        )
    else:
        quiz_preflight = _expect_object(
            quiz_preflight_response,
            200,
            "quiz_preflight_failed",
        )
        quiz_revision = quiz_preflight.get("revision")
        if not isinstance(quiz_revision, int) or quiz_revision < 1:
            raise SmokeFailure("quiz_preflight_invalid")
        _verify_attempt(quiz_preflight, quiz_id, revision=quiz_revision)
        quiz_write_status = 200
        if quiz_preflight.get("completed") is True:
            quiz_payload = _attempt_replay_payload(quiz_preflight)
        else:
            quiz_revision += 1
            quiz_payload = _attempt_payload(
                fixture,
                quiz,
                revision=quiz_revision,
                marked=[],
                completed=True,
                updated_at=started + timedelta(seconds=2),
            )
    quiz_create_response = transport(
        base_url,
        quiz_put_path,
        method="PUT",
        body=quiz_payload,
        token=tokens["STUDENT"],
    )
    created_quiz = _verify_attempt(
        _expect(quiz_create_response, quiz_write_status, "quiz_completion_failed"),
        quiz_id,
        revision=quiz_revision,
    )
    if created_quiz.get("score") != 1 or created_quiz.get("completed") is not True:
        raise SmokeFailure("quiz_server_score_diverged")
    _check(checks, "multi_correct_quiz_complete", quiz_create_response)

    quiz_retry_response = transport(
        base_url,
        quiz_put_path,
        method="PUT",
        body=quiz_payload,
        token=tokens["STUDENT"],
    )
    quiz_retry = _expect_object(
        quiz_retry_response, 200, "quiz_identical_replay_failed"
    )
    if quiz_retry != created_quiz:
        raise SmokeFailure("quiz_identical_replay_diverged")
    _check(checks, "quiz_identical_replay", quiz_retry_response)

    quiz_read_response = transport(base_url, quiz_get_path, token=tokens["STUDENT"])
    quiz_read = _verify_attempt(
        _expect(quiz_read_response, 200, "quiz_context_read_failed"),
        quiz_id,
        revision=quiz_revision,
    )
    if quiz_read.get("score") != 1:
        raise SmokeFailure("quiz_context_read_diverged")
    _check(checks, "quiz_context_read", quiz_read_response)

    hydrate_response = transport(
        base_url,
        quiz_get_path + "/content",
        token=tokens["STUDENT"],
    )
    hydrated = _expect_object(hydrate_response, 200, "quiz_content_hydration_failed")
    answer_key = hydrated.get("answer_key")
    if not isinstance(answer_key, list) or len(answer_key) != 1:
        raise SmokeFailure("quiz_server_answer_key_invalid")
    answer = answer_key[0]
    correct_indices = answer.get("correct_indices") if isinstance(answer, dict) else None
    if (
        not isinstance(answer, dict)
        or answer.get("graded") is not True
        or not isinstance(correct_indices, list)
        or len(correct_indices) < int(quiz["minimum_correct_options"])
        or quiz["selected_index"] not in correct_indices
    ):
        raise SmokeFailure("quiz_multi_correct_contract_diverged")
    _check(checks, "server_owned_multi_correct_answer_key", hydrate_response)

    tampered_version = f"tampered-{sha256(quiz['block_version_id'])[:16]}"
    tampered_payload = {**quiz_payload, "block_version_id": tampered_version}
    tampered_response = transport(
        base_url,
        f"/assessment-attempts/{tampered_id}",
        method="PUT",
        body=tampered_payload,
        token=tokens["STUDENT"],
    )
    if (
        tampered_response.status != 409
        or _detail_code(tampered_response.body) != "published_block_snapshot_conflict"
    ):
        raise SmokeFailure("tampered_lineage_not_rejected")
    _check(checks, "tampered_lineage_rejected", tampered_response)
    tampered_read_response = transport(
        base_url,
        f"/classes/{class_id}/assessment-attempts/{tampered_id}",
        token=tokens["STUDENT"],
    )
    if tampered_read_response.status != 404:
        raise SmokeFailure("tampered_attempt_was_persisted")
    _check(checks, "tampered_lineage_not_persisted", tampered_read_response)

    client_content_response = transport(
        base_url,
        f"/assessment-attempts/wave2b-client-content-{run_id}",
        method="PUT",
        body={
            **question_mark_payload,
            "assessment_content_id": "client-owned-content-must-be-rejected",
        },
        token=tokens["STUDENT"],
    )
    if (
        client_content_response.status != 422
        or _detail_code(client_content_response.body)
        != "published_block_content_is_server_owned"
    ):
        raise SmokeFailure("client_owned_content_not_rejected")
    _check(checks, "published_content_is_server_owned", client_content_response)

    evidence_path = "/events?" + urllib.parse.urlencode(
        {"course_id": fixture["course_id"], "limit": 100}
    )
    evidence_response = transport(
        base_url,
        evidence_path,
        token=tokens["STUDENT"],
    )
    evidence: dict[str, object]
    if evidence_response.status in {403, 404}:
        evidence = {
            "status": "UNKNOWN",
            "reason": "authorized_evidence_read_endpoint_unavailable",
        }
        _check(
            checks,
            "zero_credit_completion_evidence",
            evidence_response,
            status="UNKNOWN",
            reason="authorized_evidence_read_endpoint_unavailable",
        )
    elif evidence_response.status == 200 and isinstance(evidence_response.body, dict):
        events = evidence_response.body.get("events")
        if not isinstance(events, list):
            raise SmokeFailure("evidence_read_response_invalid")
        matching = [
            event
            for event in events
            if isinstance(event, dict)
            and event.get("event_type") == "assessment_completed"
            and isinstance(event.get("payload"), dict)
            and event["payload"].get("attempt_id") == quiz_id
        ]
        if len(matching) != 1:
            raise SmokeFailure("completion_evidence_cardinality_diverged")
        event = matching[0]
        payload = event["payload"]
        if (
            event.get("validated_seconds") != 0
            or event.get("active_seconds") not in {0, None}
            or event.get("course_id") != fixture["course_id"]
            or payload.get("schema_version") != "published-block-completion-v1"
            or payload.get("origin") != "published_block"
            or payload.get("course_id") != fixture["course_id"]
            or payload.get("score") != 1
            or payload.get("graded") is not True
            or any(
                payload.get(field) != fixture["lineage"][field]
                for field in EVENT_CONTEXT_FIELDS
            )
            or payload.get("block_id") != quiz["block_id"]
            or payload.get("block_version_id") != quiz["block_version_id"]
            or any(field in payload for field in PERSON_SCOPED_EVENT_FIELDS)
        ):
            raise SmokeFailure("completion_evidence_not_zero_credit_or_wrong_lineage")
        evidence = {
            "status": "PASS",
            "matching_event_count": 1,
            "event_sha256": sha256(event),
        }
        _check(checks, "zero_credit_completion_evidence", evidence_response)
    else:
        raise SmokeFailure("evidence_read_failed")

    revocation = _run_revocation_check(
        fixture=fixture,
        run_id=run_id,
        base_url=base_url,
        own_attempt_path=question_get_path,
        attempt_id=question_id,
        attempt_revision=question_unmark_revision,
        attempt_block=question,
        tokens=tokens,
        env=env,
        transport=transport,
        checks=checks,
    )

    finished = datetime.now(timezone.utc)
    report: dict[str, object] = {
        "schema_version": REPORT_SCHEMA,
        "status": "PASS" if evidence["status"] == "PASS" else "INCOMPLETE",
        "run_id": run_id,
        "started_at": started.isoformat().replace("+00:00", "Z"),
        "finished_at": finished.isoformat().replace("+00:00", "Z"),
        "target": {
            "lane": lane,
            "host": STAGING_LANES[lane]["host"],
            "path": STAGING_LANES[lane]["path"] or "/",
            "acceptance": STAGING_LANES[lane]["acceptance"],
        },
        "fixture_precondition": {
            "status": "SUPPLIED_EXTERNALLY",
            "runner_mutation": "NONE",
            "runtime_validation": "exact_lineage_and_block_versions",
        },
        "fixture_sha256": sha256(fixture),
        "attempts": {
            "question_id_sha256": sha256(question_id),
            "quiz_id_sha256": sha256(quiz_id),
        },
        "checks": checks,
        "evidence": evidence,
        "revocation": revocation,
        "secrets_emitted": False,
    }
    report["report_sha256"] = sha256(report)
    return report


def write_report(report: dict[str, object], output_dir: str | Path) -> Path:
    directory = Path(output_dir).resolve()
    if not directory.is_dir():
        raise SmokePrecondition("output_directory_unavailable")
    run_id = validate_run_id(str(report.get("run_id", "")))
    path = directory / f"{run_id}.json"
    try:
        descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    except OSError as exc:
        raise SmokePrecondition("output_artifact_create_failed") from exc
    try:
        with os.fdopen(descriptor, "wb") as output:
            output.write(canonical_json(report) + b"\n")
            output.flush()
            os.fsync(output.fileno())
    except OSError as exc:
        path.unlink(missing_ok=True)
        raise SmokePrecondition("output_artifact_write_failed") from exc
    except BaseException:
        path.unlink(missing_ok=True)
        raise
    return path


def _failure_report(
    run_id: str,
    code: str,
    status: str,
    lane: str | None = None,
) -> dict[str, object]:
    report: dict[str, object] = {
        "schema_version": REPORT_SCHEMA,
        "status": status,
        "run_id": run_id,
        "error": {"code": code},
        "secrets_emitted": False,
    }
    if lane in STAGING_LANES:
        report["target"] = {
            "lane": lane,
            "acceptance": STAGING_LANES[lane]["acceptance"],
        }
    report["report_sha256"] = sha256(report)
    return report


def main() -> None:
    if len(sys.argv) != 2:
        raise SystemExit(
            "Usage: staging_dynamic_activity_smoke.py "
            "https://ead.ipexdesenvolvimento.cloud/tutor-staging-api"
        )
    run_id = new_run_id()
    env = os.environ
    lane = env.get("WAVE2B_STAGING_LANE", "").strip()
    report: dict[str, object]
    exit_code = 0
    try:
        lane = _required_env(env, "WAVE2B_STAGING_LANE")
        validate_staging_base_url(sys.argv[1], lane)
        fixture = load_fixture(_required_env(env, "WAVE2B_FIXTURE_DESCRIPTOR"))
        report = run_smoke(
            sys.argv[1],
            fixture,
            run_id=run_id,
            env=env,
        )
        if report["status"] == "INCOMPLETE":
            exit_code = 2
    except SmokePrecondition as exc:
        report = _failure_report(
            run_id, exc.code, "PRECONDITION_FAILED", lane=lane
        )
        exit_code = 2
    except SmokeFailure as exc:
        report = _failure_report(run_id, exc.code, "FAIL", lane=lane)
        exit_code = 1

    output_dir = env.get("WAVE2B_SMOKE_OUTPUT_DIR", "").strip()
    if output_dir:
        try:
            write_report(report, output_dir)
        except SmokeFailure as exc:
            report = _failure_report(
                run_id, exc.code, "PRECONDITION_FAILED", lane=lane
            )
            exit_code = 2
    print(canonical_json(report).decode("utf-8"))
    raise SystemExit(exit_code)


if __name__ == "__main__":
    main()
