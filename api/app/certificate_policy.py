"""Opt-in TDS institutional policy; deterministic rules, candidate activation only.

EvidenceItem is the EvidenceRecord adapter. No external baseline data, SMTP,
institutional PDF signature or VPS deployment is invented by this module.
"""
from datetime import datetime, timezone
import hashlib
from typing import Literal
from uuid import NAMESPACE_URL, uuid5

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, ConfigDict, Field, StrictInt, field_validator, model_validator
from sqlalchemy import select, update
from sqlalchemy.orm import Session

from .auth import access_claims
from .certificate_requests import _context
from .certificate_transport import canonical
from .learning_context import resolve_student_context
from .models import (AssessmentAttemptRecord, AssessmentContentRecord, CertificateEmissionAttempt,
    CertificateReference, CertificateRequest, Classroom, ClassSession, CourseVersion, EvidenceItem,
    ProgramMembership, ReviewDecision, SessionPresence, StudentBaseline, User)

router = APIRouter(tags=["certificate-policy-candidate"])
STATES = ("GENERATED", "PENDING_INSTRUCTOR_VALIDATION", "PENDING_COORDINATOR_SIGNATURE", "VALID")


def enabled(request):
    settings = request.app.state.settings
    if settings.environment != "development" or not settings.certificate_candidate_enabled:
        raise HTTPException(503, "Contrato candidato desativado neste ambiente.")


def role(session, classroom, actor):
    membership = session.get(ProgramMembership, (actor, classroom.program_id))
    if membership is not None and membership.status == "active":
        if membership.role in {"coordinator", "admin"}:
            return membership.role
        if membership.role == "teacher" and classroom.teacher_id == actor:
            return "teacher"
    user = session.get(User, actor)
    return "admin" if user is not None and user.role == "admin" else None


def contextual_request(session, request_id, actor, *, owner_only=False):
    record = session.scalar(select(CertificateRequest).where(CertificateRequest.id == request_id).with_for_update())
    classroom = session.get(Classroom, record.class_id) if record is not None and record.class_id else None
    if record is None or classroom is None or (record.user_id != actor and (owner_only or role(session, classroom, actor) is None)):
        raise HTTPException(404, "Pedido contextual não encontrado.")
    if record.status == "rejected":
        raise HTTPException(422, "Pedido rejeitado exige reenvio explícito pelo fluxo existente.")
    _context(session, record.user_id, record.enrollment_id, record.course_version_id, record.class_id)
    context = resolve_student_context(session, record.class_id, record.user_id).context
    if (context.legacy_enrollment_id != record.enrollment_id or context.course_version_id != record.course_version_id
            or context.organization_id != record.institution_id or context.program_id != record.program_id):
        raise HTTPException(422, "Pedido diverge do contexto vigente.")
    return record, classroom, context


class CheckpointConfig(BaseModel):
    model_config = ConfigDict(extra="forbid")
    id: str = Field(min_length=1, max_length=80, pattern=r"^[A-Za-z0-9_.:-]+$")
    kind: str = Field(min_length=1, max_length=48)
    source_id: str = Field(min_length=1, max_length=180)


class PolicyCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    course_version_id: str = Field(min_length=1, max_length=36)
    formal_hours: Literal[80]
    session_ids: list[str] = Field(min_length=1, max_length=100)
    checkpoints: list[CheckpointConfig] = Field(min_length=1, max_length=100)
    operational_owner_id: str = Field(min_length=1, max_length=36)

    @model_validator(mode="after")
    def distinct(self):
        if len(set(self.session_ids)) != len(self.session_ids) or len({item.id for item in self.checkpoints}) != len(self.checkpoints):
            raise ValueError("Encontros/checkpoints configurados devem ser distintos.")
        return self


