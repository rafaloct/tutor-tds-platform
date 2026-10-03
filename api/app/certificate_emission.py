"""Development-only synthetic emission candidate. Final issuance stays blocked."""
from __future__ import annotations

from datetime import datetime, timezone
from uuid import NAMESPACE_URL, uuid5
from urllib.parse import urlsplit

from fastapi import APIRouter, Depends, HTTPException, Request
from sqlalchemy import select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .auth import access_claims
from .certificate_requests import _context, _request_eligibility
from .certificate_transport import CandidateTransport, TransportError
from .learning_context import resolve_student_context
from .certificate_policy import evaluate, generation_audit, policy_for, role
from .models import CertificateEmissionAttempt, CertificateReference, CertificateRequest, ClassEnrollment, Classroom, CohortMembership, Enrollment, ProgramMembership, StudentBaseline

router = APIRouter(prefix="/certificate-requests", tags=["certificate-emission-candidate"])


def _authorized(session, request_id, user_id):
    record = session.scalar(select(CertificateRequest).where(CertificateRequest.id == request_id).with_for_update())
    if record is None or record.user_id != user_id:
        raise HTTPException(404, "Pedido não encontrado.")
    if record.status == "rejected":
        raise HTTPException(422, "Pedido rejeitado exige reenvio explícito pelo fluxo existente.")
    classroom = session.get(Classroom, record.class_id) if record.class_id else None
    if (classroom is None or classroom.certificate_policy is None) and record.status != "approved":
        raise HTTPException(422, "Aprovação humana pendente no adaptador legado.")
    session.scalar(select(Enrollment).where(Enrollment.id == record.enrollment_id).with_for_update())
    session.scalar(select(ProgramMembership).where(ProgramMembership.user_id == user_id, ProgramMembership.program_id == record.program_id).with_for_update())
    if record.class_id is not None:
        link = session.scalar(select(ClassEnrollment).where(ClassEnrollment.class_id == record.class_id, ClassEnrollment.user_id == user_id).with_for_update())
        if link is not None and link.membership_id:
            session.scalar(select(CohortMembership).where(CohortMembership.id == link.membership_id).with_for_update())
    context = _context(session, record.user_id, record.enrollment_id, record.course_version_id, record.class_id)
    if record.class_id is None:
        raise HTTPException(422, "Candidato exige turma e matrícula contextual reconciliadas.")
    canonical_context = resolve_student_context(session, record.class_id, record.user_id).context
    if canonical_context.legacy_enrollment_id != record.enrollment_id or canonical_context.course_version_id != record.course_version_id:
        raise HTTPException(422, "Linhagem contextual divergente do pedido.")
    if context[4].id != record.program_id or context[5].id != record.institution_id:
        raise HTTPException(422, "Contexto/evidência elegível não confirmado.")
    if context[2].certificate_policy is not None:
        policy = policy_for(session, record)
        if role(session, context[2], policy["operational_owner_id"]) is None:
            raise HTTPException(422, "Responsável operacional revogado.")
        if not evaluate(session, record, canonical_context)["trail_complete"]:
            raise HTTPException(422, "Todos os checkpoints configurados da trilha são obrigatórios.")
        return record, None, canonical_context
    # Legacy technical adapter remains separate. It is not a universal TDS rule.
    if record.status != "approved" or not _request_eligibility(session, record)["eligible"]:
        raise HTTPException(422, "Aprovação/elegibilidade do adaptador legado pendente.")
    baseline = session.scalar(select(StudentBaseline).where(
        StudentBaseline.user_id == record.user_id, StudentBaseline.enrollment_id == record.enrollment_id,
        StudentBaseline.program_id == record.program_id, StudentBaseline.course_id == record.course_id,
        StudentBaseline.class_id == record.class_id,
    ).with_for_update())
    if baseline is None:
        raise HTTPException(422, "Baseline contextual obrigatório antes da emissão.")
    return record, baseline, canonical_context


