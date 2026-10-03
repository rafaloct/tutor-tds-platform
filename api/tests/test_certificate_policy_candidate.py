"""Authorized offering rules; actual API/Worker, external network/KV simulated."""
from dataclasses import replace
from datetime import datetime, timezone
import hashlib

import pytest
from sqlalchemy import select, text
from sqlalchemy.orm import Session

from app.certificate_transport import canonical
from app.models import (AssessmentAttemptRecord, AssessmentContentRecord, CertificateEmissionAttempt,
    CertificateReference, ClassEnrollment, ClassSession, CohortMembership, EvidenceItem,
    LearningEventRecord, ProgramMembership, ReviewDecision, StudentBaseline)
from test_certificate_requests import requests_api, header, create, ORIGINAL
from test_certificate_emission_candidate import WorkerExchange, SECRET


@pytest.fixture
def institutional(requests_api):
    client, engine = requests_api
    exchange = WorkerExchange()
    client.app.state.settings = replace(client.app.state.settings, certificate_candidate_enabled=True,
        certificate_candidate_url="http://127.0.0.1:9090", certificate_candidate_secret=SECRET)
    client.app.state.certificate_candidate_exchange = exchange
    with Session(engine) as session:
        session.add(CohortMembership(id="synthetic-membership", class_id="c1", user_id="learner", role="student", status="active"))
        session.flush()
        link = session.get(ClassEnrollment, ("c1", "learner"))
        link.context_id, link.membership_id, link.course_version_id = "synthetic-context", "synthetic-membership", ORIGINAL
        for index in range(10):
            session.add(ClassSession(id=f"meeting-{index}", class_id="c1", starts_at=datetime(2026, 1, 1, tzinfo=timezone.utc),
                ends_at=datetime(2027, 12, 1, tzinfo=timezone.utc), status="open", opened_by="teacher",
                checkin_token_digest="a" * 64, token_expires_at=datetime(2027, 12, 1, tzinfo=timezone.utc)))
        for index in range(2):
            source = {"questions": [{"question": "Synthetic required checkpoint", "options": ["A", "B"], "topic": "synthetic"}],
                "answer_key": [{"correct_index": 0, "explanation": "Synthetic answer"}]}
            session.add(AssessmentContentRecord(id=f"source-{index}", owner_id="coordinator", course_id="course",
                topic="synthetic", mode="quiz", title="Synthetic source", duration_seconds=0,
                questions=source["questions"], answer_key=source["answer_key"], content_digest=hashlib.sha256(canonical(source)).hexdigest()))
        session.commit()
    policy = {"course_version_id": ORIGINAL, "formal_hours": 80, "session_ids": [f"meeting-{index}" for index in range(10)],
        "checkpoints": [{"id": f"checkpoint-{index}", "kind": "assessment", "source_id": f"source-{index}"} for index in range(2)],
        "operational_owner_id": "coordinator"}
    configured = client.put("/classes/c1/certificate-policy-candidate", json=policy, headers=header("coordinator"))
    assert configured.status_code == 200, configured.text
    pending = create(client, classroom="c1").json()
    assert pending["status"] == "pending" and pending["eligibility"]["eligible"] is False
    return client, engine, exchange, pending["id"], policy


def status(data, actor="learner"):
    return data[0].get(f"/certificate-requests/{data[3]}/candidate-status", headers=header(actor))


def checkpoint(data, index, answers=None, actor="learner"):
    return data[0].post(f"/certificate-requests/{data[3]}/candidate-checkpoints/checkpoint-{index}",
        headers=header(actor), json={"answers": {"0": 0} if answers is None else answers})


def generate(data):
    assert checkpoint(data, 0).status_code == 200
    result = checkpoint(data, 1)
    assert result.status_code == 200, result.text
    assert result.json()["generation"]["state"] == "candidate_confirmed"
    return result


def document(data, kind="baseline", actor="teacher", origin="google_forms", sessions=None):
    return data[0].post(f"/certificate-requests/{data[3]}/candidate-evidence", headers=header(actor), json={
        "kind": kind, "origin": origin, "document_reference": f"synthetic-private:{kind}:{origin}:{sessions}",
        "document_digest": "b" * 64, "reason": "Registro documental sintético conferido pelo responsável",
        "session_ids": sessions or [],
    })


