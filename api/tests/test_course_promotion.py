from copy import deepcopy
from datetime import date, datetime, timezone
import json
from pathlib import Path

from alembic import command
from alembic.config import Config
import pytest
from sqlalchemy import create_engine, event, select, text
from sqlalchemy.orm import Session

from app.course_editor import snapshot_content
from app.course_promotion import export_manifest, import_manifest, main, manifest_digest, verify_manifest
from app.models import CertificateReference, Classroom, Course, CourseVersion, CourseVersionTransition, Institution, Program, ProgramCourse, ProgramMembership, User


def content(course_id="course", body="Conteúdo publicado"):
    return snapshot_content(course_id, "Curso", "Crédito editorial TDS", {"sections": [{"id": "module", "title": "Módulo", "messages": [{"id": "message", "type": "bot", "content": body}]}]})


def seed_course(engine, course_id, version_id, number, body, program_id, actor):
    snapshot = content(course_id, body)
    with Session(engine) as session:
        session.add(Course(id=course_id, title=snapshot["title"], author=snapshot["author"], content={"sections": snapshot["sections"]}, active=True))
        session.flush()
        session.add(ProgramCourse(program_id=program_id, course_id=course_id))
        session.add(CourseVersion(id=version_id, course_id=course_id, program_id=program_id, creator_user_id=actor, version_number=number, revision=1, status="published", content=snapshot))
        session.flush()
        session.add(CourseVersionTransition(id=f"audit-{version_id}", version_id=version_id, from_status=None, to_status="published", actor_user_id=actor, actor_role="coordinator"))
        session.commit()


@pytest.fixture
def promotion(tmp_path):
    engines = []
    for label in ("source", "target"):
        database = tmp_path / f"{label}.db"
        url = f"sqlite+pysqlite:///{database.as_posix()}"
        config = Config("alembic.ini")
        config.set_main_option("sqlalchemy.url", url)
        command.upgrade(config, "head")
        engine = create_engine(url)

        @event.listens_for(engine, "connect")
        def foreign_keys(connection, _):
            connection.execute("PRAGMA foreign_keys=ON")

        engines.append(engine)
        with Session(engine) as session:
            session.add(Institution(id=f"{label}-institution", name="Instituição"))
            for identity in ("reviewer", "student", "admin"):
                session.add(User(id=f"{label}-{identity}", cpf_digest=identity, name=identity, phone="61999990000", password_digest="never-export-password", role="admin" if identity == "admin" else "student"))
            session.flush()
            session.add_all([Program(id=f"{label}-program", institution_id=f"{label}-institution", name="Programa"), Program(id=f"{label}-other", institution_id=f"{label}-institution", name="Outro")])
            session.flush()
            session.add(ProgramMembership(user_id=f"{label}-reviewer", program_id=f"{label}-program", role="coordinator", status="active"))
            session.add(ProgramMembership(user_id=f"{label}-student", program_id=f"{label}-program", role="student", status="active"))
            session.commit()
    source, target = engines
    seed_course(source, "course", "exported-v2", 2, "Conteúdo novo", "source-program", "source-reviewer")
    seed_course(target, "course", "baseline-v1", 1, "Conteúdo anterior", "target-program", "target-reviewer")
    with Session(target) as session:
        session.add(Classroom(id="class", program_id="target-program", course_id="course", course_version_id="baseline-v1", teacher_id="target-reviewer", name="Turma", start_date=date(2026, 1, 1), end_date=date(2026, 12, 1)))
        session.flush()
        session.add(CertificateReference(id="certificate", user_id="target-student", course_id="course", program_id="target-program", class_id="class", verification_url="https://example.test/certificate", content_hash="unchanged", issued_at=datetime(2026, 1, 1, tzinfo=timezone.utc)))
        session.commit()
    manifest = export_manifest(source, "course", "exported-v2")
    kwargs = {"expected_digest": manifest["sha256"], "expected_database_name": (tmp_path / "target.db").as_posix(), "actor_user_id": "target-reviewer", "program_id": "target-program"}
    yield source, target, manifest, kwargs
    for engine in engines:
        engine.dispose()


