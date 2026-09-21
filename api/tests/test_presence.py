from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timezone
from uuid import uuid4

import pytest
from sqlalchemy import delete, func, select, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.models import ClassEnrollment, ClassMonitor, ClassSession, Enrollment, EvidenceItem, ProgramMembership, SessionPresence, SessionPresenceDecision, SessionReport, User
from test_certificate_requests import header, requests_api


@pytest.fixture
def presence_api(requests_api):
    client, engine = requests_api
    with Session(engine) as session:
        session.add(ClassMonitor(class_id="c1", user_id="monitor", program_id="p1"))
        session.add(ClassEnrollment(class_id="c1", user_id="other", enrollment_id="other-e", program_id="p1", course_id="course", status="active"))
        for identity, classroom in (("s1", "c1"), ("s2", "c2")):
            session.add(ClassSession(id=identity, class_id=classroom, starts_at=datetime(2026, 1, 1, tzinfo=timezone.utc), ends_at=datetime(2027, 12, 1, tzinfo=timezone.utc), status="open", opened_by="teacher", checkin_token_digest="a" * 64, token_expires_at=datetime(2027, 12, 1, tzinfo=timezone.utc)))
        session.commit()
    yield client, engine


def roster(client, actor="teacher", suffix=""):
    return client.get(f"/classes/c1/sessions/s1/presence{suffix}", headers=header(actor))


def decide(client, *, actor="teacher", user="learner", revision=0, status="confirmed_present", reason="Observado pela equipe", key="presence-decision-1"):
    return client.post(f"/classes/c1/sessions/s1/presence/{user}", headers=header(actor), json={"status": status, "expected_revision": revision, "reason": reason, "idempotency_key": key})


def close(client, *, confirm=False):
    return client.post(f"/classes/c1/sessions/s1/close?confirm_pending={'true' if confirm else 'false'}", headers=header("teacher"))


def activity(engine, *, identity=None, user="learner", session_id="s1", status="pending", kind="activity"):
    with Session(engine) as session:
        identity = identity or str(uuid4())
        session.add(EvidenceItem(id=identity, class_id="c1", session_id=session_id, user_id=user, evidence_type=kind, occurred_at=datetime.now(timezone.utc), review_status=status, item_digest=uuid4().hex * 2, metadata_json={}))
        session.commit()


def test_roster_is_paginated_scoped_and_never_auto_confirms(presence_api):
    client, engine = presence_api
    initial = roster(client).json()
    assert initial["total"] == 2 and initial["session_status"] == "open"
    assert all(item["status"] == "pending" and item["revision"] == 0 and item["decided_at"] is None for item in initial["items"])
    assert roster(client, "monitor").status_code == 200
    for actor in ("learner", "outsider", "teacher2", "coordinator"):
        assert roster(client, actor).status_code == 403
    assert client.get("/classes/c1/sessions/s2/presence", headers=header("teacher")).status_code == 404
    page = roster(client, suffix="?limit=1&offset=1").json()
    assert page["total"] == 2 and page["limit"] == page["offset"] == 1
    assert len(page["items"]) == 1
    assert roster(client, suffix="?limit=101").status_code == 422
    activity(engine, status="accepted")
    activity(engine, status="rejected")
    activity(engine, session_id=None)
    activity(engine, session_id="s2")
    activity(engine, kind="observation")
    for kind in ("checkin", "checkout"):
        response = client.post("/classes/c1/sessions/s1/checkins", headers=header("teacher"), json={"kind": kind, "user_id": "learner", "idempotency_key": f"presence-test-{kind}"})
        assert response.status_code == 201, response.text
    items = {item["user_id"]: item for item in roster(client).json()["items"]}
    assert items["learner"]["status"] == "suggested_present"
    assert items["learner"]["activity_count"] == items["learner"]["checkin_count"] == items["learner"]["checkout_count"] == 1
    assert items["other"]["status"] == "pending"
    with Session(engine) as session:
        assert session.scalar(select(func.count()).select_from(SessionPresence)) == 0