def presence(data, count, *, remaining="absent"):
    for index in range(10):
        result = data[0].post(f"/classes/c1/sessions/meeting-{index}/presence/learner", headers=header("teacher"), json={
            "status": "confirmed_present" if index < count else remaining, "expected_revision": 0,
            "reason": "Frequência sintética conferida", "idempotency_key": f"synthetic-presence-{index}",
        })
        assert result.status_code == 200, result.text


def transition(data, action, expected, actor="learner", **extra):
    return data[0].post(f"/certificate-requests/{data[3]}/candidate-lifecycle", headers=header(actor),
        json={"action": action, "expected_state": expected, **extra})


def test_last_required_checkpoint_automatically_generates_before_baseline_hours_presence_signatures(institutional):
    client, engine, exchange, request_id, _ = institutional
    first = checkpoint(institutional, 0)
    assert first.status_code == 200 and "generation" not in first.json()
    assert not exchange.calls
    assert status(institutional).json()["trail_complete"] is False
    second = checkpoint(institutional, 1)
    assert second.status_code == 200, second.text
    command = second.json()["generation"]["context"]
    assert command["protocol"] == "certificate-candidate-v2" and command["formal_hours"] == 80
    assert command["baseline_id"] is None and command["baseline_revision"] == 0
    assert command["required_seconds"] == 288000
    snapshot = status(institutional).json()
    assert snapshot["lifecycle_state"] == "GENERATED" and snapshot["trail_certificate_generated"] is True
    assert snapshot["capacitado"] is False and snapshot["certificate_valid"] is False
    assert snapshot["baseline_registered"] is False and snapshot["confirmed_presence"] == 0
    assert exchange.calls == ["GET", "POST"] and exchange.writes == 1
    assert checkpoint(institutional, 1).status_code == 200
    assert exchange.calls.count("POST") == 1
    with Session(engine) as session:
        assert not session.scalars(select(LearningEventRecord)).all()
        assert not session.scalars(select(StudentBaseline)).all()
        reference = session.scalar(select(CertificateReference))
        assert reference.planned_seconds == 288000 and reference.is_candidate
        dispatch = session.scalar(select(EvidenceItem).where(EvidenceItem.evidence_type == "certificate_dispatch"))
        assert dispatch.metadata_json["state"] == "pending_dispatch" and dispatch.metadata_json["target_email"] == "tdsdados@gmail.com"
        assert dispatch.metadata_json["sent"] is False and dispatch.metadata_json["delivery_receipt"] is None
        assert len(session.scalars(select(EvidenceItem).where(EvidenceItem.evidence_type == "certificate_dispatch")).all()) == 1
    assert client.get("/certificates", headers=header("learner")).json() == {"certificates": []}


def test_capacitado_is_separate_and_full_document_signatures_lead_to_candidate_valid(institutional):
    generate(institutional)
    assert document(institutional).status_code == 200
    presence(institutional, 7)
    snapshot = status(institutional).json()
    assert snapshot["attendance_70_percent"] and snapshot["capacitado"] and not snapshot["certificate_valid"]
    assert transition(institutional, "submit", "GENERATED").json()["lifecycle_state"] == "PENDING_INSTRUCTOR_VALIDATION"
    assert transition(institutional, "instructor_validate", "PENDING_INSTRUCTOR_VALIDATION", "learner").status_code == 403
    assert document(institutional, "attendance_sheet", sessions=[f"meeting-{i}" for i in range(6)]).status_code == 200
    assert not status(institutional).json()["instructor_sheets_signed"]
    assert transition(institutional, "instructor_validate", "PENDING_INSTRUCTOR_VALIDATION", "teacher").status_code == 422
    assert document(institutional, "attendance_sheet", sessions=[f"meeting-{i}" for i in range(6, 10)]).status_code == 200
    assert transition(institutional, "instructor_validate", "PENDING_INSTRUCTOR_VALIDATION", "teacher").json()["lifecycle_state"] == "PENDING_COORDINATOR_SIGNATURE"
    assert transition(institutional, "coordinator_sign", "PENDING_COORDINATOR_SIGNATURE", "admin", document_reference="synthetic-signature", document_digest="c" * 64).status_code == 403
    signed = transition(institutional, "coordinator_sign", "PENDING_COORDINATOR_SIGNATURE", "coordinator", document_reference="synthetic-signature", document_digest="c" * 64)
    assert signed.status_code == 200, signed.text
    value = signed.json()
    assert value["lifecycle_state"] == "VALID" and value["capacitado"] and value["certificate_valid"]
    assert value["activation"] == "synthetic_candidate_only" and value["institutional_release"] == "blocked"
    assert institutional[0].post(f"/certificate-requests/{institutional[3]}/emit", headers=header("learner")).status_code == 503