def database_snapshot(engine):
    with engine.connect() as connection:
        return {table: [tuple(row) for row in connection.execute(text(f"SELECT * FROM {table}"))] for table in ("courses", "course_versions", "course_version_transitions", "program_courses", "classes", "certificates")}


def test_export_is_content_only_and_checksum_detects_tampering(promotion):
    source, _, manifest, _ = promotion
    assert set(manifest) == {"schema_version", "course_id", "version_id", "version_number", "content", "sha256"}
    serialized = json.dumps(manifest)
    for excluded in ("source-reviewer", "source-program", "never-export-password", "cpf_digest", "actor_user_id"):
        assert excluded not in serialized
    assert manifest["sha256"] == manifest_digest(manifest)
    assert export_manifest(source, "course", "exported-v2") == manifest
    mutated = deepcopy(manifest)
    mutated["content"]["title"] = "Alterado"
    with pytest.raises(ValueError, match="SHA256"):
        verify_manifest(mutated, manifest["sha256"])
    with pytest.raises(ValueError, match="SHA256"):
        verify_manifest(manifest, "0" * 64)
    with pytest.raises(ValueError, match="SHA256"):
        verify_manifest({**manifest, "sha256": "não-é-um-digest"}, manifest["sha256"])
    with pytest.raises(ValueError, match="publicada"):
        export_manifest(source, "different", "exported-v2")
    with Session(source) as session:
        session.get(CourseVersion, "exported-v2").status = "archived"
        session.add(CourseVersion(id="draft-v3", course_id="course", version_number=3, revision=1, status="draft", content=content()))
        session.commit()
    for version_id in ("exported-v2", "draft-v3"):
        with pytest.raises(ValueError, match="publicada"):
            export_manifest(source, "course", version_id)


def test_dry_run_default_is_read_only_and_apply_preserves_pinned_history(promotion):
    _, target, manifest, kwargs = promotion
    before = database_snapshot(target)
    plan = import_manifest(target, manifest, **kwargs)
    assert plan["dry_run"] and plan["action"] == "publish"
    assert plan["will_archive_version_ids"] == ["baseline-v1"]
    assert database_snapshot(target) == before
    applied = import_manifest(target, manifest, **kwargs, apply=True)
    assert not applied["dry_run"]
    with Session(target) as session:
        previous = session.get(CourseVersion, "baseline-v1")
        imported = session.get(CourseVersion, "exported-v2")
        assert previous.status == "archived" and previous.content == content(body="Conteúdo anterior")
        assert imported.status == "published" and imported.content == manifest["content"]
        assert imported.program_id == "target-program" and imported.creator_user_id == "target-reviewer"
        assert session.get(Course, "course").content["sections"] == manifest["content"]["sections"]
        assert session.get(Classroom, "class").course_version_id == "baseline-v1"
        assert len(session.scalars(select(Course)).all()) == 1
        assert session.get(CertificateReference, "certificate").content_hash == "unchanged"
        assert session.get(User, "source-reviewer") is None
        history = session.scalars(select(CourseVersionTransition).where(CourseVersionTransition.id != "audit-baseline-v1")).all()
        assert {row.to_status for row in history} == {"published", "archived"}
        assert all(row.actor_user_id == "target-reviewer" for row in history)
    after = database_snapshot(target)
    assert import_manifest(target, manifest, **kwargs, apply=True)["action"] == "already_present"
    assert database_snapshot(target) == after


def test_old_already_imported_manifest_never_reactivates_archived_version(promotion):
    source, target, manifest, kwargs = promotion
    import_manifest(target, manifest, **kwargs, apply=True)
    newer = deepcopy(manifest)
    newer.update(version_id="exported-v3", version_number=3, content=content(body="Terceira versão"))
    newer["sha256"] = manifest_digest(newer)
    import_manifest(target, newer, **{**kwargs, "expected_digest": newer["sha256"]}, apply=True)
    before = database_snapshot(target)
    assert import_manifest(target, manifest, **kwargs, apply=True)["action"] == "already_present"
    assert database_snapshot(target) == before
    with Session(target) as session:
        assert session.get(CourseVersion, "exported-v2").status == "archived"
        assert session.get(CourseVersion, "exported-v3").status == "published"


