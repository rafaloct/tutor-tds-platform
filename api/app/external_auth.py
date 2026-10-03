from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from functools import lru_cache
import secrets
from typing import Literal
from uuid import uuid4

import jwt
from fastapi import APIRouter, HTTPException, Request, status
from jwt import PyJWKClient
from jwt.exceptions import InvalidTokenError
from pydantic import BaseModel, Field, SecretStr
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .auth import AuthService, LoginRequest, RegisterRequest, TokenResponse
from .config import Settings
from .database import Database
from .models import ExternalIdentity, User

router = APIRouter(prefix="/auth/external", tags=["auth"])
_PROVIDER = "supabase"
_ONBOARDING_MINUTES = 15
_ALLOWED_ALGS = {"RS256", "ES256", "EdDSA"}


class ExternalExchangeRequest(BaseModel):
    access_token: SecretStr


class ExternalProfileCompleteRequest(BaseModel):
    onboarding_token: SecretStr
    name: str = Field(min_length=2, max_length=240)
    cpf: SecretStr
    phone: str = Field(min_length=10, max_length=32)


class ExternalLinkExistingRequest(BaseModel):
    onboarding_token: SecretStr
    cpf: SecretStr
    password: SecretStr


class ExternalAuthResponse(BaseModel):
    status: Literal[
        "authenticated",
        "profile_completion_required",
        "existing_account_link_required",
    ]
    session: TokenResponse | None = None
    onboarding_token: str | None = None
    verified_email: str | None = None


@dataclass(frozen=True)
class ValidatedExternalIdentity:
    subject: str
    verified_email: str | None


@lru_cache(maxsize=8)
def _jwks_client(url: str) -> PyJWKClient:
    return PyJWKClient(url, cache_jwk_set=True, lifespan=300)


def _external_unauthorized() -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Identidade externa inválida ou expirada.",
    )


def _validate_supabase_access(
    token: str, settings: Settings
) -> ValidatedExternalIdentity:
    base = settings.resolved_supabase_auth_url()
    if base is None:
        raise HTTPException(
            status_code=503,
            detail="Autenticação externa indisponível.",
        )
    try:
        header = jwt.get_unverified_header(token)
        algorithm = header.get("alg")
        if algorithm not in _ALLOWED_ALGS:
            raise _external_unauthorized()
        signing_key = _jwks_client(
            f"{base}/auth/v1/.well-known/jwks.json"
        ).get_signing_key_from_jwt(token)
        claims = jwt.decode(
            token,
            signing_key.key,
            algorithms=[algorithm],
            audience=settings.supabase_auth_audience,
            issuer=f"{base}/auth/v1",
            options={"require": ["exp", "iat", "iss", "aud", "sub"]},
        )
    except HTTPException:
        raise
    except (InvalidTokenError, ValueError, TypeError) as error:
        raise _external_unauthorized() from error

    subject = claims.get("sub")
    email = claims.get("email")
    if not isinstance(subject, str) or not subject.strip():
        raise _external_unauthorized()
    if email is not None and (
        not isinstance(email, str) or len(email) > 320
    ):
        raise _external_unauthorized()
    return ValidatedExternalIdentity(
        subject=subject.strip(),
        verified_email=(
            email.strip().lower()
            if isinstance(email, str) and email.strip()
            else None
        ),
    )


def _issue_onboarding_token(
    settings: Settings, identity: ValidatedExternalIdentity
) -> str:
    jwt_secret, _ = settings.require_auth_secrets()
    now = datetime.now(timezone.utc)
    return jwt.encode(
        {
            "sub": identity.subject,
            "provider": _PROVIDER,
            "email": identity.verified_email,
            "type": "external_onboarding",
            "jti": secrets.token_urlsafe(24),
            "iat": now,
            "exp": now + timedelta(minutes=_ONBOARDING_MINUTES),
        },
        jwt_secret,
        algorithm="HS256",
    )


def _decode_onboarding_token(
    token: str, settings: Settings
) -> ValidatedExternalIdentity:
    jwt_secret, _ = settings.require_auth_secrets()
    try:
        claims = jwt.decode(
            token,
            jwt_secret,
            algorithms=["HS256"],
            options={
                "require": [
                    "exp",
                    "iat",
                    "sub",
                    "provider",
                    "type",
                    "jti",
                ]
            },
        )
    except InvalidTokenError as error:
        raise HTTPException(
            status_code=401,
            detail="Fluxo de cadastro expirado ou inválido.",
        ) from error
    if (
        claims.get("type") != "external_onboarding"
        or claims.get("provider") != _PROVIDER
    ):
        raise HTTPException(
            status_code=401,
            detail="Fluxo de cadastro expirado ou inválido.",
        )
    subject = claims.get("sub")
    email = claims.get("email")
    if not isinstance(subject, str) or not subject.strip():
        raise HTTPException(
            status_code=401,
            detail="Fluxo de cadastro expirado ou inválido.",
        )
    if email is not None and not isinstance(email, str):
        raise HTTPException(
            status_code=401,
            detail="Fluxo de cadastro expirado ou inválido.",
        )
    return ValidatedExternalIdentity(
        subject=subject.strip(),
        verified_email=email,
    )


