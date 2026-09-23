from __future__ import annotations

import hashlib
import hmac
import json
import os
import re
import sys
from collections.abc import Mapping
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone

from fastapi import HTTPException
from pwdlib.exceptions import UnknownHashError
from sqlalchemy import Engine, select
from sqlalchemy.engine import make_url
from sqlalchemy.exc import ArgumentError, IntegrityError
from sqlalchemy.orm import Session

from .auth import _valid_cpf, password_hash
from .config import Settings
from .database import Database
from .context_memberships import bind_membership, bind_student
from .course_editor import ensure_legacy_course_version, latest_published_version
from .models import (
    AssessmentAttemptRecord,
    AssessmentContentRecord,
    ClassEnrollment,
    ClassMonitor,
    Classroom,
    CohortMembership,
    ClassSession,
    Course,
    CourseVersion,
    Enrollment,
    EvidenceImport,
    EvidenceItem,
    Institution,
    LearningEventRecord,
    MediaAsset,
    Program,
    ProgramCourse,
    ProgramMembership,
    User,
)

CONFIRMATION = "SEED_SYNTHETIC_STAGING_DATA"
IDS = {
    "institution": "staging-qa-institution",
    "program": "staging-qa-program",
    "course": "staging-qa-course",
    "classroom": "staging-qa-class",
    "session": "staging-qa-class-session",
    "evidence_import": "staging-qa-evidence-import",
    "evidence": "staging-qa-evidence-item",
    "assessment": "staging-qa-assessment-attempt",
    "assessment_content": "staging-qa-assessment-content",
    "media": "staging-qa-media",
    "enrollment": "staging-qa-enrollment",
    "admin": "staging-qa-admin",
    "teacher": "staging-qa-teacher",
    "monitor": "staging-qa-monitor",
    "student": "staging-qa-student",
}
PUBLIC_TEST_HLS = "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8"
CERTIFICATE_PLANNED_SECONDS = 8 * 60 * 60


@dataclass(frozen=True)
class SeedAccount:
    cpf: str
    phone: str
    password: str


@dataclass(frozen=True)
class SeedCredentials:
    admin: SeedAccount
    teacher: SeedAccount
    monitor: SeedAccount
    student: SeedAccount
    checkin_token: str

    @classmethod
    def from_environment(
        cls,
        environment: Mapping[str, str] | None = None,
    ) -> "SeedCredentials":
        values = environment if environment is not None else os.environ

        def account(role: str) -> SeedAccount:
            prefix = f"STAGING_SEED_{role.upper()}_"
            return SeedAccount(
                cpf=_required(values, prefix + "CPF"),
                phone=_required(values, prefix + "PHONE"),
                password=_required(values, prefix + "PASSWORD"),
            )

        credentials = cls(
            admin=account("admin"),
            teacher=account("teacher"),
            monitor=account("monitor"),
            student=account("student"),
            checkin_token=_required(values, "STAGING_SEED_CHECKIN_TOKEN"),
        )
        credentials.validate()
        return credentials

    def validate(self) -> None:
        normalized_cpfs: set[str] = set()
        for role, account in self.accounts().items():
            try:
                cpf = _valid_cpf(account.cpf)
            except HTTPException as exc:
                raise RuntimeError(f"CPF sintético inválido para {role}.") from exc
            if cpf in normalized_cpfs:
                raise RuntimeError("CPFs sintéticos devem ser distintos.")
            normalized_cpfs.add(cpf)
            phone = re.sub(r"\D", "", account.phone)
            if not 10 <= len(phone) <= 15:
                raise RuntimeError(f"Telefone sintético inválido para {role}.")
            if not 12 <= len(account.password) <= 128:
                raise RuntimeError(f"Senha sintética inválida para {role}.")
        if not 16 <= len(self.checkin_token) <= 200:
            raise RuntimeError("STAGING_SEED_CHECKIN_TOKEN deve ter 16 a 200 caracteres.")

    def accounts(self) -> dict[str, SeedAccount]:
        return {
            "admin": self.admin,
            "teacher": self.teacher,
            "monitor": self.monitor,
            "student": self.student,
        }


@dataclass(frozen=True)
class SeedSummary:
    created: dict[str, int]

    @property
    def total_created(self) -> int:
        return sum(self.created.values())


