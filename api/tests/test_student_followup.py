from concurrent.futures import ThreadPoolExecutor
from datetime import datetime

import pytest
from sqlalchemy import delete, func, select, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models import BaselineRevision, BaselineSourceRecord, ClassEnrollment, ClassMonitor, Enrollment, MentorshipCase, MentorshipRevision, ProgramMembership, StudentBaseline, User
from test_certificate_requests import header, requests_api
from test_presence import presence_api


def baseline(client, *, actor="teacher", user="learner", classroom="c1", revision=0, record="tablet-7-1789996700697", key="baseline-review-key", **changes):
    payload = {"source": "baseline_forms", "record_id": record, "baseline_date": "2026-09-20", "territory_id": "territory-synthetic", "expected_revision": revision, "reason": "Vínculo conferido pessoalmente", "idempotency_key": key} | changes
    return client.put(f"/classes/{classroom}/students/{user}/baseline", headers=header(actor), json=payload)


def baseline_get(client, *, actor="teacher", user="learner", classroom="c1"):
    return client.get(f"/classes/{classroom}/students/{user}/baseline", headers=header(actor))


def case_create(client, *, actor="teacher", key="mentorship-create-key", **changes):
    payload = {"user_id": "learner", "mentor_id": "monitor", "objective": "Concluir atividade introdutória", "next_action": "Rever plano com o estudante", "reason": "Acompanhamento combinado", "idempotency_key": key} | changes
    return client.post("/classes/c1/mentorship-cases", headers=header(actor), json=payload)


def case_patch(client, identity, *, actor="teacher", revision=1, key="mentorship-update-key", **changes):
    payload = {"expected_revision": revision, "reason": "Próxima etapa combinada", "idempotency_key": key} | changes
    return client.patch(f"/classes/c1/mentorship-cases/{identity}", headers=header(actor), json=payload)


def test_mentor_picker_uses_active_class_staff_only(presence_api):
    client, engine = presence_api
    path = "/classes/c1/students/learner/mentors"
    response = client.get(path, headers=header("teacher"))
    assert response.status_code == 200
    assert {row["user_id"] for row in response.json()["mentors"]} == {"teacher", "monitor"}
    assert all(set(row) == {"user_id", "name"} for row in response.json()["mentors"])
    assert client.get(path, headers=header("learner")).status_code == 403
    assert client.get(path, headers=header("teacher2")).status_code == 403
    with Session(engine) as session:
        session.get(ProgramMembership, ("monitor", "p1")).status = "inactive"
        session.commit()
    assert [row["user_id"] for row in client.get(path, headers=header("teacher")).json()["mentors"]] == ["teacher"]


def test_baseline_is_explicit_reference_not_inferred_or_copied(presence_api):
    client, engine = presence_api
    assert baseline_get(client).json() == {"baseline": None, "history": []}
    first = baseline(client)
    assert first.status_code == 200, first.text
    assert first.json()["record_id"] == "tablet-7-1789996700697"
    assert first.json()["reviewed_by"] == "teacher"
    assert first.json()["revision"] == 1
    assert datetime.fromisoformat(first.json()["reviewed_at"]).utcoffset().total_seconds() == 0
    assert baseline(client).json() == first.json()
    assert baseline(client, profile={"income": "private"}).status_code == 422
    assert baseline(client, record="tablet\nrecord", key="bad-control-key").status_code == 422
    assert baseline(client, reason="  ").status_code == 422
    assert baseline_get(client, user="other").json()["baseline"] is None
    read = baseline_get(client).json()
    assert read["baseline"] == first.json()
    assert [item["revision"] for item in read["history"]] == [1]
    with Session(engine) as session:
        assert session.scalar(select(func.count()).select_from(BaselineSourceRecord)) == 1
        assert session.scalar(select(func.count()).select_from(BaselineRevision)) == 1
        assert "reviewed_by" not in session.scalar(select(BaselineRevision)).snapshot


def test_baseline_reuse_only_same_person_and_prior_reference_stays_reserved(presence_api):
    client, engine = presence_api
    assert baseline(client).status_code == 200
    same_person = baseline(client, classroom="c2", actor="teacher2", key="same-person-other-class")
    assert same_person.status_code == 200, same_person.text
    assert baseline(client, user="other", key="cannot-share-with-other").status_code == 409
    changed = baseline(client, revision=1, record="tablet-new-1789996700698", key="correct-reference-key", territory_id=None)
    assert changed.status_code == 200 and changed.json()["revision"] == 2
    assert baseline(client, user="other", key="old-reference-still-reserved").status_code == 409
    assert baseline(client, revision=0, record="another-record", key="stale-revision-key").status_code == 409
    assert baseline(client, record="changed-replay").status_code == 409
    assert baseline(client, actor="monitor").status_code == 409
    history = baseline_get(client).json()["history"]
    assert [item["snapshot"]["record_id"] for item in history] == ["tablet-7-1789996700697", "tablet-new-1789996700698"]
    assert baseline(client).json()["revision"] == 1
    assert baseline_get(client).json()["baseline"]["revision"] == 2