def test_guardrails_reject_wrong_database_actor_program_and_scope_without_writes(promotion):
    _, target, manifest, kwargs = promotion
    before = database_snapshot(target)
    for changed in ({"expected_database_name": kwargs["expected_database_name"] + "-wrong"}, {"actor_user_id": "source-reviewer"}, {"actor_user_id": "target-student"}, {"program_id": "source-program"}, {"program_id": "target-other"}, {"expected_digest": "a" * 64}):
        with pytest.raises(ValueError):
            import_manifest(target, manifest, **{**kwargs, **changed}, apply=True)
        assert database_snapshot(target) == before
    with Session(target) as session:
        session.add(ProgramCourse(program_id="target-other", course_id="course"))
        session.commit()
    before = database_snapshot(target)
    with pytest.raises(ValueError, match="autorização"):
        import_manifest(target, manifest, **kwargs, apply=True)
    assert database_snapshot(target) == before
    assert import_manifest(target, manifest, **{**kwargs, "actor_user_id": "target-admin"})["action"] == "publish"


def test_id_number_content_conflicts_fail_atomically(promotion):
    _, target, manifest, kwargs = promotion
    import_manifest(target, manifest, **kwargs, apply=True)
    before = database_snapshot(target)
    for changed in ({"content": content(body="Mesmo ID, outro conteúdo")}, {"version_number": 7}, {"version_id": "collision-v2"}, {"version_id": "older-v1", "version_number": 1}):
        conflicting = {**deepcopy(manifest), **changed}
        conflicting["sha256"] = manifest_digest(conflicting)
        with pytest.raises(ValueError, match="Conflito"):
            import_manifest(target, conflicting, **{**kwargs, "expected_digest": conflicting["sha256"]}, apply=True)
        assert database_snapshot(target) == before


def test_manifest_rejects_nonpublishable_extra_data_and_component_identity_rewrites(promotion):
    _, target, manifest, kwargs = promotion
    before = database_snapshot(target)
    mutations = []
    arbitrary_type = deepcopy(manifest)
    arbitrary_type["content"] = snapshot_content("course", "Curso", "Autor", {"sections": [{"id": "module", "title": "Módulo", "messages": [{"id": "message", "type": "arbitrary", "content": "Texto"}]}]})
    mutations.append(arbitrary_type)
    private_data = deepcopy(manifest)
    private_data["content"]["student_id"] = "must-not-travel"
    mutations.append(private_data)
    rewritten_component = deepcopy(manifest)
    rewritten_component["content"]["sections"][0]["version_id"] = "wrong"
    mutations.append(rewritten_component)
    for invalid in mutations:
        invalid["sha256"] = manifest_digest(invalid)
        with pytest.raises(ValueError):
            import_manifest(target, invalid, **{**kwargs, "expected_digest": invalid["sha256"]}, apply=True)
        assert database_snapshot(target) == before


def test_manifest_preserves_typed_learning_experience_content(promotion):
    _, target, manifest, kwargs = promotion
    experience = {
        "id": "scenario-intro-01",
        "kind": "scenario",
        "objective": "Explore a practical situation.",
        "required": False,
        "actionLabel": "Choose a point",
        "ai": {"starterPrompt": "Help me explore this situation."},
    }
    candidate = deepcopy(manifest)
    candidate["content"]["sections"][0]["messages"][0]["experience"] = experience
    candidate["content"] = snapshot_content(
        candidate["course_id"],
        candidate["content"]["title"],
        candidate["content"]["author"],
        candidate["content"],
    )
    candidate["sha256"] = manifest_digest(candidate)
    verified = verify_manifest(candidate, candidate["sha256"])
    assert verified == candidate

    imported = import_manifest(
        target,
        verified,
        **{**kwargs, "expected_digest": verified["sha256"]},
        apply=True,
    )
    assert not imported["dry_run"]
    with Session(target) as session:
        saved = session.get(CourseVersion, verified["version_id"])
        assert saved.content["sections"][0]["messages"][0]["experience"] == experience

    invalid_experiences = [
        experience | {"unknown": "rejected"},
        experience | {"id": "unstable text"},
        experience | {"kind": "unknown"},
        experience | {"required": 1},
        experience | {"ai": {"starterPrompt": "Valid", "private": "rejected"}},
        experience | {"ai": {"starterPrompt": ""}},
    ]
    for invalid_experience in invalid_experiences:
        invalid = deepcopy(candidate)
        invalid["content"]["sections"][0]["messages"][0]["experience"] = invalid_experience
        invalid["content"] = snapshot_content(
            invalid["course_id"],
            invalid["content"]["title"],
            invalid["content"]["author"],
            invalid["content"],
        )
        invalid["sha256"] = manifest_digest(invalid)
        with pytest.raises(ValueError):
            verify_manifest(invalid, invalid["sha256"])


