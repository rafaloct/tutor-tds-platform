"""Staging-only, read-only digests and rollback-only PostgreSQL trigger checks.

Run before and after the first 0015 deployment; output has no student records.
"""
import argparse
from copy import deepcopy
import hashlib
import json
import os

from sqlalchemy import MetaData, Table, create_engine, inspect, select, text
from sqlalchemy.engine import make_url
from sqlalchemy.exc import DBAPIError


TABLES = (
    "courses", "users", "programs", "program_courses", "program_memberships",
    "enrollments", "classes", "class_enrollments", "class_monitors",
    "certificates", "learning_events", "class_sessions", "evidence_items",
    "class_checkins", "review_decisions", "assessment_contents", "assessment_attempts",
)


def audit(verify_versioning=False):
    url = os.environ["DATABASE_URL"]
    if make_url(url).database != "tutor_tds_staging":
        raise SystemExit("This audit only accepts tutor_tds_staging.")
    engine = create_engine(url)
    result = {"tables": {}}
    with engine.connect() as connection:
        result["schema"] = connection.scalar(text("SELECT version_num FROM alembic_version"))
        for name in TABLES:
            table = Table(name, MetaData(), autoload_with=connection)
            rows = [dict(row) for row in connection.execute(select(table)).mappings()]
            for row in rows:
                if name == "classes":
                    row.pop("course_version_id", None)
            encoded = sorted(json.dumps(row, ensure_ascii=False, sort_keys=True, default=str) for row in rows)
            result["tables"][name] = {"count": len(rows), "sha256": hashlib.sha256("\n".join(encoded).encode()).hexdigest()}
        if verify_versioning:
            from app.course_editor import legacy_version_id, snapshot_content
            from app.models import Course, CourseVersion, Classroom
            from sqlalchemy.orm import Session
            assert result["schema"] == "20260921_0015"
            with Session(engine) as session:
                courses = session.scalars(select(Course)).all()
                versions = session.scalars(select(CourseVersion)).all()
                assert len(versions) == len(courses)
                for course in courses:
                    version = session.get(CourseVersion, legacy_version_id(course.id))
                    assert version is not None and version.version_number == 1
                    assert version.content == snapshot_content(course.id, course.title, course.author, course.content, legacy=True)
                classes = session.scalars(select(Classroom)).all()
                assert all(row.course_version_id == legacy_version_id(row.course_id) for row in classes)
                candidate = next(version for version in versions if version.status == "published")
                candidate_id = candidate.id
                changed = deepcopy(candidate.content)
                changed["title"] = "ROLLBACK-ONLY MUTATION PROBE"
            foreign_keys = inspect(connection).get_foreign_keys("classes")
            assert any(fk["referred_table"] == "course_versions" and fk["constrained_columns"] == ["course_version_id", "course_id"] for fk in foreign_keys)
            guarded = False
            nested = connection.begin_nested()
            try:
                connection.execute(text("UPDATE course_versions SET content=CAST(:content AS json) WHERE id=:id"), {"content": json.dumps(changed), "id": candidate_id})
            except DBAPIError as error:
                if "immutable course version" not in str(error.orig):
                    raise
                guarded = True
            finally:
                nested.rollback()
            assert guarded, "Published snapshot mutation was not blocked."
            result["versioning"] = {"backfilled_courses": len(courses), "pinned_classes": len(classes), "lineage_fk": "pass", "immutable_trigger": "pass"}
    engine.dispose()
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--verify-versioning", action="store_true")
    args = parser.parse_args()
    print(json.dumps(audit(args.verify_versioning), sort_keys=True))
