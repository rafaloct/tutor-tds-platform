from __future__ import annotations

from datetime import date, datetime, timedelta, timezone
from pathlib import Path

from fastapi import FastAPI, Header
from fastapi.testclient import TestClient
import pytest
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.assessment_sync import (
    _published_attempt_id,
    content_router,
    context_router,
    router,
)
from app.auth import access_claims
from app.classrooms import router as classrooms_router
from app.config import Settings
from app.context_memberships import bind_membership, bind_student
from app.course_editor import snapshot_content
from app.database import Database
from app.events import router as events_router
from app.events import student_claims as event_student_claims
from app.models import (
    AssessmentAttemptRecord,
    AssessmentContentRecord,
    Base,
    ClassEnrollment,
    ClassMonitor,
    Classroom,
    CohortMembership,
    Course,
    CourseVersion,
    Enrollment,
    Institution,
    LearningEventRecord,
    Program,
    ProgramCourse,
    ProgramMembership,
    User,
)


@pytest.fixture
def dynamic_activity(tmp_path: Path):
    database = Database(
        f"sqlite+pysqlite:///{(tmp_path / 'dynamic-activity.db').as_posix()}"
    )
    Base.metadata.create_all(database.engine)
    app = FastAPI()
    app.state.database = database
    app.state.settings = Settings(
        database_url=str(database.engine.url),
        allowed_origins=(),
        learning_context_enabled=True,
        dynamic_activity_enabled=True,
    )
    app.include_router(router)
    app.include_router(content_router)
    app.include_router(context_router)
    app.include_router(classrooms_router)
    app.include_router(events_router)

    roles = {
        "learner": "student",
        "teacher": "teacher",
        "outsider": "teacher",
        "monitor": "monitor",
        "admin": "admin",
    }

    def claims(x_user: str = Header(default="learner")) -> dict[str, str]:
        return {"sub": x_user, "role": roles[x_user]}

    app.dependency_overrides[access_claims] = claims
    app.dependency_overrides[event_student_claims] = claims

    content = snapshot_content(
        "course",
        "Curso dinâmico",
        "TDS",
        {
            "sections": [
                {
                    "id": "section",
                    "title": "Módulo dinâmico",
                    "messages": [
                        {
                            "id": "quiz",
                            "type": "quiz",
                            "content": "Quais alternativas são aceitas?",
                            "feedback": "Feedback geral reservado",
                            "explanation": "Explicação reservada",
                            "options": [
                                {
                                    "id": "option-a",
                                    "label": "A",
                                    "value": "a",
                                    "isCorrect": True,
                                    "feedback": "Correta",
                                },
                                {"label": "B", "isCorrect": True},
                                {"label": "C", "isCorrect": False},
                            ],
                        },
                        {
                            "id": "question",
                            "type": "question",
                            "content": "Qual opção você prefere?",
                            "options": [
                                {"label": "A", "value": "a"},
                                {"label": "B", "value": "b"},
                            ],
                        },
                    ],
                }
            ]
        },
    )
    section = content["sections"][0]
    blocks = {item["id"]: item for item in section["messages"]}
    with Session(database.engine) as session:
        session.add(Institution(id="organization", name="IPEX"))
        session.flush()
        session.add(Program(id="program", institution_id="organization", name="TDS"))
        session.add(
            Course(
                id="course",
                title="Curso dinâmico",
                author="TDS",
                content={"sections": []},
                active=True,
            )
        )
        session.flush()
        session.add(ProgramCourse(program_id="program", course_id="course"))
        for index, (identity, role) in enumerate(roles.items()):
            session.add(
                User(
                    id=identity,
                    name=identity,
                    cpf_digest=str(index).zfill(64),
                    phone="61999990000",
                    password_digest="digest",
                    role=role,
                )
            )
        session.flush()
        session.add_all(
            [
                ProgramMembership(
                    user_id="learner",
                    program_id="program",
                    role="student",
                    status="active",
                ),
                ProgramMembership(
                    user_id="teacher",
                    program_id="program",
                    role="teacher",
                    status="active",
                ),
                ProgramMembership(
                    user_id="outsider",
                    program_id="program",
                    role="teacher",
                    status="active",
                ),
                ProgramMembership(
                    user_id="monitor",
                    program_id="program",
                    role="monitor",
                    status="active",
                ),
            ]
        )
        session.add(
            CourseVersion(
                id="version",
                course_id="course",
                program_id="program",
                creator_user_id="teacher",
                version_number=1,
                revision=1,
                status="published",
                content=content,
            )
        )
        session.flush()
        session.add(
            Classroom(
                id="class",
                program_id="program",
                course_id="course",
                course_version_id="version",
                teacher_id="teacher",
                name="Turma",
                start_date=date(2026, 1, 1),
                end_date=date(2026, 12, 31),
                status="active",
            )
        )
        session.add(
            Enrollment(
                id="legacy-enrollment",
                user_id="learner",
                program_id="program",
                course_id="course",
                status="active",
            )
        )
        session.flush()
        link = ClassEnrollment(
            class_id="class",
            user_id="learner",
            enrollment_id="legacy-enrollment",
            program_id="program",
            course_id="course",
            status="active",
        )
        session.add(link)
        session.flush()
        bind_student(session, session.get(Classroom, "class"), link)
        session.add(
            ClassMonitor(
                class_id="class", user_id="monitor", program_id="program"
            )
        )
        bind_membership(session, "class", "monitor", "monitor")
        session.commit()
        lineage = {
            "organization_id": "organization",
            "program_id": "program",
            "class_id": "class",
            "membership_id": link.membership_id,
            "enrollment_id": link.context_id,
            "legacy_enrollment_id": "legacy-enrollment",
            "course_version_id": "version",
            "section_id": "section",
            "section_version_id": section["version_id"],
        }

    with TestClient(app) as client:
        yield client, database, lineage, blocks
    database.dispose()