def validate_staging_target(
    *,
    environment: str | None,
    database_url: str,
    confirmation: str | None,
) -> None:
    if environment != "staging":
        raise RuntimeError("Seed permitido somente com TUTOR_ENVIRONMENT=staging.")
    if confirmation != CONFIRMATION:
        raise RuntimeError(
            f"Confirmação ausente: STAGING_SEED_CONFIRM deve ser {CONFIRMATION}."
        )
    try:
        target = make_url(database_url)
    except ArgumentError as exc:
        raise RuntimeError("DATABASE_URL inválida para o seed.") from exc
    host = (target.host or "").lower()
    database = (target.database or "").lower()
    if target.get_backend_name() != "postgresql":
        raise RuntimeError("Seed real exige PostgreSQL de staging.")
    if "staging" not in host or "staging" not in database:
        raise RuntimeError(
            "Host e nome do banco devem conter 'staging'; produção/local são recusados."
        )


def seed_staging_data(
    engine: Engine,
    settings: Settings,
    credentials: SeedCredentials,
) -> SeedSummary:
    credentials.validate()
    _, cpf_pepper = settings.require_auth_secrets()
    now = datetime.now(timezone.utc).replace(microsecond=0)
    created: dict[str, int] = {}

    with Session(engine) as session:
        try:
            users: dict[str, User] = {}
            user_spec = {
                "admin": ("Administrador QA [STAGING]", "admin"),
                "teacher": ("Professor QA [STAGING]", "student"),
                "monitor": ("Monitor QA [STAGING]", "student"),
                "student": ("Aluno QA [STAGING]", "student"),
            }
            for role, account in credentials.accounts().items():
                name, global_role = user_spec[role]
                users[role], was_created = _ensure_user(
                    session,
                    user_id=IDS[role],
                    name=name,
                    global_role=global_role,
                    account=account,
                    cpf_pepper=cpf_pepper,
                )
                _count(created, "users", was_created)

            institution, was_created = _ensure(
                session,
                Institution,
                IDS["institution"],
                Institution(id=IDS["institution"], name="Instituição Sintética QA [STAGING]"),
            )
            institution.name = "Instituição Sintética QA [STAGING]"
            _count(created, "institutions", was_created)

            program, was_created = _ensure(
                session,
                Program,
                IDS["program"],
                Program(
                    id=IDS["program"],
                    institution_id=institution.id,
                    name="Programa Sintético QA [STAGING]",
                ),
            )
            _require_equal(program.institution_id, institution.id, "program.institution_id")
            program.name = "Programa Sintético QA [STAGING]"
            _count(created, "programs", was_created)

            course_content = {
                "sections": [
                    {
                        "id": "boas-vindas-qa",
                        "title": "Boas-vindas ao ambiente de QA",
                        "messages": [
                            {
                                "type": "bot",
                                "content": "Este conteúdo é totalmente sintético e existe somente para validar o aplicativo em staging.",
                            },
                            {
                                "type": "question",
                                "content": "O ambiente exibido é o staging de testes?",
                                "options": [
                                    {"label": "Sim", "value": "sim", "feedback": "Correto: nenhum dado desta turma é real."},
                                    {"label": "Não", "value": "nao", "feedback": "Confirme a URL de staging antes de continuar."},
                                ],
                            },
                        ],
                    }
                ],
                "downloadUrl": None,
                "thumbnailUrl": None,
            }
            course, was_created = _ensure(
                session,
                Course,
                IDS["course"],
                Course(
                    id=IDS["course"],
                    title="Curso Sintético QA [STAGING]",
                    author="Tutor TDS - dados sintéticos",
                    content=course_content,
                    active=True,
                ),
            )
            course.title = "Curso Sintético QA [STAGING]"
            course.author = "Tutor TDS - dados sintéticos"
            course.content = course_content
            course.active = True
            _count(created, "courses", was_created)
            session.flush()

            offering, was_created = _ensure(
                session,
                ProgramCourse,
                (program.id, course.id),
                ProgramCourse(
                    program_id=program.id,
                    course_id=course.id,
                    planned_seconds=CERTIFICATE_PLANNED_SECONDS,
                ),
            )
            offering.planned_seconds = CERTIFICATE_PLANNED_SECONDS
            _count(created, "offerings", was_created)

            membership_roles = {
                "admin": "creator",
                "teacher": "teacher",
                "monitor": "monitor",
                "student": "student",
            }
            for role, member_role in membership_roles.items():
                membership, was_created = _ensure(
                    session,
                    ProgramMembership,
                    (users[role].id, program.id),
                    ProgramMembership(
                        user_id=users[role].id,
                        program_id=program.id,
                        role=member_role,
                        status="active",
                    ),
                )
                membership.role = member_role
                membership.status = "active"
                _count(created, "memberships", was_created)
            session.flush()

            enrollment, was_created = _ensure(
                session,
                Enrollment,
                IDS["enrollment"],
                Enrollment(
                    id=IDS["enrollment"],
                    user_id=users["student"].id,
                    program_id=program.id,
                    course_id=course.id,
                    status="active",
                ),
            )
            _require_equal(enrollment.user_id, users["student"].id, "enrollment.user_id")
            _require_equal(enrollment.program_id, program.id, "enrollment.program_id")
            _require_equal(enrollment.course_id, course.id, "enrollment.course_id")
            enrollment.status = "active"
            _count(created, "enrollments", was_created)

            existing_version = session.scalar(select(CourseVersion.id).where(CourseVersion.course_id == course.id).limit(1))
            seed_version = latest_published_version(session, course.id)
            if seed_version is None:
                seed_version = ensure_legacy_course_version(session, course)
            if seed_version.status not in {"published", "archived"}:
                raise ValueError("Synthetic classroom requires a published edition")
            _count(created, "course_versions", existing_version is None)
            _count(created, "course_version_transitions", existing_version is None)
            classroom, was_created = _ensure(
                session,
                Classroom,
                IDS["classroom"],
                Classroom(
                    id=IDS["classroom"],
                    program_id=program.id,
                    course_id=course.id,
                    course_version_id=seed_version.id,
                    teacher_id=users["teacher"].id,
                    name="Turma Sintética QA [STAGING]",
                    start_date=(now - timedelta(days=30)).date(),
                    end_date=(now + timedelta(days=365)).date(),
                    status="active",
                ),
            )
            _require_equal(classroom.program_id, program.id, "classroom.program_id")
            _require_equal(classroom.course_id, course.id, "classroom.course_id")
            _require_equal(classroom.teacher_id, users["teacher"].id, "classroom.teacher_id")
            classroom.name = "Turma Sintética QA [STAGING]"
            classroom.start_date = (now - timedelta(days=30)).date()
            classroom.end_date = (now + timedelta(days=365)).date()
            classroom.status = "active"
            _count(created, "classes", was_created)
            session.flush()

            student_link, was_created = _ensure(
                session,
                ClassEnrollment,
                (classroom.id, users["student"].id),
                ClassEnrollment(
                    class_id=classroom.id,
                    user_id=users["student"].id,
                    enrollment_id=enrollment.id,
                    program_id=program.id,
                    course_id=course.id,
                    status="active",
                ),
            )
            _count(created, "class_enrollments", was_created)
            _, was_created = _ensure(
                session,
                ClassMonitor,
                (classroom.id, users["monitor"].id),
                ClassMonitor(
                    class_id=classroom.id,
                    user_id=users["monitor"].id,
                    program_id=program.id,
                ),
            )
            _count(created, "class_monitors", was_created)
            session.flush()
            previous_bindings = set(session.scalars(select(CohortMembership.id).where(CohortMembership.class_id == classroom.id)))
            bind_membership(session, classroom.id, users["teacher"].id, "teacher", preserve_inactive=True)
            bind_membership(session, classroom.id, users["monitor"].id, "monitor", preserve_inactive=True)
            bind_student(session, classroom, student_link, preserve_inactive=True)
            for identity in session.scalars(select(CohortMembership.id).where(CohortMembership.class_id == classroom.id)):
                _count(created, "cohort_memberships", identity not in previous_bindings)

            class_session, was_created = _ensure(
                session,
                ClassSession,
                IDS["session"],
                ClassSession(
                    id=IDS["session"],
                    class_id=classroom.id,
                    starts_at=now - timedelta(hours=1),
                    ends_at=now + timedelta(days=30),
                    status="open",
                    opened_by=users["teacher"].id,
                    closed_by=None,
                    checkin_token_digest=_sha256(credentials.checkin_token),
                    token_expires_at=now + timedelta(hours=8),
                    token_version=1,
                ),
            )
            token_digest = _sha256(credentials.checkin_token)
            token_expires_at = class_session.token_expires_at
            if token_expires_at.tzinfo is None or token_expires_at.utcoffset() is None:
                token_expires_at = token_expires_at.replace(tzinfo=timezone.utc)
            if class_session.status == "open" and (
                class_session.checkin_token_digest != token_digest
                or token_expires_at <= now
            ):
                class_session.checkin_token_digest = token_digest
                class_session.token_expires_at = now + timedelta(hours=8)
                class_session.token_version += 1
            _count(created, "class_sessions", was_created)

            evidence_import, was_created = _ensure(
                session,
                EvidenceImport,
                IDS["evidence_import"],
                EvidenceImport(
                    id=IDS["evidence_import"],
                    class_id=classroom.id,
                    source_type="manual_metadata",
                    status="pending_review",
                    imported_by=users["monitor"].id,
                    retention_until=now + timedelta(days=365),
                    source_digest=_sha256("staging-qa-evidence-source-v1"),
                    idempotency_key="staging:qa:evidence:import:v1",
                ),
            )
            _count(created, "evidence_imports", was_created)
            _, was_created = _ensure(
                session,
                EvidenceItem,
                IDS["evidence"],
                EvidenceItem(
                    id=IDS["evidence"],
                    import_id=evidence_import.id,
                    class_id=classroom.id,
                    session_id=class_session.id,
                    user_id=users["student"].id,
                    evidence_type="observation",
                    occurred_at=now,
                    confidence_basis_points=0,
                    review_status="pending",
                    object_reference=None,
                    item_digest=_sha256("staging-qa-evidence-item-v1"),
                    metadata_json={"source_item_id": "synthetic-observation-1"},
                ),
            )
            _count(created, "evidence_items", was_created)

            assessment_questions = [
                {
                    "question": "Este ambiente contém somente dados sintéticos?",
                    "options": ["Sim", "Não"],
                    "topic": "Ambiente de QA",
                }
            ]
            assessment_answer_key = [
                {
                    "correct_index": 0,
                    "explanation": "Todo o conteúdo desta turma é sintético.",
                }
            ]
            assessment_canonical = {
                "course_id": course.id,
                "topic": "Conteúdo sintético de QA",
                "mode": "exam",
                "title": "Simulado sintético de QA",
                "duration_seconds": 600,
                "questions": assessment_questions,
                "answer_key": assessment_answer_key,
            }
            _, was_created = _ensure(
                session,
                AssessmentContentRecord,
                IDS["assessment_content"],
                AssessmentContentRecord(
                    id=IDS["assessment_content"],
                    owner_id=users["student"].id,
                    course_id=course.id,
                    topic="Conteúdo sintético de QA",
                    mode="exam",
                    title="Simulado sintético de QA",
                    duration_seconds=600,
                    questions=assessment_questions,
                    answer_key=assessment_answer_key,
                    content_digest=_sha256(json.dumps(
                        assessment_canonical,
                        ensure_ascii=False,
                        separators=(",", ":"),
                        sort_keys=True,
                    )),
                ),
            )
            _count(created, "assessment_contents", was_created)

            assessment_attempt, was_created = _ensure(
                session,
                AssessmentAttemptRecord,
                IDS["assessment"],
                AssessmentAttemptRecord(
                    attempt_id=IDS["assessment"],
                    owner_id=users["student"].id,
                    course_id=course.id,
                    assessment_content_id=IDS["assessment_content"],
                    topic="Conteúdo sintético de QA",
                    mode="exam",
                    revision=1,
                    answers={"0": 0},
                    marked=[1],
                    current_index=1,
                    remaining_seconds=600,
                    completed=False,
                    score=0,
                    updated_at=now,
                ),
            )
            if assessment_attempt.assessment_content_id is None:
                assessment_attempt.assessment_content_id = IDS["assessment_content"]
            _require_equal(
                assessment_attempt.assessment_content_id,
                IDS["assessment_content"],
                "assessment_attempt.assessment_content_id",
            )
            _count(created, "assessment_attempts", was_created)

            media, was_created = _ensure(
                session,
                MediaAsset,
                IDS["media"],
                MediaAsset(
                    id=IDS["media"],
                    institution_id=institution.id,
                    program_id=program.id,
                    course_id=course.id,
                    module_id="modulo-qa",
                    creator_user_id=users["admin"].id,
                    title="Vídeo público de teste [STAGING]",
                    description="Stream público usado somente para validação técnica do player em staging.",
                    competency_id="competencia-qa",
                    provider="external_hls",
                    provider_asset_id=PUBLIC_TEST_HLS,
                    duration_seconds=634,
                    thumbnail_url=None,
                    captions=[],
                    visibility="institution",
                    offline_policy="forbidden",
                    status="published",
                    master_drive_file_id=None,
                    rights_confirmed=True,
                    followup_activity_id="quiz-qa",
                    published_at=now,
                    published_by=users["admin"].id,
                ),
            )
            _count(created, "media", was_created)

            event_specs = [
                (
                    "staging-qa-study-activity",
                    "study_activity",
                    CERTIFICATE_PLANNED_SECONDS,
                    CERTIFICATE_PLANNED_SECONDS,
                    {"fixture": "certificate_eligibility"},
                ),
                (
                    "staging-qa-lesson-completed",
                    "lesson_completed",
                    0,
                    0,
                    {},
                ),
            ]
            for event_id, event_type, active, validated, payload in event_specs:
                learning_event, was_created = _ensure(
                    session,
                    LearningEventRecord,
                    event_id,
                    LearningEventRecord(
                        event_id=event_id,
                        user_id=users["student"].id,
                        enrollment_id=enrollment.id,
                        course_id=course.id,
                        event_type=event_type,
                        session_id="staging-qa-learning-session",
                        occurred_at=now,
                        payload=payload,
                        active_seconds=active,
                        validated_seconds=validated,
                        sync_status="pending",
                    ),
                )
                # The fixture intentionally represents an already completed,
                # synthetic curriculum. Keep reruns deterministic so staging
                # can exercise certificate eligibility without real activity.
                learning_event.active_seconds = active
                learning_event.validated_seconds = validated
                learning_event.payload = payload
                _count(created, "learning_events", was_created)

            session.commit()
        except (IntegrityError, RuntimeError):
            session.rollback()
            raise

    return SeedSummary(created=created)


