from __future__ import annotations

from datetime import date, datetime, timezone

from fastapi.testclient import TestClient
import pytest

import app.classrooms as classrooms_module
from sqlalchemy.orm import Session

from app.config import Settings
from app.main import create_app
from app.models import (
    Base,
    ClassEnrollment,
    ClassMonitor,
    Classroom,
    Course,
    Enrollment,
    Institution,
    Program,
    ProgramCourse,
    ProgramMembership,
    User,
)

PASSWORD = "uma-senha-forte-2026"
CPFS = {
    "admin": "123.456.789-09",
    "teacher": "987.654.321-00",
    "monitor": "529.982.247-25",
    "student": "168.995.350-09",
    "outsider": "111.444.777-35",
}


def make_client() -> tuple[TestClient, object]:
    settings = Settings(
        database_url="sqlite+pysqlite:///:memory:",
        allowed_origins=(),
        jwt_secret="test-jwt-secret-with-at-least-32-chars",
        cpf_pepper="test-cpf-pepper-with-at-least-32-chars",
    )
    app = create_app(database_url=settings.database_url, settings=settings)
    Base.metadata.create_all(app.state.database.engine)
    return TestClient(app), app


def register(client: TestClient, role: str) -> dict[str, object]:
    response = client.post(
        "/auth/register",
        json={
            "name": role.title(),
            "cpf": CPFS[role],
            "phone": "61999990000",
            "password": PASSWORD,
        },
    )
    assert response.status_code == 201
    return response.json()


def bearer(token: object) -> dict[str, str]:
    return {"Authorization": f"Bearer {token}"}


