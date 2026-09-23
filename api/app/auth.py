from __future__ import annotations

import hashlib
import hmac
import re
import secrets
from collections.abc import Callable
from datetime import datetime, timedelta, timezone
from uuid import uuid4

import jwt
from fastapi import APIRouter, Depends, Header, HTTPException, Request, Response, status
from jwt.exceptions import InvalidTokenError
from pydantic import BaseModel, Field, SecretStr
from pwdlib import PasswordHash
from pwdlib.exceptions import UnknownHashError
from sqlalchemy import delete, select, update
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .config import Settings
from .database import Database
from .models import (
    AssessmentAttemptRecord,
    AssessmentContentRecord,
    BaselineRevision,
    BaselineSourceRecord,
    CertificateReference,
    CertificateRequest,
    CertificateRequestTransition,
    ClassEnrollment,
    ClassCheckin,
    ClassMonitor,
    Classroom,
    CohortMembership,
    CourseVersion,
    CourseVersionTransition,
    Enrollment,
    EvidenceItem,
    LearningEventRecord,
    MediaEventRecord,
    MediaPlaybackGrant,
    MediaRating,
    MentorshipCase,
    MentorshipRevision,
    ProgramMembership,
    ReviewDecision,
    SessionToken,
    SessionPresence,
    SessionPresenceDecision,
    StudentBaseline,
    SyncLog,
    SyncDeletionRequest,
    User,
)

router = APIRouter(prefix="/auth", tags=["auth"])
password_hash = PasswordHash.recommended()
dummy_password_digest = password_hash.hash(secrets.token_urlsafe(32))


class RegisterRequest(BaseModel):
    name: str = Field(min_length=2, max_length=240)
    cpf: SecretStr
    phone: str = Field(min_length=10, max_length=32)
    password: SecretStr


class LoginRequest(BaseModel):
    cpf: SecretStr
    password: SecretStr


class RefreshRequest(BaseModel):
    refresh_token: SecretStr


class PublicUser(BaseModel):
    id: str
    name: str
    role: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int
    user: PublicUser


@router.post("/register", response_model=TokenResponse, status_code=201)
def register(payload: RegisterRequest, request: Request) -> TokenResponse:
    service, session = _service(request)
    try:
        user = service.register(payload)
        response = service.issue_tokens(user)
        session.commit()
        return response
    except IntegrityError as error:
        session.rollback()
        raise HTTPException(status_code=409, detail="Usuário já cadastrado.") from error
    finally:
        session.close()


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, request: Request) -> TokenResponse:
    service, session = _service(request)
    try:
        user = service.authenticate(payload)
        response = service.issue_tokens(user)
        session.commit()
        return response
    finally:
        session.close()


@router.post("/refresh", response_model=TokenResponse)
def refresh(payload: RefreshRequest, request: Request) -> TokenResponse:
    service, session = _service(request)
    try:
        response = service.rotate_refresh(payload.refresh_token.get_secret_value())
        session.commit()
        return response
    finally:
        session.close()


def access_claims(
    request: Request,
    authorization: str | None = Header(default=None),
) -> dict[str, str]:
    service, session = _service(request)
    try:
        claims = service.decode_access(_bearer_token(authorization))
        user = session.get(User, claims["sub"])
        if user is None or user.role != claims["role"]:
            raise _unauthorized()
        return claims
    finally:
        session.close()


def optional_access_claims(
    request: Request,
    authorization: str | None = Header(default=None),
) -> dict[str, str] | None:
    if authorization is None:
        return None
    return access_claims(request, authorization)


def require_roles(*allowed_roles: str) -> Callable[..., dict[str, str]]:
    allowed = frozenset(allowed_roles)
    if not allowed:
        raise ValueError("Informe ao menos uma função permitida.")

    def authorized_role(
        claims: dict[str, str] = Depends(access_claims),
    ) -> dict[str, str]:
        if claims["role"] not in allowed:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Acesso não autorizado para esta função.",
            )
        return claims

    return authorized_role


