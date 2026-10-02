from dataclasses import replace
from datetime import datetime, timezone

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import BaselineSourceRecord, CertificateReference, ClassEnrollment, StudentBaseline
from test_certificate_requests import header, requests_api
from test_presence import presence_api
from test_student_followup import baseline, baseline_get


def enable(client):
    client.app.state.settings = replace(client.app.state.settings,
        journey_traceability_enabled=True, sheets_pseudonym_secret="s" * 32)


def test_flag_preserves_legacy_and_explicit_bi_identity(presence_api):
    client, engine = presence_api
    assert baseline(client).status_code == 200
    assert baseline(client, revision=1, key="disabled-bi-key", bi_record_id="DIG-0001").status_code == 404
    enable(client)
    linked = baseline(client, revision=1, key="link-bi-key", bi_record_id="DIG-0001")
    assert linked.status_code == 200, linked.text
    assert linked.json()["bi_record_id"] == "DIG-0001"
    assert baseline(client, revision=1, key="link-bi-key", bi_record_id="DIG-0001").json() == linked.json()
    assert baseline(client, revision=2, key="legacy-update-key").status_code == 200
    assert baseline_get(client).json()["baseline"]["bi_record_id"] == "DIG-0001"
    assert baseline(client, user="other", record="tablet-other", key="bi-other-person-key", bi_record_id="DIG-0001").status_code == 409
    assert baseline(client, actor="teacher2", classroom="c2", key="bi-other-class-key", bi_record_id="DIG-0001").status_code == 409
    assert baseline(client, revision=3, key="replace-bi-key", bi_record_id="DIG-0002").status_code == 200
    assert baseline(client, user="other", record="tablet-other", key="old-bi-reserved-key", bi_record_id="DIG-0001").status_code == 409
    with Session(engine) as session:
        assert session.scalar(select(BaselineSourceRecord).where(BaselineSourceRecord.record_id == "DIG-0001")).user_id == "learner"
        assert session.scalar(select(StudentBaseline).where(StudentBaseline.user_id == "learner")).bi_source_record_id is not None


def test_export_authorized_sanitized_and_unknown_is_not_zero(presence_api):
    client, engine = presence_api
    path = "/classes/c1/journey-export"
    assert client.get(path, headers=header("teacher")).status_code == 404
    enable(client)
    assert baseline(client, bi_record_id="DIG-0001").status_code == 200
    for actor in ("learner", "outsider", "teacher2", "coordinator"):
        assert client.get(path, headers=header(actor)).status_code == 403
    data = client.get(path, headers=header("teacher")).json()
    assert data["contract"] == "tds-journey-v1"
    assert len(data["items"]) == 1 and len(data["pending"]) == 1
    item = data["items"][0]
    assert item["registro_id"] == "DIG-0001" and len(item["pessoa_id"]) == 64
    assert item["certificado_flag"] is None
    assert item["concluiu_frequencia_flag"] is None
    assert item["acompanhamento_30d"] is None
    assert item["progresso_estudo_percentual"] == 0
    assert not any(word in str(data) for word in ("61999990000", "Name learner", "tablet-7", "Vínculo conferido pessoalmente"))
    assert client.get(path + "?limit=1&offset=1", headers=header("teacher")).json()["items"] == []
    with Session(engine) as session:
        session.add(CertificateReference(id="verified-reference", user_id="learner", course_id="course",
            program_id="p1", class_id="c1", verification_url="https://synthetic.example/cert/test",
            content_hash="a" * 64, issued_at=datetime.now(timezone.utc)))
        session.commit()
    item = client.get(path, headers=header("teacher")).json()["items"][0]
    assert item["certificado_flag"] == 1 and item["certificado_emitido_em"] is not None
    assert item["concluiu_frequencia_flag"] is None
    client.app.state.settings = replace(client.app.state.settings, sheets_pseudonym_secret=None)
    assert client.get(path, headers=header("teacher")).status_code == 503


