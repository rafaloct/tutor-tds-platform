from __future__ import annotations

import hashlib
import secrets
from datetime import datetime, timedelta, timezone
from typing import Literal
from urllib.parse import quote, urlparse
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response
from fastapi.responses import RedirectResponse
from pydantic import BaseModel, ConfigDict, Field, model_validator
from sqlalchemy import delete, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .auth import access_claims, optional_access_claims
from .config import Settings
from .database import Database
from .media_delivery import DEFAULT_MEDIA_DELIVERY
from .models import (
    Enrollment,
    MediaAsset,
    MediaEventRecord,
    MediaPlaybackGrant,
    MediaRating,
    MediaStatusTransition,
    Program,
    ProgramCourse,
    ProgramMembership,
)

router = APIRouter(tags=["media"])
admin_router = APIRouter(prefix="/admin/media", tags=["admin", "media"])
creator_router = APIRouter(prefix="/creators/me", tags=["creators"])
Provider = Literal["youtube", "cloudflare_stream", "external_hls"]
Visibility = Literal["public", "unlisted", "enrolled", "institution"]
OfflinePolicy = Literal["forbidden", "allowed"]
MediaStatus = Literal["draft", "processing", "published", "blocked", "archived"]
PLAYBACK_TTL_SECONDS = 300


class Caption(BaseModel):
    model_config = ConfigDict(extra="forbid")
    language: str = Field(pattern=r"^[a-z]{2,3}(?:-[A-Z]{2})?$")
    label: str | None = Field(default=None, max_length=80)
    format: Literal["vtt"]
    reference: str = Field(min_length=1, max_length=500)


class MediaCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    institution_id: str = Field(min_length=1, max_length=36)
    program_id: str = Field(min_length=1, max_length=36)
    course_id: str = Field(min_length=1, max_length=120)
    module_id: str = Field(pattern=r"^[a-z0-9][a-z0-9_.-]{0,79}$")
    creator_user_id: str | None = Field(default=None, max_length=36)
    title: str = Field(min_length=2, max_length=240)
    description: str = Field(default="", max_length=4000)
    competency_id: str = Field(pattern=r"^[a-z0-9][a-z0-9_.-]{0,79}$")
    provider: Provider
    provider_asset_id: str = Field(min_length=1, max_length=500)
    duration_seconds: int = Field(gt=0, le=24 * 60 * 60)
    thumbnail_url: str | None = Field(default=None, max_length=500)
    captions: list[Caption] = Field(default_factory=list, max_length=20)
    visibility: Visibility = "enrolled"
    offline_policy: OfflinePolicy = "forbidden"
    master_drive_file_id: str | None = Field(default=None, max_length=240)
    rights_confirmed: bool = False
    followup_activity_id: str = Field(pattern=r"^[a-z0-9][a-z0-9_.-]{0,79}$")

    @model_validator(mode="after")
    def provider_contract(self) -> "MediaCreate":
        _validate_provider(self.provider, self.provider_asset_id)
        _validate_https_optional(self.thumbnail_url, "thumbnail_url")
        for caption in self.captions:
            _validate_https_optional(caption.reference, "caption.reference")
        return self


class MediaPatch(BaseModel):
    model_config = ConfigDict(extra="forbid")
    title: str | None = Field(default=None, min_length=2, max_length=240)
    description: str | None = Field(default=None, max_length=4000)
    competency_id: str | None = Field(
        default=None, pattern=r"^[a-z0-9][a-z0-9_.-]{0,79}$"
    )
    provider: Provider | None = None
    provider_asset_id: str | None = Field(default=None, min_length=1, max_length=500)
    duration_seconds: int | None = Field(default=None, gt=0, le=24 * 60 * 60)
    thumbnail_url: str | None = Field(default=None, max_length=500)
    captions: list[Caption] | None = Field(default=None, max_length=20)
    visibility: Visibility | None = None
    offline_policy: OfflinePolicy | None = None
    master_drive_file_id: str | None = Field(default=None, max_length=240)
    rights_confirmed: bool | None = None
    followup_activity_id: str | None = Field(
        default=None, pattern=r"^[a-z0-9][a-z0-9_.-]{0,79}$"
    )


