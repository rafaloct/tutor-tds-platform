from __future__ import annotations

from datetime import date
from fastapi.testclient import TestClient
from sqlalchemy import event
from sqlalchemy.orm import Session

from app.config import Settings
from app.main import create_app
from app.models import (Base, ClassEnrollment, ClassMonitor, Classroom, Course,
    Enrollment, Institution, Program, ProgramCourse, ProgramMembership)

PASSWORD = "uma-senha-forte-2026"

def register(client, cpf, name):
    return client.post("/auth/register", json={"name": name, "cpf": cpf, "phone": "61999990000", "password": PASSWORD}).json()
def bearer(account): return {"Authorization": f"Bearer {account['access_token']}"}

def test_evidence_session_token_import_review_and_auditable_close() -> None:
    settings = Settings(database_url="sqlite+pysqlite:///:memory:", allowed_origins=(), jwt_secret="j"*32, cpf_pepper="p"*32)
    app = create_app(database_url=settings.database_url, settings=settings); Base.metadata.create_all(app.state.database.engine)
    with app.state.database.engine.connect() as connection:
        connection.exec_driver_sql("PRAGMA foreign_keys=ON")
    client = TestClient(app)
    attendance_insert_order: list[str] = []

    def record_attendance_insert(_conn, _cursor, statement, _parameters, _context, _executemany):
        normalized = " ".join(statement.lower().split())
        if normalized.startswith("insert into evidence_items"):
            attendance_insert_order.append("evidence_items")
        elif normalized.startswith("insert into class_checkins"):
            attendance_insert_order.append("class_checkins")

    event.listen(
        app.state.database.engine,
        "before_cursor_execute",
        record_attendance_insert,
    )
    with client:
        teacher = register(client, "123.456.789-09", "Professora")
        student = register(client, "987.654.321-00", "Estudante")
        outsider = register(client, "529.982.247-25", "Terceiro")
        teacher_id, student_id = teacher["user"]["id"], student["user"]["id"]
        with Session(app.state.database.engine) as session:
            session.add(Institution(id="institution-1", name="Instituto"))
            session.add(Program(id="program-1", institution_id="institution-1", name="Programa"))
            session.add(Course(id="course-1", title="Curso", author="TDS", content={"sections": []}, active=True)); session.flush()
            session.add(ProgramCourse(program_id="program-1", course_id="course-1"))
            session.add_all([
                ProgramMembership(user_id=teacher_id, program_id="program-1", role="teacher", status="active"),
                ProgramMembership(user_id=student_id, program_id="program-1", role="student", status="active"),
            ]); session.flush()
            session.add(Enrollment(id="enrollment-1", user_id=student_id, program_id="program-1", course_id="course-1", status="active")); session.flush()
            session.add(Classroom(id="class-1", program_id="program-1", course_id="course-1", teacher_id=teacher_id,
                name="Turma A", start_date=date(2026,1,1), end_date=date(2027,12,1), status="active")); session.flush()
            session.add(ClassEnrollment(class_id="class-1", user_id=student_id, enrollment_id="enrollment-1", program_id="program-1", course_id="course-1", status="active")); session.commit()
        created = client.post("/admin/classes/class-1/sessions", headers=bearer(teacher), json={"starts_at":"2026-01-01T00:00:00Z","ends_at":"2027-12-01T00:00:00Z"})
        session_id, token = created.json()["id"], created.json()["checkin_token"]
        listed = client.get("/classes/class-1/sessions", headers=bearer(student))
        listed_open = client.get("/classes/class-1/sessions?status=open", headers=bearer(teacher))
        recovered_open = client.get("/classes/class-1/sessions/open", headers=bearer(student))
        recovered_by_id = client.get(f"/classes/class-1/sessions/{session_id}", headers=bearer(teacher))
        outsider_sessions = client.get("/classes/class-1/sessions", headers=bearer(outsider))
        checkin = client.post(f"/classes/class-1/sessions/{session_id}/checkins", headers=bearer(student), json={"kind":"checkin","idempotency_key":"checkin:student:1","token":token})
        checkin_retry = client.post(f"/classes/class-1/sessions/{session_id}/checkins", headers=bearer(student), json={"kind":"checkin","idempotency_key":"checkin:student:1","token":token})
        rotated = client.post(f"/classes/class-1/sessions/{session_id}/token", headers=bearer(teacher))
        old_token = client.post(f"/classes/class-1/sessions/{session_id}/checkins", headers=bearer(student), json={"kind":"checkout","idempotency_key":"checkout:old:1","token":token})
        checkout = client.post(f"/classes/class-1/sessions/{session_id}/checkins", headers=bearer(student), json={"kind":"checkout","idempotency_key":"checkout:new:1","token":rotated.json()["checkin_token"]})
        imported = client.post("/classes/class-1/evidence-imports", headers=bearer(teacher), json={
            "source_type":"whatsapp_export", "source_digest":"a"*64, "idempotency_key":"import:whatsapp:1",
            "retention_until":"2027-12-31T00:00:00Z", "items":[{
                "item_digest":"b"*64, "evidence_type":"message_metadata", "occurred_at":"2026-09-20T12:00:00Z",
                "user_id":student_id, "session_id":session_id, "metadata":{"message_count":"1"}
            }]})
        evidence_id = imported.json()["evidence_ids"][0]
        outsider_read = client.get(f"/classes/class-1/evidence-imports/{imported.json()['id']}", headers=bearer(outsider))
        student_exceptions = client.get("/classes/class-1/exceptions", headers=bearer(student))
        reviewed = client.post(f"/classes/class-1/evidence/{evidence_id}/review", headers=bearer(teacher), json={"decision":"accepted","reason_code":"verified"})
        blocked_close = client.post(f"/classes/class-1/sessions/{session_id}/close", headers=bearer(teacher))
        closed = client.post(f"/classes/class-1/sessions/{session_id}/close?confirm_pending=true", headers=bearer(teacher))
        closed_retry = client.post(f"/classes/class-1/sessions/{session_id}/close?confirm_pending=true", headers=bearer(teacher))
        report = client.get(f"/classes/class-1/reports/{closed.json()['id']}", headers=bearer(teacher))
        open_after_close = client.get("/classes/class-1/sessions/open", headers=bearer(student))
        closed_sessions = client.get("/classes/class-1/sessions?status=closed", headers=bearer(student))
    event.remove(
        app.state.database.engine,
        "before_cursor_execute",
        record_attendance_insert,
    )
    assert created.status_code == 201 and token
    assert listed.status_code == 200 and listed.json()["total"] == 1
    assert listed_open.status_code == 200 and listed_open.json()["sessions"][0]["id"] == session_id
    assert recovered_open.status_code == 200 and recovered_open.json()["id"] == session_id
    assert recovered_by_id.status_code == 200 and recovered_by_id.json()["id"] == session_id
    assert "checkin_token" not in recovered_open.json()
    assert "checkin_token" not in recovered_by_id.json()
    assert outsider_sessions.status_code == 403
    assert checkin.status_code == 201 and checkin_retry.status_code == 200
    assert attendance_insert_order[:4] == [
        "evidence_items", "class_checkins", "evidence_items", "class_checkins"
    ]
    assert rotated.json()["token_version"] == 2
    assert old_token.status_code == 401 and checkout.status_code == 201
    assert imported.status_code == 201 and outsider_read.status_code == 403
    assert all(item.get("user_id") in {None, student_id} for item in student_exceptions.json()["exceptions"])
    assert reviewed.status_code == 200
    assert blocked_close.status_code == 409
    assert closed.status_code == 200 and closed_retry.json()["id"] == closed.json()["id"]
    assert report.json()["report_digest"] == closed.json()["report_digest"]
    assert report.json()["summary"]["external_integrations"] == "disabled"
    assert open_after_close.status_code == 404
    assert closed_sessions.status_code == 200
    assert [item["id"] for item in closed_sessions.json()["sessions"]] == [session_id]