def test_classroom_preserves_teacher_monitor_student_hierarchy(monkeypatch: pytest.MonkeyPatch) -> None:
    # This scenario starts on the first course day, regardless of the runner date.
    # Freeze only the pedagogical clock; authentication and other tests are untouched.
    class ClassroomDateTime(datetime):
        @classmethod
        def now(cls, tz=None):
            instant = cls(2026, 10, 1, 12, tzinfo=timezone.utc)
            return instant.replace(tzinfo=None) if tz is None else instant.astimezone(tz)

    monkeypatch.setattr(classrooms_module, "datetime", ClassroomDateTime)
    client, app = make_client()
    with client:
        accounts = {role: register(client, role) for role in CPFS}
        ids = {
            role: account["user"]["id"]
            for role, account in accounts.items()
        }
        with Session(app.state.database.engine) as session:
            admin = session.get(User, ids["admin"])
            assert admin is not None
            admin.role = "admin"
            session.add_all(
                [
                    Institution(id="institution-1", name="Instituto"),
                    Program(
                        id="program-1",
                        institution_id="institution-1",
                        name="Programa",
                    ),
                    Course(
                        id="course-1",
                        title="Curso",
                        author="TDS",
                        content={"sections": []},
                        active=True,
                    ),
                ]
            )
            session.flush()
            session.add(ProgramCourse(program_id="program-1", course_id="course-1"))
            session.add_all(
                [
                    ProgramMembership(
                        user_id=ids["teacher"],
                        program_id="program-1",
                        role="teacher",
                        status="active",
                    ),
                    ProgramMembership(
                        user_id=ids["monitor"],
                        program_id="program-1",
                        role="monitor",
                        status="active",
                    ),
                    ProgramMembership(
                        user_id=ids["student"],
                        program_id="program-1",
                        role="student",
                        status="active",
                    ),
                ]
            )
            session.flush()
            session.add(
                Enrollment(
                    id="enrollment-1",
                    user_id=ids["student"],
                    program_id="program-1",
                    course_id="course-1",
                    status="active",
                )
            )
            session.commit()

        admin_login = client.post(
            "/auth/login",
            json={"cpf": CPFS["admin"], "password": PASSWORD},
        ).json()
        admin_headers = bearer(admin_login["access_token"])
        payload = {
            "program_id": "program-1",
            "course_id": "course-1",
            "teacher_id": ids["teacher"],
            "name": "Turma A",
            "start_date": "2026-10-01",
            "end_date": "2026-12-01",
            "status": "planned",
        }
        created = client.post("/admin/classes", json=payload, headers=admin_headers)
        class_id = created.json()["id"]
        student_added = client.post(
            f"/admin/classes/{class_id}/students/{ids['student']}",
            headers=admin_headers,
        )
        monitor_added = client.post(
            f"/admin/classes/{class_id}/monitors/{ids['monitor']}",
            headers=admin_headers,
        )
        duplicate_student = client.post(
            f"/admin/classes/{class_id}/students/{ids['student']}",
            headers=admin_headers,
        )
        outsider_added = client.post(
            f"/admin/classes/{class_id}/students/{ids['outsider']}",
            headers=admin_headers,
        )

        teacher_view = client.get(
            f"/classes/{class_id}",
            headers=bearer(accounts["teacher"]["access_token"]),
        )
        monitor_view = client.get(
            f"/classes/{class_id}",
            headers=bearer(accounts["monitor"]["access_token"]),
        )
        student_view = client.get(
            f"/classes/{class_id}",
            headers=bearer(accounts["student"]["access_token"]),
        )
        teacher_list = client.get(
            "/classes", headers=bearer(accounts["teacher"]["access_token"])
        )
        monitor_list = client.get(
            "/classes", headers=bearer(accounts["monitor"]["access_token"])
        )
        student_list = client.get(
            "/classes", headers=bearer(accounts["student"]["access_token"])
        )
        outsider_list = client.get(
            "/classes", headers=bearer(accounts["outsider"]["access_token"])
        )
        dashboard = client.get(
            f"/classes/{class_id}/dashboard",
            headers=bearer(accounts["teacher"]["access_token"]),
        )
        student_dashboard = client.get(
            f"/classes/{class_id}/dashboard",
            headers=bearer(accounts["student"]["access_token"]),
        )

        invalid_teacher = client.post(
            "/admin/classes",
            json=payload | {"teacher_id": ids["student"], "name": "Inválida"},
            headers=admin_headers,
        )
        invalid_dates = client.post(
            "/admin/classes",
            json=payload | {"start_date": "2026-12-02", "end_date": "2026-12-01"},
            headers=admin_headers,
        )

    assert created.status_code == 201
    assert student_added.status_code == 201
    assert monitor_added.status_code == 201
    assert duplicate_student.status_code == 409
    assert outsider_added.status_code == 422
    assert teacher_view.status_code == 200
    assert monitor_view.status_code == 200
    assert teacher_view.json()["student_ids"] == [ids["student"]]
    assert teacher_view.json()["monitor_ids"] == [ids["monitor"]]
    assert student_view.status_code == 403
    assert [item["id"] for item in teacher_list.json()["classes"]] == [class_id]
    assert [item["id"] for item in monitor_list.json()["classes"]] == [class_id]
    assert [item["id"] for item in student_list.json()["classes"]] == [class_id]
    assert outsider_list.json() == {"classes": []}
    assert dashboard.status_code == 200
    assert dashboard.json()["summary"] == {
        "total_students": 1,
        "inactive_students": 0,
        "pending_students": 1,
        "below_expected_students": 0,
        "baseline_linked_students": 0,
        "confirmed_participations": 0,
        "open_mentorship_cases": 0,
    }
    assert dashboard.json()["students"][0]["user_id"] == ids["student"]
    assert dashboard.json()["students"][0]["alerts"] == [
        {"code": "required_activity_pending"}
    ]
    assert student_dashboard.status_code == 403
    assert invalid_teacher.status_code == 422
    assert invalid_dates.status_code == 422