class MediaResponse(BaseModel):
    id: str
    institution_id: str
    program_id: str
    course_id: str
    module_id: str
    creator_user_id: str
    title: str
    description: str
    competency_id: str
    provider: Provider
    duration_seconds: int
    thumbnail_url: str | None
    captions: list[dict[str, str]]
    visibility: Visibility
    offline_policy: OfflinePolicy
    status: MediaStatus
    followup_activity_id: str
    playback_url: str | None
    published_at: datetime | None


class MediaPage(BaseModel):
    media: list[MediaResponse]


class CreatorMediaAnalytics(BaseModel):
    media_id: str
    started: int
    unique_participants: int
    qualified_completions: int
    followups: int
    saves: int
    ratings: int
    average_rating: float | None


class EditorialTransitionRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    reason: str = Field(min_length=3, max_length=500)

    @model_validator(mode="after")
    def meaningful_reason(self) -> "EditorialTransitionRequest":
        self.reason = self.reason.strip()
        if len(self.reason) < 3:
            raise ValueError("reason deve ter ao menos 3 caracteres úteis")
        return self


class EditorialTransitionResponse(BaseModel):
    id: str
    media_id: str
    from_status: MediaStatus | None
    to_status: MediaStatus
    actor_user_id: str
    actor_role: str
    reason: str | None
    occurred_at: datetime


class MediaRatingRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    rating: int = Field(ge=1, le=5)


class MediaRatingResponse(BaseModel):
    media_id: str
    rating: int
    submitted_at: datetime
    updated_at: datetime


class PlaybackAuthorizationResponse(BaseModel):
    media_id: str
    playback_url: str
    expires_at: datetime
    token_type: Literal["media_playback"] = "media_playback"


@admin_router.post("", response_model=MediaResponse, status_code=201)
def create_media(
    payload: MediaCreate,
    request: Request,
    claims: dict[str, str] = Depends(access_claims),
) -> MediaResponse:
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        _validate_lineage(session, payload)
        creator_id = payload.creator_user_id or claims["sub"]
        if claims["role"] != "admin" and creator_id != claims["sub"]:
            raise HTTPException(status_code=403, detail="Creator só pode criar conteúdo próprio.")
        _require_program_role(session, claims, payload.program_id, {"creator"}, allow_admin=True)
        creator = session.get(ProgramMembership, (creator_id, payload.program_id))
        if creator is None or creator.status != "active" or creator.role != "creator":
            raise HTTPException(status_code=422, detail="Creator sem vínculo ativo no programa.")
        record = MediaAsset(
            id=str(uuid4()), creator_user_id=creator_id, status="draft",
            **payload.model_dump(exclude={"creator_user_id", "captions"}),
            captions=[item.model_dump() for item in payload.captions],
        )
        session.add(record)
        session.flush()
        _append_transition(
            session,
            media=record,
            claims=claims,
            from_status=None,
            to_status="draft",
            reason="Mídia criada como rascunho.",
        )
        _commit(session, "Mídia/provedor já cadastrado.")
        return _serialize(record, request.app.state.settings)


@admin_router.patch("/{media_id}", response_model=MediaResponse)
def patch_media(
    media_id: str,
    payload: MediaPatch,
    request: Request,
    claims: dict[str, str] = Depends(access_claims),
) -> MediaResponse:
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        media = _media(session, media_id)
        _require_editor(session, media, claims, publish=False)
        if media.status != "draft":
            raise HTTPException(status_code=409, detail="Somente rascunho pode ser editado.")
        values = payload.model_dump(exclude_unset=True)
        captions = values.pop("captions", None)
        for key, value in values.items():
            setattr(media, key, value)
        if captions is not None:
            media.captions = [item if isinstance(item, dict) else item.model_dump() for item in captions]
        try:
            _validate_provider(media.provider, media.provider_asset_id)
            _validate_https_optional(media.thumbnail_url, "thumbnail_url")
            for caption in media.captions:
                _validate_https_optional(caption["reference"], "caption.reference")
        except (KeyError, ValueError) as exc:
            raise HTTPException(status_code=422, detail=str(exc)) from exc
        session.commit()
        return _serialize(media, request.app.state.settings)