@router.get("/me", response_model=PublicUser)
def me(
    request: Request,
    claims: dict[str, str] = Depends(access_claims),
) -> PublicUser:
    database: Database = request.app.state.database
    session = Session(database.engine)
    try:
        user = session.get(User, claims["sub"])
        if user is None:
            raise _unauthorized()
        return _public_user(user)
    finally:
        session.close()


@router.delete("/me", status_code=status.HTTP_204_NO_CONTENT)
def delete_me(
    request: Request,
    claims: dict[str, str] = Depends(require_roles("student")),
) -> Response:
    """Remove a conta do estudante e todos os dados transacionais associados."""
    database: Database = request.app.state.database
    session = Session(database.engine)
    user_id = claims["sub"]
    try:
        # Contas de equipe não podem ser apagadas por este fluxo de autoatendimento.
        # A checagem também protege dados inconsistentes que tenham sido promovidos
        # sem a atualização correspondente da função global.
        if session.scalar(select(Classroom.id).where(Classroom.teacher_id == user_id)):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Conta vinculada a uma turma. Solicite a exclusão à equipe TDS.",
            )
        if session.scalar(select(ClassMonitor.class_id).where(ClassMonitor.user_id == user_id)) or session.scalar(
            select(ProgramMembership.user_id).where(
                ProgramMembership.user_id == user_id,
                ProgramMembership.status == "active",
                ProgramMembership.role != "student",
            )
        ):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Conta de equipe/creator exige exclusão assistida para preservar registros institucionais.",
            )

        event_id_values = list(session.scalars(select(LearningEventRecord.event_id).where(
            LearningEventRecord.user_id == user_id
        )))
        event_ids = select(LearningEventRecord.event_id).where(LearningEventRecord.user_id == user_id)
        for event_id in event_id_values:
            if session.scalar(select(SyncDeletionRequest.id).where(SyncDeletionRequest.event_id == event_id)) is None:
                session.add(SyncDeletionRequest(id=str(uuid4()), event_id=event_id, status="pending"))
        session.execute(delete(SyncLog).where(SyncLog.event_id.in_(event_ids)))
        session.execute(
            delete(MediaEventRecord).where(MediaEventRecord.user_id == user_id)
        )
        session.execute(delete(MediaRating).where(MediaRating.user_id == user_id))
        session.execute(
            delete(MediaPlaybackGrant).where(MediaPlaybackGrant.user_id == user_id)
        )
        session.execute(
            delete(LearningEventRecord).where(LearningEventRecord.user_id == user_id)
        )
        session.execute(
            delete(CertificateReference).where(CertificateReference.user_id == user_id)
        )
        # Private certificate requests contain the learner's name. Delete their
        # entire history before removing enrollment/user lineage (also on SQLite
        # without FK enforcement). Reviewers of other requests are anonymized.
        request_ids = list(session.scalars(select(CertificateRequest.id).where(CertificateRequest.user_id == user_id)))
        session.execute(delete(CertificateRequest).where(CertificateRequest.user_id == user_id))
        if request_ids:
            session.execute(delete(CertificateRequestTransition).where(CertificateRequestTransition.request_id.in_(request_ids)))
        session.execute(update(CertificateRequestTransition).where(CertificateRequestTransition.actor_user_id == user_id).values(actor_user_id=None))
        # Presence snapshots and reasons are private learner data. Erase the
        # parent first; immutable history permits deletion only after this.
        presence_ids = list(session.scalars(select(SessionPresence.id).where(SessionPresence.user_id == user_id)))
        session.execute(delete(SessionPresence).where(SessionPresence.user_id == user_id))
        if presence_ids:
            session.execute(delete(SessionPresenceDecision).where(SessionPresenceDecision.presence_id.in_(presence_ids)))
        session.execute(update(SessionPresenceDecision).where(SessionPresenceDecision.actor_user_id == user_id).values(actor_user_id=None))
        # Baseline references and mentorship narratives never outlive their owner.
        # Actor/mentor IDs in other people's audit are separate nullable FKs;
        # immutable JSON snapshots do not duplicate those identifiers.
        for parent, history, history_fk in ((StudentBaseline, BaselineRevision, BaselineRevision.baseline_id), (MentorshipCase, MentorshipRevision, MentorshipRevision.case_id)):
            owned_ids = list(session.scalars(select(parent.id).where(parent.user_id == user_id)))
            session.execute(delete(parent).where(parent.user_id == user_id))
            if owned_ids:
                session.execute(delete(history).where(history_fk.in_(owned_ids)))
            session.execute(update(history).where(history.actor_user_id == user_id).values(actor_user_id=None))
        session.execute(delete(BaselineSourceRecord).where(BaselineSourceRecord.user_id == user_id))
        session.execute(update(MentorshipCase).where(MentorshipCase.mentor_id == user_id).values(mentor_id=None))
        session.execute(update(MentorshipRevision).where(MentorshipRevision.mentor_id == user_id).values(mentor_id=None))
        session.execute(
            delete(AssessmentAttemptRecord).where(
                AssessmentAttemptRecord.owner_id == user_id
            )
        )
        session.execute(
            delete(AssessmentContentRecord).where(
                AssessmentContentRecord.owner_id == user_id
            )
        )
        evidence_ids = select(EvidenceItem.id).where(EvidenceItem.user_id == user_id)
        session.execute(delete(ClassCheckin).where(ClassCheckin.user_id == user_id))
        session.execute(delete(ReviewDecision).where(ReviewDecision.evidence_id.in_(evidence_ids)))
        session.execute(delete(EvidenceItem).where(EvidenceItem.user_id == user_id))
        session.execute(
            delete(ClassEnrollment).where(ClassEnrollment.user_id == user_id)
        )
        session.execute(delete(ClassMonitor).where(ClassMonitor.user_id == user_id))
        session.execute(delete(CohortMembership).where(CohortMembership.user_id == user_id))
        session.execute(delete(Enrollment).where(Enrollment.user_id == user_id))
        session.execute(
            delete(ProgramMembership).where(ProgramMembership.user_id == user_id)
        )
        session.execute(delete(SessionToken).where(SessionToken.user_id == user_id))
        # Keep immutable institutional history but anonymize departed creators.
        # Explicit updates also cover SQLite installations without FK enforcement.
        session.execute(update(CourseVersion).where(CourseVersion.creator_user_id == user_id).values(creator_user_id=None))
        session.execute(update(CourseVersionTransition).where(CourseVersionTransition.actor_user_id == user_id).values(actor_user_id=None))
        session.execute(delete(User).where(User.id == user_id))
        session.commit()
        return Response(status_code=status.HTTP_204_NO_CONTENT)
    except HTTPException:
        session.rollback()
        raise
    except IntegrityError as error:
        session.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="A conta possui vínculos que exigem atendimento da equipe TDS.",
        ) from error
    finally:
        session.close()