def test_session_recovery_is_isolated_by_class_and_institution() -> None:
    settings = Settings(database_url="sqlite+pysqlite:///:memory:", allowed_origins=(), jwt_secret="j"*32, cpf_pepper="p"*32)
    app = create_app(database_url=settings.database_url, settings=settings); Base.metadata.create_all(app.state.database.engine)
    client = TestClient(app)
    with client:
        teacher_a = register(client, "123.456.789-09", "Professora A")
        monitor_a = register(client, "987.654.321-00", "Monitor A")
        student_a = register(client, "529.982.247-25", "Estudante A")
        teacher_b = register(client, "168.995.350-09", "Professora B")
        ids = {
            "teacher_a": teacher_a["user"]["id"],
            "monitor_a": monitor_a["user"]["id"],
            "student_a": student_a["user"]["id"],
            "teacher_b": teacher_b["user"]["id"],
        }
        with Session(app.state.database.engine) as session:
            session.add_all([
                Institution(id="institution-a", name="Instituto A"),
                Institution(id="institution-b", name="Instituto B"),
                Course(id="course-a", title="Curso A", author="TDS", content={"sections": []}, active=True),
                Course(id="course-b", title="Curso B", author="TDS", content={"sections": []}, active=True),
            ])
            session.flush()
            session.add_all([
                Program(id="program-a", institution_id="institution-a", name="Programa A"),
                Program(id="program-b", institution_id="institution-b", name="Programa B"),
            ])
            session.flush()
            session.add_all([
                ProgramCourse(program_id="program-a", course_id="course-a"),
                ProgramCourse(program_id="program-b", course_id="course-b"),
                ProgramMembership(user_id=ids["teacher_a"], program_id="program-a", role="teacher", status="active"),
                ProgramMembership(user_id=ids["monitor_a"], program_id="program-a", role="monitor", status="active"),
                ProgramMembership(user_id=ids["student_a"], program_id="program-a", role="student", status="active"),
                ProgramMembership(user_id=ids["teacher_b"], program_id="program-b", role="teacher", status="active"),
            ])
            session.flush()
            session.add(Enrollment(id="enrollment-a", user_id=ids["student_a"], program_id="program-a", course_id="course-a", status="active"))
            session.add_all([
                Classroom(id="class-a", program_id="program-a", course_id="course-a", teacher_id=ids["teacher_a"], name="Turma A", start_date=date(2026,1,1), end_date=date(2027,12,1), status="active"),
                Classroom(id="class-b", program_id="program-b", course_id="course-b", teacher_id=ids["teacher_b"], name="Turma B", start_date=date(2026,1,1), end_date=date(2027,12,1), status="active"),
            ])
            session.flush()
            session.add_all([
                ClassEnrollment(class_id="class-a", user_id=ids["student_a"], enrollment_id="enrollment-a", program_id="program-a", course_id="course-a", status="active"),
                ClassMonitor(class_id="class-a", user_id=ids["monitor_a"], program_id="program-a"),
            ])
            session.commit()

        session_a = client.post(
            "/admin/classes/class-a/sessions",
            headers=bearer(teacher_a),
            json={"starts_at":"2026-01-01T00:00:00Z","ends_at":"2027-12-01T00:00:00Z"},
        )
        session_b = client.post(
            "/admin/classes/class-b/sessions",
            headers=bearer(teacher_b),
            json={"starts_at":"2026-01-01T00:00:00Z","ends_at":"2027-12-01T00:00:00Z"},
        )
        session_a_id = session_a.json()["id"]
        session_b_id = session_b.json()["id"]

        teacher_a_list = client.get("/classes/class-a/sessions", headers=bearer(teacher_a))
        monitor_a_open = client.get("/classes/class-a/sessions/open", headers=bearer(monitor_a))
        student_a_get = client.get(f"/classes/class-a/sessions/{session_a_id}", headers=bearer(student_a))
        student_cross_org = client.get("/classes/class-b/sessions", headers=bearer(student_a))
        teacher_cross_org = client.get("/classes/class-b/sessions/open", headers=bearer(teacher_a))
        monitor_cross_org = client.get(f"/classes/class-b/sessions/{session_b_id}", headers=bearer(monitor_a))
        cross_class_session_a = client.get(f"/classes/class-a/sessions/{session_b_id}", headers=bearer(teacher_a))
        cross_class_session_b = client.get(f"/classes/class-b/sessions/{session_a_id}", headers=bearer(teacher_b))

    assert session_a.status_code == session_b.status_code == 201
    assert teacher_a_list.status_code == 200 and teacher_a_list.json()["total"] == 1
    assert monitor_a_open.status_code == 200 and monitor_a_open.json()["id"] == session_a_id
    assert student_a_get.status_code == 200 and student_a_get.json()["id"] == session_a_id
    assert student_cross_org.status_code == 403
    assert teacher_cross_org.status_code == 403
    assert monitor_cross_org.status_code == 403
    assert cross_class_session_a.status_code == 404
    assert cross_class_session_b.status_code == 404
