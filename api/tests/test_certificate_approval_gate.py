from app.config import Settings


def test_certificate_approval_gate_is_off_by_default_for_published_app():
    settings = Settings(database_url="sqlite+pysqlite:///:memory:", allowed_origins=())
    assert settings.certificate_approval_required is False