class AuthService:
    def __init__(self, session: Session, settings: Settings) -> None:
        self.session = session
        self.settings = settings
        self.jwt_secret, self.cpf_pepper = settings.require_auth_secrets()

    def register(self, payload: RegisterRequest) -> User:
        password = payload.password.get_secret_value()
        if len(password) < 12 or len(password) > 128:
            raise HTTPException(
                status_code=422,
                detail="A senha deve ter entre 12 e 128 caracteres.",
            )
        cpf_digest = self._cpf_digest(payload.cpf.get_secret_value())
        if self.session.scalar(select(User.id).where(User.cpf_digest == cpf_digest)):
            raise HTTPException(status_code=409, detail="Usuário já cadastrado.")

        phone = re.sub(r"\D", "", payload.phone)
        if not 10 <= len(phone) <= 15:
            raise HTTPException(status_code=422, detail="Telefone inválido.")
        name = payload.name.strip()
        if len(name) < 2:
            raise HTTPException(status_code=422, detail="Nome inválido.")
        user = User(
            id=str(uuid4()),
            cpf_digest=cpf_digest,
            phone=phone,
            name=name,
            password_digest=password_hash.hash(password),
            role="student",
        )
        self.session.add(user)
        self.session.flush()
        return user

    def authenticate(self, payload: LoginRequest) -> User:
        try:
            digest = self._cpf_digest(payload.cpf.get_secret_value())
        except HTTPException:
            digest = "0" * 64
        user = self.session.scalar(select(User).where(User.cpf_digest == digest))
        stored_digest = user.password_digest if user else dummy_password_digest
        try:
            verified = password_hash.verify(
                payload.password.get_secret_value(), stored_digest
            )
        except UnknownHashError:
            verified = False
        if user is None or not verified:
            raise _unauthorized("Credenciais inválidas.")
        return user

    def issue_tokens(self, user: User) -> TokenResponse:
        now = datetime.now(timezone.utc)
        access_expires = now + timedelta(minutes=self.settings.access_token_minutes)
        access_token = jwt.encode(
            {
                "sub": user.id,
                "role": user.role,
                "type": "access",
                "iat": now,
                "exp": access_expires,
            },
            self.jwt_secret,
            algorithm="HS256",
        )
        refresh_token = secrets.token_urlsafe(48)
        self.session.add(
            SessionToken(
                id=str(uuid4()),
                user_id=user.id,
                refresh_token_digest=_token_digest(refresh_token),
                expires_at=now + timedelta(days=self.settings.refresh_token_days),
            )
        )
        return TokenResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            expires_in=max(0, self.settings.access_token_minutes * 60),
            user=_public_user(user),
        )

    def rotate_refresh(self, refresh_token: str) -> TokenResponse:
        now = datetime.now(timezone.utc)
        record = self.session.scalar(
            select(SessionToken)
            .where(SessionToken.refresh_token_digest == _token_digest(refresh_token))
            .with_for_update()
        )
        if (
            record is None
            or record.revoked_at is not None
            or _as_utc(record.expires_at) <= now
        ):
            raise _unauthorized("Refresh token inválido.")
        user = self.session.get(User, record.user_id)
        if user is None:
            raise _unauthorized("Refresh token inválido.")
        record.revoked_at = now
        return self.issue_tokens(user)

    def decode_access(self, token: str) -> dict[str, str]:
        try:
            claims = jwt.decode(
                token,
                self.jwt_secret,
                algorithms=["HS256"],
                options={"require": ["exp", "iat", "sub", "role", "type"]},
            )
        except InvalidTokenError as error:
            raise _unauthorized() from error
        if claims.get("type") != "access" or claims.get("role") not in {
            "student",
            "teacher",
            "monitor",
            "admin",
        }:
            raise _unauthorized()
        return claims

    def _cpf_digest(self, value: str) -> str:
        normalized = _valid_cpf(value)
        return hmac.new(
            self.cpf_pepper.encode(), normalized.encode(), hashlib.sha256
        ).hexdigest()