def test_scope_hides_other_classes_and_does_not_infer_equal_names(presence_api):
    client, engine = presence_api
    with Session(engine) as session:
        session.get(User, "other").name = session.get(User, "learner").name
        session.commit()
    assert baseline(client).status_code == 200
    assert baseline_get(client, user="other").json()["baseline"] is None
    for actor in ("learner", "outsider", "teacher2", "coordinator"):
        assert baseline_get(client, actor=actor).status_code == 403
        assert baseline(client, actor=actor).status_code == 403
        assert case_create(client, actor=actor).status_code == 403
        assert client.get("/classes/c1/mentorship-cases", headers=header(actor)).status_code == 403
    assert baseline_get(client, actor="monitor").status_code == 200
    assert baseline(client, user="outsider", key="foreign-student-key").status_code == 403


def test_mentorship_human_lifecycle_history_and_exact_replay(presence_api):
    client, engine = presence_api
    created = case_create(client)
    assert created.status_code == 201, created.text
    record = created.json()
    assert record["status"] == "open" and record["revision"] == 1
    assert record["mentor_name"] == "Name monitor"
    assert record["closed_at"] is None
    assert case_create(client).status_code == 200
    assert case_create(client).json() == record
    identity = record["id"]
    progress = case_patch(client, identity, status="in_progress", next_action="Revisar exercício na próxima sessão")
    assert progress.status_code == 200, progress.text
    assert progress.json()["revision"] == 2
    assert case_patch(client, identity, status="in_progress", next_action="Revisar exercício na próxima sessão").json() == progress.json()
    assert case_patch(client, identity, status="closed").status_code == 409
    assert case_patch(client, identity, key="stale-key-different", status="closed").status_code == 409
    closed = case_patch(client, identity, revision=2, key="close-case-key", status="closed", mentor_id="teacher")
    assert closed.status_code == 200
    assert closed.json()["closed_at"] is not None
    reopened = case_patch(client, identity, revision=3, key="reopen-case-key", status="open")
    assert reopened.status_code == 200 and reopened.json()["closed_at"] is None
    detail = client.get(f"/classes/c1/mentorship-cases/{identity}", headers=header("monitor")).json()
    assert [item["snapshot"]["status"] for item in detail["history"]] == ["open", "in_progress", "closed", "open"]
    assert all(datetime.fromisoformat(item["occurred_at"]).utcoffset().total_seconds() == 0 for item in detail["history"])
    assert case_create(client).json()["revision"] == 1
    assert client.get(f"/classes/c2/mentorship-cases/{identity}", headers=header("teacher2")).status_code == 404
    assert client.patch(f"/classes/c2/mentorship-cases/{identity}", headers=header("teacher2"), json={"expected_revision": 4, "status": "closed", "reason": "Wrong class", "idempotency_key": "wrong-class-update"}).status_code == 404


def test_cases_page_filters_student_and_never_accepts_unlinked_mentor(presence_api):
    client, engine = presence_api
    first = case_create(client).json()
    assert case_create(client, user_id="other", key="other-case-key").status_code == 201
    for mentor in ("outsider", "teacher2", "coordinator", "admin", "learner"):
        assert case_create(client, mentor_id=mentor, key=f"invalid-mentor-{mentor}").status_code == 422
    assert case_create(client, objective=" ", key="empty-objective-key").status_code == 422
    assert case_patch(client, first["id"]).status_code == 422
    assert case_patch(client, first["id"], next_action=None).status_code == 422
    page = client.get("/classes/c1/mentorship-cases?limit=1&offset=1", headers=header("teacher")).json()
    assert page["total"] == 2 and page["limit"] == page["offset"] == 1 and len(page["items"]) == 1
    filtered = client.get("/classes/c1/mentorship-cases?user_id=learner", headers=header("teacher")).json()
    assert [item["id"] for item in filtered["items"]] == [first["id"]]
    with Session(engine) as session:
        session.get(ProgramMembership, ("monitor", "p1")).status = "inactive"
        session.commit()
    assert case_create(client).status_code == 422
    assert case_patch(client, first["id"], status="closed").status_code == 422
    assert case_patch(client, first["id"], mentor_id="teacher", status="in_progress").status_code == 200


@pytest.mark.parametrize("target", ["staff", "membership", "enrollment", "class"])
def test_current_authority_and_links_are_revalidated_for_replay(presence_api, target):
    client, engine = presence_api
    assert baseline(client).status_code == 200
    created = case_create(client).json()
    with Session(engine) as session:
        if target == "staff":
            record = session.get(ProgramMembership, ("teacher", "p1"))
        elif target == "membership":
            record = session.get(ProgramMembership, ("learner", "p1"))
        elif target == "enrollment":
            record = session.get(Enrollment, "e1")
        else:
            record = session.get(ClassEnrollment, ("c1", "learner"))
        record.status = "inactive"
        session.commit()
    assert baseline(client).status_code == 403
    assert baseline_get(client).status_code == 403
    assert case_create(client).status_code == 403
    assert case_patch(client, created["id"], status="closed").status_code == 403
    if target != "staff":
        assert client.get("/classes/c1/mentorship-cases", headers=header("teacher")).json()["total"] == 0