@router.put("/classes/{class_id}/certificate-policy-candidate")
def configure_policy(class_id: str, payload: PolicyCreate, request: Request, claims=Depends(access_claims)):
    enabled(request)
    with Session(request.app.state.database.engine) as session:
        classroom = session.scalar(select(Classroom).where(Classroom.id == class_id).with_for_update())
        if classroom is None or role(session, classroom, claims["sub"]) not in {"coordinator", "admin"}:
            raise HTTPException(403, "Configuração exige coordenação autorizada da oferta.")
        if classroom.course_version_id != payload.course_version_id:
            raise HTTPException(422, "Edição configurada diverge da turma.")
        edition = session.get(CourseVersion, payload.course_version_id)
        if edition is None or edition.course_id != classroom.course_id or edition.status not in {"published", "archived"}:
            raise HTTPException(422, "Política exige edição publicada ou arquivada da oferta.")
        if role(session, classroom, payload.operational_owner_id) not in {"teacher", "coordinator", "admin"}:
            raise HTTPException(422, "Responsável operacional autorizado precisa ser identificado.")
        for identity in payload.session_ids:
            meeting = session.get(ClassSession, identity)
            if meeting is None or meeting.class_id != class_id:
                raise HTTPException(422, "Encontro configurado não pertence à oferta.")
        checkpoints = []
        for checkpoint in payload.checkpoints:
            # Extensible discriminator, not a universal quiz requirement. Unsupported
            # representations stay blocked instead of trusting aggregate completion.
            if checkpoint.kind != "assessment":
                raise HTTPException(422, "Representação determinística deste tipo de checkpoint ainda não suportada.")
            source = session.get(AssessmentContentRecord, checkpoint.source_id)
            author = session.get(ProgramMembership, (source.owner_id, classroom.program_id)) if source else None
            if source is None or source.course_id != classroom.course_id or author is None or author.status != "active" or author.role not in {"teacher", "coordinator", "admin"}:
                raise HTTPException(422, "Fonte do checkpoint precisa ser editorial e da oferta.")
            checkpoints.append(checkpoint.model_dump() | {"source_digest": source.content_digest})
        document = {"version": 1, "formal_hours": 80, "course_id": classroom.course_id,
            "course_version_id": payload.course_version_id, "session_ids": payload.session_ids,
            "checkpoints": checkpoints, "operational_owner_id": payload.operational_owner_id}
        document["policy_hash"] = hashlib.sha256(canonical(document)).hexdigest()
        if classroom.certificate_policy is not None:
            if classroom.certificate_policy == document:
                return document
            raise HTTPException(409, "Política fixada; não alterar retroativamente a trilha/denominador.")
        if session.scalar(select(CertificateEmissionAttempt.request_id).join(CertificateRequest, CertificateRequest.id == CertificateEmissionAttempt.request_id).where(CertificateRequest.class_id == class_id).limit(1)):
            raise HTTPException(409, "Transporte anterior precisa ser reconciliado antes de configurar nova regra.")
        classroom.certificate_policy = document
        session.commit()
        return document


def policy_for(session, record):
    classroom = session.get(Classroom, record.class_id)
    policy = classroom.certificate_policy if classroom else None
    if not isinstance(policy, dict):
        raise HTTPException(503, "Oferta sem política institucional configurada.")
    unsigned = {key: value for key, value in policy.items() if key != "policy_hash"}
    if (policy.get("policy_hash") != hashlib.sha256(canonical(unsigned)).hexdigest()
            or policy.get("formal_hours") != 80 or policy.get("course_id") != record.course_id
            or policy.get("course_version_id") != record.course_version_id
            or not policy.get("session_ids") or not policy.get("checkpoints")):
        raise HTTPException(409, "Política inconsistente ou divergente da edição.")
    return policy


def matching_evidence(session, record, context, policy, kind):
    items = session.scalars(select(EvidenceItem).where(EvidenceItem.class_id == record.class_id,
        EvidenceItem.user_id == record.user_id, EvidenceItem.evidence_type == kind)).all()
    return [item for item in items if item.metadata_json.get("enrollment_id") == context.enrollment_id
        and item.metadata_json.get("course_version_id") == record.course_version_id
        and item.metadata_json.get("policy_hash") == policy["policy_hash"]]


def baseline_for(session, record, context, policy):
    baseline = session.scalar(select(StudentBaseline).where(StudentBaseline.user_id == record.user_id,
        StudentBaseline.class_id == record.class_id, StudentBaseline.enrollment_id == record.enrollment_id,
        StudentBaseline.program_id == record.program_id, StudentBaseline.course_id == record.course_id))
    if baseline is not None:
        return {"id": baseline.id, "revision": baseline.revision, "kind": "StudentBaseline"}
    evidence = [item for item in matching_evidence(session, record, context, policy, "baseline") if item.review_status == "accepted"]
    return {"id": evidence[0].id, "revision": 1, "kind": "EvidenceItem"} if evidence else None