def _valid_cpf(value: str) -> str:
    digits = re.sub(r"\D", "", value)
    if len(digits) != 11 or len(set(digits)) == 1:
        raise HTTPException(status_code=422, detail="CPF inválido.")
    for index in (9, 10):
        total = sum(int(digits[position]) * (index + 1 - position) for position in range(index))
        expected = (total * 10 % 11) % 10
        if int(digits[index]) != expected:
            raise HTTPException(status_code=422, detail="CPF inválido.")
    return digits


def _service(request: Request) -> tuple[AuthService, Session]:
    database: Database = request.app.state.database
    settings: Settings = request.app.state.settings
    session = Session(database.engine)
    return AuthService(session, settings), session


def _public_user(user: User) -> PublicUser:
    return PublicUser(id=user.id, name=user.name, role=user.role)


def _token_digest(token: str) -> str:
    return hashlib.sha256(token.encode()).hexdigest()


def _as_utc(value: datetime) -> datetime:
    return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value


def _bearer_token(authorization: str | None) -> str:
    if not authorization or not authorization.startswith("Bearer "):
        raise _unauthorized()
    return authorization.removeprefix("Bearer ").strip()


def _unauthorized(detail: str = "Token inválido ou expirado.") -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=detail,
        headers={"WWW-Authenticate": "Bearer"},
    )