def test_bundled_experiences_match_the_course_version_promotion_contract():
    lessons = (
        Path(__file__).resolve().parents[2]
        / "cartilhas_app"
        / "assets"
        / "data"
        / "lessons"
    )
    lesson_files = sorted(lessons.glob("*.json"))
    assert lesson_files

    for path in lesson_files:
        lesson = json.loads(path.read_text(encoding="utf-8"))
        content_snapshot = snapshot_content(
            lesson["id"],
            lesson["title"],
            lesson["author"],
            lesson,
        )
        manifest = {
            "schema_version": 1,
            "course_id": lesson["id"],
            "version_id": "asset-v1",
            "version_number": 1,
            "content": content_snapshot,
        }
        manifest["sha256"] = manifest_digest(manifest)
        assert verify_manifest(manifest, manifest["sha256"]) == manifest, path.name


def test_new_course_is_created_once_with_local_program_mapping(promotion):
    source, target, _, kwargs = promotion
    seed_course(source, "new-course", "new-version", 1, "Novo curso", "source-program", "source-reviewer")
    manifest = export_manifest(source, "new-course", "new-version")
    kwargs = {**kwargs, "expected_digest": manifest["sha256"]}
    before = database_snapshot(target)
    plan = import_manifest(target, manifest, **kwargs)
    assert plan["will_create_course"] and plan["will_link_program"]
    assert database_snapshot(target) == before
    import_manifest(target, manifest, **kwargs, apply=True)
    assert import_manifest(target, manifest, **kwargs, apply=True)["action"] == "already_present"
    with Session(target) as session:
        assert len(session.scalars(select(Course).where(Course.id == "new-course")).all()) == 1
        assert session.get(ProgramCourse, ("target-program", "new-course")) is not None


def test_cli_export_and_default_import_dry_run(promotion, tmp_path, monkeypatch, capsys):
    source, target, manifest, kwargs = promotion
    artifact = tmp_path / "artifact.json"
    monkeypatch.setenv("PROMOTION_TEST_URL", str(source.url))
    main(["--database-url-env", "PROMOTION_TEST_URL", "export", "--course-id", "course", "--version-id", "exported-v2", "--output", str(artifact)])
    output = json.loads(capsys.readouterr().out)
    assert output["sha256"] == manifest["sha256"]
    assert json.loads(artifact.read_text(encoding="utf-8")) == manifest
    with pytest.raises(SystemExit) as error:
        main(["--database-url-env", "PROMOTION_TEST_URL", "export", "--course-id", "course", "--version-id", "exported-v2", "--output", str(artifact)])
    assert error.value.code == 2
    assert json.loads(artifact.read_text(encoding="utf-8")) == manifest
    capsys.readouterr()
    monkeypatch.setenv("PROMOTION_TEST_URL", str(target.url))
    before = database_snapshot(target)
    main(["--database-url-env", "PROMOTION_TEST_URL", "import", str(artifact), "--expected-digest", manifest["sha256"], "--expected-database-name", kwargs["expected_database_name"], "--actor-user-id", "target-reviewer", "--program-id", "target-program"])
    assert json.loads(capsys.readouterr().out)["dry_run"] is True
    assert database_snapshot(target) == before
