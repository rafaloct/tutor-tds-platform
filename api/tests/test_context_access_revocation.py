import pytest
from fastapi import Header
from sqlalchemy.orm import Session

from app.auth import access_claims
from app.classrooms import router
from app.models import ProgramMembership
from test_course_version_events import version_events


@pytest.mark.parametrize("actor", ["student", "teacher"])
def test_course_rechecks_program_membership_without_new_login(version_events, actor):
    client, engine = version_events
    client.app.include_router(router)

    def claims(x_user: str = Header(default=actor)):
        return {"sub": x_user, "role": "student"}

    client.app.dependency_overrides[access_claims] = claims
    path = "/classes/class-p1/course"
    assert client.get(path).status_code == 200
    with Session(engine) as session:
        session.get(ProgramMembership, (actor, "p1")).status = "inactive"
        session.commit()
    assert client.get(path).status_code == 403
    assert client.get("/classes/class-p2/course").status_code == 200
    if actor == "student":
        classes = client.get("/classes?enrolled_only=true").json()["classes"]
        assert [item["id"] for item in classes] == ["class-p2"]
    with Session(engine) as session:
        session.get(ProgramMembership, (actor, "p1")).status = "active"
        session.commit()
    assert client.get(path).status_code == 200
