"""Disposable PostgreSQL proof for the operator command boundary only."""
import os
from urllib.parse import urlsplit
from uuid import uuid4

import psycopg
from psycopg import sql
import pytest
from sqlalchemy import text
from alembic import command as migration
from alembic.config import Config

from test_operator_operations import (
    operator_api, requests_api, command,
    test_account_erasure_removes_subject_receipts_and_anonymizes_actor as _privacy,
    test_closed_class_allows_authorized_receipt_replay_but_no_new_command as _replay,
)


@pytest.fixture
def requests_database_url():
    admin = os.getenv('TDS_OPERATOR_PG_ADMIN_URL')
    if not admin:
        pytest.skip('Disposable loopback PostgreSQL is opt-in')
    parsed = urlsplit(admin)
    if (parsed.scheme != 'postgresql' or parsed.hostname != '127.0.0.1'
        or parsed.port != 15430 or parsed.username != 'qa_operator'
        or parsed.password or parsed.path != '/postgres' or parsed.query or parsed.fragment):
        raise RuntimeError('Refusing non-disposable PostgreSQL target')
    name = 'qa_operator_' + uuid4().hex
    with psycopg.connect(admin, autocommit=True) as conn:
        conn.execute(sql.SQL('CREATE DATABASE {}').format(sql.Identifier(name)))
    try:
        yield (admin.rsplit('/', 1)[0] + '/' + name).replace('postgresql://', 'postgresql+psycopg://')
    finally:
        with psycopg.connect(admin, autocommit=True) as conn:
            conn.execute(sql.SQL('DROP DATABASE {} WITH (FORCE)').format(sql.Identifier(name)))


def test_postgres_privacy(operator_api):
    _privacy(operator_api)


def test_postgres_replay(operator_api):
    _replay(operator_api)


def test_postgres_concurrent_identical_command_commits_once(operator_api):
    from concurrent.futures import ThreadPoolExecutor
    from test_certificate_requests import header, ORIGINAL
    client, engine = operator_api
    body = dict(id=str(uuid4()), action='assign', reason='Synthetic concurrent command',
                institution_id='i1', program_id='p1', course_id='course', version_id=ORIGINAL,
                person_id='other', expected_revision=0)
    def send():
        return client.post('/operations/c1/commands', headers=header('coordinator'), json=body)
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda _: send(), range(2)))
    assert [result.status_code for result in results] == [200, 200]
    assert results[0].json() == results[1].json()
    with engine.connect() as conn:
        assert conn.scalar(text('SELECT count(*) FROM operator_command_receipts')) == 1


def test_postgres_migration_and_populated_rollback_guard(operator_api):
    client, engine = operator_api
    config = Config('alembic.ini')
    config.set_main_option('sqlalchemy.url', str(engine.url))
    with engine.connect() as conn:
        before = conn.execute(text('SELECT id, user_id, course_id FROM enrollments ORDER BY id')).all()
    migration.downgrade(config, '20261003_0022')
    migration.upgrade(config, 'head')
    with engine.connect() as conn:
        assert conn.execute(text('SELECT id, user_id, course_id FROM enrollments ORDER BY id')).all() == before
        assert conn.scalar(text('SELECT version_num FROM alembic_version')) == '20261003_0023'
    result, _ = command(client, 'assign')
    assert result.status_code == 200, result.text
    with pytest.raises(RuntimeError, match='Preserve operator history'):
        migration.downgrade(config, '20261003_0022')
    with engine.connect() as conn:
        assert conn.scalar(text('SELECT count(*) FROM operator_command_receipts')) == 1
        assert conn.scalar(text('SELECT version_num FROM alembic_version')) == '20261003_0023'
