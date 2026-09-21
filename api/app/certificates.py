from __future__ import annotations

import re
import json
from datetime import datetime, timezone
from urllib import request as urlrequest

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from pydantic import BaseModel, ConfigDict, Field, HttpUrl, field_validator
from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .auth import require_roles
from .config import Settings
from .database import Database
from .models import (
    CertificateReference,
    CertificateRequest,
    ClassEnrollment,
    Classroom,
    Course,
    Enrollment,
    Institution,
    Program,
    ProgramCourse,
    LearningEventRecord,
    User,
)

router = APIRouter(prefix="/certificates", tags=["certificates"])
student_claims = require_roles("student")
CONTENT_HASH = re.compile(r"^[0-9a-f]{64,128}$")


class CertificateReferenceCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: str = Field(min_length=8, max_length=120)
    program_id: str = Field(min_length=1, max_length=36)
    course_id: str = Field(min_length=1, max_length=120)
    class_id: str | None = Field(default=None, min_length=1, max_length=36)
    issued_at: datetime
    verification_url: HttpUrl
    content_hash: str

    @field_validator("issued_at")
    @classmethod
    def issued_at_has_timezone(cls, value: datetime) -> datetime:
        if value.tzinfo is None or value.utcoffset() is None:
            raise ValueError("issued_at deve conter fuso horário")
        return value.astimezone(timezone.utc)

    @field_validator("content_hash")
    @classmethod
    def valid_content_hash(cls, value: str) -> str:
        normalized = value.lower()
        if not CONTENT_HASH.fullmatch(normalized):
            raise ValueError("content_hash deve ser hexadecimal SHA-256/512")
        return normalized


class CertificateReferenceResponse(BaseModel):
    id: str
    user_id: str
    program_id: str | None
    course_id: str
    class_id: str | None
    holder_name: str | None
    course_title: str | None
    institution_name: str | None
    planned_hours: float | None
    issued_at: datetime
    verification_url: str
    content_hash: str


class CertificatePage(BaseModel):
    certificates: list[CertificateReferenceResponse]


@router.post("/references", response_model=CertificateReferenceResponse, status_code=201)
def create_reference(
    payload: CertificateReferenceCreate,
    request: Request,
    response: Response,
    claims: dict[str, str] = Depends(student_claims),
) -> CertificateReferenceResponse:
    settings: Settings = request.app.state.settings
    prefix = settings.certificate_verification_url_prefix
    if not prefix or not prefix.startswith("https://") or not prefix.endswith("/"):
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Origem de verificação de certificados não configurada.",
        )
    verification_url = str(payload.verification_url)
    if not verification_url.startswith(prefix):
        raise HTTPException(
            status_code=422,
            detail="URL de verificação fora da origem autorizada.",
        )
    if payload.issued_at > datetime.now(timezone.utc):
        raise HTTPException(status_code=422, detail="Data de emissão futura.")

    database: Database = request.app.state.database
    with Session(database.engine) as session:
        existing = session.get(CertificateReference, payload.id)
        if existing is not None:
            if _same_reference(existing, payload, claims["sub"], verification_url):
                response.status_code = 200
                return _serialize(existing)
            raise HTTPException(status_code=409, detail="Código de certificado em conflito.")

        enrollment = session.scalar(
            select(Enrollment).where(
                Enrollment.user_id == claims["sub"],
                Enrollment.program_id == payload.program_id,
                Enrollment.course_id == payload.course_id,
                Enrollment.status == "active",
            )
        )
        if enrollment is None:
            raise HTTPException(status_code=422, detail="Matrícula ativa não encontrada.")
        if settings.certificate_approval_required:
            approved = session.scalar(select(CertificateRequest).where(
                CertificateRequest.enrollment_id == enrollment.id,
                CertificateRequest.user_id == claims["sub"],
                CertificateRequest.status == "approved",
            ))
            if approved is None:
                raise HTTPException(status_code=422, detail="Emissão exige aprovação humana da matrícula e edição.")
            if payload.class_id is not None and approved.class_id != payload.class_id:
                raise HTTPException(status_code=422, detail="A aprovação não corresponde à turma informada.")
        offering = session.get(
            ProgramCourse, (payload.program_id, payload.course_id)
        )
        course = session.get(Course, payload.course_id)
        program = session.get(Program, payload.program_id)
        user = session.get(User, claims["sub"])
        if offering is None or course is None or program is None or user is None:
            raise HTTPException(status_code=409, detail="Hierarquia acadêmica inconsistente.")
        institution = session.get(Institution, program.institution_id)
        if institution is None:
            raise HTTPException(status_code=409, detail="Instituição inconsistente.")
        if payload.class_id is not None:
            classroom = session.get(Classroom, payload.class_id)
            class_enrollment = session.get(
                ClassEnrollment, (payload.class_id, claims["sub"])
            )
            if (
                classroom is None
                or class_enrollment is None
                or class_enrollment.status != "active"
                or class_enrollment.enrollment_id != enrollment.id
                or classroom.program_id != payload.program_id
                or classroom.course_id != payload.course_id
            ):
                raise HTTPException(
                    status_code=422,
                    detail="Certificado não pertence a uma turma ativa do estudante.",
                )

        validated = session.scalar(
            select(func.coalesce(func.sum(LearningEventRecord.validated_seconds), 0)).where(
                LearningEventRecord.enrollment_id == enrollment.id,
                LearningEventRecord.event_type == "study_activity",
            )
        )
        completed = session.scalar(
            select(LearningEventRecord.event_id).where(
                LearningEventRecord.enrollment_id == enrollment.id,
                LearningEventRecord.event_type == "lesson_completed",
            )
        )
        if int(validated or 0) < offering.planned_seconds or completed is None:
            raise HTTPException(
                status_code=422,
                detail="Carga horária/conclusão ainda não elegível para certificado.",
            )
        _verify_public_certificate(
            verification_url,
            certificate_id=payload.id,
            course_id=payload.course_id,
            holder_name=user.name,
            content_hash=payload.content_hash,
        )

        record = CertificateReference(
            id=payload.id,
            user_id=claims["sub"],
            program_id=payload.program_id,
            course_id=payload.course_id,
            class_id=payload.class_id,
            holder_name=user.name,
            course_title=course.title,
            institution_name=institution.name,
            planned_seconds=offering.planned_seconds,
            issued_at=payload.issued_at,
            verification_url=verification_url,
            content_hash=payload.content_hash,
        )
        session.add(record)
        try:
            session.commit()
        except IntegrityError as exc:
            session.rollback()
            raise HTTPException(
                status_code=409, detail="Não foi possível registrar o certificado."
            ) from exc
        return _serialize(record)


