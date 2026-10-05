from __future__ import annotations

import hashlib
from dataclasses import replace
from datetime import datetime, timedelta, timezone
from uuid import uuid4

import pytest
from alembic import command as alembic_command
from alembic.config import Config
from sqlalchemy import create_engine, func, inspect, select, text
from sqlalchemy.orm import Session

from app.context_memberships import bind_student
from app.models import (
    CertificateReference,
    ClassEnrollment,
    Classroom,
    ClassroomCommandReceipt,
    ClassSession,
    Enrollment,
    OperatorCommandReceipt,
    ProgramMembership,
    SessionPresence,
    User,
)
from test_certificate_requests import header, requests_api


@pytest.fixture
def lifecycle_api(requests_api):
    client, engine = requests_api
    client.app.state.settings = replace(
        client.app.state.settings,
        class_lifecycle_enabled=True,
        operator_operations_enabled=True,
    )
    with Session(engine) as session:
        operator = session.get(ProgramMembership, ("other", "p1"))
        assert operator is not None
        operator.role = "program_operator"
        session.commit()
    return client, engine


def prepare_payload(**overrides):
    body = {
        "id": str(uuid4()),
        "reason": "Preparação territorial autorizada",
        "institution_id": "i1",
        "program_id": "p1",
        "course_id": "course",
        "teacher_id": "teacher",
        "monitor_ids": ["monitor"],
        "name": "Turma Palmas Centro",
        "offer_municipality": "Palmas",
        "offer_location": "Unidade territorial Centro",
        "start_date": "2026-10-11",
        "end_date": "2026-10-30",
    }
    body.update(overrides)
    return body


def prepare(client, actor="coordinator", **overrides):
    body = prepare_payload(**overrides)
    return client.post(
        "/operations/classes",
        headers=header(actor),
        json=body,
    ), body


def scoped(result, **overrides):
    classroom = result["classroom"]
    body = {
        "id": str(uuid4()),
        "reason": "Decisão operacional auditável",
        "institution_id": classroom["institution_id"],
        "program_id": classroom["program_id"],
        "course_id": classroom["course_id"],
        "version_id": classroom["course_version_id"],
        "expected_revision": classroom["revision"],
    }
    body.update(overrides)
    return body


def test_feature_flag_fail_closed_and_options_are_scoped(requests_api):
    client, _ = requests_api
    assert client.get(
        "/operations/classes/options",
        headers=header("coordinator"),
    ).status_code == 404

    client.app.state.settings = replace(
        client.app.state.settings,
        class_lifecycle_enabled=True,
    )
    options = client.get(
        "/operations/classes/options",
        headers=header("coordinator"),
    )
    assert options.status_code == 200
    row = options.json()["options"][0]
    assert row["institution_id"] == "i1"
    assert row["program_id"] == "p1"
    assert row["course_id"] == "course"
    assert row["course_version_id"] == "v2"
    assert row["role"] == "coordinator"
    assert row["can_override_capacity"] is True

    for actor in ("teacher", "monitor", "learner"):
        assert client.get(
            "/operations/classes/options",
            headers=header(actor),
        ).json() == {"options": []}


def test_legacy_admin_routes_remain_compatible_when_lifecycle_flag_is_off(
    requests_api,
):
    client, engine = requests_api
    legacy_payload = {
        "program_id": "p1",
        "course_id": "course",
        "teacher_id": "teacher",
        "name": "Legacy active bootstrap",
        "start_date": "2026-10-11",
        "end_date": "2026-10-30",
        "status": "active",
    }
    created = client.post(
        "/admin/classes",
        headers=header("admin"),
        json=legacy_payload,
    )
    assert created.status_code == 201, created.text
    class_id = created.json()["id"]

    with Session(engine) as session:
        session.add(
            User(
                id="legacy-monitor",
                cpf_digest="legacy-monitor",
                phone="61999990001",
                name="Legacy Monitor",
                password_digest="digest",
                role="student",
            )
        )
        session.flush()
        session.add(
            ProgramMembership(
                user_id="legacy-monitor",
                program_id="p1",
                role="monitor",
                status="active",
            )
        )
        session.commit()

    legacy_monitor = client.post(
        f"/admin/classes/{class_id}/monitors/legacy-monitor",
        headers=header("admin"),
    )
    assert legacy_monitor.status_code == 201, legacy_monitor.text

    client.app.state.settings = replace(
        client.app.state.settings,
        class_lifecycle_enabled=True,
    )
    strict_create = client.post(
        "/admin/classes",
        headers=header("admin"),
        json=legacy_payload | {"name": "Strict active bootstrap"},
    )
    assert strict_create.status_code == 422

    with Session(engine) as session:
        session.add(
            User(
                id="strict-monitor",
                cpf_digest="strict-monitor",
                phone="61999990002",
                name="Strict Monitor",
                password_digest="digest",
                role="student",
            )
        )
        session.flush()
        session.add(
            ProgramMembership(
                user_id="strict-monitor",
                program_id="p1",
                role="monitor",
                status="active",
            )
        )
        session.commit()

    strict_monitor = client.post(
        f"/admin/classes/{class_id}/monitors/strict-monitor",
        headers=header("admin"),
    )
    assert strict_monitor.status_code == 409