def payload(lineage: dict[str, str], block: dict, *, revision: int = 1, completed: bool = True):
    return {
        "course_id": "course",
        "origin": "published_block",
        **lineage,
        "block_id": block["id"],
        "block_version_id": block["version_id"],
        "topic": "Módulo dinâmico",
        "mode": "quiz",
        "revision": revision,
        "answers": {"0": 1},
        "marked": [],
        "current_index": 0,
        "remaining_seconds": 0,
        "completed": completed,
        "score": 0,
        "updated_at": f"2026-10-07T12:0{revision}:00Z",
    }


def canonical_attempt_id(
    lineage: dict[str, str], block: dict, *, owner_id: str = "learner"
) -> str:
    return _published_attempt_id(
        owner_id,
        {
            "course_id": "course",
            **lineage,
            "block_id": block["id"],
            "block_version_id": block["version_id"],
        },
    )


def test_published_quiz_uses_server_snapshot_and_writes_zero_credit_evidence(
    dynamic_activity,
) -> None:
    client, database, lineage, blocks = dynamic_activity
    body = payload(lineage, blocks["quiz"])
    attempt_id = canonical_attempt_id(lineage, blocks["quiz"])
    created = client.put(
        f"/assessment-attempts/{attempt_id}", headers={"X-User": "learner"}, json=body
    )
    retry = client.put(
        f"/assessment-attempts/{attempt_id}", headers={"X-User": "learner"}, json=body
    )
    contextual = client.get(
        f"/classes/class/assessment-attempts/{attempt_id}",
        headers={"X-User": "learner"},
    )
    legacy = client.get(
        f"/assessment-attempts/{attempt_id}", headers={"X-User": "learner"}
    )
    hydrated = client.get(
        f"/classes/class/assessment-attempts/{attempt_id}/content",
        headers={"X-User": "learner"},
    )
    teacher = client.get(
        "/classes/class/students/learner/assessment-attempts",
        headers={"X-User": "teacher"},
    )
    outsider = client.get(
        "/classes/class/students/learner/assessment-attempts",
        headers={"X-User": "outsider"},
    )
    monitor = client.get(
        "/classes/class/students/learner/assessment-attempts",
        headers={"X-User": "monitor"},
    )
    admin = client.get(
        "/classes/class/students/learner/assessment-attempts",
        headers={"X-User": "admin"},
    )
    listed_events = client.get(
        "/events?course_id=course&limit=100",
        headers={"X-User": "learner"},
    )
    fabricated_event = client.post(
        "/events",
        headers={"X-User": "learner"},
        json={
            "event_id": "client-fabricated-completion",
            "event_type": "assessment_completed",
            "course_id": "course",
            "session_id": "client-session",
            "occurred_at": "2026-10-07T12:00:00Z",
            "payload": {"attempt_id": "attempt-quiz"},
        },
    )

    assert created.status_code == 201, created.text
    assert retry.status_code == 200 and retry.json() == created.json()
    assert created.json()["score"] == 1
    assert created.json()["origin"] == "published_block"
    assert created.json()["assessment_content_id"].startswith("published-block:")
    assert contextual.status_code == 200
    assert legacy.status_code == 404
    assert hydrated.status_code == 200
    assert hydrated.json()["answer_key"] == [
        {
            "correct_indices": [0, 1],
            "explanation": "Explicação reservada",
            "graded": True,
        }
    ]
    assert teacher.status_code == 200 and teacher.json()["total"] == 1
    assert monitor.status_code == 403
    assert admin.status_code == 200 and admin.json()["total"] == 1
    assert outsider.status_code == 403
    assert listed_events.status_code == 200, listed_events.text
    completion = next(
        item
        for item in listed_events.json()["events"]
        if item["event_type"] == "assessment_completed"
    )
    assert completion["active_seconds"] is None
    assert completion["validated_seconds"] == 0
    assert completion["payload"]["attempt_id"] == attempt_id
    assert (
        completion["payload"]["block_version_id"]
        == blocks["quiz"]["version_id"]
    )
    assert fabricated_event.status_code == 422

    with Session(database.engine) as session:
        assert session.scalar(select(func.count()).select_from(AssessmentContentRecord)) == 1
        events = session.scalars(select(LearningEventRecord)).all()
        assert len(events) == 1
        assert events[0].event_type == "assessment_completed"
        assert events[0].active_seconds == events[0].validated_seconds == 0
        assert events[0].payload["origin"] == "published_block"
        assert not {
            "owner_id",
            "membership_id",
            "enrollment_id",
            "legacy_enrollment_id",
        } & set(events[0].payload)
        assert events[0].payload["course_id"] == "course"
        assert events[0].payload["graded"] is True
        assert events[0].payload["class_id"] == "class"


