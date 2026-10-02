"""Read-only projection for the inspected TDS BI; never grants learning outcomes."""
from datetime import datetime, timezone
import re

from fastapi import APIRouter, Depends, HTTPException, Query, Request
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from .auth import access_claims
from .classrooms import _student_progress
from .evidence import _active_student
from .models import (BaselineSourceRecord, CertificateReference, ClassEnrollment,
                     Course, CourseVersion, LearningEventRecord, ProgramCourse, StudentBaseline, User)
from .student_followup import BI_SOURCE, _scope
from .sync_worker import _pseudonym

router = APIRouter(tags=["journey-traceability"])


def _enabled(request):
    settings = request.app.state.settings
    if not settings.journey_traceability_enabled:
        raise HTTPException(404, "Exportação de rastreio ainda não habilitada.")
    return settings


def _secret(settings):
    value = settings.sheets_pseudonym_secret
    if value is None or len(value) < 32:
        raise HTTPException(503, "Identificação analítica não configurada.")
    return value


def _iso(value):
    if value is None:
        return None
    return (value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value.astimezone(timezone.utc)).isoformat()


@router.get("/classes/{class_id}/journey-export")
def export_journey(class_id: str, request: Request, limit: int = Query(100, ge=1, le=100),
                   offset: int = Query(0, ge=0), claims=Depends(access_claims)):
    settings = _enabled(request)
    now = datetime.now(timezone.utc)
    with Session(request.app.state.database.engine) as session:
        classroom = _scope(session, class_id, claims)
        secret = _secret(settings)
        members = session.scalars(select(ClassEnrollment).where(
            ClassEnrollment.class_id == class_id).order_by(ClassEnrollment.user_id)).all()
        items, pending = [], []
        course = session.get(Course, classroom.course_id)
        version = session.get(CourseVersion, classroom.course_version_id) if classroom.course_version_id else None
        for member in members[offset:offset + limit]:
            person = _pseudonym(secret, member.user_id)
            if not _active_student(session, classroom, member.user_id):
                pending.append({"pessoa_id": person, "status": "inactive_or_inconsistent"})
                continue
            baseline = session.scalar(select(StudentBaseline).where(
                StudentBaseline.class_id == class_id, StudentBaseline.user_id == member.user_id))
            if baseline is None or baseline.bi_source_record_id is None:
                pending.append({"pessoa_id": person, "status": "bi_link_pending"})
                continue
            if baseline.enrollment_id != member.enrollment_id:
                pending.append({"pessoa_id": person, "status": "enrollment_lineage_changed"})
                continue
            source = session.get(BaselineSourceRecord, baseline.bi_source_record_id)
            if source is None or source.user_id != member.user_id or source.source != BI_SOURCE:
                pending.append({"pessoa_id": person, "status": "bi_link_inconsistent"})
                continue
            # Canonical shared study projection. It is NOT classroom attendance.
            content = version.content if version else (course.content if course else {})
            offering = session.get(ProgramCourse, (classroom.program_id, classroom.course_id))
            planned = offering.planned_seconds if offering else 0
            progress = _student_progress(session, classroom=classroom, membership=member,
                user=session.get(User, member.user_id), planned_seconds=planned,
                expected_percent=0, now=now)
            certificate = session.scalar(select(CertificateReference).where(
                CertificateReference.user_id == member.user_id,
                CertificateReference.program_id == classroom.program_id,
                CertificateReference.course_id == classroom.course_id,
                CertificateReference.class_id == class_id,
                CertificateReference.issued_at >= member.enrolled_at,
            ).order_by(CertificateReference.issued_at.desc()).limit(1))
            # Only explicit class+edition evidence can be assigned to an inscription.
            events = session.scalars(select(LearningEventRecord).where(
                LearningEventRecord.user_id == member.user_id,
                LearningEventRecord.enrollment_id == member.enrollment_id,
                LearningEventRecord.course_id == classroom.course_id,
                LearningEventRecord.payload["class_id"].as_string() == class_id,
                LearningEventRecord.payload["course_version_id"].as_string() == classroom.course_version_id,
            )).all()
            last = max((event.occurred_at for event in events), default=None)
            items.append({
                "registro_id": source.record_id, "pessoa_id": person,
                "turma_id": class_id, "programa_id": classroom.program_id,
                "curso_id": classroom.course_id,
                "curso": content.get("title") or (course.title if course else classroom.course_id),
                "curso_versao_id": classroom.course_version_id,
                "matricula_contextual_id": member.context_id,
                "status_baseline": "Vínculo conferido", "vinculo_revisao": baseline.revision,
                "vinculo_conferido_em": _iso(baseline.reviewed_at),
                "carga_horaria_prevista": planned / 3600,
                "horas_estudo_validadas": progress.validated_hours,
                "progresso_estudo_percentual": progress.progress_percent,
                "frequencia_percentual": None, "concluiu_frequencia_flag": None,
                "certificado_flag": 1 if certificate else None,
                "certificado_emitido_em": _iso(certificate.issued_at) if certificate else None,
                "certificado_cobertura": "api_class_references_only",
                "elegivel_mentoria": None, "status_convite_mentoria": None,
                "mentor_id": None, "status_mentoria": None,
                "data_ultima_interacao": _iso(last), "interacoes_qtd": len(events),
                "plano_aplicacao_status": None, "aplicacao_iniciada_flag": None,
                "evidencia_validada_flag": None,
                "acompanhamento_30d": None, "acompanhamento_60d": None,
                "acompanhamento_90d": None, "encaminhamentos_qtd": None,
                "estagio_jornada": None, "data_proxima_acao": None,
                "status_qualidade": "confirmed_identity_partial_outcomes",
                "atualizado_em": _iso(now),
            })
        return {"contract": "tds-journey-v1", "generated_at": _iso(now),
                "class_id": class_id, "total": len(members), "offset": offset,
                "limit": limit, "items": items, "pending": pending}


