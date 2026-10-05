#!/usr/bin/env python3
"""Disposable local API for Issue #140 E2E.

Runs the real FastAPI app and migrations against an isolated database, seeds
only synthetic QA identities, and enables only the lifecycle/context flags
needed by the local Android integration test.
"""
from __future__ import annotations

import argparse
import sys
from datetime import datetime, timezone
from pathlib import Path

import uvicorn
from alembic import command as alembic_command
from alembic.config import Config
from sqlalchemy import select
from sqlalchemy.orm import Session

REPO_ROOT = Path(__file__).resolve().parents[2]
API_ROOT = REPO_ROOT / "api"
sys.path.insert(0, str(API_ROOT))

from app.auth import AuthService, password_hash  # noqa: E402
from app.config import Settings  # noqa: E402
from app.main import create_app  # noqa: E402
from app.models import (  # noqa: E402
    Course,
    CourseVersion,
    Enrollment,
    Institution,
    Program,
    ProgramCourse,
    ProgramMembership,
    User,
)

PASSWORD = "qa-" + "class-lifecycle-" + "2026!"
JWT_SECRET = "qa-jwt-" + ("x" * 40)
CPF_PEPPER = "qa-pepper-" + ("y" * 40)
IDS = {
    "institution": "qa-i1",
    "foreign_institution": "qa-i2",
    "program": "qa-p1",
    "foreign_program": "qa-p2",
    "course": "qa-course",
    "version": "qa-v1",
    "enrollment": "qa-enrollment",
    "foreign_enrollment": "qa-foreign-enrollment",
}
ACCOUNTS = {
    "operator": ("qa-operator", "39053344705", "program_operator", "program_operator"),
    "coordinator": ("qa-coordinator", "16899535009", "coordinator", "coordinator"),
    "teacher": ("qa-teacher", "98765432100", "teacher", "teacher"),
    "monitor": ("qa-monitor", "11144477735", "monitor", "monitor"),
    "student": ("qa-student", "12345678909", "student", "student"),
    "outsider": ("qa-outsider", "52998224725", "student", "student"),
}


def settings(database_url: str) -> Settings:
    return Settings(
        database_url=database_url,
        allowed_origins=(),
        jwt_secret=JWT_SECRET,
        cpf_pepper=CPF_PEPPER,
        access_token_minutes=120,
        refresh_token_days=1,
        environment="development",
        operator_operations_enabled=True,
        class_lifecycle_enabled=True,
        learning_context_enabled=True,
        journey_traceability_enabled=True,
        certificate_approval_required=True,
        cpf_activation_required=False,
    )


def migrate(database_url: str) -> None:
    config = Config(str(API_ROOT / "alembic.ini"))
    config.set_main_option("script_location", str(API_ROOT / "migrations"))
    config.set_main_option("sqlalchemy.url", database_url)
    alembic_command.upgrade(config, "head")


def seed(app, cfg: Settings) -> None:
    engine = app.state.database.engine
    now = datetime.now(timezone.utc)
    with Session(engine) as session:
        if session.get(Institution, IDS["institution"]) is not None:
            return

        session.add_all(
            [
                Institution(id=IDS["institution"], name="Instituição QA Palmas"),
                Institution(
                    id=IDS["foreign_institution"],
                    name="Instituição QA Estrangeira",
                ),
            ]
        )
        session.flush()
        session.add_all(
            [
                Program(
                    id=IDS["program"],
                    institution_id=IDS["institution"],
                    name="Programa QA Lifecycle",
                ),
                Program(
                    id=IDS["foreign_program"],
                    institution_id=IDS["foreign_institution"],
                    name="Programa QA Estrangeiro",
                ),
            ]
        )
        session.add(
            Course(
                id=IDS["course"],
                title="Curso QA Lifecycle",
                author="Tutor TDS QA",
                content={"title": "Curso QA Lifecycle", "sections": []},
                active=True,
            )
        )
        session.flush()
        session.add_all(
            [
                ProgramCourse(
                    program_id=IDS["program"],
                    course_id=IDS["course"],
                    planned_seconds=1,
                ),
                ProgramCourse(
                    program_id=IDS["foreign_program"],
                    course_id=IDS["course"],
                    planned_seconds=1,
                ),
            ]
        )
        session.add(
            CourseVersion(
                id=IDS["version"],
                course_id=IDS["course"],
                version_number=1,
                revision=1,
                status="published",
                content={"title": "Curso QA Lifecycle", "sections": []},
            )
        )

        auth = AuthService(session, cfg)
        users: dict[str, User] = {}
        for index, (name, (user_id, cpf, global_role, _)) in enumerate(
            ACCOUNTS.items(), start=1
        ):
            user = User(
                id=user_id,
                cpf_digest=auth._cpf_digest(cpf),
                phone=f"6399900{index:04d}",
                name=f"QA {name.title()}",
                password_digest=password_hash.hash(PASSWORD),
                role=global_role,
                activated_at=now,
            )
            session.add(user)
            users[name] = user
        session.flush()

        for name in ("operator", "coordinator", "teacher", "monitor", "student"):
            _, _, _, member_role = ACCOUNTS[name]
            session.add(
                ProgramMembership(
                    user_id=users[name].id,
                    program_id=IDS["program"],
                    role=member_role,
                    status="active",
                )
            )
        session.add(
            ProgramMembership(
                user_id=users["outsider"].id,
                program_id=IDS["foreign_program"],
                role="student",
                status="active",
            )
        )
        session.flush()

        session.add_all(
            [
                Enrollment(
                    id=IDS["enrollment"],
                    user_id=users["student"].id,
                    program_id=IDS["program"],
                    course_id=IDS["course"],
                    status="active",
                ),
                Enrollment(
                    id=IDS["foreign_enrollment"],
                    user_id=users["outsider"].id,
                    program_id=IDS["foreign_program"],
                    course_id=IDS["course"],
                    status="active",
                ),
            ]
        )
        session.commit()


def build_app(database_url: str):
    migrate(database_url)
    cfg = settings(database_url)
    app = create_app(settings=cfg)
    seed(app, cfg)
    return app


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--database-url", required=True)
    parser.add_argument("--host", default="0.0.0.0")
    parser.add_argument("--port", type=int, default=18040)
    parser.add_argument("--ssl-certfile", required=True)
    parser.add_argument("--ssl-keyfile", required=True)
    args = parser.parse_args()

    app = build_app(args.database_url)
    uvicorn.run(
        app,
        host=args.host,
        port=args.port,
        ssl_certfile=args.ssl_certfile,
        ssl_keyfile=args.ssl_keyfile,
        log_level="warning",
        access_log=False,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