def test_team_candidates_and_manageable_classes_are_contextual(lifecycle_api):
    client, _ = lifecycle_api

    candidates = client.get(
        "/operations/classes/team-candidates",
        headers=header("other"),
        params={"program_id": "p1"},
    )
    assert candidates.status_code == 200, candidates.text
    payload = candidates.json()
    assert payload["program_id"] == "p1"
    assert payload["candidates"] == [
        {
            "user_id": "monitor",
            "display_name": "Name monitor",
            "role": "monitor",
        },
        {
            "user_id": "teacher",
            "display_name": "Name teacher",
            "role": "teacher",
        },
        {
            "user_id": "teacher2",
            "display_name": "Name teacher2",
            "role": "teacher",
        },
    ]
    assert all(
        set(candidate) == {"user_id", "display_name", "role"}
        for candidate in payload["candidates"]
    )
    assert client.get(
        "/operations/classes/team-candidates",
        headers=header("teacher"),
        params={"program_id": "p1"},
    ).status_code == 403
    assert client.get(
        "/operations/classes/team-candidates",
        headers=header("other"),
        params={"program_id": "p2"},
    ).status_code == 403

    operator_classes = client.get(
        "/operations/classes",
        headers=header("other"),
    )
    assert operator_classes.status_code == 200, operator_classes.text
    assert {
        item["classroom"]["id"] for item in operator_classes.json()["classes"]
    } == {"c1", "c2"}
    assert all(
        item["classroom"]["program_id"] == "p1"
        for item in operator_classes.json()["classes"]
    )

    teacher_classes = client.get(
        "/operations/classes",
        headers=header("teacher"),
    )
    assert teacher_classes.status_code == 200
    assert [
        item["classroom"]["id"] for item in teacher_classes.json()["classes"]
    ] == ["c1"]
    assert teacher_classes.json()["classes"][0]["capabilities"]["can_close"] is False

    assert client.get(
        "/operations/classes",
        headers=header("monitor"),
    ).json() == {"classes": []}

    outsider_classes = client.get(
        "/operations/classes",
        headers=header("outsider"),
    )
    assert outsider_classes.status_code == 200
    assert [
        item["classroom"]["id"] for item in outsider_classes.json()["classes"]
    ] == ["foreign-class"]


def test_prepare_pins_published_version_separates_territory_and_replays(lifecycle_api):
    client, engine = lifecycle_api
    response, body = prepare(client, actor="other")
    assert response.status_code == 201, response.text
    result = response.json()
    classroom = result["classroom"]
    class_id = classroom["id"]

    assert classroom["status"] == "planned"
    assert classroom["revision"] == 1
    assert classroom["course_version_id"] == "v2"
    assert classroom["offer_municipality"] == "Palmas"
    assert classroom["offer_location"] == "Unidade territorial Centro"
    assert result["capacity"] == {
        "limit": 30,
        "occupancy": 0,
        "remaining": 30,
        "over_capacity": False,
        "exception": None,
    }
    assert result["capabilities"]["role"] == "program_operator"
    assert result["capabilities"]["can_activate"] is False
    assert result["readiness"]["activation_blockers"] == []
    assert result["history"][0]["action"] == "prepare"

    replay = client.post(
        "/operations/classes",
        headers=header("other"),
        json=body,
    )
    assert replay.status_code == 201
    assert replay.json() == result

    divergent = body | {"offer_location": "Outro local"}
    assert client.post(
        "/operations/classes",
        headers=header("other"),
        json=divergent,
    ).status_code == 409

    with Session(engine) as session:
        persisted = session.get(Classroom, class_id)
        assert persisted is not None
        assert persisted.course_version_id == "v2"
        assert persisted.offer_municipality == "Palmas"
        assert persisted.offer_location == "Unidade territorial Centro"
        assert persisted.lifecycle_revision == 1
        assert session.scalar(
            select(func.count()).select_from(ClassroomCommandReceipt)
        ) == 1
        participant = session.get(User, "learner")
        assert participant is not None
        assert participant.name == "Name learner"
        assert participant.phone == "61999990000"

    cross_institution, _ = prepare(
        client,
        actor="other",
        institution_id="i2",
    )
    assert cross_institution.status_code == 403
    for actor in ("teacher", "monitor", "outsider"):
        denied, _ = prepare(client, actor=actor)
        assert denied.status_code == 403