def test_six_of_ten_and_justified_absence_or_accepted_exception_do_not_fabricate_presence(institutional):
    generate(institutional)
    document(institutional)
    presence(institutional, 6, remaining="justified_absence")
    exception = document(institutional, "attendance_exception", origin="human_exception")
    assert exception.status_code == 200 and exception.json()["status"] == "pending_human_validation"
    value = status(institutional).json()
    assert value["confirmed_presence"] == 6 and value["configured_meetings"] == 10
    assert not value["attendance_70_percent"] and not value["capacitado"]
    assert value["exceptions_state"] == "pending_human_validation"
    decision = institutional[0].post(f"/classes/c1/evidence/{exception.json()['evidence_id']}/review",
        headers=header("teacher"), json={"decision": "accepted", "reason_code": "verified"})
    assert decision.status_code == 200
    value = status(institutional).json()
    assert value["exceptions_state"] is None and value["confirmed_presence"] == 6 and not value["capacitado"]


@pytest.mark.parametrize("origin", ["google_forms", "jotform", "app", "physical_scan"])
def test_baseline_any_origin_uses_existing_evidence_record_and_owner_scope(institutional, origin):
    registered = document(institutional, origin=origin)
    assert registered.status_code == 200 and registered.json()["origin"] == origin
    assert registered.json()["external_document_read"] is False
    assert status(institutional).json()["baseline_registered"] is True
    assert status(institutional, "other").status_code == 404
    assert document(institutional, actor="learner").status_code == 403


@pytest.mark.parametrize("answers", [{}, {"0": True}, {"0": "0"}, {"0": 9}, {"0": 0, "1": 0}])
def test_checkpoints_require_all_deterministic_answers_and_never_client_completion_flag(institutional, answers):
    assert checkpoint(institutional, 0, answers).status_code == 422
    assert not institutional[2].calls
    assert status(institutional).json()["completed_checkpoints"] == 0


def test_wrong_context_unsupported_types_and_frozen_denominator(institutional):
    client, engine, exchange, request_id, policy = institutional
    assert checkpoint(institutional, 0, actor="other").status_code == 404
    assert client.post(f"/certificate-requests/{request_id}/candidate-checkpoints/unconfigured", headers=header("learner"), json={"answers": {"0": 0}}).status_code == 422
    assert client.put("/classes/c1/certificate-policy-candidate", headers=header("coordinator"), json=policy | {"session_ids": []}).status_code == 422
    assert client.put("/classes/c1/certificate-policy-candidate", headers=header("coordinator"), json=policy | {"session_ids": policy["session_ids"][:7]}).status_code == 409
    assert client.put("/classes/c1/certificate-policy-candidate", headers=header("coordinator"), json=policy | {"checkpoints": [{"id": "future", "kind": "unsupported_agent_output", "source_id": "source-0"}]}).status_code == 422
    assert not exchange.calls


def test_lost_automatic_generation_response_reconciles_without_resend_after_baseline_added(institutional):
    assert checkpoint(institutional, 0).status_code == 200
    institutional[2].lose_post_response = True
    assert checkpoint(institutional, 1).status_code == 503
    assert document(institutional).status_code == 200
    assert checkpoint(institutional, 1).status_code == 200
    assert institutional[2].calls.count("POST") == 1 and institutional[2].writes == 1
    assert status(institutional).json()["trail_certificate_generated"]