@admin_router.post("/{media_id}/publish", response_model=MediaResponse)
def publish_media(
    media_id: str,
    request: Request,
    claims: dict[str, str] = Depends(access_claims),
) -> MediaResponse:
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        media = _media(session, media_id)
        _require_editor(session, media, claims, publish=True)
        if media.status not in {"draft", "processing"}:
            raise HTTPException(status_code=409, detail="Mídia não está publicável.")
        if not media.rights_confirmed:
            raise HTTPException(status_code=422, detail="Direitos da mídia não confirmados.")
        previous_status = media.status
        media.status = "published"
        media.published_at = datetime.now(timezone.utc)
        media.published_by = claims["sub"]
        _append_transition(
            session,
            media=media,
            claims=claims,
            from_status=previous_status,
            to_status="published",
            reason="Publicação aprovada editorialmente.",
        )
        session.commit()
        return _serialize(media, request.app.state.settings)


@admin_router.post("/{media_id}/block", response_model=MediaResponse)
def block_media(
    media_id: str,
    payload: EditorialTransitionRequest,
    request: Request,
    claims: dict[str, str] = Depends(access_claims),
) -> MediaResponse:
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        media = _media(session, media_id)
        _require_editor(session, media, claims, publish=True)
        if media.status not in {"published", "processing"}:
            raise HTTPException(status_code=409, detail="Mídia não pode ser bloqueada neste estado.")
        previous_status = media.status
        media.status = "blocked"
        _append_transition(
            session,
            media=media,
            claims=claims,
            from_status=previous_status,
            to_status="blocked",
            reason=payload.reason.strip(),
        )
        session.commit()
        return _serialize(media, request.app.state.settings)


@admin_router.post("/{media_id}/archive", response_model=MediaResponse)
def archive_media(
    media_id: str,
    payload: EditorialTransitionRequest,
    request: Request,
    claims: dict[str, str] = Depends(access_claims),
) -> MediaResponse:
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        media = _media(session, media_id)
        _require_editor(session, media, claims, publish=True)
        if media.status == "archived":
            raise HTTPException(status_code=409, detail="Mídia já está arquivada.")
        previous_status = media.status
        media.status = "archived"
        _append_transition(
            session,
            media=media,
            claims=claims,
            from_status=previous_status,
            to_status="archived",
            reason=payload.reason.strip(),
        )
        session.commit()
        return _serialize(media, request.app.state.settings)


@admin_router.get(
    "/{media_id}/history",
    response_model=list[EditorialTransitionResponse],
)
def media_editorial_history(
    media_id: str,
    request: Request,
    claims: dict[str, str] = Depends(access_claims),
) -> list[EditorialTransitionResponse]:
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        media = _media(session, media_id)
        _require_editor_view(session, media, claims)
        records = session.scalars(
            select(MediaStatusTransition)
            .where(MediaStatusTransition.media_id == media.id)
            .order_by(MediaStatusTransition.occurred_at, MediaStatusTransition.id)
        ).all()
        return [EditorialTransitionResponse.model_validate(item, from_attributes=True) for item in records]


@router.get("/media", response_model=MediaPage)
def published_media(
    request: Request,
    course_id: str | None = Query(default=None, max_length=120),
    module_id: str | None = Query(default=None, max_length=120),
    claims: dict[str, str] | None = Depends(optional_access_claims),
) -> MediaPage:
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        statement = select(MediaAsset).where(
            MediaAsset.status == "published",
            MediaAsset.visibility != "unlisted",
        )
        if course_id is not None:
            statement = statement.where(MediaAsset.course_id == course_id)
        if module_id is not None:
            statement = statement.where(MediaAsset.module_id == module_id)
        records = session.scalars(statement.order_by(MediaAsset.published_at, MediaAsset.id)).all()
        user_id = claims["sub"] if claims is not None else None
        visible = [item for item in records if _can_view_media(session, item, user_id)]
        return MediaPage(media=[_serialize(item, request.app.state.settings) for item in visible])


@router.get("/media/{media_id}", response_model=MediaResponse)
def published_media_detail(
    media_id: str,
    request: Request,
    claims: dict[str, str] | None = Depends(optional_access_claims),
) -> MediaResponse:
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        media = _media(session, media_id)
        user_id = claims["sub"] if claims is not None else None
        if media.status != "published" or not _can_view_media(session, media, user_id):
            raise HTTPException(status_code=404, detail="Mídia publicada não encontrada.")
        return _serialize(media, request.app.state.settings)