def test_wave2b_course_projection_hides_answers_from_learners_and_monitors(
    dynamic_activity,
) -> None:
    client, database, _, _ = dynamic_activity

    learner = client.get(
        "/classes/class/course", headers={"X-User": "learner"}
    )
    monitor = client.get(
        "/classes/class/course", headers={"X-User": "monitor"}
    )
    teacher = client.get(
        "/classes/class/course", headers={"X-User": "teacher"}
    )
    admin = client.get(
        "/classes/class/course", headers={"X-User": "admin"}
    )

    assert learner.status_code == monitor.status_code == 200
    learner_quiz = learner.json()["sections"][0]["messages"][0]
    monitor_quiz = monitor.json()["sections"][0]["messages"][0]
    assert learner_quiz == monitor_quiz
    assert learner_quiz["options"] == [
        {"id": "option-a", "label": "A"},
        {"label": "B"},
        {"label": "C"},
    ]
    assert not {"feedback", "explanation"} & set(learner_quiz)
    assert all(
        not {"value", "isCorrect", "feedback"} & set(option)
        for option in learner_quiz["options"]
    )
    assert teacher.status_code == admin.status_code == 200
    for staff_view in (teacher.json(), admin.json()):
        staff_quiz = staff_view["sections"][0]["messages"][0]
        assert staff_quiz["feedback"] == "Feedback geral reservado"
        assert staff_quiz["explanation"] == "Explicação reservada"
        assert staff_quiz["options"][0]["isCorrect"] is True
        assert staff_quiz["options"][0]["value"] == "a"

    with Session(database.engine) as session:
        stored = session.get(CourseVersion, "version").content
        assert stored["sections"][0]["messages"][0]["options"][0][
            "isCorrect"
        ] is True

    client.app.state.settings = Settings(
        database_url=str(database.engine.url),
        allowed_origins=(),
        learning_context_enabled=True,
        dynamic_activity_enabled=False,
    )
    legacy = client.get(
        "/classes/class/course", headers={"X-User": "learner"}
    )
    assert legacy.status_code == 200
    assert legacy.json()["sections"][0]["messages"][0]["options"][0][
        "isCorrect"
    ] is True


