"""Real API -> transport/signatures -> Worker, with synthetic HTTP and KV only."""
from dataclasses import replace
from concurrent.futures import ThreadPoolExecutor
from datetime import date, datetime, timezone
import hashlib
import hmac
import json
from pathlib import Path
import shutil
import subprocess
from threading import Lock

import pytest
from sqlalchemy import create_engine, select, text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.certificate_transport import CandidateTransport, TransportError, _NoRedirect, canonical
from app.models import Base, BaselineSourceRecord, CertificateEmissionAttempt, CertificateReference, ClassEnrollment, CohortMembership, ProgramMembership, StudentBaseline
from test_certificate_requests import requests_api, create, evidence, header, review, ORIGINAL
from test_presence import presence_api

SECRET = "synthetic-candidate-key-only-not-for-deployment"
BRIDGE = Path(__file__).parent / "fixtures" / "certificate_worker_bridge.mjs"


class WorkerExchange:
    def __init__(self):
        self.storage = {}
        self.calls = []
        self.writes = 0
        self.lose_post_response = False
        self.hide_reads = False
        self.tamper_signature = False
        self.fail_get = False
        self.after_call = None
        self.env = {}
        self.lock = Lock()

    def __call__(self, method, path, body, headers):
        # This simulator models one consistent backing store. Eventual invisibility
        # is injected explicitly; concurrent snapshots must not lose another write.
        with self.lock:
            return self._exchange(method, path, body, headers)

    def _exchange(self, method, path, body, headers):
        self.calls.append(method)
        result = subprocess.run([shutil.which("node") or "node", str(BRIDGE)], input=json.dumps({
            "method": method, "path": path, "body": body.decode(), "headers": headers,
            "storage": {} if self.hide_reads and method == "GET" else self.storage,
            "secret": SECRET, "failGet": self.fail_get, "env": self.env,
        }), text=True, capture_output=True, check=True)
        output = json.loads(result.stdout)
        if not self.hide_reads or method == "POST":
            self.storage = output["storage"]
        self.writes += output["writes"]
        if self.after_call:
            self.after_call(method)
        if method == "POST" and self.lose_post_response:
            raise TimeoutError("synthetic response lost after Worker persisted")
        if self.tamper_signature:
            output["headers"]["x-candidate-signature"] = "0" * 64
        return output["status"], output["headers"], output["body"].encode()


@pytest.fixture
def candidate(requests_api):
    client, engine = requests_api
    exchange = WorkerExchange()
    client.app.state.settings = replace(client.app.state.settings, certificate_candidate_enabled=True,
        certificate_candidate_url="http://127.0.0.1:9090", certificate_candidate_secret=SECRET)
    client.app.state.certificate_candidate_exchange = exchange
    with Session(engine) as session:
        session.add(CohortMembership(id="synthetic-membership", class_id="c1", user_id="learner", role="student", status="active"))
        session.add(BaselineSourceRecord(id="synthetic-source", source="synthetic-test", record_id="synthetic-record", user_id="learner"))
        session.flush()
        link = session.get(ClassEnrollment, ("c1", "learner"))
        link.context_id = "synthetic-context-enrollment"
        link.membership_id = "synthetic-membership"
        link.course_version_id = ORIGINAL
        session.add(StudentBaseline(id="synthetic-baseline", class_id="c1", user_id="learner", enrollment_id="e1", program_id="p1", course_id="course", source_record_id="synthetic-source", baseline_date=date(2026, 1, 1), revision=1, reviewed_at=datetime.now(timezone.utc)))
        session.commit()
    pending = create(client, classroom="c1").json()
    evidence(engine, classroom="c1")
    assert review(client, pending, user="teacher").status_code == 200
    return client, engine, exchange, pending["id"]


def emit(candidate, suffix="emission-candidate", user="learner"):
    client, _, _, request_id = candidate
    return client.post(f"/certificate-requests/{request_id}/{suffix}", headers=header(user))