@router.put("/media/{media_id}/rating", response_model=MediaRatingResponse)
def rate_media(
    media_id: str,
    payload: MediaRatingRequest,
    request: Request,
    response: Response,
    claims: dict[str, str] = Depends(access_claims),
) -> MediaRatingResponse:
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        media = _media(session, media_id)
        if media.status != "published":
            raise HTTPException(status_code=404, detail="Mídia publicada não encontrada.")
        enrollment = _active_enrollment(session, media, claims["sub"])
        if enrollment is None:
            raise HTTPException(status_code=403, detail="Matrícula ativa obrigatória para avaliar.")
        qualified = session.scalar(
            select(MediaEventRecord.event_id).where(
                MediaEventRecord.media_id == media.id,
                MediaEventRecord.user_id == claims["sub"],
                MediaEventRecord.enrollment_id == enrollment.id,
                MediaEventRecord.event_type == "video_completed",
                MediaEventRecord.qualified.is_(True),
            )
        )
        if qualified is None:
            raise HTTPException(
                status_code=409,
                detail="Avaliação exige conclusão qualificada da mídia.",
            )
        now = datetime.now(timezone.utc)
        record = session.get(MediaRating, (media.id, claims["sub"]))
        if record is None:
            record = MediaRating(
                media_id=media.id,
                user_id=claims["sub"],
                enrollment_id=enrollment.id,
                rating=payload.rating,
                submitted_at=now,
                updated_at=now,
            )
            session.add(record)
            response.status_code = 201
        elif record.rating != payload.rating:
            record.rating = payload.rating
            record.enrollment_id = enrollment.id
            record.updated_at = now
        session.commit()
        return _rating_response(record)


@router.get("/media/{media_id}/rating", response_model=MediaRatingResponse)
def own_media_rating(
    media_id: str,
    request: Request,
    claims: dict[str, str] = Depends(access_claims),
) -> MediaRatingResponse:
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        record = session.get(MediaRating, (media_id, claims["sub"]))
        if record is None:
            raise HTTPException(status_code=404, detail="Avaliação não encontrada.")
        return _rating_response(record)


@router.post(
    "/media/{media_id}/playback-authorizations",
    response_model=PlaybackAuthorizationResponse,
    status_code=201,
)
def authorize_media_playback(
    media_id: str,
    request: Request,
    claims: dict[str, str] = Depends(access_claims),
) -> PlaybackAuthorizationResponse:
    database: Database = request.app.state.database
    settings: Settings = request.app.state.settings
    with Session(database.engine) as session:
        media = _media(session, media_id)
        if media.status != "published" or not _can_view_media(session, media, claims["sub"]):
            raise HTTPException(status_code=404, detail="Mídia publicada não encontrada.")
        if _playback_url(media, settings) is None:
            raise HTTPException(status_code=503, detail="Entrega da mídia não configurada.")
        now = datetime.now(timezone.utc)
        expires_at = now + timedelta(seconds=PLAYBACK_TTL_SECONDS)
        token = secrets.token_urlsafe(32)
        session.execute(
            delete(MediaPlaybackGrant).where(
                MediaPlaybackGrant.expires_at <= now
            )
        )
        session.add(
            MediaPlaybackGrant(
                id=str(uuid4()),
                token_digest=_sha256(token),
                media_id=media.id,
                user_id=claims["sub"],
                expires_at=expires_at,
            )
        )
        session.commit()
        playback_url = _playback_authorization_url(
            request=request,
            settings=settings,
            media_id=media.id,
            token=token,
        )
        return PlaybackAuthorizationResponse(
            media_id=media.id,
            playback_url=playback_url,
            expires_at=expires_at,
        )


@router.get(
    "/media/{media_id}/playback/{token}",
    name="resolve_media_playback",
    response_class=RedirectResponse,
)
def resolve_media_playback(
    media_id: str,
    token: str,
    request: Request,
) -> RedirectResponse:
    settings: Settings = request.app.state.settings
    if not 32 <= len(token) <= 200:
        raise HTTPException(status_code=401, detail="Autorização de playback inválida ou expirada.")
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        grant = session.scalar(
            select(MediaPlaybackGrant).where(
                MediaPlaybackGrant.token_digest == _sha256(token),
                MediaPlaybackGrant.media_id == media_id,
            )
        )
        now = datetime.now(timezone.utc)
        if grant is None or _aware(grant.expires_at) <= now:
            raise HTTPException(status_code=401, detail="Autorização de playback inválida ou expirada.")
        media = _media(session, media_id)
        if media.status != "published" or not _can_view_media(session, media, grant.user_id):
            raise HTTPException(status_code=404, detail="Mídia publicada não encontrada.")
        target = _playback_url(media, settings)
        if target is None:
            raise HTTPException(status_code=503, detail="Entrega da mídia não configurada.")
        return RedirectResponse(target, status_code=307)