def evaluate(session, record, context, reference=None):
    policy = policy_for(session, record)
    session_ids = policy["session_ids"]
    for identity in session_ids:
        meeting = session.get(ClassSession, identity)
        if meeting is None or meeting.class_id != record.class_id:
            raise HTTPException(409, "Encontro configurado divergente ou ausente.")
    present = set(session.scalars(select(SessionPresence.session_id).where(
        SessionPresence.session_id.in_(session_ids), SessionPresence.class_id == record.class_id,
        SessionPresence.user_id == record.user_id, SessionPresence.enrollment_id == record.enrollment_id,
        SessionPresence.program_id == record.program_id, SessionPresence.course_id == record.course_id,
        SessionPresence.status == "confirmed_present")))
    proofs = matching_evidence(session, record, context, policy, "trail_checkpoint")
    completed, proof_hashes = set(), []
    for checkpoint in policy["checkpoints"]:
        if checkpoint["kind"] != "assessment":
            raise HTTPException(409, "Tipo de checkpoint sem representação validada.")
        source = session.get(AssessmentContentRecord, checkpoint["source_id"])
        if source is None or source.content_digest != checkpoint["source_digest"] or source.course_id != record.course_id:
            raise HTTPException(409, "Fonte editorial de checkpoint alterada ou ausente.")
        attempt_id = str(uuid5(NAMESPACE_URL, "tds-checkpoint:" + context.enrollment_id + ":" + policy["policy_hash"] + ":" + checkpoint["id"]))
        attempt = session.get(AssessmentAttemptRecord, attempt_id)
        required = {str(index) for index in range(len(source.questions))}
        if (attempt is None or attempt.owner_id != record.user_id or attempt.course_id != record.course_id
                or attempt.assessment_content_id != source.id or not attempt.completed or not required
                or set(attempt.answers) != required
                or any(isinstance(answer, bool) or not isinstance(answer, int) or answer < 0
                    or answer >= len(source.questions[int(index)]["options"]) for index, answer in attempt.answers.items())):
            continue
        for proof in proofs:
            if (proof.object_reference == attempt_id and proof.metadata_json.get("attempt_id") == attempt_id
                    and proof.metadata_json.get("document_digest") == hashlib.sha256(canonical(attempt.answers)).hexdigest()
                    and proof.review_status == "accepted" and proof.metadata_json.get("checkpoint_id") == checkpoint["id"]
                    and proof.metadata_json.get("validation_mode") == "backend_deterministic"
                    and proof.metadata_json.get("source_digest") == checkpoint["source_digest"]):
                completed.add(checkpoint["id"])
                proof_hashes.append(proof.item_digest)
    baseline = baseline_for(session, record, context, policy)
    trail_complete = len(completed) == len(policy["checkpoints"])
    attendance_ok = 10 * len(present) >= 7 * len(session_ids)
    generated = reference is not None and reference.is_candidate and reference.request_id == record.id and reference.lifecycle_state in STATES
    sheets = matching_evidence(session, record, context, policy, "attendance_sheet")
    covered = set()
    for item in sheets:
        if item.review_status == "accepted" and item.metadata_json.get("signed_by") == session.get(Classroom, record.class_id).teacher_id:
            covered.update(item.metadata_json.get("covered_session_ids", []))
    instructor_signed = set(session_ids).issubset(covered)
    signatures = matching_evidence(session, record, context, policy, "certificate_signature")
    coordinator_signed = generated and any(item.review_status == "accepted" and item.object_reference == reference.id for item in signatures)
    capacitado = baseline is not None and attendance_ok and trail_complete and generated
    valid = capacitado and instructor_signed and coordinator_signed and reference.lifecycle_state == "VALID"
    pending_exceptions = [item.id for item in matching_evidence(session, record, context, policy, "attendance_exception") if item.review_status == "pending"]
    return {"formal_hours": 80, "configured_meetings": len(session_ids), "confirmed_presence": len(present),
        "attendance_70_percent": attendance_ok, "baseline_registered": baseline is not None,
        "required_checkpoints": len(policy["checkpoints"]), "completed_checkpoints": len(completed),
        "trail_complete": trail_complete, "trail_certificate_generated": generated,
        "capacitado": capacitado, "instructor_sheets_signed": instructor_signed,
        "coordinator_certificate_signed": bool(coordinator_signed), "certificate_valid": bool(valid),
        "lifecycle_state": reference.lifecycle_state if generated else None,
        "exceptions_state": "pending_human_validation" if pending_exceptions else None,
        "pending_exception_ids": pending_exceptions, "policy_hash": policy["policy_hash"],
        "checkpoint_evidence_digest": hashlib.sha256(canonical({"proofs": sorted(set(proof_hashes))})).hexdigest(),
        "activation": "synthetic_candidate_only", "institutional_release": "blocked"}


