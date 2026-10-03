from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from dataclasses import replace
from datetime import datetime, timedelta, timezone

import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import rsa
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app import external_auth
from app.external_auth import ValidatedExternalIdentity
from app.models import ExternalIdentity, User
from test_auth import CPF, PASSWORD, make_client, registration_payload


class _SigningKey:
    def __init__(self, key):
        self.key = key


class _Jwks:
    def __init__(self, key):
        self._key = key

    def get_signing_key_from_jwt(self, _token):
        return _SigningKey(self._key)


def _external_settings(app):
    return replace(
        app.state.settings,
        supabase_auth_url="https://project-ref.supabase.co",
        supabase_auth_audience="authenticated",
    )


def _rsa_token(
    private_key,
    *,
    issuer="https://project-ref.supabase.co/auth/v1",
    audience="authenticated",
    subject="external-subject",
    expires_delta=timedelta(minutes=5),
):
    now = datetime.now(timezone.utc)
    return jwt.encode(
        {
            "sub": subject,
            "email": "verified@example.org",
            "iss": issuer,
            "aud": audience,
            "iat": now,
            "exp": now + expires_delta,
        },
        private_key,
        algorithm="RS256",
        headers={"kid": "test-key"},
    )


@pytest.mark.parametrize(
    "mutation",
    ["signature", "issuer", "audience", "expired"],
)
def test_external_token_crypto_validation_fails_closed(
    monkeypatch, mutation
):
    _, app = make_client()
    settings = _external_settings(app)
    key = rsa.generate_private_key(
        public_exponent=65537,
        key_size=2048,
    )
    other = rsa.generate_private_key(
        public_exponent=65537,
        key_size=2048,
    )
    monkeypatch.setattr(
        external_auth,
        "_jwks_client",
        lambda _url: _Jwks(key.public_key()),
    )

    signer = other if mutation == "signature" else key
    issuer = (
        "https://evil.example/auth/v1"
        if mutation == "issuer"
        else "https://project-ref.supabase.co/auth/v1"
    )
    audience = "other" if mutation == "audience" else "authenticated"
    expires = (
        timedelta(minutes=-1)
        if mutation == "expired"
        else timedelta(minutes=5)
    )
    token = _rsa_token(
        signer,
        issuer=issuer,
        audience=audience,
        expires_delta=expires,
    )

    with pytest.raises(Exception) as caught:
        external_auth._validate_supabase_access(token, settings)
    assert getattr(caught.value, "status_code", None) == 401


def test_external_token_crypto_validation_accepts_signed_subject(
    monkeypatch,
):
    _, app = make_client()
    settings = _external_settings(app)
    key = rsa.generate_private_key(
        public_exponent=65537,
        key_size=2048,
    )
    monkeypatch.setattr(
        external_auth,
        "_jwks_client",
        lambda _url: _Jwks(key.public_key()),
    )

    identity = external_auth._validate_supabase_access(
        _rsa_token(key),
        settings,
    )

    assert identity.subject == "external-subject"
    assert identity.verified_email == "verified@example.org"


@pytest.fixture
def external_client(monkeypatch):
    client, app = make_client()
    app.state.settings = _external_settings(app)
    monkeypatch.setattr(
        external_auth,
        "_validate_supabase_access",
        lambda token, _settings: ValidatedExternalIdentity(
            subject=f"subject-{token}",
            verified_email="verified@example.org",
        ),
    )
    return client, app


def _exchange(client, marker="new"):
    return client.post(
        "/auth/external/exchange",
        json={"access_token": marker},
    )


def _complete(client, onboarding_token, *, cpf=CPF):
    return client.post(
        "/auth/external/complete",
        json={
            "onboarding_token": onboarding_token,
            "name": "Pessoa Externa",
            "cpf": cpf,
            "phone": "(61) 99999-0000",
        },
    )


def test_exchange_does_not_create_incomplete_user(external_client):
    client, app = external_client
    with client:
        response = _exchange(client)
        with Session(app.state.database.engine) as session:
            assert (
                session.scalar(
                    select(func.count()).select_from(User)
                )
                == 0
            )
            assert (
                session.scalar(
                    select(func.count()).select_from(ExternalIdentity)
                )
                == 0
            )

    assert response.status_code == 200
    assert response.json()["status"] == "profile_completion_required"
    assert response.json()["onboarding_token"]
    assert response.json()["session"] is None