def test_published_content_provenance_canonical_attempt_and_answer_release(
    dynamic_activity,
) -> None:
    client, database, lineage, blocks = dynamic_activity
    quiz = blocks["quiz"]
    attempt_id = canonical_attempt_id(lineage, quiz)
    pending = payload(lineage, quiz, completed=False)
    created = client.put(
        f"/assessment-attempts/{attempt_id}",
        headers={"X-User": "learner"},
        json=pending,
    )
    assert created.status_code == 201, created.text
    content_id = created.json()["assessment_content_id"]

    before_completion = client.get(
        f"/classes/class/assessment-attempts/{attempt_id}/content",
        headers={"X-User": "learner"},
    )
    assert before_completion.status_code == 200
    assert before_completion.json()["answer_key"] is None

    practice_laundering = client.put(
        "/assessment-attempts/practice-laundering",
        headers={"X-User": "learner"},
        json={
            "course_id": "course",
            "origin": "practice",
            "assessment_content_id": content_id,
            "topic": "Módulo dinâmico",
            "mode": "quiz",
            "revision": 1,
            "answers": {},
            "marked": [],
            "current_index": 0,
            "remaining_seconds": 0,
            "completed": False,
            "score": 0,
            "updated_at": "2026-10-07T12:00:00Z",
        },
    )
    assert practice_laundering.status_code == 409
    assert practice_laundering.json()["detail"]["code"] == (
        "published_block_content_is_server_owned"
    )
    assert client.get(
        f"/assessment-contents/{content_id}",
        headers={"X-User": "learner"},
    ).status_code == 404

    reserved = client.put(
        "/assessment-contents/published-block:client",
        headers={"X-User": "learner"},
        json={
            "course_id": "course",
            "topic": "Módulo dinâmico",
            "mode": "quiz",
            "title": "Quiz",
            "duration_seconds": 0,
            "questions": [
                {
                    "question": "Pergunta?",
                    "options": ["A", "B"],
                    "correct_index": 0,
                    "topic": "Módulo dinâmico",
                }
            ],
        },
    )
    assert reserved.status_code == 422
    assert reserved.json()["detail"]["code"] == (
        "assessment_content_namespace_reserved"
    )

    completed = client.put(
        f"/assessment-attempts/{attempt_id}",
        headers={"X-User": "learner"},
        json=payload(lineage, quiz, revision=2, completed=True),
    )
    assert completed.status_code == 200, completed.text
    after_completion = client.get(
        f"/classes/class/assessment-attempts/{attempt_id}/content",
        headers={"X-User": "learner"},
    )
    assert after_completion.json()["answer_key"] == [
        {"correct_indices": [0, 1], "explanation": "Explicação reservada", "graded": True}
    ]

    noncanonical = client.put(
        "/assessment-attempts/second-id-for-same-block",
        headers={"X-User": "learner"},
        json=payload(lineage, quiz, revision=1, completed=True),
    )
    assert noncanonical.status_code == 409
    assert noncanonical.json()["detail"] == {
        "code": "canonical_attempt_id_required",
        "expected_attempt_id": attempt_id,
    }
    with Session(database.engine) as session:
        assert session.scalar(
            select(func.count()).select_from(AssessmentAttemptRecord)
        ) == 1
        assert session.scalar(
            select(func.count()).select_from(LearningEventRecord)
        ) == 1