def evidence_record(session, record, context, policy, kind, actor, metadata, reference, digest, *, accepted=True):
    binding = {"kind": kind, "actor": actor, "user_id": record.user_id, "class_id": record.class_id,
        "enrollment_id": context.enrollment_id, "legacy_enrollment_id": record.enrollment_id,
        "course_version_id": record.course_version_id, "policy_hash": policy["policy_hash"],
        "reference": reference, "document_digest": digest, **metadata}
    item_digest = hashlib.sha256(canonical(binding)).hexdigest()
    existing = session.scalar(select(EvidenceItem).where(EvidenceItem.item_digest == item_digest))
    if existing is not None:
        return existing
    identity = str(uuid5(NAMESPACE_URL, "tds-candidate-evidence:" + item_digest))
    item = EvidenceItem(id=identity, class_id=record.class_id, user_id=record.user_id,
        evidence_type=kind, occurred_at=datetime.now(timezone.utc), review_status="accepted" if accepted else "pending",
        item_digest=item_digest, object_reference=reference, metadata_json=binding)
    session.add(item)
    session.flush()
    if accepted and kind not in {"trail_checkpoint", "certificate_generation", "certificate_lifecycle"}:
        session.add(ReviewDecision(id=str(uuid5(NAMESPACE_URL, "tds-candidate-review:" + identity)),
            evidence_id=identity, decision="accepted", reason_code="verified", decided_by=actor, decided_at=datetime.now(timezone.utc)))
    return item


class CheckpointComplete(BaseModel):
    model_config = ConfigDict(extra="forbid")
    answers: dict[str, StrictInt]


@router.post("/certificate-requests/{request_id}/candidate-checkpoints/{checkpoint_id}")
def complete_checkpoint(request_id: str, checkpoint_id: str, payload: CheckpointComplete, request: Request, claims=Depends(access_claims)):
    enabled(request)
    with Session(request.app.state.database.engine) as session:
        record, _, context = contextual_request(session, request_id, claims["sub"], owner_only=True)
        policy = policy_for(session, record)
        configured = next((item for item in policy["checkpoints"] if item["id"] == checkpoint_id), None)
        if configured is None or configured["kind"] != "assessment":
            raise HTTPException(422, "Checkpoint não configurado ou representação não suportada.")
        content = session.get(AssessmentContentRecord, configured["source_id"])
        if content is None or content.content_digest != configured["source_digest"] or content.course_id != record.course_id:
            raise HTTPException(409, "Fonte do checkpoint mudou.")
        required = {str(index) for index in range(len(content.questions))}
        if not required or set(payload.answers) != required or any(isinstance(answer, bool) or answer < 0 or answer >= len(content.questions[int(index)]["options"]) for index, answer in payload.answers.items()):
            raise HTTPException(422, "Todas as respostas configuradas são obrigatórias; sem completed/score do cliente.")
        attempt_id = str(uuid5(NAMESPACE_URL, "tds-checkpoint:" + context.enrollment_id + ":" + policy["policy_hash"] + ":" + checkpoint_id))
        attempt = session.get(AssessmentAttemptRecord, attempt_id)
        if attempt is not None and attempt.answers != payload.answers:
            raise HTTPException(409, "Checkpoint já concluído com outra resposta.")
        if attempt is None:
            score = sum(payload.answers[str(index)] == key["correct_index"] for index, key in enumerate(content.answer_key))
            session.add(AssessmentAttemptRecord(attempt_id=attempt_id, owner_id=record.user_id,
                course_id=record.course_id, assessment_content_id=content.id, topic=content.topic,
                mode=content.mode, revision=1, answers=payload.answers, marked=[], current_index=len(content.questions) - 1,
                remaining_seconds=0, completed=True, score=score, updated_at=datetime.now(timezone.utc)))
        proof = evidence_record(session, record, context, policy, "trail_checkpoint", claims["sub"],
            {"checkpoint_id": checkpoint_id, "source_digest": configured["source_digest"],
             "validation_mode": "backend_deterministic", "origin": "backend", "attempt_id": attempt_id},
            attempt_id, hashlib.sha256(canonical(payload.answers)).hexdigest())
        session.commit()
        result = {"checkpoint_id": checkpoint_id, "evidence_id": proof.id, "completed": True, "validation": "backend_deterministic"}
        complete = evaluate(session, record, context)["trail_complete"]
    if complete:
        # Preserve the automatic generation trigger, but the real producer/consumer
        # is isolated locally. A lost response leaves durable checkpoint + reservation.
        from .certificate_emission import _run
        result["generation"] = _run(request_id, request, claims["sub"], allow_initial_send=True)
    return result


