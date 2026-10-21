from dataclasses import replace
import hashlib
import hmac

from fastapi.testclient import TestClient
from pydantic import ValidationError
import pytest

from app.config import Settings
from app.main import create_app
from app.support import SupportWidgetConfig
from test_classrooms import make_client, register, bearer


def test_support_identity_requires_auth_and_configuration():
    client, app = make_client()
    assert client.get('/support/identity').status_code == 401
    user = register(client, 'student')
    headers = bearer(user['access_token'])
    assert client.get('/support/identity', headers=headers).status_code == 503
    app.state.settings = replace(app.state.settings, chatwoot_identity_secret='synthetic-only', chatwoot_identity_namespace='tds-staging')
    response = client.get('/support/identity?user_id=someone-else', headers=headers)
    assert response.status_code == 200
    assert response.headers['cache-control'] == 'no-store'
    identity = response.json()
    assert set(identity) == {'identifier', 'identifier_hash'}
    assert identity['identifier'] == f"tds-staging:{user['user']['id']}"
    assert identity['identifier_hash'] == hmac.new(b'synthetic-only', identity['identifier'].encode(), hashlib.sha256).hexdigest()
    assert client.get('/support/identity', headers=headers).json() == identity
    other = register(client, 'outsider')
    assert client.get('/support/identity', headers=bearer(other['access_token'])).json()['identifier'] != identity['identifier']
    app.state.settings = replace(app.state.settings, chatwoot_identity_namespace='tds-production')
    assert client.get('/support/identity', headers=headers).json()['identifier'] != identity['identifier']


@pytest.fixture
def widget_config_api():
    # This public endpoint must work without users, tables or auth credentials
    # supplied by the caller. The lifespan uses synthetic server-only secrets.
    settings = Settings(
        database_url="sqlite+pysqlite:///:memory:",
        allowed_origins=(),
        jwt_secret="j" * 32,
        cpf_pepper="p" * 32,
        chatwoot_base_url="https://chat.example.org",
        chatwoot_website_token="qa_widget_token_A",
        chatwoot_identity_secret="h" * 32,
        chatwoot_identity_namespace="qa-private-namespace",
    )
    app = create_app(settings=settings)
    with TestClient(app) as client:
        yield client, app


def test_widget_config_is_public_exact_projection_and_never_exports_hmac(widget_config_api):
    client, app = widget_config_api
    response = client.get(
        "/support/config?website_token=override&base_url=https://localhost",
        headers={"Authorization": "Bearer invalid-synthetic", "Host": "attacker.invalid"},
    )
    assert response.status_code == 200
    assert response.json() == {
        "base_url": "https://chat.example.org",
        "website_token": "qa_widget_token_A",
    }
    assert response.headers["cache-control"] == "no-store"
    assert response.headers["pragma"] == "no-cache"
    assert app.state.settings.chatwoot_identity_secret not in response.text
    assert app.state.settings.chatwoot_identity_namespace not in response.text
    assert app.state.settings.jwt_secret not in response.text
    assert app.state.settings.cpf_pepper not in response.text
    assert client.get("/support/identity").status_code == 401


@pytest.mark.parametrize("url", [
    None, "", "http://chat.example.org", "//chat.example.org",
    "https://user:pass@chat.example.org", "https://@chat.example.org",
    "https://chat.example.org?inbox=1", "https://chat.example.org?",
    "https://chat.example.org#widget", "https://chat.example.org#",
    " https://chat.example.org", "https://chat.example.org\n",
    "https://chat.exa\tmple.org", "https://chat.example.org\\private",
    "https://chat.example.org/%2e%2e", "https://chat.example.org/../private",
    "https://chat.example.org/./widget", "https://chat.example.org//widget",
    "https://chat.example.org/a%2fb", "https://chat.example.org/a%5cb",
    "https://chat.example.org/unsafe<script>", "https://chat.example.org:",
    "https://chat.example.org:0", "https://chat.example.org:65536",
    "https://localhost", "https://LOCALHOST.", "https://chat.localhost",
    "https://chat.local", "https://chat.internal", "https://chat.lan",
    "https://home.arpa", "https://router.home.arpa",
    "https://127.0.0.1", "https://10.0.0.1", "https://172.16.0.1",
    "https://192.168.1.1", "https://169.254.169.254", "https://100.64.0.1",
    "https://0.0.0.0", "https://224.0.0.1", "https://192.0.2.1",
    "https://[::1]", "https://[fc00::1]", "https://[fe80::1]",
    "https://[2001:db8::1]", "https://[::ffff:127.0.0.1]",
    "https://[2001:4860:4860::8888%zone]",
    "https://127.1", "https://2130706433", "https://0x7f000001",
    "https://0177.0.0.1", "https://0x7f.0.0.1", "https://%31%32%37.0.0.1",
])
def test_widget_config_rejects_unsafe_urls_without_disclosing_values(widget_config_api, url):
    client, app = widget_config_api
    app.state.settings = replace(app.state.settings, chatwoot_base_url=url)
    response = client.get("/support/config")
    assert response.status_code == 503
    assert response.json() == {"detail": "Configuração do suporte indisponível."}
    assert response.headers["cache-control"] == "no-store"
    assert response.headers["pragma"] == "no-cache"
    assert client.get("/live").status_code == 200