@router.get("", response_model=CertificatePage)
def own_certificates(
    request: Request,
    claims: dict[str, str] = Depends(student_claims),
) -> CertificatePage:
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        records = session.scalars(
            select(CertificateReference)
            .where(CertificateReference.user_id == claims["sub"])
            .order_by(
                CertificateReference.issued_at.desc(),
                CertificateReference.id,
            )
        ).all()
        return CertificatePage(certificates=[_serialize(record) for record in records])


def _same_reference(
    record: CertificateReference,
    payload: CertificateReferenceCreate,
    user_id: str,
    verification_url: str,
) -> bool:
    issued_at = record.issued_at
    if issued_at.tzinfo is None:
        issued_at = issued_at.replace(tzinfo=timezone.utc)
    return (
        record.user_id == user_id
        and record.program_id == payload.program_id
        and record.course_id == payload.course_id
        and record.class_id == payload.class_id
        and issued_at.astimezone(timezone.utc) == payload.issued_at
        and record.verification_url == verification_url
        and record.content_hash == payload.content_hash
    )


def _has_snapshot(record: CertificateReference) -> bool:
    return all(
        value is not None
        for value in (
            record.program_id,
            record.holder_name,
            record.course_title,
            record.institution_name,
            record.planned_seconds,
        )
    )


def _serialize(record: CertificateReference) -> CertificateReferenceResponse:
    return CertificateReferenceResponse(
        id=record.id,
        user_id=record.user_id,
        program_id=record.program_id,
        course_id=record.course_id,
        class_id=record.class_id,
        holder_name=record.holder_name,
        course_title=record.course_title,
        institution_name=record.institution_name,
        planned_hours=(round(record.planned_seconds / 3600, 4) if record.planned_seconds is not None else None),
        issued_at=record.issued_at,
        verification_url=record.verification_url,
        content_hash=record.content_hash,
    )


def _verify_public_certificate(
    verification_url: str,
    *,
    certificate_id: str,
    course_id: str,
    holder_name: str,
    content_hash: str,
) -> None:
    try:
        with urlrequest.urlopen(verification_url, timeout=5) as response:
            document = json.loads(response.read())
    except Exception as exc:
        raise HTTPException(status_code=503, detail="Verificação pública indisponível.") from exc
    certificate = document.get("certificate") if document.get("valid") is True else None
    if not isinstance(certificate, dict):
        raise HTTPException(status_code=422, detail="Certificado público inválido.")
    actual = {
        "id": certificate.get("id"),
        "course": certificate.get("courseId", certificate.get("course_id")),
        "holder": certificate.get("holderName", certificate.get("holder_name")),
        "hash": certificate.get("contentHash", certificate.get("content_hash")),
    }
    expected = {"id": certificate_id, "course": course_id, "holder": holder_name, "hash": content_hash}
    if actual != expected:
        raise HTTPException(status_code=422, detail="Certificado público divergente.")