class EvidenceCreate(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)
    kind: Literal["baseline", "attendance_sheet", "attendance_exception"]
    origin: str = Field(min_length=1, max_length=100, pattern=r"^[A-Za-z0-9_.:-]+$")
    document_reference: str = Field(min_length=3, max_length=240)
    document_digest: str = Field(pattern=r"^[0-9a-f]{64}$")
    reason: str = Field(min_length=3, max_length=500)
    session_ids: list[str] = Field(default_factory=list, max_length=100)

    @field_validator("document_reference")
    @classmethod
    def private_reference(cls, value):
        if "://" in value or any(ord(character) < 32 for character in value):
            raise ValueError("Referência privada estruturada obrigatória, sem URL/conteúdo bruto.")
        return value


@router.post("/certificate-requests/{request_id}/candidate-evidence")
def record_evidence(request_id: str, payload: EvidenceCreate, request: Request, claims=Depends(access_claims)):
    enabled(request)
    with Session(request.app.state.database.engine) as session:
        record, classroom, context = contextual_request(session, request_id, claims["sub"])
        actor_role = role(session, classroom, claims["sub"])
        if actor_role is None or (payload.kind == "attendance_sheet" and actor_role != "teacher"):
            raise HTTPException(403, "Registro exige responsável autorizado; fichas exigem instrutor da turma.")
        policy = policy_for(session, record)
        if payload.kind == "attendance_sheet" and (not payload.session_ids or len(set(payload.session_ids)) != len(payload.session_ids) or not set(payload.session_ids).issubset(policy["session_ids"])):
            raise HTTPException(422, "Ficha assinada precisa vincular os encontros configurados que cobre.")
        metadata = {"origin": payload.origin, "reason": payload.reason, "responsible_user_id": claims["sub"],
            "status": "pending_human_validation" if payload.kind == "attendance_exception" else "registered"}
        if payload.kind == "attendance_sheet":
            metadata.update({"signed_by": claims["sub"], "signature_representation": "human_document_attestation", "covered_session_ids": payload.session_ids})
        item = evidence_record(session, record, context, policy, payload.kind, claims["sub"], metadata,
            payload.document_reference, payload.document_digest, accepted=payload.kind != "attendance_exception")
        session.commit()
        return {"evidence_id": item.id, "kind": item.evidence_type, "origin": payload.origin, "status": metadata["status"], "external_document_read": False}


@router.get("/certificate-requests/{request_id}/candidate-status")
def candidate_status(request_id: str, request: Request, claims=Depends(access_claims)):
    enabled(request)
    with Session(request.app.state.database.engine) as session:
        record, _, context = contextual_request(session, request_id, claims["sub"])
        reference = session.scalar(select(CertificateReference).where(CertificateReference.request_id == request_id, CertificateReference.is_candidate.is_(True)))
        return evaluate(session, record, context, reference)


