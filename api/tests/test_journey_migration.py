"""Populated 0019 gate on SQLite or an explicitly disposable PostgreSQL DB."""
from dataclasses import replace
import os

from alembic import command
from alembic.config import Config
from fastapi.testclient import TestClient
import pytest
from sqlalchemy import MetaData, create_engine, inspect, select, text
from sqlalchemy.engine import make_url
from sqlalchemy.exc import DBAPIError

from app.main import create_app
from app.models import Base
from test_certificate_requests import requests_api, header
from test_presence import presence_api
from test_student_followup import baseline, case_create


def test_populated_journey_upgrade_preserves_baseline_and_guards(presence_api, tmp_path):
    origin_client, source = presence_api
    assert baseline(origin_client).status_code == 200
    assert case_create(origin_client).status_code == 201
    url = os.environ.get('TDS_JOURNEY_GATE_DATABASE_URL') or f"sqlite+pysqlite:///{(tmp_path / 'journey-gate.db').as_posix()}"
    if os.environ.get('TDS_JOURNEY_GATE_DATABASE_URL'):
        parsed = make_url(url)
        assert parsed.drivername == 'postgresql+psycopg' and parsed.database == 'tds_context_gate'
    target = create_engine(url)
    assert not inspect(target).get_table_names(), 'Requires empty disposable DB'
    migration = Config('alembic.ini')
    migration.set_main_option('sqlalchemy.url', url)
    command.upgrade(migration, '20260923_0019')
    old = MetaData()
    old.reflect(target)
    with source.connect() as origin, target.begin() as destination:
        for table in old.sorted_tables:
            if table.name == 'alembic_version': continue
            rows = origin.execute(select(Base.metadata.tables[table.name])).mappings().all()
            if rows:
                destination.execute(table.insert(), [{c.name: row[c.name] for c in table.columns} for row in rows])
        before = destination.execute(text('SELECT id,revision,snapshot FROM baseline_revisions ORDER BY id')).all()
    command.upgrade(migration, 'head')
    with target.connect() as connection:
        assert connection.execute(text('SELECT id,revision,snapshot FROM baseline_revisions ORDER BY id')).all() == before
        assert connection.execute(text('SELECT bi_source_record_id FROM student_baselines')).scalar_one() is None
        for statement, message in [("UPDATE student_baselines SET user_id='other'", "immutable association or invalid revision"), ("DELETE FROM baseline_revisions", "history requires owner erasure"), ("UPDATE baseline_revisions SET reason='rewritten'", "immutable followup history")]:
            if target.dialect.name == 'sqlite': connection.execute(text('PRAGMA foreign_keys=ON'))
            with pytest.raises(DBAPIError, match=message): connection.execute(text(statement))
            connection.rollback()
    settings = replace(origin_client.app.state.settings, database_url=url,
        journey_traceability_enabled=True, sheets_pseudonym_secret='s' * 32)
    app = create_app(settings=settings)
    app.dependency_overrides.update(origin_client.app.dependency_overrides)
    with TestClient(app) as client:
        response = baseline(client, revision=1, key='gate-bi-key', bi_record_id='DIG-0001')
        assert response.status_code == 200, response.text
        assert client.get('/classes/c1/journey-export', headers=header('teacher')).json()['items'][0]['registro_id'] == 'DIG-0001'
        assert baseline(client, user='other', record='another-source', key='gate-conflict-key', bi_record_id='DIG-0001').status_code == 409
        with pytest.raises(RuntimeError, match='Confirmed BI references'):
            command.downgrade(migration, '20260923_0019')
        # Human detach is audited; the old reference still cannot change owners.
        detached = baseline(client, revision=2, key='gate-detach-key', bi_record_id=None)
        assert detached.status_code == 200 and detached.json()['bi_record_id'] is None
        assert baseline(client, revision=2, key='gate-detach-key', bi_record_id=None).json() == detached.json()
    command.downgrade(migration, '20260923_0019')
    command.upgrade(migration, 'head')
    with target.connect() as connection:
        assert connection.execute(text('SELECT COUNT(*) FROM baseline_revisions')).scalar_one() == 3
        assert connection.execute(text('SELECT COUNT(*) FROM mentorship_revisions')).scalar_one() == 1
        assert connection.execute(text("SELECT user_id FROM baseline_source_records WHERE source='fabric:tds-inscription-v1'")).scalar_one() == 'learner'
    target.dispose()
