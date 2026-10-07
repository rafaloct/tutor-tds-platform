"""Synthetic end-to-end commands against the actual API and persistence."""
from dataclasses import replace
from uuid import uuid4

import pytest
from sqlalchemy import select, text
from sqlalchemy.orm import Session

from app.models import (ClassEnrollment, Classroom, CohortMembership, Enrollment,
                        OperatorCommandReceipt, ProgramMembership, User)
from test_certificate_requests import requests_api, header, ORIGINAL


@pytest.fixture
def operator_api(requests_api):
    client, engine = requests_api
    client.app.state.settings = replace(client.app.state.settings, operator_operations_enabled=True)
    with Session(engine) as session:
        session.get(ProgramMembership, ("coordinator", "p1")).role = "program_operator"
        for class_id in ("c1", "c2"):
            session.get(Classroom, class_id).status = "active"
        session.commit()
    return client, engine


def command(client, action, person="other", revision=0, class_id="c1", **overrides):
    body = dict(id=str(uuid4()), action=action, reason="Conferência sintética autorizada",
                institution_id="i1", program_id="p1", course_id="course",
                version_id=ORIGINAL if class_id == "c1" else "v2",
                person_id=person, expected_revision=revision)
    body.update(overrides)
    return client.post(f"/operations/{class_id}/commands", headers=header("coordinator"), json=body), body


def test_canonical_program_operator_grant_unlocks_scoped_operations(requests_api):
    client, engine = requests_api
    client.app.state.settings = replace(
        client.app.state.settings,
        operator_operations_enabled=True,
    )

    denied = client.post(
        "/operations/c1/search",
        headers=header("admin"),
        json={"query": "Name"},
    )
    assert denied.status_code == 403

    granted = client.post(
        "/admin/programs/p1/memberships",
        headers=header("admin"),
        json={"user_id": "admin", "role": "program_operator"},
    )
    assert granted.status_code == 201
    assert granted.json()["role"] == "program_operator"

    scopes = client.get("/operations/scopes", headers=header("admin"))
    assert scopes.status_code == 200
    assert {row["class_id"] for row in scopes.json()["scopes"]} == {"c1", "c2"}

    allowed = client.post(
        "/operations/c1/search",
        headers=header("admin"),
        json={"query": "Name"},
    )
    assert allowed.status_code == 200

    with Session(engine) as session:
        membership = session.get(ProgramMembership, ("admin", "p1"))
        assert membership is not None
        assert membership.role == "program_operator"
        assert membership.status == "active"


def test_scoped_search_and_global_admin_does_not_bypass(operator_api):
    client, _ = operator_api
    contexts = client.get("/operations/scopes", headers=header("coordinator")).json()["scopes"]
    assert {row["class_id"] for row in contexts} == {"c1", "c2"}
    for actor in ("admin", "teacher", "outsider", "learner"):
        response = client.post("/operations/c1/search", headers=header(actor), json={"query": "Name"})
        assert response.status_code == 403
    response = client.post("/operations/foreign-class/search", headers=header("coordinator"), json={"query": "Name"})
    assert response.status_code == 403
    assert client.post("/operations/c1/inspect", headers=header("coordinator"), json={"person_id": "outsider"}).status_code == 403


def test_registration_enrollment_assignment_and_correction_preserve_identity(operator_api):
    client, engine = operator_api
    registration = dict(name="Synthetic New Person", cpf="12345678909", phone="61999990000", password="synthetic-password-2026")
    created, body = command(client, "register", person=None, registration=registration)
    assert created.status_code == 200, created.text
    person = created.json()["person"]["id"]
    replay = client.post("/operations/c1/commands", headers=header("coordinator"), json=body)
    assert replay.json() == created.json()
    enrolled, _ = command(client, "enroll", person=person, revision=1)
    assert enrolled.status_code == 200, enrolled.text
    linked, _ = command(client, "assign", person=person, revision=2)
    assert linked.status_code == 200, linked.text
    assert linked.json()["assigned"] and not linked.json()["baseline_linked"]
    revoked, _ = command(client, "revoke", person=person, revision=3)
    assert revoked.status_code == 200, revoked.text
    assert not revoked.json()["assigned"] and revoked.json()["enrolled"]
    moved, _ = command(client, "assign", person=person, revision=4, class_id="c2")
    assert moved.status_code == 200, moved.text
    assert moved.json()["scope"]["version_id"] == "v2"
    with Session(engine) as session:
        assert session.get(ClassEnrollment, ("c1", person)).status == "inactive"
        assert session.get(ClassEnrollment, ("c2", person)).status == "active"
        assert len(session.scalars(select(Enrollment).where(Enrollment.user_id == person)).all()) == 1
        receipts = session.scalars(select(OperatorCommandReceipt).where(OperatorCommandReceipt.subject_id == person)).all()
        assert len(receipts) == 5
        assert registration["password"] not in str([row.result for row in receipts])
        assert registration["cpf"] not in str([row.result for row in receipts])
        assert session.get(User, person).role == "student"