@creator_router.get("/media", response_model=MediaPage)
def creator_media(
    request: Request,
    claims: dict[str, str] = Depends(access_claims),
) -> MediaPage:
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        records = session.scalars(select(MediaAsset).where(
            MediaAsset.creator_user_id == claims["sub"]
        ).order_by(MediaAsset.created_at.desc())).all()
        return MediaPage(media=[_serialize(item, request.app.state.settings) for item in records])


@creator_router.get("/analytics", response_model=list[CreatorMediaAnalytics])
def creator_analytics(
    request: Request,
    claims: dict[str, str] = Depends(access_claims),
) -> list[CreatorMediaAnalytics]:
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        media_ids = list(session.scalars(select(MediaAsset.id).where(
            MediaAsset.creator_user_id == claims["sub"]
        )))
        result: list[CreatorMediaAnalytics] = []
        for media_id in media_ids:
            events = session.scalars(select(MediaEventRecord).where(MediaEventRecord.media_id == media_id)).all()
            result.append(CreatorMediaAnalytics(
                media_id=media_id,
                started=sum(item.event_type == "video_started" for item in events),
                unique_participants=len({item.user_id for item in events}),
                qualified_completions=sum(item.event_type == "video_completed" and item.qualified for item in events),
                followups=sum(item.event_type == "video_followup_completed" and item.qualified for item in events),
                saves=sum(item.event_type == "video_saved" for item in events),
                ratings=len(ratings := session.scalars(select(MediaRating).where(
                    MediaRating.media_id == media_id
                )).all()),
                average_rating=(
                    round(sum(item.rating for item in ratings) / len(ratings), 2)
                    if ratings else None
                ),
            ))
        return result


def _validate_lineage(session: Session, payload: MediaCreate) -> None:
    program = session.get(Program, payload.program_id)
    if program is None or program.institution_id != payload.institution_id:
        raise HTTPException(status_code=422, detail="Programa fora da instituição.")
    if session.get(ProgramCourse, (payload.program_id, payload.course_id)) is None:
        raise HTTPException(status_code=422, detail="Curso não ofertado pelo programa.")


def _require_program_role(session: Session, claims: dict[str, str], program_id: str, roles: set[str], *, allow_admin: bool) -> None:
    if allow_admin and claims["role"] == "admin":
        return
    membership = session.get(ProgramMembership, (claims["sub"], program_id))
    if membership is None or membership.status != "active" or membership.role not in roles:
        raise HTTPException(status_code=403, detail="Vínculo editorial não autorizado.")


def _require_editor(session: Session, media: MediaAsset, claims: dict[str, str], *, publish: bool) -> None:
    if claims["role"] == "admin":
        return
    if publish:
        _require_program_role(session, claims, media.program_id, {"coordinator"}, allow_admin=False)
        return
    if media.creator_user_id == claims["sub"]:
        _require_program_role(session, claims, media.program_id, {"creator"}, allow_admin=False)
        return
    _require_program_role(session, claims, media.program_id, {"coordinator"}, allow_admin=False)


def _require_editor_view(session: Session, media: MediaAsset, claims: dict[str, str]) -> None:
    if claims["role"] == "admin":
        return
    if media.creator_user_id == claims["sub"]:
        _require_program_role(session, claims, media.program_id, {"creator"}, allow_admin=False)
        return
    _require_program_role(session, claims, media.program_id, {"coordinator"}, allow_admin=False)


def _can_view_media(session: Session, media: MediaAsset, user_id: str | None) -> bool:
    if media.visibility in {"public", "unlisted"}:
        return True
    if user_id is None:
        return False
    membership = session.get(ProgramMembership, (user_id, media.program_id))
    if media.visibility == "institution":
        return membership is not None and membership.status == "active"
    return session.scalar(select(Enrollment.id).where(
        Enrollment.user_id == user_id, Enrollment.program_id == media.program_id,
        Enrollment.course_id == media.course_id, Enrollment.status == "active",
    )) is not None