class LifecycleAction(BaseModel):
    model_config = ConfigDict(extra="forbid")
    action: Literal["submit", "instructor_validate", "coordinator_sign"]
    expected_state: Literal["GENERATED", "PENDING_INSTRUCTOR_VALIDATION", "PENDING_COORDINATOR_SIGNATURE", "VALID"]
    document_reference: str | None = Field(default=None, min_length=3, max_length=240)
    document_digest: str | None = Field(default=None, pattern=r"^[0-9a-f]{64}$")

    @field_validator("document_reference")
    @classmethod
    def private_reference(cls, value):
        if value is not None and ("://" in value or any(ord(character) < 32 for character in value)):
            raise ValueError("Referência de assinatura deve ser privada e estruturada.")
        return value


@router.post("/certificate-requests/{request_id}/candidate-lifecycle")
def transition(request_id: str, payload: LifecycleAction, request: Request, claims=Depends(access_claims)):
    enabled(request)
    with Session(request.app.state.database.engine) as session:
        record, classroom, context = contextual_request(session, request_id, claims["sub"])
        policy = policy_for(session, record)
        reference = session.scalar(select(CertificateReference).where(CertificateReference.request_id == request_id,
            CertificateReference.is_candidate.is_(True)).with_for_update())
        if reference is None or reference.lifecycle_state not in STATES:
            raise HTTPException(409, "Certificado de trilha ainda não gerado.")
        actor_role = role(session, classroom, claims["sub"])
        if payload.action == "submit" and record.user_id != claims["sub"] and actor_role is None:
            raise HTTPException(403, "Sem autorização para encaminhar validação.")
        if payload.action == "instructor_validate" and actor_role != "teacher":
            raise HTTPException(403, "Somente instrutor responsável valida fichas.")
        # A global admin is not an institutional coordinator signature.
        membership = session.get(ProgramMembership, (claims["sub"], classroom.program_id))
        if payload.action == "coordinator_sign" and (membership is None or membership.status != "active" or membership.role != "coordinator"):
            raise HTTPException(403, "Assinatura exige coordenação ativa autorizada.")
        source, target = {"submit": STATES[:2], "instructor_validate": STATES[1:3], "coordinator_sign": STATES[2:4]}[payload.action]
        if payload.expected_state != source or reference.lifecycle_state != source:
            raise HTTPException(409, "Estado de validação alterado ou transição fora de ordem.")
        state = evaluate(session, record, context, reference)
        if payload.action != "submit" and (not state["capacitado"] or not state["instructor_sheets_signed"]):
            raise HTTPException(422, "Capacitação e fichas assinadas pelo instrutor são obrigatórias.")
        if payload.action == "coordinator_sign":
            if not payload.document_reference or "://" in payload.document_reference or not payload.document_digest:
                raise HTTPException(422, "Referência/digest de assinatura documental da coordenação obrigatórios.")
            evidence_record(session, record, context, policy, "certificate_signature", claims["sub"],
                {"origin": "institutional_document", "signed_by": claims["sub"],
                 "signature_representation": "human_document_attestation", "signature_reference": payload.document_reference},
                reference.id, payload.document_digest)
        result = session.execute(update(CertificateReference).where(CertificateReference.id == reference.id,
            CertificateReference.lifecycle_state == source).values(lifecycle_state=target), execution_options={"synchronize_session": False})
        if result.rowcount != 1:
            raise HTTPException(409, "Transição concorrente; recarregue.")
        evidence_record(session, record, context, policy, "certificate_lifecycle", claims["sub"],
            {"origin": "backend", "from_state": source, "to_state": target}, reference.id,
            hashlib.sha256((reference.id + source + target).encode()).hexdigest())
        session.commit()
        session.refresh(reference)
        return evaluate(session, record, context, reference)


def generation_audit(session, record, context, reference, command, actor):
    policy = policy_for(session, record)
    evidence_record(session, record, context, policy, "certificate_generation", actor,
        {"origin": "authenticated_worker_candidate", "operational_owner_id": policy["operational_owner_id"],
         "operational_responsible_label": "Eliza", "operational_authorization_role": role(session, session.get(Classroom, record.class_id), policy["operational_owner_id"]), "state": "GENERATED", "transport": "synthetic_no_vps_call"},
        reference.id, reference.content_hash)
    evidence_record(session, record, context, policy, "certificate_dispatch", actor,
        {"origin": "institutional_email_workflow", "target_email": "tdsdados@gmail.com", "state": "pending_dispatch",
         "operational_owner_id": policy["operational_owner_id"], "sent": False, "delivery_receipt": None},
        reference.id, reference.content_hash, accepted=False)