def test_staff_can_include_only_active_students_in_the_same_offering() -> None:
    client, app = make_client()
    with client:
        accounts = {role: register(client, role) for role in CPFS}
        ids = {role: account["user"]["id"] for role, account in accounts.items()}
        with Session(app.state.database.engine) as session:
            session.add(Institution(id="i", name="Instituto"))
            session.flush()
            session.add_all([
                Program(id=p, institution_id="i", name=p) for p in ("p1", "p2")
            ] + [Course(id=c, title=c, author="TDS", content={}) for c in ("c1", "c2")])
            session.flush()
            session.add_all([
                ProgramCourse(program_id=p, course_id=c)
                for p, c in (("p1", "c1"), ("p1", "c2"), ("p2", "c1"))
            ] + [
                ProgramMembership(user_id=user_id, program_id=p, role=role if role in ("teacher", "monitor") else "student", status="active")
                for role, user_id in ids.items() for p in ("p1", "p2")
            ])
            session.flush()
            session.add_all([
                Classroom(id="a", program_id="p1", course_id="c1", teacher_id=ids["teacher"], name="Turma A", start_date=date(2026, 1, 1), end_date=date(2026, 12, 1), status="active"),
                Classroom(id="b", program_id="p2", course_id="c1", teacher_id=ids["outsider"], name="Turma B", start_date=date(2026, 1, 1), end_date=date(2026, 12, 1), status="active"),
                Enrollment(id="student-e", user_id=ids["student"], program_id="p1", course_id="c1", status="active"),
                Enrollment(id="admin-e", user_id=ids["admin"], program_id="p1", course_id="c1", status="active"),
                Enrollment(id="other-program", user_id=ids["outsider"], program_id="p2", course_id="c1", status="active"),
                Enrollment(id="other-course", user_id=ids["outsider"], program_id="p1", course_id="c2", status="active"),
                Enrollment(id="inactive", user_id=ids["monitor"], program_id="p1", course_id="c1", status="inactive"),
            ])
            session.flush()
            session.add(ClassMonitor(class_id="a", user_id=ids["monitor"], program_id="p1"))
            session.commit()
        headers = {role: bearer(account["access_token"]) for role, account in accounts.items()}
        # Teacher and monitor retain their global student role.
        assert accounts["teacher"]["user"]["role"] == "student"
        assert accounts["monitor"]["user"]["role"] == "student"
        path = "/classes/a/eligible-students"
        page = client.get(path, params={"limit": 1}, headers=headers["teacher"])
        assert page.status_code == 200
        assert page.json() == {"students": [{"user_id": ids["admin"], "name": "Admin"}], "next_offset": 1}
        second = client.get(path, params={"limit": 1, "offset": 1}, headers=headers["monitor"])
        assert second.json() == {"students": [{"user_id": ids["student"], "name": "Student"}], "next_offset": None}
        assert client.get(path, params={"q": "tud"}, headers=headers["teacher"]).json()["students"] == second.json()["students"]
        assert client.get(path, params={"q": "%"}, headers=headers["teacher"]).json()["students"] == []
        for params in ({"limit": 51}, {"offset": -1}, {"q": "a" * 101}):
            assert client.get(path, params=params, headers=headers["teacher"]).status_code == 422
        for actor in ("student", "outsider"):
            assert client.get(path, headers=headers[actor]).status_code == 403
            assert client.put(f"/classes/a/students/{ids['student']}", headers=headers[actor]).status_code == 403
        assert client.get("/classes/b/eligible-students", headers=headers["teacher"]).status_code == 403
        assert client.put(f"/classes/b/students/{ids['outsider']}", headers=headers["monitor"]).status_code == 403
        for candidate in ("outsider", "monitor"):
            assert client.put(f"/classes/a/students/{ids[candidate]}", headers=headers["teacher"]).status_code == 422
        for actor in ("teacher", "monitor"):
            response = client.put(f"/classes/a/students/{ids['student']}", headers=headers[actor])
            assert response.status_code == 200
            assert response.json()["status"] == "active"
        assert client.get(path, params={"q": "Student"}, headers=headers["teacher"]).json()["students"] == []
        with Session(app.state.database.engine) as session:
            memberships = session.query(ClassEnrollment).all()
            assert len(memberships) == 1
            assert memberships[0].enrollment_id == "student-e"
            assert session.query(Enrollment).count() == 5
            assert session.get(User, ids["teacher"]).role == "student"
            # A monitor can make a new inclusion, not just repeat a teacher's request.
        assert client.put(f"/classes/a/students/{ids['admin']}", headers=headers["monitor"]).status_code == 200
        with Session(app.state.database.engine) as session:
            session.get(Classroom, "a").status = "closed"
            session.commit()
        assert client.get(path, headers=headers["teacher"]).status_code == 409
        assert client.put(f"/classes/a/students/{ids['student']}", headers=headers["monitor"]).status_code == 409