def test_plan_team_and_strict_lifecycle_authority(lifecycle_api):
    client, engine = lifecycle_api
    prepared, _ = prepare(client)
    assert prepared.status_code == 201
    result = prepared.json()
    class_id = result["classroom"]["id"]
    pinned_version = result["classroom"]["course_version_id"]

    plan = scoped(
        result,
        name="Turma Palmas Sul",
        offer_municipality="Palmas",
        offer_location="Polo Sul",
        start_date="2026-10-12",
        end_date="2026-10-31",
    )
    planned = client.post(
        f"/operations/classes/{class_id}/plan",
        headers=header("other"),
        json=plan,
    )
    assert planned.status_code == 200, planned.text
    result = planned.json()
    assert result["classroom"]["revision"] == 2
    assert result["classroom"]["offer_location"] == "Polo Sul"
    assert result["classroom"]["course_version_id"] == pinned_version

    team = scoped(
        result,
        teacher_id="teacher",
        monitor_ids=["monitor"],
    )
    changed = client.post(
        f"/operations/classes/{class_id}/team",
        headers=header("other"),
        json=team,
    )
    assert changed.status_code == 200
    result = changed.json()
    assert result["classroom"]["revision"] == 3

    operator_activate = scoped(result, target_status="active")
    assert client.post(
        f"/operations/classes/{class_id}/transition",
        headers=header("other"),
        json=operator_activate,
    ).status_code == 403

    activate = scoped(result, target_status="active")
    activated = client.post(
        f"/operations/classes/{class_id}/transition",
        headers=header("coordinator"),
        json=activate,
    )
    assert activated.status_code == 200, activated.text
    result = activated.json()
    assert result["classroom"]["status"] == "active"
    assert result["classroom"]["revision"] == 4

    replay = client.post(
        f"/operations/classes/{class_id}/transition",
        headers=header("coordinator"),
        json=activate,
    )
    assert replay.status_code == 200
    assert replay.json() == result

    operator_team = scoped(
        result,
        teacher_id="teacher2",
        monitor_ids=[],
    )
    assert client.post(
        f"/operations/classes/{class_id}/team",
        headers=header("other"),
        json=operator_team,
    ).status_code == 403

    coordinator_team = scoped(
        result,
        teacher_id="teacher2",
        monitor_ids=[],
    )
    changed = client.post(
        f"/operations/classes/{class_id}/team",
        headers=header("coordinator"),
        json=coordinator_team,
    )
    assert changed.status_code == 200
    result = changed.json()
    assert result["classroom"]["teacher_id"] == "teacher2"
    assert result["classroom"]["monitor_ids"] == []
    assert result["classroom"]["revision"] == 5

    with Session(engine) as session:
        session.add(
            ClassSession(
                id=str(uuid4()),
                class_id=class_id,
                starts_at=datetime(2026, 10, 20, 12, tzinfo=timezone.utc),
                ends_at=datetime(2026, 10, 20, 14, tzinfo=timezone.utc),
                status="open",
                opened_by="teacher2",
                checkin_token_digest="d" * 64,
                token_expires_at=datetime(
                    2026, 10, 20, 12, 10, tzinfo=timezone.utc
                ),
            )
        )
        session.commit()
        presence_before = session.scalar(
            select(func.count())
            .select_from(SessionPresence)
            .where(SessionPresence.class_id == class_id)
        )
        certificates_before = session.scalar(
            select(func.count()).select_from(CertificateReference)
        )

    readiness = client.get(
        f"/operations/classes/{class_id}/readiness",
        headers=header("coordinator"),
    )
    assert readiness.status_code == 200
    assert readiness.json()["readiness"]["closure_warnings"]["open_sessions"] == 1
    assert readiness.json()["readiness"]["closure_warnings_block_close"] is False
    assert (
        readiness.json()["readiness"]["close_open_session_policy"]
        == "HUMAN_GATE_CLOSE_WITH_OPEN_SESSION"
    )

    close = scoped(readiness.json(), target_status="closed")
    closed = client.post(
        f"/operations/classes/{class_id}/transition",
        headers=header("coordinator"),
        json=close,
    )
    assert closed.status_code == 200, closed.text
    result = closed.json()
    assert result["classroom"]["status"] == "closed"
    assert result["classroom"]["revision"] == 6
    assert result["classroom"]["course_version_id"] == pinned_version
    assert result["readiness"]["closure_warnings"]["open_sessions"] == 1

    reopen = scoped(result, target_status="active")
    assert client.post(
        f"/operations/classes/{class_id}/transition",
        headers=header("coordinator"),
        json=reopen,
    ).status_code == 409
    replan = scoped(
        result,
        name="Não reabrir",
        offer_municipality="Palmas",
        offer_location="Polo",
        start_date="2026-10-12",
        end_date="2026-10-31",
    )
    assert client.post(
        f"/operations/classes/{class_id}/plan",
        headers=header("coordinator"),
        json=replan,
    ).status_code == 409

    with Session(engine) as session:
        assert session.scalar(
            select(func.count())
            .select_from(SessionPresence)
            .where(SessionPresence.class_id == class_id)
        ) == presence_before
        assert session.scalar(
            select(func.count()).select_from(CertificateReference)
        ) == certificates_before
        actions = list(
            session.scalars(
                select(ClassroomCommandReceipt.action)
                .where(ClassroomCommandReceipt.class_id == class_id)
                .order_by(ClassroomCommandReceipt.revision)
            )
        )
        assert actions == [
            "prepare",
            "plan",
            "team",
            "transition_active",
            "team",
            "transition_closed",
        ]


