"""Opt-in disposable local PostgreSQL attendance proof, no shared database."""
import os
from urllib.parse import urlsplit
from uuid import uuid4
from concurrent.futures import ThreadPoolExecutor

import psycopg
from psycopg import sql
import pytest
from alembic import command
from alembic.config import Config
from sqlalchemy import text

from test_official_attendance import (
    attendance_api, presence_api, requests_api, official,
    test_makeup_needs_explicit_decision_and_keeps_denominator as _makeup,
    test_ledger_immutable_and_privacy_erasure as _privacy,
    test_original_meetings_exact_70_percent_and_legacy_fallback as _threshold,
    test_designated_global_admin_has_no_contextual_bypass as _scope,
    test_departed_instructor_anonymized_by_real_erasure_endpoint as _actor_erasure,
)
from test_operator_operations import operator_api
from test_operator_postgres import test_postgres_migration_and_populated_rollback_guard
from test_certificate_emission_candidate import candidate
from test_certificate_policy_candidate import institutional
from test_certificate_postgres_integration import (
    test_postgres_empty_upgrade_downgrade_and_reupgrade,
    test_postgres_candidate_authorization_holds_request_row_lock,
    test_postgres_concurrent_candidate_sends_at_most_once,
    test_postgres_institutional_policy_generated_capacitado_and_valid_are_distinct,
    test_postgres_populated_0020_upgrade_preserves_context_and_policy_guard,
)


@pytest.fixture
def requests_database_url():
    admin=os.getenv('TDS_ATTENDANCE_PG_ADMIN_URL')
    if not admin:
        pytest.skip('Disposable loopback PostgreSQL attendance proof is opt-in')
    parsed=urlsplit(admin)
    if (parsed.scheme!='postgresql' or parsed.hostname!='127.0.0.1' or parsed.port!=15406
            or parsed.username!='qa_attendance' or parsed.password or parsed.path!='/postgres'
            or parsed.query or parsed.fragment):
        raise RuntimeError('Refusing non-disposable attendance database')
    name='qa_attendance_'+uuid4().hex
    with psycopg.connect(admin,autocommit=True) as conn:
        conn.execute(sql.SQL('CREATE DATABASE {}').format(sql.Identifier(name)))
    try:
        yield (admin.rsplit('/',1)[0]+'/'+name).replace('postgresql://','postgresql+psycopg://',1)
    finally:
        with psycopg.connect(admin,autocommit=True) as conn:
            conn.execute(sql.SQL('DROP DATABASE {} WITH (FORCE)').format(sql.Identifier(name)))


def test_postgres_makeup(attendance_api):
    _makeup(attendance_api)


def test_postgres_threshold(attendance_api):
    _threshold(attendance_api)


def test_postgres_privacy(attendance_api):
    _privacy(attendance_api,True)


def test_postgres_actor_erasure(attendance_api):
    _actor_erasure(attendance_api,True)


@pytest.mark.parametrize('revoke',['program','cohort'])
def test_postgres_contextual_instructor(attendance_api,revoke):
    _scope(attendance_api,revoke)


def test_postgres_concurrent_decision_replay_once(attendance_api):
    client,engine=attendance_api
    with ThreadPoolExecutor(max_workers=2) as pool:
        responses=list(pool.map(lambda _:official(client),range(2)))
    assert [response.status_code for response in responses]==[200,200]
    assert responses[0].json()==responses[1].json()
    with engine.connect() as conn:
        assert conn.scalar(text('SELECT count(*) FROM official_attendance_decisions'))==1


def test_postgres_attendance_migration_preserves_data_and_refuses_populated_loss(attendance_api):
    client,engine=attendance_api
    config=Config('alembic.ini'); config.set_main_option('sqlalchemy.url',str(engine.url))
    with engine.connect() as conn:
        before=conn.execute(text('SELECT id,user_id FROM enrollments ORDER BY id')).all()
    command.downgrade(config,'20261003_0023')
    command.upgrade(config,'head')
    with engine.connect() as conn:
        assert conn.execute(text('SELECT id,user_id FROM enrollments ORDER BY id')).all()==before
    assert official(client).status_code==200
    with pytest.raises(RuntimeError,match='Preserve official attendance history'):
        command.downgrade(config,'20261003_0023')
    with engine.connect() as conn:
        assert conn.scalar(text('SELECT version_num FROM alembic_version'))=='20261007_0030'
        assert conn.scalar(text('SELECT count(*) FROM official_attendance_decisions'))==1