@pytest.mark.parametrize("token", [None, "", "short", "a" * 257, "bad token", "bad\ntoken", 'bad"token', "bad<script>"])
def test_widget_config_rejects_missing_or_unsafe_token(widget_config_api, token):
    client, app = widget_config_api
    app.state.settings = replace(app.state.settings, chatwoot_website_token=token)
    response = client.get("/support/config")
    assert response.status_code == 503
    assert response.json() == {"detail": "Configuração do suporte indisponível."}
    assert response.headers["cache-control"] == "no-store"


@pytest.mark.parametrize("url, canonical", [
    ("https://chat.example.org/", "https://chat.example.org"),
    ("https://chat.example.org/support-v1/chat/", "https://chat.example.org/support-v1/chat"),
    ("https://chat.example.org:8443/chat", "https://chat.example.org:8443/chat"),
    ("https://8.8.8.8", "https://8.8.8.8"),
    ("https://[2001:4860:4860::8888]/", "https://[2001:4860:4860::8888]"),
])
def test_widget_config_accepts_public_origin_or_safe_path_prefix(widget_config_api, url, canonical):
    client, app = widget_config_api
    app.state.settings = replace(app.state.settings, chatwoot_base_url=url)
    response = client.get("/support/config")
    assert response.status_code == 200
    assert response.json()["base_url"] == canonical


def test_widget_config_changes_only_after_settings_are_reloaded(widget_config_api, monkeypatch):
    client, app = widget_config_api
    monkeypatch.setenv("TUTOR_ENVIRONMENT", "development")
    monkeypatch.setenv("DATABASE_URL", "sqlite+pysqlite:///:memory:")
    monkeypatch.setenv("CHATWOOT_BASE_URL", "https://chat.example.org")
    monkeypatch.setenv("CHATWOOT_WEBSITE_TOKEN", "qa_widget_token_A")
    app.state.settings = Settings.from_environment()
    assert client.get("/support/config").json()["website_token"] == "qa_widget_token_A"
    monkeypatch.setenv("CHATWOOT_WEBSITE_TOKEN", "qa_widget_token_B")
    # Changing an env/file alone is not hot reload. Recreating the API loads
    # Settings.from_environment again; this simulates that settings boundary.
    assert client.get("/support/config").json()["website_token"] == "qa_widget_token_A"
    app.state.settings = Settings.from_environment()
    response = client.get("/support/config")
    assert response.json()["website_token"] == "qa_widget_token_B"
    assert response.headers["cache-control"] == "no-store"


def test_widget_config_optional_settings_do_not_break_api_startup(monkeypatch):
    monkeypatch.setenv("TUTOR_ENVIRONMENT", "development")
    monkeypatch.setenv("DATABASE_URL", "sqlite+pysqlite:///:memory:")
    monkeypatch.setenv("JWT_SECRET", "j" * 32)
    monkeypatch.setenv("CPF_PEPPER", "p" * 32)
    monkeypatch.setenv("CHATWOOT_BASE_URL", "http://localhost")
    monkeypatch.delenv("CHATWOOT_WEBSITE_TOKEN", raising=False)
    app = create_app(settings=Settings.from_environment())
    with TestClient(app) as client:
        assert client.get("/live").status_code == 200
        assert client.get("/support/config").status_code == 503


def test_widget_config_openapi_model_has_only_two_public_fields(widget_config_api):
    _, app = widget_config_api
    spec = app.openapi()
    operation = spec["paths"]["/support/config"]["get"]
    assert "parameters" not in operation
    assert "503" in operation["responses"]
    assert operation["responses"]["200"]["content"]["application/json"]["schema"] == {
        "$ref": "#/components/schemas/SupportWidgetConfig",
    }
    schema = spec["components"]["schemas"]["SupportWidgetConfig"]
    assert set(schema["properties"]) == {"base_url", "website_token"}
    assert set(schema["required"]) == {"base_url", "website_token"}
    assert schema["additionalProperties"] is False
    with pytest.raises(ValidationError):
        SupportWidgetConfig(base_url="https://chat.example.org", website_token="qa_widget_token_A", identity_secret="not-public")