def _command(record, baseline, context):
    return {
        "protocol": "certificate-candidate-v1", "synthetic": True,
        "id": str(uuid5(NAMESPACE_URL, "tutor-tds:certificate-candidate:" + record.id)),
        "request_id": record.id, "revision": record.revision,
        "user_id": record.user_id, "enrollment_id": context.enrollment_id,
        "legacy_enrollment_id": record.enrollment_id, "membership_id": context.membership_id,
        "program_id": record.program_id, "institution_id": record.institution_id,
        "course_id": record.course_id, "course_version_id": record.course_version_id,
        "class_id": record.class_id, "baseline_id": baseline.id if baseline else None, "baseline_revision": baseline.revision if baseline else 0,
        "holder_name": record.holder_name, "course_title": record.course_title,
        "institution_name": record.institution_name, "required_seconds": record.required_seconds,
    }


def _build_command(session, record, baseline, context):
    offering = session.get(Classroom, record.class_id)
    if offering.certificate_policy is None:
        return _command(record, baseline, context)
    policy = policy_for(session, record)
    state = evaluate(session, record, context)
    # Baseline qualifies CAPACITADO later, not generation. Null is explicit;
    # adding a baseline after response loss must not alter the reserved command.
    document = _command(record, None, context)
    return document | {"protocol": "certificate-candidate-v2", "baseline_id": None, "baseline_revision": 0,
        "required_seconds": 80 * 3600, "formal_hours": 80, "policy_hash": policy["policy_hash"],
        "checkpoint_evidence_digest": state["checkpoint_evidence_digest"], "operational_owner_id": policy["operational_owner_id"]}


def _transport(request):
    settings = request.app.state.settings
    # Production stays fail-closed. Staging is allowed only through a real,
    # explicitly named HTTPS staging endpoint; injected transports remain
    # development-only so a fake cannot masquerade as staging evidence.
    if settings.environment not in {"development", "staging"} or not settings.certificate_candidate_enabled:
        raise HTTPException(503, "Candidato sintético desativado neste ambiente.")
    if not settings.certificate_candidate_secret or len(settings.certificate_candidate_secret) < 32:
        raise HTTPException(503, "Transporte autenticado do candidato não configurado.")
    url = urlsplit(settings.certificate_candidate_url or "")
    try:
        url.port
    except ValueError as error:
        raise HTTPException(503, "Porta do transporte do candidato inválida.") from error

    injected = getattr(request.app.state, "certificate_candidate_exchange", None)
    common_invalid = (
        url.username
        or url.password
        or url.path not in {"", "/"}
        or url.query
        or url.fragment
    )
    if settings.environment == "development":
        if (
            url.scheme != "http"
            or url.hostname not in {"localhost", "127.0.0.1", "::1"}
            or common_invalid
        ):
            raise HTTPException(503, "Candidato em development exige transporte local isolado.")
        return CandidateTransport(
            settings.certificate_candidate_url,
            settings.certificate_candidate_secret,
            injected,
        )

    hostname = (url.hostname or "").lower()
    if (
        injected is not None
        or url.scheme != "https"
        or common_invalid
        or not hostname
        or "staging" not in hostname
        or hostname in {"localhost", "127.0.0.1", "::1"}
        or hostname.endswith(".local")
    ):
        raise HTTPException(503, "Candidato em staging exige endpoint HTTPS isolado de staging.")
    return CandidateTransport(
        settings.certificate_candidate_url,
        settings.certificate_candidate_secret,
    )


@router.post("/{request_id}/emit")
def emit_final(request_id: str, request: Request, claims=Depends(access_claims)):
    with Session(request.app.state.database.engine) as session:
        _authorized(session, request_id, claims["sub"])
    # No runtime flag or payload opens institutional activation before homologation.
    raise HTTPException(503, "Emissão final bloqueada pelo gate de ativação institucional: candidato sintético não homologa provedor instalado, assinatura institucional nem liberação em ambiente real.")


@router.post("/{request_id}/emission-candidate")
def emit_candidate(request_id: str, request: Request, claims=Depends(access_claims)):
    return _run(request_id, request, claims["sub"], allow_initial_send=True)