def _active_enrollment(
    session: Session, media: MediaAsset, user_id: str
) -> Enrollment | None:
    return session.scalar(
        select(Enrollment).where(
            Enrollment.user_id == user_id,
            Enrollment.program_id == media.program_id,
            Enrollment.course_id == media.course_id,
            Enrollment.status == "active",
        )
    )


def _validate_provider(provider: str, asset_id: str) -> None:
    DEFAULT_MEDIA_DELIVERY.validate_asset(provider, asset_id)


def _validate_https_optional(value: str | None, field: str) -> None:
    if value is not None:
        parsed = urlparse(value)
        if parsed.scheme != "https" or not parsed.netloc or _is_google_storage_host(parsed.netloc):
            raise ValueError(f"{field} deve usar HTTPS e não pode usar Drive/Google")


def _is_google_storage_host(host: str) -> bool:
    normalized = host.split(":", 1)[0].lower()
    return normalized in {"drive.google.com", "docs.google.com"} or normalized.endswith(".googleusercontent.com") or normalized == "googleusercontent.com"


def _playback_url(media: MediaAsset, settings: Settings) -> str | None:
    return DEFAULT_MEDIA_DELIVERY.playback_url(
        provider=media.provider,
        asset_id=media.provider_asset_id,
        settings=settings,
    )


def _playback_authorization_url(
    *, request: Request, settings: Settings, media_id: str, token: str
) -> str:
    public_base = settings.resolved_public_api_base_url()
    if public_base is not None:
        return (
            f"{public_base}/media/{quote(media_id, safe='')}"
            f"/playback/{quote(token, safe='')}"
        )
    return str(
        request.url_for(
            "resolve_media_playback",
            media_id=media_id,
            token=token,
        )
    )


def _serialize(media: MediaAsset, settings: Settings) -> MediaResponse:
    return MediaResponse(
        id=media.id, institution_id=media.institution_id, program_id=media.program_id,
        course_id=media.course_id, module_id=media.module_id, creator_user_id=media.creator_user_id,
        title=media.title, description=media.description, competency_id=media.competency_id,
        provider=media.provider, duration_seconds=media.duration_seconds,
        thumbnail_url=media.thumbnail_url,
        captions=[{
            "language": item["language"],
            "label": item.get("label") or item["language"],
            "format": item["format"],
            "url": item["reference"],
        } for item in media.captions],
        visibility=media.visibility, offline_policy=media.offline_policy, status=media.status,
        followup_activity_id=media.followup_activity_id,
        playback_url=(
            _playback_url(media, settings)
            if media.visibility in {"public", "unlisted"} and media.status == "published"
            else None
        ),
        published_at=media.published_at,
    )


def _append_transition(
    session: Session,
    *,
    media: MediaAsset,
    claims: dict[str, str],
    from_status: str | None,
    to_status: str,
    reason: str,
) -> None:
    session.add(
        MediaStatusTransition(
            id=str(uuid4()),
            media_id=media.id,
            from_status=from_status,
            to_status=to_status,
            actor_user_id=claims["sub"],
            actor_role=_effective_program_role(
                session, claims, media.program_id
            ),
            reason=reason,
            occurred_at=datetime.now(timezone.utc),
        )
    )


def _rating_response(record: MediaRating) -> MediaRatingResponse:
    return MediaRatingResponse(
        media_id=record.media_id,
        rating=record.rating,
        submitted_at=record.submitted_at,
        updated_at=record.updated_at,
    )


def _sha256(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()


def _aware(value: datetime) -> datetime:
    return value if value.tzinfo is not None else value.replace(tzinfo=timezone.utc)


def _effective_program_role(
    session: Session, claims: dict[str, str], program_id: str
) -> str:
    if claims["role"] == "admin":
        return "admin"
    membership = session.get(ProgramMembership, (claims["sub"], program_id))
    return membership.role if membership is not None else claims["role"]


def _media(session: Session, media_id: str) -> MediaAsset:
    media = session.get(MediaAsset, media_id)
    if media is None:
        raise HTTPException(status_code=404, detail="Mídia não encontrada.")
    return media


def _commit(session: Session, detail: str) -> None:
    try:
        session.commit()
    except IntegrityError as exc:
        session.rollback()
        raise HTTPException(status_code=409, detail=detail) from exc