def test_audit_and_association_are_immutable_under_real_migration(presence_api):
    client, engine = presence_api
    assert baseline(client).status_code == 200
    assert case_create(client).status_code == 201
    for statement in (
        "UPDATE baseline_source_records SET user_id = 'other'",
        "UPDATE student_baselines SET user_id = 'other', enrollment_id = 'other-e', revision = 2",
        "UPDATE student_baselines SET revision = 3",
        "UPDATE baseline_revisions SET snapshot = '{}'",
        "DELETE FROM baseline_revisions",
        "UPDATE mentorship_cases SET class_id = 'c2', revision = 2",
        "UPDATE mentorship_cases SET revision = 3",
        "UPDATE mentorship_revisions SET reason = 'changed'",
        "DELETE FROM mentorship_revisions",
    ):
        with pytest.raises(IntegrityError), engine.begin() as connection:
            connection.execute(text(statement))


@pytest.mark.parametrize("same_key", [True, False])
def test_concurrent_baseline_and_case_cas(presence_api, same_key):
    client, engine = presence_api
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda i: baseline(client, key="same-baseline-key" if same_key else f"baseline-race-key-{i}"), range(2)))
    assert sorted(result.status_code for result in results) == ([200, 200] if same_key else [200, 409])
    created = case_create(client).json()
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda i: case_patch(client, created["id"], key="same-patch-key" if same_key else f"patch-race-key-{i}", status="in_progress"), range(2)))
    assert sorted(result.status_code for result in results) == ([200, 200] if same_key else [200, 409])
    with Session(engine) as session:
        assert session.scalar(select(func.count()).select_from(BaselineRevision)) == 1
        assert session.scalar(select(func.count()).select_from(MentorshipRevision)) == 2


def test_concurrent_reference_for_different_people_never_double_assigns(presence_api):
    client, engine = presence_api
    with Session(engine) as session:
        session.add(ClassEnrollment(class_id="c2", user_id="other", enrollment_id="other-e", program_id="p1", course_id="course", status="active"))
        session.commit()
    with ThreadPoolExecutor(max_workers=2) as pool:
        first = pool.submit(baseline, client)
        second = pool.submit(baseline, client, actor="teacher2", user="other", classroom="c2", key="another-person-key")
        assert sorted((first.result().status_code, second.result().status_code)) == [200, 409]
    with Session(engine) as session:
        assert session.scalar(select(func.count()).select_from(BaselineSourceRecord)) == 1
        assert session.scalar(select(func.count()).select_from(StudentBaseline)) == 1


@pytest.mark.parametrize("foreign_keys_enabled", [True, False])
def test_owner_erasure_removes_source_references_cases_and_narrative_history(presence_api, foreign_keys_enabled):
    client, engine = presence_api
    assert baseline(client).status_code == 200
    assert baseline(client, classroom="c2", actor="teacher2", key="same-owner-second-class").status_code == 200
    assert case_create(client).status_code == 201
    if not foreign_keys_enabled:
        with engine.connect() as connection:
            connection.exec_driver_sql("PRAGMA foreign_keys=OFF")
    response = client.delete("/auth/me")
    assert response.status_code == 204, response.text
    with Session(engine) as session:
        for model in (BaselineSourceRecord, StudentBaseline, BaselineRevision, MentorshipCase, MentorshipRevision):
            assert session.scalar(select(func.count()).select_from(model)) == 0


def test_departed_reviewer_and_mentor_anonymized_without_mutating_history(presence_api):
    client, engine = presence_api
    assert baseline(client, actor="monitor").status_code == 200
    created = case_create(client, actor="monitor").json()
    with Session(engine) as session:
        session.execute(delete(ClassMonitor).where(ClassMonitor.user_id == "monitor"))
        session.get(ProgramMembership, ("monitor", "p1")).status = "inactive"
        session.commit()
    response = client.delete("/auth/me", headers=header("monitor"))
    assert response.status_code == 204, response.text
    read = baseline_get(client).json()
    assert read["baseline"]["reviewed_by"] is None
    assert read["history"][0]["actor_user_id"] is None
    detail = client.get(f"/classes/c1/mentorship-cases/{created['id']}", headers=header("teacher")).json()
    assert detail["mentor_id"] is detail["mentor_name"] is None
    assert detail["revision"] == 1
    assert detail["history"][0]["actor_user_id"] is None
    assert detail["history"][0]["snapshot"]["mentor_id"] is None
    assert detail["history"][0]["actor_role"] == "monitor"
    with Session(engine) as session:
        assert "mentor_id" not in session.scalar(select(MentorshipRevision)).snapshot
    assert case_patch(client, created["id"], mentor_id="teacher", status="in_progress").status_code == 200