@router.get("/classes/{class_id}/journey-activity")
def export_activity(class_id: str, request: Request, limit: int = Query(100, ge=1, le=500),
                    offset: int = Query(0, ge=0), since: datetime | None = None,
                    until: datetime | None = None, claims=Depends(access_claims)):
    """Account activity of enrolled participants; never infer class attribution.

    The event ID is the unique fact key. The same person's event returned by two
    authorized cohorts MUST be deduplicated by event_id by the export consumer.
    """
    settings = _enabled(request)
    if any(value is not None and (value.tzinfo is None or value.utcoffset() is None) for value in (since, until)):
        raise HTTPException(422, "Janela de atividade exige fuso horário.")
    if since and until and since >= until:
        raise HTTPException(422, "Janela de atividade inválida.")
    with Session(request.app.state.database.engine) as session:
        classroom = _scope(session, class_id, claims)
        secret = _secret(settings)
        owners = []
        for member in session.scalars(select(ClassEnrollment).where(ClassEnrollment.class_id == class_id)):
            if not _active_student(session, classroom, member.user_id):
                continue
            # Identity already exists in Auth+ClassEnrollment. A missing external
            # baseline is an explicit reconciliation task, not a reason to lose
            # the participant's consenting account activity.
            owners.append(member.user_id)
        query = select(LearningEventRecord).where(LearningEventRecord.user_id.in_(owners),
            LearningEventRecord.event_type.in_(["page_viewed", "resource_opened", "feature_used", "screen_engagement"]))
        if since: query = query.where(LearningEventRecord.occurred_at >= since)
        if until: query = query.where(LearningEventRecord.occurred_at < until)
        total = session.scalar(select(func.count()).select_from(query.subquery())) or 0
        events = session.scalars(query.order_by(LearningEventRecord.occurred_at, LearningEventRecord.event_id)
                                .offset(offset).limit(limit))
        # Stable taxonomy only. Never export free text from historical payloads.
        keys = {"page_viewed": "page_id", "screen_engagement": "page_id", "feature_used": "feature_id", "resource_opened": "resource_id"}
        items = []
        for event in events:
            key = keys[event.event_type]
            target = event.payload.get(key, "")
            if not isinstance(target, str) or not re.fullmatch(r"[a-z0-9][a-z0-9_.-]{0,79}", target):
                continue
            items.append({"event_id": event.event_id, "pessoa_id": _pseudonym(secret, event.user_id),
                "evento": event.event_type, "alvo_tipo": key, "alvo_id": target,
                "ocorreu_em": _iso(event.occurred_at), "segundos_tela": event.active_seconds if event.event_type == "screen_engagement" else None,
                "escopo": "conta_autenticada", "atribuicao_turma": None})
        return {"contract": "tds-activity-v1", "total": total, "offset": offset, "limit": limit, "items": items}
