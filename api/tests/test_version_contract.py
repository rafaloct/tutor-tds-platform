from alembic import command
from alembic.config import Config
from alembic.script import ScriptDirectory
from fastapi.testclient import TestClient

from app.config import Settings
from app.main import create_app


def _settings(database_url: str, **overrides) -> Settings:
    values = {
        "database_url": database_url,
        "allowed_origins": (),
        "jwt_secret": "test-jwt-secret-with-at-least-32-chars",
        "cpf_pepper": "test-cpf-pepper-with-at-least-32-chars",
        "minimum_supported_app_version": "1.2.0+11",
        "compatibility_verified": False,
        "environment": "development",
    }
    values.update(overrides)
    return Settings(**values)


def test_version_contract_reports_real_alembic_head(tmp_path) -> None:
    url = f"sqlite+pysqlite:///{(tmp_path / 'version.db').as_posix()}"
    config = Config("alembic.ini")
    config.set_main_option("sqlalchemy.url", url)
    command.upgrade(config, "head")
    expected_head = ScriptDirectory.from_config(config).get_current_head()

    app = create_app(settings=_settings(url))
    with TestClient(app) as client:
        response = client.get("/version")

    assert response.status_code == 200, response.text
    payload = response.json()
    assert payload == {
        "api_version": "0.1.0",
        "schema_version": expected_head,
        "minimum_supported_app_version": "1.2.0+11",
        "environment": "development",
        "compatibility_verified": False,
    }
    serialized = response.text.lower()
    for forbidden in ("database_url", "postgres", "jwt", "pepper", "password", "token"):
        assert forbidden not in serialized


def test_version_contract_fails_closed_without_alembic_identity(tmp_path) -> None:
    url = f"sqlite+pysqlite:///{(tmp_path / 'unversioned.db').as_posix()}"
    app = create_app(settings=_settings(url))

    with TestClient(app) as client:
        response = client.get("/version")

    assert response.status_code == 503
    assert response.json() == {"detail": "Schema version unavailable."}


def test_release_identity_settings_are_explicit_and_nonempty(monkeypatch) -> None:
    monkeypatch.delenv("DATABASE_URL", raising=False)
    monkeypatch.setenv("TUTOR_ENVIRONMENT", "development")
    monkeypatch.setenv("MINIMUM_SUPPORTED_APP_VERSION", "1.2.0+11")
    monkeypatch.setenv("COMPATIBILITY_VERIFIED", "true")

    settings = Settings.from_environment()

    assert settings.minimum_supported_app_version == "1.2.0+11"
    assert settings.compatibility_verified is True


def test_release_identity_rejects_empty_minimum_supported_version(monkeypatch) -> None:
    monkeypatch.delenv("DATABASE_URL", raising=False)
    monkeypatch.setenv("TUTOR_ENVIRONMENT", "development")
    monkeypatch.setenv("MINIMUM_SUPPORTED_APP_VERSION", "   ")

    try:
        Settings.from_environment()
    except RuntimeError as exc:
        assert "MINIMUM_SUPPORTED_APP_VERSION" in str(exc)
    else:
        raise AssertionError("empty minimum supported app version must fail closed")
