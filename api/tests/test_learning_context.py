from dataclasses import replace

from fastapi import Header
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.auth import access_claims
from app.classrooms import router as classroom_router
from app.config import Settings
from app.context_memberships import backfill_context_bindings
from app.learning_context import router
from app.models import ClassEnrollment, Classroom, CohortMembership, CourseVersion, LearningEventRecord, ProgramMembership, User
from test_course_version_events import event, version_events


def setup_context(client):
    with Session(client.app.state.database.engine) as session:
        backfill_context_bindings(session)
        session.commit()
    client.app.include_router(router)
    client.app.include_router(classroom_router)
    client.app.state.settings = Settings(database_url="sqlite://", allowed_origins=(), learning_context_enabled=True)

    def claims(x_user: str = Header(default="student")):
        return {"sub": x_user, "role": "student"}

    client.app.dependency_overrides[access_claims] = claims


def test_student_learning_path_and_instructor_observation_share_exact_projection(version_events):
    client, engine = version_events
    setup_context(client)
    path = "/classes/class-p1/learning-context"
    first = client.get(path)
    assert first.status_code == 200, first.text
    context = first.json()["context"]
    assert context["user_id"] == "student"
    assert context["organization_id"] == "i"
    assert context["program_id"] == "p1"
    assert context["cohort_id"] == "class-p1"
    assert context["course_version_id"] == "old"
    assert context["legacy_enrollment_id"] == "enrollment-p1"
    assert context["enrollment_id"] != context["legacy_enrollment_id"]
    assert first.json()["contract_version"] == "cohort-enrollment-v2"
    assert first.json()["progress"]["context_enrollment_id"] == context["enrollment_id"]
    assert context["role"] == "student"
    assert client.get("/classes/class-p1/course").json()["course_version_id"] == context["course_version_id"]
    payload = event("activity", "study_activity", course_version_id="old", class_id="class-p1")
    assert client.post("/events", json=payload).status_code == 201
    assert client.post("/events", json=payload).status_code == 200
    student = client.get(path).json()
    observed = client.get("/classes/class-p1/students/student/learning-context", headers={"X-User": "teacher"}).json()
    assert student["context"] == observed["context"]
    assert student["progress"] == observed["progress"]
    dashboard = client.get("/classes/class-p1/dashboard", headers={"X-User": "teacher"}).json()
    assert student["progress"] == dashboard["students"][0]
    assert student["progress"]["validated_hours"] > 0
    assert client.get(path).json()["progress"] == student["progress"]
    assert client.get("/classes/class-p2/learning-context").json()["progress"]["validated_hours"] == 0
    with Session(engine) as session:
        assert session.scalar(select(func.count()).select_from(LearningEventRecord)) == 1


def test_context_never_uses_global_role_or_changes_pinned_edition(version_events):
    client, engine = version_events
    setup_context(client)
    first = client.get("/classes/class-p1/learning-context").json()["context"]
    with Session(engine) as session:
        session.get(User, "student").role = "teacher"
        session.get(CourseVersion, "current").version_number = 99
        session.commit()
    assert client.get("/classes/class-p1/learning-context").json()["context"] == first
    second = client.get("/classes/class-p2/learning-context").json()["context"]
    assert first["membership_id"] != second["membership_id"]
    assert first["course_version_id"] != second["course_version_id"]


def test_context_fails_closed_on_revocation_outsider_and_invalid_edition(version_events):
    client, engine = version_events
    setup_context(client)
    path = "/classes/class-p1/learning-context"
    assert client.get(path, headers={"X-User": "outsider"}).status_code == 403
    observer = "/classes/class-p1/students/student/learning-context"
    assert client.get(observer).status_code == 403
    assert client.get(observer, headers={"X-User": "outsider"}).status_code == 403
    with Session(engine) as session:
        session.get(ProgramMembership, ("teacher", "p1")).status = "inactive"
        session.get(ProgramMembership, ("student", "p1")).status = "inactive"
        session.commit()
    assert client.get(path).status_code == 403
    assert client.get(observer, headers={"X-User": "teacher"}).status_code == 403
    with Session(engine) as session:
        session.get(ProgramMembership, ("student", "p1")).status = "active"
        session.get(Classroom, "class-p1").course_version_id = "draft"
        session.commit()
    # The pinned enrollment now disagrees with the tampered cohort: deny access.
    assert client.get(path).status_code == 403


def test_context_flag_defaults_off(version_events):
    client, _ = version_events
    setup_context(client)
    assert Settings(database_url="sqlite://", allowed_origins=()).learning_context_enabled is False
    client.app.state.settings = replace(client.app.state.settings, learning_context_enabled=False)
    assert client.get("/classes/class-p1/learning-context").status_code == 404


