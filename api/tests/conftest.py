import pytest


@pytest.fixture
def requests_database_url(tmp_path):
    """Certificate fixtures default to SQLite; PostgreSQL proof overrides locally."""
    return f"sqlite+pysqlite:///{(tmp_path / 'requests.db').as_posix()}"