def test_profile_completion_creates_user_identity_and_tutor_session(
    external_client,
):
    client, app = external_client
    with client:
        exchange = _exchange(client).json()
        completed = _complete(
            client,
            exchange["onboarding_token"],
        )
        replay = _complete(
            client,
            exchange["onboarding_token"],
        )

        with Session(app.state.database.engine) as session:
            users = session.scalars(select(User)).all()
            identities = session.scalars(
                select(ExternalIdentity)
            ).all()
            assert len(users) == 1
            assert len(identities) == 1
            assert identities[0].user_id == users[0].id
            assert identities[0].provider == "supabase"
            assert (
                identities[0].provider_subject
                == "subject-new"
            )
            assert (
                identities[0].verified_email
                == "verified@example.org"
            )
            assert users[0].password_digest.startswith(
                "$argon2id$"
            )

    assert completed.status_code == 200
    assert completed.json()["status"] == "authenticated"
    assert completed.json()["session"]["access_token"]
    assert replay.status_code == 200
    assert replay.json()["status"] == "authenticated"
    assert CPF not in completed.text


def test_existing_cpf_requires_password_proof_before_link(
    external_client,
):
    client, app = external_client
    with client:
        existing = client.post(
            "/auth/register",
            json=registration_payload(),
        )
        existing_id = existing.json()["user"]["id"]
        exchange = _exchange(client, "existing").json()
        completion = _complete(
            client,
            exchange["onboarding_token"],
        )
        wrong = client.post(
            "/auth/external/link-existing",
            json={
                "onboarding_token": exchange["onboarding_token"],
                "cpf": CPF,
                "password": "senha-incorreta",
            },
        )
        linked = client.post(
            "/auth/external/link-existing",
            json={
                "onboarding_token": exchange["onboarding_token"],
                "cpf": CPF,
                "password": PASSWORD,
            },
        )
        replay = _exchange(client, "existing")

        with Session(app.state.database.engine) as session:
            assert (
                session.scalar(
                    select(func.count()).select_from(User)
                )
                == 1
            )
            identity = session.scalar(
                select(ExternalIdentity)
            )
            assert identity is not None
            assert identity.user_id == existing_id

    assert completion.status_code == 200
    assert (
        completion.json()["status"]
        == "existing_account_link_required"
    )
    assert wrong.status_code == 401
    assert linked.status_code == 200
    assert linked.json()["status"] == "authenticated"
    assert replay.json()["status"] == "authenticated"


def test_concurrent_profile_completion_never_duplicates(
    external_client,
):
    client, app = external_client
    with client:
        token = _exchange(
            client,
            "race",
        ).json()["onboarding_token"]

        def send():
            return _complete(client, token)

        with ThreadPoolExecutor(max_workers=2) as pool:
            responses = list(
                pool.map(lambda _index: send(), range(2))
            )

        assert all(
            response.status_code == 200
            for response in responses
        )
        assert all(
            response.json()["status"] == "authenticated"
            for response in responses
        )
        with Session(app.state.database.engine) as session:
            assert (
                session.scalar(
                    select(func.count()).select_from(User)
                )
                == 1
            )
            assert (
                session.scalar(
                    select(func.count()).select_from(ExternalIdentity)
                )
                == 1
            )


def test_external_identity_is_removed_with_account(
    external_client,
):
    client, app = external_client
    with client:
        token = _exchange(
            client,
            "erase",
        ).json()["onboarding_token"]
        completed = _complete(client, token).json()
        headers = {
            "Authorization": (
                "Bearer "
                + completed["session"]["access_token"]
            )
        }
        assert (
            client.delete("/auth/me", headers=headers).status_code
            == 204
        )
        with Session(app.state.database.engine) as session:
            assert (
                session.scalar(
                    select(func.count()).select_from(User)
                )
                == 0
            )
            assert (
                session.scalar(
                    select(func.count()).select_from(ExternalIdentity)
                )
                == 0
            )