def test_human_decisions_cas_exact_replay_and_snapshot(presence_api):
    client, engine = presence_api
    first = decide(client, status="absent", reason="  Ausência conferida  ")
    assert first.status_code == 200, first.text
    assert first.json()["reason"] == "Ausência conferida"
    assert first.json()["status"] == "absent" and first.json()["revision"] == 1
    assert datetime.fromisoformat(first.json()["decided_at"].replace("Z", "+00:00")).utcoffset().total_seconds() == 0
    assert decide(client, actor="monitor", revision=1, status="justified_absence", key="correction-key").status_code == 200
    activity(engine)
    with Session(engine) as session:
        session.get(User, "learner").name = "Changed name"
        session.commit()
    retry = decide(client, status="absent", reason="Ausência conferida")
    assert retry.json() == first.json()
    assert decide(client, key="stale-revision").status_code == 409
    assert decide(client, actor="monitor", status="absent", reason="Ausência conferida").status_code == 409
    assert decide(client, status="absent", reason="Razão diferente").status_code == 409
    current = next(item for item in roster(client).json()["items"] if item["user_id"] == "learner")
    assert current["status"] == "justified_absence" and current["revision"] == 2
    assert current["user_name"] == "Name learner"
    with Session(engine) as session:
        history = session.scalars(select(SessionPresenceDecision).order_by(SessionPresenceDecision.revision)).all()
        assert [item.status for item in history] == ["absent", "justified_absence"]
        assert [item.actor_role for item in history] == ["teacher", "monitor"]


@pytest.mark.parametrize("target", ["staff", "membership", "enrollment", "class"])
def test_revocation_blocks_new_decisions_and_retries(presence_api, target):
    client, engine = presence_api
    assert decide(client).status_code == 200
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
    assert decide(client).status_code == 403
    assert decide(client, revision=1, key="new-decision-revoked").status_code == 403
    if target != "staff":
        assert roster(client).json()["total"] == 1


def test_invalid_self_foreign_and_student_decisions(presence_api):
    client, engine = presence_api
    for actor in ("learner", "outsider", "teacher2"):
        assert decide(client, actor=actor).status_code == 403
    assert decide(client, user="teacher").status_code == 403
    assert decide(client, user="outsider").status_code == 403
    assert decide(client, status="suggested_present").status_code == 422
    assert decide(client, reason="  ").status_code == 422
    assert decide(client, reason="a" * 501).status_code == 422
    assert decide(client, revision=-1).status_code == 422
    assert decide(client, key="short").status_code == 422
    # Corruption cannot let a class link borrow another student's enrollment.
    with engine.connect() as connection:
        connection.exec_driver_sql("PRAGMA foreign_keys=OFF")
        connection.execute(text("UPDATE class_enrollments SET enrollment_id = 'other-e' WHERE user_id = 'learner' AND class_id = 'c1'"))
        connection.commit()
    assert decide(client).status_code == 403
    assert roster(client).json()["total"] == 1


def test_close_requires_explicit_pending_without_qr_and_preserves_report(presence_api):
    client, engine = presence_api
    assert close(client).status_code == 409
    closed = close(client, confirm=True)
    assert closed.status_code == 200
    summary = closed.json()["summary"]
    assert summary["presence"]["total"] == summary["presence"]["pending_count"] == 2
    assert summary["presence"]["counts"]["pending"] == 2
    assert summary["pending_explicitly_confirmed"] is True
    assert decide(client).status_code == 409
    assert roster(client).json()["session_status"] == "closed"
    with Session(engine) as session:
        session.get(ClassEnrollment, ("c1", "other")).status = "inactive"
        session.commit()
    assert close(client).json() == closed.json()


def test_closed_session_allows_only_authorized_exact_retry(presence_api):
    client, engine = presence_api
    first = decide(client)
    assert decide(client, user="other", status="absent", key="absent-other-key").status_code == 200
    report = close(client)
    assert report.status_code == 200, report.text
    assert report.json()["summary"]["presence"]["counts"]["absent"] == 1
    assert report.json()["summary"]["presence"]["pending_count"] == 0
    assert decide(client).json() == first.json()
    assert decide(client, revision=1, key="cannot-edit-after-close").status_code == 409
    with Session(engine) as session:
        session.get(ProgramMembership, ("teacher", "p1")).status = "inactive"
        session.commit()
    assert decide(client).status_code == 403