def test_divergent_replay_stale_revision_and_foreign_scope_fail(operator_api):
    client, engine = operator_api
    first, body = command(client, "assign")
    assert first.status_code == 200, first.text
    divergent = body | {"reason": "Outro motivo"}
    assert client.post("/operations/c1/commands", headers=header("coordinator"), json=divergent).status_code == 409
    stale, _ = command(client, "revoke", revision=0)
    assert stale.status_code == 409
    foreign, _ = command(client, "revoke", revision=1, institution_id="i2")
    assert foreign.status_code == 409
    with Session(engine) as session:
        assert len(session.scalars(select(OperatorCommandReceipt)).all()) == 1
        assert session.get(ClassEnrollment, ("c1", "other")).status == "active"


def test_revoked_operator_cannot_replay_previously_successful_command(operator_api):
    client, engine = operator_api
    first, body = command(client, "assign")
    assert first.status_code == 200
    with Session(engine) as session:
        session.get(ProgramMembership, ("coordinator", "p1")).status = "inactive"
        session.commit()
    assert client.post("/operations/c1/commands", headers=header("coordinator"), json=body).status_code == 403


def test_closed_class_allows_authorized_receipt_replay_but_no_new_command(operator_api):
    client, engine = operator_api
    first, body = command(client, "assign")
    assert first.status_code == 200
    with Session(engine) as session:
        session.get(Classroom, "c1").status = "closed"
        session.commit()
    replay = client.post("/operations/c1/commands", headers=header("coordinator"), json=body)
    assert replay.status_code == 200
    assert replay.json() == first.json()
    fresh, _ = command(client, "revoke", revision=1)
    assert fresh.status_code == 409


def test_account_erasure_removes_subject_receipts_and_anonymizes_actor(operator_api):
    client, engine = operator_api
    first, _ = command(client, "assign")
    assert first.status_code == 200
    with Session(engine) as session:
        receipt = session.scalar(select(OperatorCommandReceipt))
        assert "coordinator" not in str(receipt.result)
        session.get(ProgramMembership, ("coordinator", "p1")).status = "inactive"
        session.commit()
    assert client.delete("/auth/me", headers=header("coordinator")).status_code == 204
    with Session(engine) as session:
        receipt = session.scalar(select(OperatorCommandReceipt))
        assert receipt.actor_id is None
        assert "coordinator" not in str(receipt.result)
    assert client.delete("/auth/me", headers=header("other")).status_code == 204
    with Session(engine) as session:
        assert session.scalar(select(OperatorCommandReceipt)) is None


def test_sqlite_erasure_also_works_without_foreign_key_cascades(operator_api):
    _, engine = operator_api
    with engine.connect() as conn:
        conn.execute(text('PRAGMA foreign_keys=OFF'))
        assert conn.scalar(text('PRAGMA foreign_keys')) == 0
    test_account_erasure_removes_subject_receipts_and_anonymizes_actor(operator_api)


def test_exact_identity_lookup_can_link_existing_person_without_duplicate(operator_api):
    client, engine = operator_api
    created = client.post("/auth/register", json=dict(name="Synthetic Outside", cpf="12345678909",
        phone="61999990000", password="synthetic-password-2026"))
    assert created.status_code == 201, created.text
    person = created.json()["user"]["id"]
    assert client.post("/operations/c1/search", headers=header("coordinator"), json={"query": "Synthetic Outside"}).json()["people"] == []
    found = client.post("/operations/c1/search", headers=header("coordinator"), json={"query": "12345678909"})
    assert found.status_code == 200
    proof = found.json()["people"][0]["identity_proof"]
    denied, _ = command(client, "enroll", person=person)
    assert denied.status_code == 403
    enrolled, _ = command(client, "enroll", person=person, identity_proof=proof)
    assert enrolled.status_code == 200, enrolled.text
    assert enrolled.json()["enrolled"]


def test_feature_disabled_and_duplicate_identity_never_write_partial_membership(operator_api):
    client, engine = operator_api
    registration = dict(name="Synthetic", cpf="12345678909", phone="61999990000", password="synthetic-password-2026")
    first, _ = command(client, "register", person=None, registration=registration)
    assert first.status_code == 200
    duplicate, _ = command(client, "register", person=None, registration=registration)
    assert duplicate.status_code == 409
    with Session(engine) as session:
        assert session.scalar(select(text("count(*)")).select_from(OperatorCommandReceipt)) == 1
    client.app.state.settings = replace(client.app.state.settings, operator_operations_enabled=False)
    assert client.get("/operations/scopes", headers=header("coordinator")).status_code == 404


def test_sqlite_migration_preserves_existing_data_and_rejects_populated_downgrade(operator_api):
    from test_operator_postgres import test_postgres_migration_and_populated_rollback_guard
    test_postgres_migration_and_populated_rollback_guard(operator_api)