def _ensure_user(
    session: Session,
    *,
    user_id: str,
    name: str,
    global_role: str,
    account: SeedAccount,
    cpf_pepper: str,
) -> tuple[User, bool]:
    normalized_cpf = _valid_cpf(account.cpf)
    cpf_digest = hmac.new(
        cpf_pepper.encode(), normalized_cpf.encode(), hashlib.sha256
    ).hexdigest()
    phone = re.sub(r"\D", "", account.phone)
    existing = session.get(User, user_id)
    collision = session.scalar(select(User).where(User.cpf_digest == cpf_digest))
    if collision is not None and collision.id != user_id:
        raise RuntimeError("CPF sintético já pertence a outro usuário no staging.")
    if existing is None:
        record = User(
            id=user_id,
            cpf_digest=cpf_digest,
            phone=phone,
            name=name,
            role=global_role,
            password_digest=password_hash.hash(account.password),
        )
        session.add(record)
        return record, True
    if existing.cpf_digest != cpf_digest or existing.phone != phone:
        raise RuntimeError("Credenciais do seed divergiram do usuário sintético existente.")
    try:
        valid_password = password_hash.verify(account.password, existing.password_digest)
    except UnknownHashError as exc:
        raise RuntimeError("Hash de senha inválido no usuário sintético existente.") from exc
    if not valid_password:
        raise RuntimeError("Senha do seed divergiu do usuário sintético existente.")
    existing.name = name
    existing.role = global_role
    return existing, False