def test_contextual_timestamp_is_bounded_without_changing_practice_model(
    dynamic_activity,
) -> None:
    client, database, lineage, blocks = dynamic_activity
    question = blocks["question"]
    attempt_id = canonical_attempt_id(lineage, question)
    future = datetime.now(timezone.utc) + timedelta(minutes=6)
    rejected = client.put(
        f"/assessment-attempts/{attempt_id}",
        headers={"X-User": "learner"},
        json=payload(lineage, question, completed=False)
        | {"updated_at": future.isoformat()},
    )
    assert rejected.status_code == 422
    detail = rejected.json()["detail"]
    assert detail["code"] == "future_updated_at"
    assert detail["max_future_seconds"] == 300
    server_time = datetime.fromisoformat(detail["server_time"].replace("Z", "+00:00"))
    assert server_time.tzinfo is not None
    with Session(database.engine) as session:
        assert session.get(AssessmentAttemptRecord, attempt_id) is None

    corrected = client.put(
        f"/assessment-attempts/{attempt_id}",
        headers={"X-User": "learner"},
        json=payload(lineage, question, completed=False)
        | {"updated_at": detail["server_time"]},
    )
    assert corrected.status_code == 201, corrected.text
    assert corrected.json()["revision"] == 1
    assert corrected.json()["answers"] == {"0": 1}

    from app.assessment_sync import AssessmentAttemptUpsert

    legacy_future = AssessmentAttemptUpsert.model_validate(
        {
            "course_id": "course",
            "origin": "practice",
            "assessment_content_id": "practice-content",
            "topic": "Prática",
            "mode": "quiz",
            "revision": 1,
            "answers": {},
            "marked": [],
            "current_index": 0,
            "remaining_seconds": 0,
            "completed": False,
            "score": 0,
            "updated_at": "2126-10-07T12:00:00Z",
        }
    )
    assert legacy_future.updated_at.year == 2126


def test_question_without_key_is_persisted_without_grade_and_client_key_is_rejected(
    dynamic_activity,
) -> None:
    client, _, lineage, blocks = dynamic_activity
    body = payload(lineage, blocks["question"])
    attempt_id = canonical_attempt_id(lineage, blocks["question"])
    created = client.put(
        f"/assessment-attempts/{attempt_id}",
        headers={"X-User": "learner"},
        json=body,
    )
    injected = client.put(
        "/assessment-attempts/attempt-injected",
        headers={"X-User": "learner"},
        json=body | {"answer_key": [{"correct_indices": [1]}]},
    )
    supplied_content = client.put(
        "/assessment-attempts/attempt-supplied-content",
        headers={"X-User": "learner"},
        json=body | {"assessment_content_id": "client-owned"},
    )
    hydrated = client.get(
        f"/classes/class/assessment-attempts/{attempt_id}/content",
        headers={"X-User": "learner"},
    )

    assert created.status_code == 201, created.text
    assert created.json()["score"] == 0
    assert injected.status_code == 422
    assert supplied_content.status_code == 422
    assert supplied_content.json()["detail"]["code"] == "published_block_content_is_server_owned"
    assert hydrated.json()["answer_key"] == [
        {"correct_indices": [], "explanation": "", "graded": False}
    ]