def test_existing_legacy_report_is_returned_without_new_presence_summary(presence_api):
    client, engine = presence_api
    with Session(engine) as session:
        session.get(ClassSession, "s1").status = "closed"
        session.add(SessionReport(id="legacy-report", class_id="c1", session_id="s1", generated_by="teacher", generated_at=datetime.now(timezone.utc), report_digest="d" * 64, summary={"checkin_count": 0, "external_integrations": "disabled"}))
        session.commit()
    response = close(client)
    assert response.status_code == 200
    assert response.json()["id"] == "legacy-report"
    assert response.json()["summary"] == {"checkin_count": 0, "external_integrations": "disabled"}
    with Session(engine) as session:
        assert session.scalar(select(func.count()).select_from(SessionPresence)) == 0


def test_migration_guards_history_association_and_revision(presence_api):
    client, engine = presence_api
    assert decide(client).status_code == 200
    for statement in (
        "UPDATE session_presence SET user_name = 'Tampered', revision = 2",
        "UPDATE session_presence SET revision = 3",
        "UPDATE session_presence SET class_id = 'c2', revision = 2",
        "UPDATE session_presence_decisions SET reason = 'Rewritten'",
        "DELETE FROM session_presence_decisions",
    ):
        with pytest.raises(IntegrityError), engine.begin() as connection:
            connection.execute(text(statement))
    assert close(client, confirm=True).status_code == 200
    with pytest.raises(IntegrityError), engine.begin() as connection:
        connection.execute(text("UPDATE session_presence SET revision = 2, status = 'absent'"))


@pytest.mark.parametrize("same_key", [False, True])
def test_concurrent_decisions_are_atomic_and_idempotent(presence_api, same_key):
    client, engine = presence_api
    with ThreadPoolExecutor(max_workers=2) as pool:
        responses = list(pool.map(lambda i: decide(client, key="same-decision-key" if same_key else f"competing-key-{i}"), range(2)))
    assert sorted(response.status_code for response in responses) == ([200, 200] if same_key else [200, 409])
    with Session(engine) as session:
        assert session.scalar(select(func.count()).select_from(SessionPresenceDecision)) == 1
        assert session.scalar(select(SessionPresence.revision)) == 1


def test_concurrent_close_and_decision_report_agree(presence_api):
    client, engine = presence_api
    with ThreadPoolExecutor(max_workers=2) as pool:
        decision = pool.submit(decide, client)
        closed = pool.submit(close, client, confirm=True)
        decision_response, report_response = decision.result(), closed.result()
    assert decision_response.status_code in {200, 409}
    assert report_response.status_code == 200
    with Session(engine) as session:
        actual = session.scalar(select(func.count()).select_from(SessionPresence))
    assert report_response.json()["summary"]["presence"]["counts"]["confirmed_present"] == actual


@pytest.mark.parametrize("foreign_keys_enabled", [True, False])
def test_owner_erasure_removes_private_presence_history(presence_api, foreign_keys_enabled):
    client, engine = presence_api
    assert decide(client, reason="Motivo privado do estudante").status_code == 200
    if not foreign_keys_enabled:
        with engine.connect() as connection:
            connection.exec_driver_sql("PRAGMA foreign_keys=OFF")
    response = client.delete("/auth/me")
    assert response.status_code == 204, response.text
    with Session(engine) as session:
        assert session.get(User, "learner") is None
        assert session.scalars(select(SessionPresence)).all() == []
        assert session.scalars(select(SessionPresenceDecision)).all() == []


def test_departed_actor_is_anonymized_but_history_retained(presence_api):
    client, engine = presence_api
    assert decide(client, actor="monitor").status_code == 200
    with Session(engine) as session:
        session.execute(delete(ClassMonitor).where(ClassMonitor.user_id == "monitor"))
        session.get(ProgramMembership, ("monitor", "p1")).status = "inactive"
        session.commit()
    response = client.delete("/auth/me", headers=header("monitor"))
    assert response.status_code == 204, response.text
    with Session(engine) as session:
        decision = session.scalar(select(SessionPresenceDecision))
        assert decision.actor_user_id is None and decision.actor_role == "monitor"
        assert decision.status == "confirmed_present" and decision.revision == 1