def test_real_api_transport_worker_roundtrip_and_replay(candidate):
    client, engine, exchange, request_id = candidate
    result = emit(candidate)
    assert result.status_code == 200, result.text
    value = result.json()
    assert value["state"] == "candidate_confirmed" and value["final_issuance"] == "blocked"
    context = value["context"]
    assert context["enrollment_id"] == "synthetic-context-enrollment"
    assert context["legacy_enrollment_id"] == "e1" and context["membership_id"] == "synthetic-membership"
    assert context["course_version_id"] == ORIGINAL and context["class_id"] == "c1"
    assert emit(candidate).json() == value
    assert exchange.calls == ["GET", "POST", "GET"] and exchange.writes == 1
    with Session(engine) as session:
        reference = session.scalar(select(CertificateReference))
        assert reference.request_id == request_id and reference.user_id == "learner" and reference.is_candidate
        assert session.get(CertificateEmissionAttempt, request_id).state == "confirmed"
        assert len(session.scalars(select(CertificateReference)).all()) == 1
    assert client.get("/certificates", headers=header("learner")).json() == {"certificates": []}
    # Even a candidate-owned official replay must fail before public verification.
    client.app.state.settings = replace(client.app.state.settings, certificate_verification_url_prefix="https://synthetic.invalid/certificate-candidates/")
    with Session(engine) as session:
        reference = session.get(CertificateReference, value["reference_id"])
        issued_at = reference.issued_at.replace(tzinfo=timezone.utc).isoformat()
    official = client.post("/certificates/references", headers=header("learner"), json={
        "id": value["reference_id"], "program_id": "p1", "course_id": "course", "class_id": "c1",
        "issued_at": issued_at, "verification_url": value["verification_url"], "content_hash": value["content_hash"],
    })
    assert official.status_code == 409
    assert emit(candidate, "emit").status_code == 503
    assert exchange.calls == ["GET", "POST", "GET"]


def test_lost_response_and_eventually_invisible_lookup_never_resends(candidate):
    _, engine, exchange, request_id = candidate
    exchange.lose_post_response = True
    assert emit(candidate).status_code == 503
    with Session(engine) as session:
        assert session.get(CertificateEmissionAttempt, request_id).state == "indeterminate"
        assert not session.scalars(select(CertificateReference)).all()
    exchange.hide_reads = True
    assert emit(candidate).status_code == 503
    assert emit(candidate, "reconcile-candidate").status_code == 503
    assert exchange.calls.count("POST") == 1 and exchange.writes == 1
    exchange.hide_reads = False
    assert emit(candidate, "reconcile-candidate").status_code == 200
    assert exchange.calls.count("POST") == 1 and exchange.writes == 1


def test_crash_after_reservation_before_send_recovers_read_only(candidate):
    from app.certificate_emission import _authorized, _command
    _, engine, exchange, request_id = candidate
    with Session(engine) as session:
        record, baseline, context = _authorized(session, request_id, "learner")
        reserved = _command(record, baseline, context)
        session.add(CertificateEmissionAttempt(request_id=request_id, certificate_id=reserved["id"], command=reserved, state="reserved"))
        session.commit()
    assert emit(candidate).status_code == 503
    assert emit(candidate, "reconcile-candidate").status_code == 503
    assert exchange.calls == ["GET", "GET"] and exchange.writes == 0
    with Session(engine) as session:
        assert session.get(CertificateEmissionAttempt, request_id).state == "indeterminate"


@pytest.mark.parametrize("environment", ["staging", "production"])
def test_environment_cannot_enable_candidate_or_injected_transport(candidate, environment):
    client, _, exchange, _ = candidate
    client.app.state.settings = replace(client.app.state.settings, environment=environment)
    assert emit(candidate).status_code == 503
    assert not exchange.calls


@pytest.mark.parametrize("overrides", [{"TUTOR_ENVIRONMENT": "production"}, {"TUTOR_ENVIRONMENT": "staging"}, {"CERTIFICATE_CANDIDATE_ENABLED": "false"}])
def test_worker_activation_cannot_bypass_environment_boundary(candidate, overrides):
    _, _, exchange, _ = candidate
    exchange.env = overrides
    assert emit(candidate).status_code == 503
    assert exchange.writes == 0 and exchange.storage == {}