def _add_student_lineage(session, *, user_id: str, class_id: str, active_link: bool):
    digest = hashlib.sha256(user_id.encode()).hexdigest()
    session.add(
        User(
            id=user_id,
            cpf_digest=digest,
            phone="61999990000",
            name=f"Synthetic {user_id}",
            password_digest="digest",
            role="student",
        )
    )
    session.flush()
    session.add(
        ProgramMembership(
            user_id=user_id,
            program_id="p1",
            role="student",
            status="active",
        )
    )
    session.flush()
    session.add(
        Enrollment(
            id=f"enrollment-{user_id}",
            user_id=user_id,
            program_id="p1",
            course_id="course",
            status="active",
        )
    )
    session.flush()
    if active_link:
        session.add(
            ClassEnrollment(
                class_id=class_id,
                user_id=user_id,
                enrollment_id=f"enrollment-{user_id}",
                program_id="p1",
                course_id="course",
                status="active",
            )
        )


def test_capacity_30_blocks_operator_and_only_coordinator_override_is_audited(
    lifecycle_api,
):
    client, engine = lifecycle_api
    prepared, _ = prepare(client)
    result = prepared.json()
    class_id = result["classroom"]["id"]

    activate = scoped(result, target_status="active")
    activated = client.post(
        f"/operations/classes/{class_id}/transition",
        headers=header("coordinator"),
        json=activate,
    )
    assert activated.status_code == 200

    with Session(engine) as session:
        for index in range(30):
            _add_student_lineage(
                session,
                user_id=f"seat-{index:02d}",
                class_id=class_id,
                active_link=True,
            )
        _add_student_lineage(
            session,
            user_id="overflow",
            class_id=class_id,
            active_link=False,
        )
        _add_student_lineage(
            session,
            user_id="overflow2",
            class_id=class_id,
            active_link=False,
        )
        session.commit()

    command_body = {
        "id": str(uuid4()),
        "action": "assign",
        "reason": "Capacidade padrão atingida",
        "institution_id": "i1",
        "program_id": "p1",
        "course_id": "course",
        "version_id": "v2",
        "person_id": "overflow",
        "expected_revision": 0,
    }
    blocked = client.post(
        f"/operations/{class_id}/commands",
        headers=header("other"),
        json=command_body,
    )
    assert blocked.status_code == 409
    assert "Somente a coordenação" in blocked.json()["detail"]

    coordinator_body = command_body | {
        "id": str(uuid4()),
        "reason": "Exceção aprovada pela coordenação para esta oferta",
    }
    overridden = client.post(
        f"/operations/{class_id}/commands",
        headers=header("coordinator"),
        json=coordinator_body,
    )
    assert overridden.status_code == 200, overridden.text

    with Session(engine) as session:
        receipt = session.scalar(
            select(OperatorCommandReceipt).where(
                OperatorCommandReceipt.subject_id == "overflow"
            )
        )
        assert receipt is not None
        assert receipt.action == "assign_capacity_override"
        assert receipt.actor_id == "coordinator"
        assert receipt.reason == coordinator_body["reason"]
        assert session.scalar(
            select(func.count())
            .select_from(ClassEnrollment)
            .where(
                ClassEnrollment.class_id == class_id,
                ClassEnrollment.status == "active",
            )
        ) == 31

    readiness = client.get(
        f"/operations/classes/{class_id}/readiness",
        headers=header("coordinator"),
    )
    assert readiness.status_code == 200
    capacity = readiness.json()["capacity"]
    assert capacity["limit"] == 30
    assert capacity["occupancy"] == 31
    assert capacity["over_capacity"] is True
    assert capacity["exception"]["state"] == "authorized"
    assert capacity["exception"]["actor_id"] == "coordinator"
    assert capacity["exception"]["reason"] == coordinator_body["reason"]

    admin_bypass = client.post(
        f"/admin/classes/{class_id}/students/overflow2",
        headers=header("admin"),
    )
    teacher_bypass = client.put(
        f"/classes/{class_id}/students/overflow2",
        headers=header("teacher"),
    )
    assert admin_bypass.status_code == 409
    assert teacher_bypass.status_code == 409

    with Session(engine) as session:
        classroom = session.get(Classroom, class_id)
        assert classroom is not None
        assert classroom.status == "active"
        link = session.get(ClassEnrollment, (class_id, "overflow"))
        assert link is not None
        bind_student(session, classroom, link)
        session.rollback()