def _existing_identity(
    session: Session, subject: str
) -> ExternalIdentity | None:
    return session.scalar(
        select(ExternalIdentity).where(
            ExternalIdentity.provider == _PROVIDER,
            ExternalIdentity.provider_subject == subject,
        )
    )


def _authenticated(
    service: AuthService, user: User
) -> ExternalAuthResponse:
    return ExternalAuthResponse(
        status="authenticated",
        session=service.issue_tokens(user),
    )


def _profile_required(
    settings: Settings, identity: ValidatedExternalIdentity
) -> ExternalAuthResponse:
    return ExternalAuthResponse(
        status="profile_completion_required",
        onboarding_token=_issue_onboarding_token(settings, identity),
        verified_email=identity.verified_email,
    )


def _link_required(
    identity: ValidatedExternalIdentity,
    onboarding_token: str,
) -> ExternalAuthResponse:
    return ExternalAuthResponse(
        status="existing_account_link_required",
        onboarding_token=onboarding_token,
        verified_email=identity.verified_email,
    )


@router.post("/exchange", response_model=ExternalAuthResponse)
def exchange(
    payload: ExternalExchangeRequest, request: Request
) -> ExternalAuthResponse:
    settings: Settings = request.app.state.settings
    identity = _validate_supabase_access(
        payload.access_token.get_secret_value(),
        settings,
    )
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        service = AuthService(session, settings)
        linked = _existing_identity(session, identity.subject)
        if linked is None:
            return _profile_required(settings, identity)
        user = session.get(User, linked.user_id)
        if user is None:
            raise HTTPException(
                status_code=409,
                detail="Vínculo externo inconsistente.",
            )
        response = _authenticated(service, user)
        session.commit()
        return response


@router.post("/complete", response_model=ExternalAuthResponse)
def complete_profile(
    payload: ExternalProfileCompleteRequest, request: Request
) -> ExternalAuthResponse:
    settings: Settings = request.app.state.settings
    onboarding_token = payload.onboarding_token.get_secret_value()
    identity = _decode_onboarding_token(onboarding_token, settings)
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        service = AuthService(session, settings)
        linked = _existing_identity(session, identity.subject)
        if linked is not None:
            user = session.get(User, linked.user_id)
            if user is None:
                raise HTTPException(
                    status_code=409,
                    detail="Vínculo externo inconsistente.",
                )
            response = _authenticated(service, user)
            session.commit()
            return response

        random_password = secrets.token_urlsafe(48)
        try:
            user = service.register(
                RegisterRequest(
                    name=payload.name,
                    cpf=payload.cpf,
                    phone=payload.phone,
                    password=SecretStr(random_password),
                )
            )
        except HTTPException as error:
            if error.status_code == 409:
                session.rollback()
                return _link_required(identity, onboarding_token)
            raise

        session.add(
            ExternalIdentity(
                id=str(uuid4()),
                provider=_PROVIDER,
                provider_subject=identity.subject,
                verified_email=identity.verified_email,
                user_id=user.id,
            )
        )
        try:
            response = _authenticated(service, user)
            session.commit()
            return response
        except IntegrityError:
            session.rollback()
            linked = _existing_identity(session, identity.subject)
            if linked is not None:
                user = session.get(User, linked.user_id)
                if user is None:
                    raise HTTPException(
                        status_code=409,
                        detail="Vínculo externo inconsistente.",
                    )
                response = _authenticated(
                    AuthService(session, settings),
                    user,
                )
                session.commit()
                return response
            return _link_required(identity, onboarding_token)


@router.post("/link-existing", response_model=ExternalAuthResponse)
def link_existing(
    payload: ExternalLinkExistingRequest, request: Request
) -> ExternalAuthResponse:
    settings: Settings = request.app.state.settings
    identity = _decode_onboarding_token(
        payload.onboarding_token.get_secret_value(),
        settings,
    )
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        service = AuthService(session, settings)
        linked = _existing_identity(session, identity.subject)
        if linked is not None:
            user = session.get(User, linked.user_id)
            if user is None:
                raise HTTPException(
                    status_code=409,
                    detail="Vínculo externo inconsistente.",
                )
            response = _authenticated(service, user)
            session.commit()
            return response

        user = service.authenticate(
            LoginRequest(
                cpf=payload.cpf,
                password=payload.password,
            )
        )
        session.add(
            ExternalIdentity(
                id=str(uuid4()),
                provider=_PROVIDER,
                provider_subject=identity.subject,
                verified_email=identity.verified_email,
                user_id=user.id,
            )
        )
        try:
            response = _authenticated(service, user)
            session.commit()
            return response
        except IntegrityError:
            session.rollback()
            linked = _existing_identity(session, identity.subject)
            if linked is None or linked.user_id != user.id:
                raise HTTPException(
                    status_code=409,
                    detail="Identidade externa já vinculada.",
                )
            response = _authenticated(
                AuthService(session, settings),
                user,
            )
            session.commit()
            return response