def test_api_candidate_disabled_by_default_and_pending_is_not_emission(candidate):
    client, _, exchange, _ = candidate
    from app.config import Settings
    assert Settings(database_url="sqlite+pysqlite:///:memory:", allowed_origins=()).certificate_candidate_enabled is False
    client.app.state.settings = replace(client.app.state.settings, certificate_candidate_enabled=False)
    assert emit(candidate).status_code == 503 and not exchange.calls
    client.app.state.settings = replace(client.app.state.settings, certificate_candidate_enabled=True)
    pending = create(client, version="v2", classroom="c2").json()
    response = client.post(f"/certificate-requests/{pending['id']}/emission-candidate", headers=header("learner"))
    assert response.status_code == 422 and not exchange.calls


@pytest.mark.parametrize("change,expected", [
    ("baseline", 422), ("program_membership", 422), ("cohort_membership", 403),
    ("edition", 403), ("context_missing", 409),
])
def test_missing_or_revoked_context_fails_before_transport(candidate, change, expected):
    _, engine, exchange, _ = candidate
    with Session(engine) as session:
        if change == "baseline": session.execute(text("DELETE FROM student_baselines"))
        if change == "program_membership": session.get(ProgramMembership, ("learner", "p1")).status = "inactive"
        if change == "cohort_membership": session.get(CohortMembership, "synthetic-membership").status = "inactive"
        if change == "edition": session.get(ClassEnrollment, ("c1", "learner")).course_version_id = "v2"
        if change == "context_missing":
            link = session.get(ClassEnrollment, ("c1", "learner"))
            link.context_id = link.membership_id = link.course_version_id = None
        session.commit()
    assert emit(candidate).status_code == expected
    assert not exchange.calls


def test_other_person_cannot_emit_or_reconcile_reference(candidate):
    assert emit(candidate, user="other").status_code == 404
    assert emit(candidate).status_code == 200
    assert emit(candidate, "reconcile-candidate", "other").status_code == 404


def test_unauthenticated_receipt_never_creates_reference(candidate):
    _, engine, exchange, _ = candidate
    exchange.tamper_signature = True
    assert emit(candidate).status_code == 503
    assert exchange.calls == ["GET"]
    with Session(engine) as session:
        assert not session.scalars(select(CertificateReference)).all()


def test_worker_read_failure_is_indeterminate_not_absent(candidate):
    _, engine, exchange, _ = candidate
    exchange.fail_get = True
    assert emit(candidate).status_code == 503
    assert exchange.calls == ["GET"] and exchange.writes == 0


def test_context_revoked_after_worker_processing_blocks_reference(candidate):
    _, engine, exchange, _ = candidate
    def revoke(method):
        if method == "POST":
            with Session(engine) as session:
                session.get(CohortMembership, "synthetic-membership").status = "inactive"
                session.commit()
    exchange.after_call = revoke
    assert emit(candidate).status_code == 403
    assert exchange.writes == 1
    with Session(engine) as session:
        assert not session.scalars(select(CertificateReference)).all()


def test_changed_reserved_context_conflicts_without_transport(candidate):
    _, engine, exchange, _ = candidate
    exchange.lose_post_response = True
    assert emit(candidate).status_code == 503
    with Session(engine) as session:
        session.get(ClassEnrollment, ("c1", "learner")).context_id = "different-context"
        session.commit()
    assert emit(candidate).status_code == 409
    assert exchange.calls == ["GET", "POST"]


def test_existing_reference_context_conflict_cannot_be_returned(candidate):
    _, engine, exchange, _ = candidate
    assert emit(candidate).status_code == 200
    with Session(engine) as session:
        session.scalar(select(CertificateReference)).class_id = "c2"
        session.commit()
    assert emit(candidate, "reconcile-candidate").status_code == 409
    assert exchange.calls.count("POST") == 1