def test_closed_class_rejects_new_participant_across_write_paths(lifecycle_api):
    client, engine = lifecycle_api
    prepared, _ = prepare(client)
    result = prepared.json()
    class_id = result["classroom"]["id"]
    activated = client.post(
        f"/operations/classes/{class_id}/transition",
        headers=header("coordinator"),
        json=scoped(result, target_status="active"),
    ).json()
    closed = client.post(
        f"/operations/classes/{class_id}/transition",
        headers=header("coordinator"),
        json=scoped(activated, target_status="closed"),
    )
    assert closed.status_code == 200

    with Session(engine) as session:
        _add_student_lineage(
            session,
            user_id="after-close",
            class_id=class_id,
            active_link=False,
        )
        session.commit()

    operator_body = {
        "id": str(uuid4()),
        "action": "assign",
        "reason": "Não deve entrar em turma encerrada",
        "institution_id": "i1",
        "program_id": "p1",
        "course_id": "course",
        "version_id": "v2",
        "person_id": "after-close",
        "expected_revision": 0,
    }
    assert client.post(
        f"/operations/{class_id}/commands",
        headers=header("other"),
        json=operator_body,
    ).status_code == 409
    assert client.post(
        f"/admin/classes/{class_id}/students/after-close",
        headers=header("admin"),
    ).status_code == 409
    assert client.put(
        f"/classes/{class_id}/students/after-close",
        headers=header("teacher"),
    ).status_code == 409


def test_0028_migration_empty_roundtrip_and_populated_guard(tmp_path):
    database_path = tmp_path / "class-lifecycle.db"
    database_url = f"sqlite+pysqlite:///{database_path.as_posix()}"
    config = Config("alembic.ini")
    config.set_main_option("sqlalchemy.url", database_url)
    engine = create_engine(database_url)

    alembic_command.upgrade(config, "20261005_0027")
    alembic_command.upgrade(config, "head")
    columns = {
        item["name"] for item in inspect(engine).get_columns("classes")
    }
    assert {
        "offer_municipality",
        "offer_location",
        "lifecycle_revision",
    } <= columns
    assert "classroom_command_receipts" in inspect(engine).get_table_names()
    indexes = {
        item["name"]
        for item in inspect(engine).get_indexes("classroom_command_receipts")
    }
    assert "ix_classroom_command_receipts_class_time" in indexes

    alembic_command.downgrade(config, "20261005_0027")
    assert "classroom_command_receipts" not in inspect(engine).get_table_names()
    columns = {
        item["name"] for item in inspect(engine).get_columns("classes")
    }
    assert "offer_municipality" not in columns
    assert "lifecycle_revision" not in columns

    alembic_command.upgrade(config, "head")
    with engine.begin() as connection:
        connection.execute(
            text(
                "INSERT INTO classroom_command_receipts "
                "(id, actor_id, program_id, class_id, revision, action, reason, "
                "request_hash, result, occurred_at) VALUES "
                "('receipt-guard', NULL, 'missing-program', 'missing-class', 1, "
                "'prepare', 'guard', :hash, '{}', :occurred)"
            ),
            {
                "hash": "a" * 64,
                "occurred": datetime.now(timezone.utc),
            },
        )
    with pytest.raises(RuntimeError, match="Preserve classroom lifecycle history"):
        alembic_command.downgrade(config, "20261005_0027")
    with engine.connect() as connection:
        assert (
            connection.scalar(text("SELECT version_num FROM alembic_version"))
            == "20261005_0028"
        )
    engine.dispose()