def test_persisted_revocation_blocks_all_context_consumers_and_backfill_cannot_regrant(version_events):
    client, engine = version_events
    setup_context(client)
    with Session(engine) as session:
        link = session.get(ClassEnrollment, ('class-p1', 'student'))
        session.get(CohortMembership, link.membership_id).status = 'inactive'
        session.commit()
        backfill_context_bindings(session)
        session.commit()
        assert session.get(CohortMembership, link.membership_id).status == 'inactive'
    assert client.get('/classes/class-p1/learning-context').status_code == 403
    assert client.get('/classes/class-p1/course').status_code == 403
    assert client.post('/events', json=event('revoked-physical', class_id='class-p1', course_version_id='old')).status_code == 403
    assert all(item['id'] != 'class-p1' for item in client.get('/classes?enrolled_only=true').json()['classes'])
    assert client.get('/classes/class-p1/dashboard', headers={'X-User': 'teacher'}).json()['students'] == []
    with Session(engine) as session:
        teacher = session.scalar(select(CohortMembership).where(CohortMembership.class_id == 'class-p1', CohortMembership.role == 'teacher'))
        teacher.status = 'inactive'
        session.commit()
    for path in ('/classes/class-p1/dashboard', '/classes/class-p1/students/student/learning-context', '/classes/class-p1/eligible-students'):
        assert client.get(path, headers={'X-User': 'teacher'}).status_code == 403
    assert client.put('/classes/class-p1/students/student', headers={'X-User': 'teacher'}).status_code == 403


def test_resolver_requires_explicit_backfill_and_never_writes_during_read(version_events):
    client, engine = version_events
    client.app.include_router(router)
    client.app.state.settings = Settings(database_url='sqlite://', allowed_origins=(), learning_context_enabled=True)
    assert client.get('/classes/class-p1/learning-context').status_code == 409
    with Session(engine) as session:
        assert session.get(ClassEnrollment, ('class-p1', 'student')).context_id is None
        assert session.scalar(select(func.count()).select_from(CohortMembership)) == 0


def test_class_commands_persist_membership_and_versioned_enrollment_together(version_events):
    from app.classrooms import admin_router, admin_claims
    client, engine = version_events
    setup_context(client)
    client.app.include_router(admin_router)
    client.app.dependency_overrides[admin_claims] = lambda: {'sub': 'admin', 'role': 'admin'}
    response = client.post('/admin/classes', json={'program_id': 'p1', 'course_id': 'course',
        'teacher_id': 'teacher', 'name': 'Canonical', 'start_date': '2026-01-01', 'end_date': '2026-12-01', 'status': 'active'})
    assert response.status_code == 201, response.text
    cohort = response.json()['id']
    assert client.post(f'/admin/classes/{cohort}/students/student').status_code == 201
    with Session(engine) as session:
        session.add(ProgramMembership(program_id='p1', user_id='outsider', role='monitor', status='active'))
        session.commit()
    assert client.post(f'/admin/classes/{cohort}/monitors/outsider').status_code == 201
    assert client.put(f'/classes/{cohort}/students/student', headers={'X-User': 'teacher'}).status_code == 200
    with Session(engine) as session:
        link = session.get(ClassEnrollment, (cohort, 'student'))
        assert link.context_id and link.membership_id and link.course_version_id == 'current'
        assert {row.role for row in session.scalars(select(CohortMembership).where(CohortMembership.class_id == cohort))} == {'student', 'teacher', 'monitor'}
    snapshot = client.get(f'/classes/{cohort}/learning-context').json()
    assert snapshot['context']['enrollment_id'] == snapshot['progress']['context_enrollment_id']
    assert snapshot['progress'] == client.get(f'/classes/{cohort}/dashboard', headers={'X-User': 'teacher'}).json()['students'][0]


def test_contextual_activity_uses_cohort_membership_not_global_role(version_events):
    client, engine = version_events
    setup_context(client)

    def claims(x_user: str = Header(default="student")):
        return {"sub": x_user, "role": "teacher"}

    client.app.dependency_overrides[access_claims] = claims
    payload = event("multirole", "study_activity", course_version_id="old", class_id="class-p1")
    assert client.post("/events", json=payload).status_code == 201
    assert client.post("/events", json=payload).status_code == 200
    # A teacher of this cohort is not automatically enrolled as its student.
    assert client.post("/events", headers={"X-User": "teacher"}, json=event(
        "staff-not-student", "study_activity", course_version_id="old", class_id="class-p1"
    )).status_code == 403
    assert client.post("/events", json=event("unscoped", course_version_id="current")).status_code == 403
    with Session(engine) as session:
        session.get(ProgramMembership, ("student", "p1")).status = "inactive"
        session.commit()
    assert client.post("/events", json=event(
        "revoked", "study_activity", course_version_id="old", class_id="class-p1"
    )).status_code == 403
    assert client.post("/events", json=payload).status_code == 200
    client.app.state.settings = replace(client.app.state.settings, learning_context_enabled=False)
    assert client.post("/events", json=payload).status_code == 403
    with Session(engine) as session:
        assert session.scalar(select(func.count()).select_from(LearningEventRecord)) == 1
