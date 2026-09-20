from __future__ import annotations

from urllib.parse import urlsplit

from fastapi.testclient import TestClient
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.config import Settings
from app.main import create_app
from app.models import (
    Base,
    Course,
    Enrollment,
    Institution,
    LearningEventRecord,
    MediaEventRecord,
    MediaPlaybackGrant,
    MediaRating,
    MediaStatusTransition,
    Program,
    ProgramCourse,
    ProgramMembership,
    RevenueLedgerEntry,
)

PASSWORD = "uma-senha-forte-2026"
CPFS = {
    "creator": "123.456.789-09",
    "coordinator": "987.654.321-00",
    "finance": "529.982.247-25",
    "student": "168.995.350-09",
    "outsider": "111.444.777-35",
}


def bearer(account: dict[str, object]) -> dict[str, str]:
    return {"Authorization": f"Bearer {account['access_token']}"}


def media_event(event_id: str, event_type: str, payload: dict[str, str], occurred_at: str) -> dict[str, object]:
    return {
        "event_id": event_id,
        "event_type": event_type,
        "course_id": "course-1",
        "session_id": "video-session-1",
        "occurred_at": occurred_at,
        "payload": {"media_id": payload["media_id"], "module_id": "module-1"}
        | {key: value for key, value in payload.items() if key != "media_id"},
    }