def test_actual_bi_inscription_can_be_source_without_a_fictional_tablet_id(presence_api):
    client, engine = presence_api
    enable(client)
    linked = baseline(client, source='fabric:tds-inscription-v1', record='DIG-0042', bi_record_id='DIG-0042')
    assert linked.status_code == 200, linked.text
    with Session(engine) as session:
        ref = session.scalar(select(BaselineSourceRecord).where(BaselineSourceRecord.record_id == 'DIG-0042'))
        record = session.scalar(select(StudentBaseline).where(StudentBaseline.user_id == 'learner'))
        assert record.source_record_id == record.bi_source_record_id == ref.id
    assert baseline(client, source='fabric:tds-inscription-v1', record='DIG-0042', bi_record_id='DIG-0042').json() == linked.json()


def test_screen_activity_is_owned_sanitized_and_never_learning_credit(presence_api):
    client, engine = presence_api
    payload = {"event_id": "app-screen:one", "event_type": "screen_engagement", "course_id": "_app",
        "session_id": "app-screen", "occurred_at": "2026-09-25T12:00:00Z", "active_seconds": 15,
        "payload": {"page_id": "home"}}
    assert client.post("/events", json=payload, headers=header("learner")).status_code == 404
    enable(client)
    # No historical baseline is needed to identify an actively enrolled account.
    pending_journey = client.get('/classes/c1/journey-export', headers=header('teacher')).json()
    assert pending_journey['items'] == []
    assert all(row['status'] == 'bi_link_pending' for row in pending_journey['pending'])
    followup_person = baseline_get(client).json()['pessoa_id']
    pending_event = client.post('/events', json=payload | {'event_id': 'pending:one'}, headers=header('learner'))
    assert pending_event.status_code == 201
    before_link = client.get('/classes/c1/journey-activity', headers=header('teacher')).json()['items']
    assert len(before_link) == 1 and before_link[0]['event_id'] == 'pending:one'
    assert before_link[0]['pessoa_id'] == followup_person
    assert baseline(client, bi_record_id="DIG-0001").status_code == 200
    created = client.post("/events", json=payload, headers=header("learner"))
    assert created.status_code == 201, created.text
    assert created.json()["validated_seconds"] == 0
    assert client.post("/events", json=payload, headers=header("learner")).status_code == 200
    assert client.post("/events", json=payload, headers=header("other")).status_code == 409
    assert client.post("/events", json=payload | {"payload": {"page_id": "home", "text": "private"}}, headers=header("learner")).status_code == 422
    assert client.post("/events", json=payload | {"active_seconds": 61}, headers=header("learner")).status_code == 422
    activity = client.get("/classes/c1/journey-activity", headers=header("teacher"))
    assert activity.status_code == 200
    event = next(item for item in activity.json()["items"] if item['event_id'] == 'app-screen:one')
    assert event["segundos_tela"] == 15 and event["alvo_id"] == "home"
    assert event["atribuicao_turma"] is None and event["escopo"] == "conta_autenticada"
    assert "learner" not in str(event) and "session_id" not in event
    assert client.get("/classes/c1/journey-activity", headers=header("learner")).status_code == 403
    second_scope = client.get("/classes/c2/journey-activity", headers=header("teacher2")).json()["items"]
    assert {row['event_id'] for row in second_scope} == {'pending:one', 'app-screen:one'}
    assert all(row['pessoa_id'] == event['pessoa_id'] and row['atribuicao_turma'] is None for row in second_scope)
    with Session(engine) as session:
        session.get(ClassEnrollment, ('c2', 'learner')).status = 'inactive'
        session.commit()
    assert client.get("/classes/c2/journey-activity", headers=header("teacher2")).json()["items"] == []


def test_pdf_request_export_is_intent_only_and_idempotent(presence_api):
    client, _ = presence_api
    enable(client)
    payload = {"event_id": "pdf-request:one", "event_type": "feature_used", "course_id": "course",
        "session_id": "pdf-request", "occurred_at": "2026-10-01T12:00:00Z",
        "payload": {"feature_id": "course_pdf_open_requested"}}
    first = client.post('/events', json=payload, headers=header('learner'))
    assert first.status_code == 201, first.text
    assert first.json()['validated_seconds'] == 0
    assert client.post('/events', json=payload, headers=header('learner')).status_code == 200
    items = client.get('/classes/c1/journey-activity', headers=header('teacher')).json()['items']
    assert len(items) == 1
    assert items[0]['alvo_id'] == 'course_pdf_open_requested'
    assert items[0]['segundos_tela'] is None and items[0]['atribuicao_turma'] is None
    assert client.get('/classes/c1/journey-activity', headers=header('learner')).status_code == 403
