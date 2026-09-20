from __future__ import annotations

import hashlib
import hmac
import re
import secrets
from datetime import datetime, timedelta, timezone
from uuid import uuid4

import jwt
from fastapi import APIRouter, Header, HTTPException, Request, status
from jwt.exceptions import InvalidTokenError
from pydantic import BaseModel, Field, SecretStr
from pwdlib import PasswordHash
from pwdlib.exceptions import UnknownHashError
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .config import Settings
from .database import Database
from .models import SessionToken, User

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


@router.get("/me", response_model=PublicUser)
def me(request: Request, authorization: str | None = Header(default=None)) -> PublicUser:
    service, session = _service(request)
    try:
        claims = service.decode_access(_bearer_token(authorization))
        user = session.get(User, claims["sub"])
        if user is None:
            raise _unauthorized()
        return _public_user(user)
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