def _ensure(session: Session, model, identity, record):
    existing = session.get(model, identity)
    if existing is not None:
        return existing, False
    session.add(record)
    return record, True


def _count(counts: dict[str, int], key: str, created: bool) -> None:
    counts[key] = counts.get(key, 0) + int(created)


def _require_equal(actual: str, expected: str, field: str) -> None:
    if actual != expected:
        raise RuntimeError(f"Registro sintético existente possui {field} divergente.")


def _sha256(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def _required(values: Mapping[str, str], name: str) -> str:
    value = values.get(name, "").strip()
    if not value:
        raise RuntimeError(f"Variável obrigatória ausente: {name}.")
    return value


def main() -> None:
    settings = Settings.from_environment()
    try:
        validate_staging_target(
            environment=os.getenv("TUTOR_ENVIRONMENT"),
            database_url=settings.database_url,
            confirmation=os.getenv("STAGING_SEED_CONFIRM"),
        )
        credentials = SeedCredentials.from_environment()
        database = Database(settings.database_url)
        try:
            summary = seed_staging_data(database.engine, settings, credentials)
        finally:
            database.dispose()
    except (HTTPException, IntegrityError, RuntimeError, ValueError) as exc:
        detail = exc.detail if isinstance(exc, HTTPException) else str(exc)
        print(f"Seed recusado: {detail}", file=sys.stderr)
        raise SystemExit(2) from exc
    print(
        "Seed sintético de staging concluído; "
        f"{summary.total_created} registro(s) novo(s), sem duplicação."
    )


if __name__ == "__main__":
    main()