@router.post("/{request_id}/reconcile-candidate")
def reconcile_candidate(request_id: str, request: Request, claims=Depends(access_claims)):
    return _run(request_id, request, claims["sub"], allow_initial_send=False)


def _matches_reference(reference, record, receipt):
    expected = {
        "request_id": record.id, "is_candidate": True, "user_id": record.user_id,
        "course_id": record.course_id, "program_id": record.program_id, "class_id": record.class_id,
        "holder_name": record.holder_name, "course_title": record.course_title,
        "institution_name": record.institution_name, "planned_seconds": receipt["command"]["required_seconds"],
        "verification_url": receipt["verification_url"], "content_hash": receipt["content_hash"],
    }
    return all(getattr(reference, field) == value for field, value in expected.items())


def _run(request_id, request, user_id, *, allow_initial_send):
    transport = _transport(request)
    engine = request.app.state.database.engine
    first_send = False
    with Session(engine) as session:
        record, baseline, context = _authorized(session, request_id, user_id)
        command = _build_command(session, record, baseline, context)
        attempt = session.get(CertificateEmissionAttempt, request_id)
        if attempt is None:
            if not allow_initial_send:
                raise HTTPException(409, "Não existe tentativa reservada para reconciliar.")
            session.add(CertificateEmissionAttempt(request_id=request_id, certificate_id=command["id"], command=command, state="reserved"))
            try:
                session.commit()
                first_send = True
            except IntegrityError:
                session.rollback()
                attempt = session.get(CertificateEmissionAttempt, request_id)
                if attempt is None:
                    raise HTTPException(409, "Reserva concorrente inconsistente.")
        if attempt is not None and attempt.command != command:
            raise HTTPException(409, "Contexto alterado após reserva; conferência manual necessária.")
    try:
        receipt = transport.call(command, issue=False)
        if receipt is None and first_send:
            receipt = transport.call(command, issue=True)
        if receipt is None:
            raise TransportError("remote outcome still indeterminate")
    except TransportError as error:
        with Session(engine) as session:
            session.execute(update(CertificateEmissionAttempt).where(CertificateEmissionAttempt.request_id == request_id, CertificateEmissionAttempt.state != "confirmed").values(state="indeterminate"))
            session.commit()
        raise HTTPException(503, "Resultado indeterminado; reconciliar por consulta autenticada, sem reenviar emissão.") from error
    with Session(engine) as session:
        record, baseline, context = _authorized(session, request_id, user_id)
        if _build_command(session, record, baseline, context) != command:
            raise HTTPException(409, "Contexto mudou durante transporte; referência não registrada.")
        existing = session.get(CertificateReference, command["id"])
        if existing is not None and not _matches_reference(existing, record, receipt):
            raise HTTPException(409, "Referência em conflito.")
        if existing is None:
            existing = CertificateReference(
                id=command["id"], request_id=request_id, is_candidate=True, user_id=user_id,
                course_id=record.course_id, program_id=record.program_id, class_id=record.class_id,
                holder_name=record.holder_name, course_title=record.course_title,
                institution_name=record.institution_name, planned_seconds=command["required_seconds"],
                lifecycle_state="GENERATED" if command["protocol"] == "certificate-candidate-v2" else None,
                issued_at=datetime.now(timezone.utc), verification_url=receipt["verification_url"], content_hash=receipt["content_hash"],
            )
            session.add(existing)
        if command["protocol"] == "certificate-candidate-v2":
            generation_audit(session, record, context, existing, command, user_id)
        session.execute(update(CertificateEmissionAttempt).where(CertificateEmissionAttempt.request_id == request_id).values(state="confirmed", receipt=receipt))
        try:
            session.commit()
        except IntegrityError as error:
            session.rollback()
            # Reservation/output uniqueness is authoritative in SQL, never KV.
            existing = session.get(CertificateReference, command["id"])
            if existing is None or not _matches_reference(existing, record, receipt):
                raise HTTPException(409, "Referência concorrente em conflito.") from error
    return {"state": "candidate_confirmed", "final_issuance": "blocked", "reference_id": command["id"], "context": command, "verification_url": receipt["verification_url"], "content_hash": receipt["content_hash"]}