def test_contextual_completion_uses_revision_cas_and_replays_evidence_once(
    dynamic_activity,
) -> None:
    client, database, lineage, blocks = dynamic_activity
    pending = payload(lineage, blocks["quiz"], completed=False)
    completed = payload(lineage, blocks["quiz"], revision=2, completed=True)
    attempt_id = canonical_attempt_id(lineage, blocks["quiz"])

    created = client.put(
        f"/assessment-attempts/{attempt_id}",
        headers={"X-User": "learner"},
        json=pending,
    )
    accepted = client.put(
        f"/assessment-attempts/{attempt_id}",
        headers={"X-User": "learner"},
        json=completed,
    )
    replay = client.put(
        f"/assessment-attempts/{attempt_id}",
        headers={"X-User": "learner"},
        json=completed,
    )
    stale = client.put(
        f"/assessment-attempts/{attempt_id}",
        headers={"X-User": "learner"},
        json=pending,
    )

    assert created.status_code == 201
    assert accepted.status_code == 200
    assert accepted.json()["revision"] == 2
    assert replay.status_code == 200 and replay.json() == accepted.json()
    assert stale.status_code == 409
    with Session(database.engine) as session:
        assert session.scalar(
            select(func.count()).select_from(LearningEventRecord)
        ) == 1


def test_contextual_student_binding_does_not_depend_on_global_user_role(
    dynamic_activity,
) -> None:
    client, database, lineage, blocks = dynamic_activity
    with Session(database.engine) as session:
        session.get(User, "learner").role = "teacher"
        session.commit()

    def teacher_claims() -> dict[str, str]:
        return {"sub": "learner", "role": "teacher"}

    client.app.dependency_overrides[access_claims] = teacher_claims
    attempt_id = canonical_attempt_id(lineage, blocks["quiz"])
    created = client.put(
        f"/assessment-attempts/{attempt_id}",
        json=payload(lineage, blocks["quiz"]),
    )
    assert created.status_code == 201, created.text


@pytest.mark.parametrize(
    ("field", "expected_status"),
    [
        ("organization_id", 409),
        ("program_id", 409),
        ("class_id", 404),
        ("membership_id", 409),
        ("enrollment_id", 409),
        ("legacy_enrollment_id", 409),
        ("course_id", 409),
        ("course_version_id", 409),
        ("section_id", 404),
        ("section_version_id", 409),
        ("block_id", 404),
        ("block_version_id", 409),
    ],
)
def test_each_published_block_identifier_is_revalidated(
    dynamic_activity, field: str, expected_status: int
) -> None:
    client, database, lineage, blocks = dynamic_activity
    body = payload(lineage, blocks["quiz"]) | {field: "tampered"}
    response = client.put(
        f"/assessment-attempts/tampered-{field}",
        headers={"X-User": "learner"},
        json=body,
    )
    assert response.status_code == expected_status, response.text
    with Session(database.engine) as session:
        assert session.scalar(
            select(func.count()).select_from(AssessmentAttemptRecord)
        ) == 0


