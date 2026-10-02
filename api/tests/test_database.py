from __future__ import annotations

from io import StringIO

from alembic import command
from alembic.config import Config
import pytest
from sqlalchemy import text
from sqlalchemy.pool import StaticPool

from app.config import Settings
from app.database import Database, normalize_database_url


def test_development_keeps_local_sqlite_fallback(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.delenv("DATABASE_URL", raising=False)
    monkeypatch.setenv("TUTOR_ENVIRONMENT", "development")
    assert Settings.from_environment().database_url.startswith("sqlite")


@pytest.mark.parametrize("environment", ["staging", "production"])
def test_managed_environments_require_database_url(monkeypatch: pytest.MonkeyPatch, environment: str) -> None:
    monkeypatch.delenv("DATABASE_URL", raising=False)
    monkeypatch.setenv("TUTOR_ENVIRONMENT", environment)
    with pytest.raises(RuntimeError, match="DATABASE_URL"):
        Settings.from_environment()


def test_staging_rejects_sqlite(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("DATABASE_URL", "sqlite+pysqlite:///./staging.db")
    monkeypatch.setenv("TUTOR_ENVIRONMENT", "staging")
    with pytest.raises(RuntimeError, match="DATABASE_URL"):
        Settings.from_environment()


@pytest.mark.parametrize("url", [
    "sqlite+pysqlite:///./tutor_tds_local.db",
    "postgresql+psycopg://user:example@localhost:5432/db",
    "postgresql+psycopg://user:example@127.0.0.1:5432/db",
    "postgresql+psycopg://user:example@lgtphbbpgqnzduhtyate.supabase.co/db",
    "postgresql+psycopg://user:example@db.staging.internal/db",
])
def test_production_rejects_nonproduction_database(monkeypatch: pytest.MonkeyPatch, url: str) -> None:
    monkeypatch.setenv("TUTOR_ENVIRONMENT", "production")
    monkeypatch.setenv("DATABASE_URL", url)
    with pytest.raises(RuntimeError, match="DATABASE_URL"):
        Settings.from_environment()


def test_production_accepts_persistent_compose_postgres(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("TUTOR_ENVIRONMENT", "production")
    monkeypatch.setenv("DATABASE_URL", "postgresql+psycopg://user:example@db:5432/tutor_tds")
    assert Settings.from_environment().database_url.endswith("/tutor_tds")


@pytest.mark.parametrize("environment", ["staging", "production"])
def test_managed_alembic_rejects_missing_environment_url(monkeypatch: pytest.MonkeyPatch, environment: str) -> None:
    monkeypatch.setenv("TUTOR_ENVIRONMENT", environment)
    monkeypatch.delenv("DATABASE_URL", raising=False)
    with pytest.raises(RuntimeError, match="DATABASE_URL"):
        command.upgrade(Config("alembic.ini", output_buffer=StringIO()), "20260920_0001", sql=True)


def test_production_app_rejects_sqlite_override() -> None:
    from app.main import create_app

    settings = Settings(
        database_url="postgresql+psycopg://user:example@db:5432/tutor_tds",
        allowed_origins=(), environment="production",
    )
    with pytest.raises(RuntimeError, match="DATABASE_URL"):
        create_app(database_url="sqlite+pysqlite:///:memory:", settings=settings)


@pytest.mark.parametrize("scheme", ["postgres", "postgresql", "postgresql+psycopg"])
def test_provider_url_selects_psycopg_and_preserves_credentials_and_tls(
    scheme: str,
) -> None:
    suffix = (
        "qa_user:pa%25ss%40word%3A%2F@db.qa-project.supabase.co:5432/postgres"
        "?sslmode=verify-full&sslrootcert=%2Fapp%2Fcerts%2Froot.pem"
        "&application_name=Tutor%20TDS&connect_timeout=10"
    )
    original = f"{scheme}://{suffix}"
    assert normalize_database_url(original) == f"postgresql+psycopg://{suffix}"

    # Engine construction loads the real driver but does not contact the database.
    database = Database(original)
    try:
        assert database.engine.dialect.driver == "psycopg"
        _, parameters = database.engine.dialect.create_connect_args(database.engine.url)
        assert parameters["password"] == "pa%ss@word:/"
        assert parameters["sslmode"] == "verify-full"
        assert parameters["sslrootcert"] == "/app/certs/root.pem"
        assert parameters["connect_timeout"] == "10"
        assert parameters["application_name"] == "Tutor TDS"
    finally:
        database.dispose()


@pytest.mark.parametrize(
    "url",
    [
        "sqlite+pysqlite:///:memory:",
        "sqlite:///./existing.db",
        "postgresql+psycopg2://user:password@localhost/existing",
        "postgresql+asyncpg://user:password@localhost/existing",
    ],
)
def test_explicit_drivers_and_sqlite_are_unchanged(url: str) -> None:
    assert normalize_database_url(url) == url


def test_sqlite_memory_still_shares_data_between_sessions() -> None:
    database = Database("sqlite+pysqlite:///:memory:")
    try:
        assert isinstance(database.engine.pool, StaticPool)
        with database.engine.begin() as connection:
            connection.execute(text("CREATE TABLE sample (id INTEGER PRIMARY KEY)"))
            connection.execute(text("INSERT INTO sample (id) VALUES (1)"))
        with database.engine.connect() as connection:
            assert connection.execute(text("SELECT id FROM sample")).scalar_one() == 1
    finally:
        database.dispose()


@pytest.mark.parametrize("source", ["environment", "config"])
@pytest.mark.parametrize("scheme", ["postgres", "postgresql"])
def test_alembic_accepts_provider_url_without_losing_percent_escapes(
    monkeypatch: pytest.MonkeyPatch, source: str, scheme: str,
) -> None:
    suffix = (
        "qa_user:pa%25ss%40word@db.qa-project.supabase.co:5432/postgres"
        "?sslmode=verify-full&sslrootcert=%2Fcerts%2Froot.pem"
    )
    original = f"{scheme}://{suffix}"
    output = StringIO()
    config = Config("alembic.ini", output_buffer=output)
    monkeypatch.delenv("DATABASE_URL", raising=False)
    if source == "environment":
        monkeypatch.setenv("DATABASE_URL", original)
    else:
        config.set_main_option("sqlalchemy.url", original.replace("%", "%%"))

    # Exercise Alembic's actual environment in offline mode; no remote DB or secrets.
    command.upgrade(config, "20260920_0001", sql=True)

    assert config.get_main_option("sqlalchemy.url") == f"postgresql+psycopg://{suffix}"
    assert "CREATE TABLE users" in output.getvalue()
    assert "pa%25ss" not in output.getvalue()