def test_media_editorial_events_score_and_simulated_ledger() -> None:
    settings = Settings(
        database_url="sqlite+pysqlite:///:memory:",
        allowed_origins=(),
        jwt_secret="test-jwt-secret-with-at-least-32-chars",
        cpf_pepper="test-cpf-pepper-with-at-least-32-chars",
        commercial_simulation_enabled=True,
        payment_adapter="disabled",
        public_api_base_url="https://ead.example/tutor-staging-api/",
    )
    app = create_app(database_url=settings.database_url, settings=settings)
    Base.metadata.create_all(app.state.database.engine)
    client = TestClient(app)
    with client:
        accounts: dict[str, dict[str, object]] = {}
        for role, cpf in CPFS.items():
            accounts[role] = client.post(
                "/auth/register",
                json={
                    "name": role.title(), "cpf": cpf, "phone": "61999990000",
                    "password": PASSWORD,
                },
            ).json()
        ids = {role: account["user"]["id"] for role, account in accounts.items()}
        with Session(app.state.database.engine) as session:
            session.add(Institution(id="institution-1", name="Instituto"))
            session.add(Program(id="program-1", institution_id="institution-1", name="Programa"))
            session.add(Course(id="course-1", title="Curso", author="TDS", content={"sections": []}, active=True))
            session.flush()
            session.add(ProgramCourse(program_id="program-1", course_id="course-1"))
            session.add_all([
                ProgramMembership(user_id=ids["creator"], program_id="program-1", role="creator", status="active"),
                ProgramMembership(user_id=ids["coordinator"], program_id="program-1", role="coordinator", status="active"),
                ProgramMembership(user_id=ids["finance"], program_id="program-1", role="finance", status="active"),
                ProgramMembership(user_id=ids["student"], program_id="program-1", role="student", status="active"),
            ])
            session.flush()
            session.add(Enrollment(id="enrollment-1", user_id=ids["student"], program_id="program-1", course_id="course-1", status="active"))
            session.commit()

        created = client.post(
            "/admin/media",
            headers=bearer(accounts["creator"]),
            json={
                "institution_id": "institution-1", "program_id": "program-1",
                "course_id": "course-1", "module_id": "module-1",
                "title": "Vídeo educativo", "description": "Conteúdo",
                "competency_id": "competency-1", "provider": "youtube",
                "provider_asset_id": "abcDEF12345", "duration_seconds": 600,
                "thumbnail_url": "https://cdn.example/thumb.jpg",
                "captions": [{"language": "pt-BR", "format": "vtt", "reference": "https://cdn.example/caption.vtt"}],
                "visibility": "enrolled", "offline_policy": "forbidden",
                "master_drive_file_id": "drive-master-reference",
                "rights_confirmed": True, "followup_activity_id": "quiz-1",
            },
        )
        media_id = created.json()["id"]
        creator_publish = client.post(f"/admin/media/{media_id}/publish", headers=bearer(accounts["creator"]))
        published = client.post(f"/admin/media/{media_id}/publish", headers=bearer(accounts["coordinator"]))
        student_catalog = client.get("/media?course_id=course-1", headers=bearer(accounts["student"]))
        outsider_catalog = client.get("/media", headers=bearer(accounts["outsider"]))
        rating_before_completion = client.put(
            f"/media/{media_id}/rating",
            headers=bearer(accounts["student"]),
            json={"rating": 5},
        )
        playback = client.post(
            f"/media/{media_id}/playback-authorizations",
            headers=bearer(accounts["student"]) | {
                "Host": "attacker.invalid",
                "X-Forwarded-Host": "attacker.invalid",
                "X-Forwarded-Prefix": "/evil",
            },
        )
        outsider_playback = client.post(
            f"/media/{media_id}/playback-authorizations",
            headers=bearer(accounts["outsider"]),
        )
        prefixed_playback_path = urlsplit(playback.json()["playback_url"]).path
        playback_resolution = client.get(
            prefixed_playback_path.removeprefix("/tutor-staging-api"),
            follow_redirects=False,
        )
        tampered_playback = client.get(
            prefixed_playback_path.removeprefix("/tutor-staging-api") + "x",
            follow_redirects=False,
        )

        events = [
            media_event("video-started-1", "video_started", {"media_id": media_id}, "2026-09-20T12:00:00Z"),
            media_event("video-checkpoint-25", "video_checkpoint", {"media_id": media_id, "checkpoint": "25", "position_seconds": "150"}, "2026-09-20T12:02:00Z"),
            media_event("video-checkpoint-50", "video_checkpoint", {"media_id": media_id, "checkpoint": "50", "position_seconds": "300"}, "2026-09-20T12:04:00Z"),
            media_event("video-checkpoint-75", "video_checkpoint", {"media_id": media_id, "checkpoint": "75", "position_seconds": "450"}, "2026-09-20T12:06:00Z"),
            media_event("video-completed-1", "video_completed", {"media_id": media_id, "position_seconds": "550"}, "2026-09-20T12:08:00Z"),
            media_event("video-followup-1", "video_followup_completed", {"media_id": media_id, "followup_type": "quiz"}, "2026-09-20T12:09:00Z"),
            media_event("video-saved-1", "video_saved", {"media_id": media_id}, "2026-09-20T12:10:00Z"),
        ]
        event_responses = [client.post("/events", json=item, headers=bearer(accounts["student"])) for item in events]
        retry = client.post("/events", json=events[2], headers=bearer(accounts["student"]))
        invalid_payload = client.post(
            "/events",
            json=events[0] | {"event_id": "invalid-extra", "payload": events[0]["payload"] | {"position_seconds": "500"}},
            headers=bearer(accounts["student"]),
        )
        rating = client.put(
            f"/media/{media_id}/rating",
            headers=bearer(accounts["student"]),
            json={"rating": 5},
        )
        rating_retry = client.put(
            f"/media/{media_id}/rating",
            headers=bearer(accounts["student"]),
            json={"rating": 5},
        )
        own_rating = client.get(
            f"/media/{media_id}/rating", headers=bearer(accounts["student"])
        )
        outsider_rating = client.put(
            f"/media/{media_id}/rating",
            headers=bearer(accounts["outsider"]),
            json={"rating": 5},
        )
        score = client.post(
            "/admin/creator-scores/calculate",
            headers=bearer(accounts["coordinator"]),
            json={"media_id": media_id, "window_start": "2026-09-01T00:00:00Z", "window_end": "2026-10-01T00:00:00Z"},
        )
        score_retry = client.post(
            "/admin/creator-scores/calculate",
            headers=bearer(accounts["coordinator"]),
            json={"media_id": media_id, "window_start": "2026-09-01T00:00:00Z", "window_end": "2026-10-01T00:00:00Z"},
        )
        view_only_created = client.post(
            "/admin/media",
            headers=bearer(accounts["creator"]),
            json={
                "institution_id": "institution-1", "program_id": "program-1",
                "course_id": "course-1", "module_id": "module-1",
                "title": "Vídeo sem sinal pedagógico", "description": "Conteúdo",
                "competency_id": "competency-1", "provider": "youtube",
                "provider_asset_id": "viewOnly123", "duration_seconds": 600,
                "thumbnail_url": "https://cdn.example/view-only.jpg",
                "captions": [{"language": "pt-BR", "format": "vtt", "reference": "https://cdn.example/view-only.vtt"}],
                "visibility": "enrolled", "offline_policy": "forbidden",
                "rights_confirmed": True, "followup_activity_id": "quiz-2",
            },
        )
        view_only_media_id = view_only_created.json()["id"]
        client.post(
            f"/admin/media/{view_only_media_id}/publish",
            headers=bearer(accounts["coordinator"]),
        )
        view_only_event = client.post(
            "/events",
            headers=bearer(accounts["student"]),
            json=media_event(
                "video-started-view-only",
                "video_started",
                {"media_id": view_only_media_id},
                "2026-09-20T13:00:00Z",
            ),
        )
        view_only_score = client.post(
            "/admin/creator-scores/calculate",
            headers=bearer(accounts["coordinator"]),
            json={"media_id": view_only_media_id, "window_start": "2026-09-01T00:00:00Z", "window_end": "2026-10-01T00:00:00Z"},
        )
        ledger_payload = {
            "creator_score_id": score.json()["id"], "entry_type": "accrual",
            "amount_minor": 1234, "currency": "BRL", "idempotency_key": "score:media-1:2026-09",
            "source_event_id": "video-completed-1",
        }
        ledger = client.post("/admin/ledger/simulate", headers=bearer(accounts["finance"]), json=ledger_payload)
        ledger_retry = client.post("/admin/ledger/simulate", headers=bearer(accounts["finance"]), json=ledger_payload)
        ledger_conflict = client.post(
            "/admin/ledger/simulate", headers=bearer(accounts["finance"]),
            json=ledger_payload | {"amount_minor": 9999},
        )
        overlapping_score = client.post(
            "/admin/creator-scores/calculate",
            headers=bearer(accounts["coordinator"]),
            json={"media_id": media_id, "window_start": "2026-09-15T00:00:00Z", "window_end": "2026-10-15T00:00:00Z"},
        )
        duplicate_origin = client.post(
            "/admin/ledger/simulate", headers=bearer(accounts["finance"]),
            json=ledger_payload | {
                "creator_score_id": overlapping_score.json()["id"],
                "idempotency_key": "score:media-1:overlap",
            },
        )
        creator_block = client.post(
            f"/admin/media/{media_id}/block",
            headers=bearer(accounts["creator"]),
            json={"reason": "Revisão de segurança"},
        )
        blocked = client.post(
            f"/admin/media/{media_id}/block",
            headers=bearer(accounts["coordinator"]),
            json={"reason": "Revisão de direitos pendente"},
        )
        playback_after_block = client.get(
            playback.json()["playback_url"], follow_redirects=False
        )
        archived = client.post(
            f"/admin/media/{media_id}/archive",
            headers=bearer(accounts["coordinator"]),
            json={"reason": "Conteúdo substituído por nova edição"},
        )
        history = client.get(
            f"/admin/media/{media_id}/history",
            headers=bearer(accounts["coordinator"]),
        )
        outsider_history = client.get(
            f"/admin/media/{media_id}/history",
            headers=bearer(accounts["outsider"]),
        )

        with Session(app.state.database.engine) as session:
            learning_count = session.scalar(select(func.count()).select_from(LearningEventRecord).where(LearningEventRecord.event_type.like("video_%")))
            projection_count = session.scalar(select(func.count()).select_from(MediaEventRecord))
            qualified = session.scalars(select(MediaEventRecord).where(MediaEventRecord.qualified.is_(True))).all()
            ledger_count = session.scalar(select(func.count()).select_from(RevenueLedgerEntry))
            rating_count = session.scalar(select(func.count()).select_from(MediaRating))
            transition_count = session.scalar(
                select(func.count()).select_from(MediaStatusTransition).where(
                    MediaStatusTransition.media_id == media_id
                )
            )
        deleted = client.delete("/auth/me", headers=bearer(accounts["student"]))
        with Session(app.state.database.engine) as session:
            media_events_after_delete = session.scalar(select(func.count()).select_from(MediaEventRecord))
            ratings_after_delete = session.scalar(select(func.count()).select_from(MediaRating))
            grants_after_delete = session.scalar(
                select(func.count()).select_from(MediaPlaybackGrant)
            )

    assert created.status_code == 201
    assert created.json()["status"] == "draft"
    assert "master_drive_file_id" not in created.json()
    assert creator_publish.status_code == 403
    assert published.status_code == 200
    assert published.json()["playback_url"] is None
    assert len(student_catalog.json()["media"]) == 1
    assert outsider_catalog.json() == {"media": []}
    assert rating_before_completion.status_code == 409
    assert playback.status_code == 201
    assert playback.json()["token_type"] == "media_playback"
    assert playback.json()["playback_url"].startswith(
        "https://ead.example/tutor-staging-api/media/"
    )
    assert "attacker.invalid" not in playback.json()["playback_url"]
    assert playback_resolution.status_code == 307
    assert playback_resolution.headers["location"] == "https://www.youtube-nocookie.com/embed/abcDEF12345"
    assert tampered_playback.status_code == 401
    assert outsider_playback.status_code == 404
    assert [item.status_code for item in event_responses] == [201] * 7
    assert retry.status_code == 200
    assert invalid_payload.status_code == 422
    assert learning_count == projection_count == 8
    assert {item.event_type for item in qualified} == {"video_completed", "video_followup_completed", "video_saved"}
    assert rating.status_code == 201
    assert rating_retry.status_code == 200
    assert rating_retry.json() == rating.json()
    assert own_rating.json()["rating"] == 5
    assert outsider_rating.status_code == 403
    assert rating_count == 1
    assert score.status_code == 201
    assert score_retry.status_code == 200
    assert score.json()["rule_version"] == "creator-score-v2"
    assert score.json()["score_basis_points"] == 10000
    assert score.json()["calculation_snapshot"]["explicit_rating"]["ratings"] == 1
    assert view_only_event.status_code == 201
    assert view_only_score.status_code == 201
    assert view_only_score.json()["score_basis_points"] == 0
    assert ledger.status_code == 201
    assert ledger_retry.status_code == 200
    assert ledger_conflict.status_code == 409
    assert overlapping_score.status_code == 201
    assert duplicate_origin.status_code == 409
    assert ledger.json()["status"] == "simulated"
    assert ledger.json()["calculation_snapshot"]["payment_adapter"] == "disabled"
    assert ledger_count == 1
    assert creator_block.status_code == 403
    assert blocked.status_code == 200 and blocked.json()["status"] == "blocked"
    assert playback_after_block.status_code == 404
    assert archived.status_code == 200 and archived.json()["status"] == "archived"
    assert outsider_history.status_code == 403
    assert [item["to_status"] for item in history.json()] == [
        "draft", "published", "blocked", "archived"
    ]
    assert [item["actor_role"] for item in history.json()] == [
        "creator", "coordinator", "coordinator", "coordinator"
    ]
    assert transition_count == 4
    assert deleted.status_code == 204
    assert media_events_after_delete == 0
    assert ratings_after_delete == 0
    assert grants_after_delete == 0