def test_two_classes_and_editions_keep_attempts_isolated(dynamic_activity) -> None:
    client, database, lineage, blocks = dynamic_activity
    second_content = snapshot_content(
        "course",
        "Curso dinâmico",
        "TDS",
        {
            "sections": [
                {
                    "id": "section",
                    "title": "Módulo dinâmico",
                    "messages": [
                        {
                            "id": "quiz",
                            "type": "quiz",
                            "content": "Qual alternativa pertence à edição dois?",
                            "options": [
                                {"label": "Edição um", "isCorrect": False},
                                {"label": "Edição dois", "isCorrect": True},
                            ],
                        }
                    ],
                }
            ]
        },
    )
    second_section = second_content["sections"][0]
    second_block = second_section["messages"][0]
    with Session(database.engine) as session:
        session.add(
            CourseVersion(
                id="version-2",
                course_id="course",
                program_id="program",
                creator_user_id="teacher",
                source_version_id="version",
                version_number=2,
                revision=1,
                status="published",
                content=second_content,
            )
        )
        session.add(
            Classroom(
                id="class-2",
                program_id="program",
                course_id="course",
                course_version_id="version-2",
                teacher_id="teacher",
                name="Turma 2",
                start_date=date(2026, 1, 1),
                end_date=date(2026, 12, 31),
                status="active",
            )
        )
        session.flush()
        link = ClassEnrollment(
            class_id="class-2",
            user_id="learner",
            enrollment_id="legacy-enrollment",
            program_id="program",
            course_id="course",
            status="active",
        )
        session.add(link)
        session.flush()
        bind_student(session, session.get(Classroom, "class-2"), link)
        session.commit()
        second_lineage = {
            **lineage,
            "class_id": "class-2",
            "membership_id": link.membership_id,
            "enrollment_id": link.context_id,
            "course_version_id": "version-2",
            "section_version_id": second_section["version_id"],
        }

    first_attempt_id = canonical_attempt_id(lineage, blocks["quiz"])
    second_attempt_id = canonical_attempt_id(second_lineage, second_block)
    first = client.put(
        f"/assessment-attempts/{first_attempt_id}",
        headers={"X-User": "learner"},
        json=payload(lineage, blocks["quiz"]),
    )
    second = client.put(
        f"/assessment-attempts/{second_attempt_id}",
        headers={"X-User": "learner"},
        json=payload(second_lineage, second_block),
    )
    first_page = client.get(
        "/classes/class/assessment-attempts", headers={"X-User": "learner"}
    )
    second_page = client.get(
        "/classes/class-2/assessment-attempts", headers={"X-User": "learner"}
    )
    crossed_snapshot = client.put(
        "/assessment-attempts/crossed-edition",
        headers={"X-User": "learner"},
        json=payload(second_lineage, blocks["quiz"]),
    )

    assert first.status_code == second.status_code == 201
    assert [item["attempt_id"] for item in first_page.json()["attempts"]] == [
        first_attempt_id
    ]
    assert [item["attempt_id"] for item in second_page.json()["attempts"]] == [
        second_attempt_id
    ]
    assert crossed_snapshot.status_code == 409


def test_context_conflict_revocation_and_disabled_flag_fail_closed(
    dynamic_activity,
) -> None:
    client, database, lineage, blocks = dynamic_activity
    assert Settings(
        database_url="sqlite+pysqlite:///:memory:", allowed_origins=()
    ).dynamic_activity_enabled is False
    body = payload(lineage, blocks["quiz"], completed=False)
    attempt_id = canonical_attempt_id(lineage, blocks["quiz"])
    created = client.put(
        f"/assessment-attempts/{attempt_id}",
        headers={"X-User": "learner"},
        json=body,
    )
    wrong_snapshot = client.put(
        "/assessment-attempts/wrong-snapshot",
        headers={"X-User": "learner"},
        json=body | {"block_version_id": "wrong"},
    )
    assert created.status_code == 201, created.text
    assert wrong_snapshot.status_code == 409
    assert wrong_snapshot.json()["detail"]["code"] == "published_block_snapshot_conflict"

    with Session(database.engine) as session:
        session.get(CohortMembership, lineage["membership_id"]).status = "inactive"
        session.commit()
    revoked_write = client.put(
        f"/assessment-attempts/{attempt_id}",
        headers={"X-User": "learner"},
        json=payload(lineage, blocks["quiz"], revision=2),
    )
    revoked_read = client.get(
        "/classes/class/assessment-attempts",
        headers={"X-User": "learner"},
    )
    assert revoked_write.status_code == revoked_read.status_code == 403
    preserved_staff_history = client.get(
        "/classes/class/students/learner/assessment-attempts",
        headers={"X-User": "teacher"},
    )
    assert preserved_staff_history.status_code == 200
    assert preserved_staff_history.json()["total"] == 1

    client.app.state.settings = Settings(
        database_url=str(database.engine.url),
        allowed_origins=(),
        learning_context_enabled=True,
        dynamic_activity_enabled=False,
    )
    disabled = client.put(
        "/assessment-attempts/disabled",
        headers={"X-User": "learner"},
        json=body,
    )
    assert disabled.status_code == 404