def test_policy_and_lifecycle_downgrade_refuses_data_loss_and_account_erasure_cleans_new_evidence(institutional):
    from alembic import command
    from alembic.config import Config
    generate(institutional)
    document(institutional)
    client, engine, _, _, _ = institutional
    config = Config("alembic.ini")
    config.set_main_option("sqlalchemy.url", str(engine.url))
    with pytest.raises(RuntimeError, match="Preserve configured policy"):
        command.downgrade(config, "20261003_0021")
    # Empty later revisions can downgrade before the policy guard refuses;
    # restore the current schema before invoking its runtime.
    command.upgrade(config, "head")
    assert client.delete("/auth/me", headers=header("learner")).status_code == 204
    with Session(engine) as session:
        assert not session.scalars(select(EvidenceItem).where(EvidenceItem.user_id == "learner")).all()
        assert not session.scalars(select(CertificateEmissionAttempt)).all()
        assert not session.scalars(select(CertificateReference)).all()
        assert not session.scalars(select(AssessmentAttemptRecord).where(AssessmentAttemptRecord.owner_id == "learner")).all()


@pytest.mark.parametrize("reference", ["https://synthetic.invalid/document", "private:\nunsafe"])
def test_signature_reference_rejects_public_or_control_character_documents(institutional, reference):
    result = transition(institutional, "coordinator_sign", "PENDING_COORDINATOR_SIGNATURE", "coordinator",
        document_reference=reference, document_digest="c" * 64)
    assert result.status_code == 422
    assert not institutional[2].calls


def test_draft_edition_cannot_configure_policy(institutional):
    from app.models import Classroom
    with Session(institutional[1]) as session:
        original = session.get(Classroom, "c1")
        session.add(Classroom(id="draft-class", program_id="p1", course_id="course",
            course_version_id="draft", teacher_id="teacher", name="Synthetic draft offering",
            start_date=original.start_date, end_date=original.end_date, status="closed"))
        session.commit()
    result = institutional[0].put("/classes/draft-class/certificate-policy-candidate",
        headers=header("coordinator"), json=institutional[4] | {"course_version_id": "draft"})
    assert result.status_code == 422
    assert not institutional[2].calls



def test_rejected_policy_request_blocks_all_actions_without_network_or_evidence(institutional):
    from test_certificate_requests import review
    current = institutional[0].get(f"/certificate-requests/{institutional[3]}", headers=header("learner")).json()
    rejected = review(institutional[0], current, user="teacher", decision="reject")
    assert rejected.status_code == 200
    assert checkpoint(institutional, 0).status_code == 422
    assert document(institutional).status_code == 422
    assert transition(institutional, "submit", "GENERATED").status_code == 422
    assert institutional[0].post(f"/certificate-requests/{institutional[3]}/emission-candidate", headers=header("learner")).status_code == 422
    assert not institutional[2].calls
    with Session(institutional[1]) as session:
        assert not session.scalars(select(EvidenceItem)).all()
        assert not session.scalars(select(CertificateEmissionAttempt)).all()


@pytest.mark.parametrize("target", ["membership", "operator"])
def test_policy_revocation_blocks_generation(target, institutional):
    assert checkpoint(institutional, 0).status_code == 200
    if target == "membership":
        with Session(institutional[1]) as session:
            session.get(CohortMembership, "synthetic-membership").status = "inactive"
            session.commit()
        assert checkpoint(institutional, 1).status_code in {403, 404, 422}
    else:
        with Session(institutional[1]) as session:
            session.get(ProgramMembership, ("coordinator", "p1")).status = "revoked"
            session.commit()
        assert checkpoint(institutional, 1).status_code == 422
    assert not institutional[2].calls
    with Session(institutional[1]) as session:
        assert not session.scalars(select(CertificateEmissionAttempt)).all()
        assert not session.scalars(select(CertificateReference)).all()



def test_accepted_metadata_without_canonical_backend_attempt_does_not_complete_trail(institutional):
    from app.certificate_policy import evidence_record, policy_for, contextual_request
    from app.models import CertificateRequest
    with Session(institutional[1]) as session:
        record, _, context = contextual_request(session, institutional[3], "learner")
        policy = policy_for(session, record)
        for item in policy["checkpoints"]:
            evidence_record(session, record, context, policy, "trail_checkpoint", "teacher",
                {"checkpoint_id": item["id"], "source_digest": item["source_digest"],
                 "validation_mode": "backend_deterministic", "attempt_id": "unbound-historical-attempt"},
                "unbound-historical-attempt", "d" * 64)
        session.commit()
    assert status(institutional).json()["completed_checkpoints"] == 0
    assert institutional[0].post(f"/certificate-requests/{institutional[3]}/emission-candidate", headers=header("learner")).status_code == 422
    assert not institutional[2].calls