def test_no_external_origin_or_redirect(candidate):
    client, _, exchange, _ = candidate
    client.app.state.settings = replace(client.app.state.settings, certificate_candidate_url="https://real.example")
    assert emit(candidate).status_code == 503 and not exchange.calls
    with pytest.raises(TransportError):
        _NoRedirect().redirect_request(None, None, 302, "redirect", {}, "https://real.example")


def test_authenticated_but_divergent_receipt_never_creates_reference(candidate):
    _, engine, exchange, _ = candidate
    exchange.lose_post_response = True
    assert emit(candidate).status_code == 503
    key = next(iter(exchange.storage))
    envelope = json.loads(exchange.storage[key])
    envelope["receipt"]["command"]["user_id"] = "other"
    envelope["receipt"]["content_hash"] = hashlib.sha256(canonical(envelope["receipt"]["command"])).hexdigest()
    receipt_bytes = json.dumps(envelope["receipt"], ensure_ascii=False, separators=(",", ":")).encode()
    envelope["signature"] = hmac.new(SECRET.encode(), b"candidate-storage-v1\n" + receipt_bytes, hashlib.sha256).hexdigest()
    exchange.storage[key] = json.dumps(envelope, ensure_ascii=False, separators=(",", ":"))
    assert emit(candidate, "reconcile-candidate").status_code == 503
    with Session(engine) as session:
        assert not session.scalars(select(CertificateReference)).all()
    assert exchange.calls.count("POST") == 1


def test_worker_rejects_unauthenticated_command(candidate):
    client, _, exchange, _ = candidate
    client.app.state.settings = replace(client.app.state.settings, certificate_candidate_secret="wrong-synthetic-key-with-at-least-32-chars")
    assert emit(candidate).status_code == 503
    assert exchange.calls == ["GET"] and exchange.writes == 0


def test_worker_rejects_changed_command_and_corrupted_storage(candidate):
    _, _, exchange, _ = candidate
    value = emit(candidate).json()
    changed = value["context"] | {"class_id": "different-class"}
    transport = CandidateTransport("http://127.0.0.1:9090", SECRET, exchange)
    with pytest.raises(TransportError): transport.call(changed, issue=True)
    assert exchange.writes == 1
    key = next(iter(exchange.storage))
    exchange.storage[key] = "{corrupted synthetic KV"
    assert emit(candidate, "reconcile-candidate").status_code == 503
    assert exchange.writes == 1


@pytest.mark.parametrize("foreign_keys_enabled", [True, False])
def test_account_erasure_removes_transport_private_data(candidate, foreign_keys_enabled):
    client, engine, exchange, request_id = candidate
    assert emit(candidate).status_code == 200
    if not foreign_keys_enabled:
        with engine.connect() as connection: connection.exec_driver_sql("PRAGMA foreign_keys=OFF")
    assert client.delete("/auth/me", headers=header("learner")).status_code == 204
    with Session(engine) as session:
        assert not session.scalars(select(CertificateEmissionAttempt)).all()
        assert not session.scalars(select(CertificateReference)).all()
    # Remote deletion/retention is an explicit future gate; the in-memory test
    # store dies with this fixture and is never a real external store.


def test_concurrent_api_reservation_sends_at_most_once(candidate):
    _, engine, exchange, _ = candidate
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda _: emit(candidate).status_code, range(2)))
    assert all(status in {200, 503} for status in results)
    assert 200 in results and exchange.calls.count("POST") == 1 and exchange.writes == 1
    assert emit(candidate, "reconcile-candidate").status_code == 200
    with Session(engine) as session:
        assert len(session.scalars(select(CertificateReference)).all()) == 1


def test_reference_request_unique_and_downgrade_preserves_history(candidate):
    from alembic import command
    from alembic.config import Config
    _, engine, _, request_id = candidate
    assert emit(candidate).status_code == 200
    with Session(engine) as session:
        original = session.scalar(select(CertificateReference))
        session.add(CertificateReference(id="second-synthetic-output", request_id=request_id, is_candidate=True,
            user_id="learner", course_id="course", verification_url=original.verification_url,
            content_hash=original.content_hash, issued_at=original.issued_at))
        with pytest.raises(IntegrityError): session.commit()
    config = Config("alembic.ini")
    config.set_main_option("sqlalchemy.url", str(engine.url))
    with pytest.raises(RuntimeError, match="preserve candidate emission history"):
        command.downgrade(config, "20261001_0020")


def test_migration_upgrade_preserves_legacy_rows_and_guards_then_empty_rollback(tmp_path):
    from alembic import command
    from alembic.config import Config
    config = Config("alembic.ini")
    url = f"sqlite+pysqlite:///{(tmp_path / 'migration-candidate.db').as_posix()}"
    config.set_main_option("sqlalchemy.url", url)
    command.upgrade(config, "20261001_0020")
    engine = create_engine(url)
    with engine.begin() as connection:
        connection.execute(text("INSERT INTO users (id,cpf_digest,phone,name,password_digest,role) VALUES ('synthetic-owner','synthetic-cpf','synthetic-phone','Synthetic Owner','synthetic-digest','student')"))
        connection.execute(text("INSERT INTO courses (id,title,author,content,active) VALUES ('synthetic-course','Synthetic Course','Synthetic Author','{}',1)"))
        connection.execute(text("INSERT INTO certificates (id,user_id,course_id,verification_url,content_hash,issued_at) VALUES ('synthetic-legacy','synthetic-owner','synthetic-course','https://synthetic.invalid/legacy','unchanged-synthetic-hash','2026-01-01')"))
        original = tuple(connection.execute(text("SELECT * FROM certificates")).one())
        guards = connection.execute(text("SELECT name,sql FROM sqlite_master WHERE type='trigger' ORDER BY name")).all()
    command.upgrade(config, "head")
    with engine.connect() as connection:
        upgraded = tuple(connection.execute(text("SELECT * FROM certificates")).one())
        assert upgraded[:len(original)] == original
        assert connection.execute(text("SELECT request_id,is_candidate FROM certificates")).one() == (None, 0)
        assert connection.execute(text("SELECT name,sql FROM sqlite_master WHERE type='trigger' ORDER BY name")).all() == guards
        assert connection.execute(text("PRAGMA foreign_key_check")).all() == []
    command.downgrade(config, "20261001_0020")
    with engine.connect() as connection:
        assert tuple(connection.execute(text("SELECT * FROM certificates")).one()) == original
        assert connection.execute(text("SELECT name,sql FROM sqlite_master WHERE type='trigger' ORDER BY name")).all() == guards
    engine.dispose()


def test_metadata_default_preserves_legacy_reference_as_official():
    engine = create_engine("sqlite+pysqlite:///:memory:")
    Base.metadata.create_all(engine)
    with engine.begin() as connection:
        connection.execute(text("INSERT INTO certificates (id,user_id,course_id,verification_url,content_hash,issued_at) VALUES ('legacy-synthetic','synthetic-owner','synthetic-course','https://synthetic.invalid/legacy','synthetic-hash','2026-01-01')"))
        assert connection.execute(text("SELECT is_candidate,typeof(is_candidate) FROM certificates")).one() == (0, "integer")
    with Session(engine) as session:
        assert session.get(CertificateReference, "legacy-synthetic").is_candidate is False
        assert session.scalar(select(CertificateReference).where(CertificateReference.is_candidate.is_(False))) is not None
    engine.dispose()


def test_journey_export_does_not_claim_candidate_as_official(presence_api):
    from test_journey_traceability import enable
    from test_student_followup import baseline
    client, engine = presence_api
    enable(client)
    assert baseline(client, bi_record_id="DIG-0001").status_code == 200
    with Session(engine) as session:
        session.add(CertificateReference(id="synthetic-candidate-only", is_candidate=True, user_id="learner",
            course_id="course", program_id="p1", class_id="c1", verification_url="https://synthetic.invalid/candidate",
            content_hash="a" * 64, issued_at=datetime.now(timezone.utc)))
        session.commit()
    item = client.get("/classes/c1/journey-export", headers=header("teacher")).json()["items"][0]
    assert item["certificado_flag"] is None and item["certificado_emitido_em"] is None
