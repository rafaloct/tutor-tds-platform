from __future__ import annotations

from datetime import datetime, timezone
from typing import Literal, Protocol
from uuid import uuid4

from fastapi import APIRouter, Depends, HTTPException, Request, Response, status
from pydantic import BaseModel, ConfigDict, Field, model_validator
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from .auth import access_claims
from .database import Database
from .models import (
    CreatorScore,
    MediaAsset,
    MediaEventRecord,
    MediaRating,
    ProgramMembership,
    RevenueLedgerEntry,
)

router = APIRouter(tags=["creator-commercial"])
RULE_VERSION = "creator-score-v2"


class PaymentAdapter(Protocol):
    def create_recipient(self, *_: object, **__: object) -> str: ...
    def create_payment(self, *_: object, **__: object) -> str: ...
    def get_payment_status(self, *_: object, **__: object) -> str: ...
    def request_payout(self, *_: object, **__: object) -> str: ...
    def get_payout_status(self, *_: object, **__: object) -> str: ...
    def verify_webhook(self, *_: object, **__: object) -> bool: ...


class DisabledPaymentAdapter:
    def _disabled(self, *_: object, **__: object) -> str:
        raise RuntimeError("Adapter de pagamento desabilitado.")

    create_recipient = create_payment = get_payment_status = _disabled
    request_payout = get_payout_status = _disabled

    def verify_webhook(self, *_: object, **__: object) -> bool:
        return False


class ScoreRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")
    media_id: str = Field(min_length=1, max_length=36)
    window_start: datetime
    window_end: datetime

    @model_validator(mode="after")
    def valid_window(self) -> "ScoreRequest":
        if any(value.tzinfo is None or value.utcoffset() is None for value in (self.window_start, self.window_end)):
            raise ValueError("janela deve conter fuso horário")
        self.window_start = self.window_start.astimezone(timezone.utc)
        self.window_end = self.window_end.astimezone(timezone.utc)
        if self.window_end <= self.window_start:
            raise ValueError("window_end deve ser posterior a window_start")
        if (self.window_end - self.window_start).days > 366:
            raise ValueError("janela máxima é de 366 dias")
        return self


class ScoreResponse(BaseModel):
    id: str
    creator_user_id: str
    media_id: str
    program_id: str
    rule_version: str
    window_start: datetime
    window_end: datetime
    score_basis_points: int
    calculation_snapshot: dict[str, object]
    created_at: datetime


class LedgerCreate(BaseModel):
    model_config = ConfigDict(extra="forbid")
    creator_score_id: str = Field(min_length=1, max_length=36)
    entry_type: Literal["accrual", "reversal", "adjustment"]
    amount_minor: int = Field(ge=-100_000_000, le=100_000_000)
    currency: Literal["BRL"] = "BRL"
    idempotency_key: str = Field(min_length=8, max_length=180, pattern=r"^[A-Za-z0-9_.:-]+$")
    source_event_id: str = Field(min_length=1, max_length=180)

    @model_validator(mode="after")
    def amount_sign(self) -> "LedgerCreate":
        if self.amount_minor == 0:
            raise ValueError("lançamento não pode ser zero")
        if self.entry_type == "accrual" and self.amount_minor < 0:
            raise ValueError("accrual deve ser positivo")
        if self.entry_type == "reversal" and self.amount_minor > 0:
            raise ValueError("reversal deve ser negativo")
        return self


class LedgerResponse(BaseModel):
    id: str
    institution_id: str
    program_id: str
    creator_user_id: str
    media_id: str
    source_event_id: str
    rule_version: str
    entry_type: str
    amount_minor: int
    currency: str
    status: Literal["simulated"]
    idempotency_key: str
    calculation_snapshot: dict[str, object]
    created_at: datetime


@router.post("/admin/creator-scores/calculate", response_model=ScoreResponse, status_code=201)
def calculate_score(
    payload: ScoreRequest,
    request: Request,
    response: Response,
    claims: dict[str, str] = Depends(access_claims),
) -> ScoreResponse:
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        media = session.get(MediaAsset, payload.media_id)
        if media is None:
            raise HTTPException(status_code=404, detail="Mídia não encontrada.")
        _require_program_role(session, claims, media.program_id, {"coordinator"})
        existing = session.scalar(select(CreatorScore).where(
            CreatorScore.creator_user_id == media.creator_user_id,
            CreatorScore.media_id == media.id,
            CreatorScore.rule_version == RULE_VERSION,
            CreatorScore.window_start == payload.window_start,
            CreatorScore.window_end == payload.window_end,
        ))
        if existing is not None:
            response.status_code = 200
            return _score_response(existing)
        events = session.scalars(select(MediaEventRecord).where(
            MediaEventRecord.media_id == media.id,
            MediaEventRecord.occurred_at >= payload.window_start,
            MediaEventRecord.occurred_at <= payload.window_end,
        )).all()
        started = {item.user_id for item in events if item.event_type == "video_started"}
        completed = {item.user_id for item in events if item.event_type == "video_completed" and item.qualified}
        followups = {item.user_id for item in events if item.event_type == "video_followup_completed" and item.qualified}
        saves = {item.user_id for item in events if item.event_type == "video_saved"}
        ratings = session.scalars(select(MediaRating).where(
            MediaRating.media_id == media.id,
            MediaRating.updated_at >= payload.window_start,
            MediaRating.updated_at <= payload.window_end,
        )).all()
        rating_by_user = {item.user_id: item.rating for item in ratings}
        participants = started | completed | followups | saves | set(rating_by_user)
        denominator = max(1, len(participants))
        has_pedagogical_signal = bool(completed or followups or saves or rating_by_user)
        operational = bool(
            has_pedagogical_signal
            and media.thumbnail_url
            and media.captions
            and media.status == "published"
        )
        rating_points = round(
            1500 * sum(rating_by_user.values()) / (5 * denominator)
        )
        score = min(10_000, round(
            3500 * len(completed) / denominator
            + 3500 * len(followups) / denominator
            + rating_points
            + 1000 * len(saves) / denominator
            + (500 if operational else 0)
        ))
        snapshot: dict[str, object] = {
            "participants_started": len(started),
            "qualified_completions": len(completed),
            "qualified_followups": len(followups),
            "saves": len(saves),
            "explicit_rating": {
                "weight_basis_points": 1500,
                "ratings": len(rating_by_user),
                "rating_sum": sum(rating_by_user.values()),
                "awarded_basis_points": rating_points,
            },
            "operational_quality": operational,
            "weights_basis_points": {
                "completion": 3500, "followup": 3500, "explicit_rating": 1500,
                "save": 1000, "operational": 500,
            },
        }
        record = CreatorScore(
            id=str(uuid4()), institution_id=media.institution_id, program_id=media.program_id,
            creator_user_id=media.creator_user_id, media_id=media.id,
            rule_version=RULE_VERSION, window_start=payload.window_start,
            window_end=payload.window_end, score_basis_points=score,
            calculation_snapshot=snapshot,
        )
        session.add(record)
        _commit(session, "Score desta janela já existe.")
        return _score_response(record)


@router.get("/creators/me/scores", response_model=list[ScoreResponse])
def own_scores(
    request: Request,
    claims: dict[str, str] = Depends(access_claims),
) -> list[ScoreResponse]:
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        records = session.scalars(select(CreatorScore).where(
            CreatorScore.creator_user_id == claims["sub"]
        ).order_by(CreatorScore.created_at.desc())).all()
        return [_score_response(item) for item in records]


@router.post("/admin/ledger/simulate", response_model=LedgerResponse, status_code=201)
def simulate_ledger(
    payload: LedgerCreate,
    request: Request,
    response: Response,
    claims: dict[str, str] = Depends(access_claims),
) -> LedgerResponse:
    settings = request.app.state.settings
    if not settings.commercial_simulation_enabled:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Simulação comercial desativada.")
    if settings.payment_adapter != "disabled":
        raise HTTPException(status_code=503, detail="Somente adapter disabled é permitido nesta fase.")
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        existing = session.scalar(select(RevenueLedgerEntry).where(
            RevenueLedgerEntry.idempotency_key == payload.idempotency_key
        ))
        if existing is not None:
            _require_program_role(
                session, claims, existing.program_id, {"finance"}
            )
            same_payload = (
                existing.entry_type == payload.entry_type
                and existing.amount_minor == payload.amount_minor
                and existing.currency == payload.currency
                and existing.source_event_id == payload.source_event_id
                and existing.calculation_snapshot.get("creator_score_id")
                == payload.creator_score_id
            )
            if not same_payload:
                raise HTTPException(
                    status_code=409,
                    detail="Chave de idempotência usada com payload divergente.",
                )
            response.status_code = 200
            return _ledger_response(existing)
        score = session.get(CreatorScore, payload.creator_score_id)
        if score is None:
            raise HTTPException(status_code=404, detail="Creator Score não encontrado.")
        _require_program_role(session, claims, score.program_id, {"finance"})
        source = session.get(MediaEventRecord, payload.source_event_id)
        if source is None or source.media_id != score.media_id:
            raise HTTPException(
                status_code=422,
                detail="Evento-fonte não pertence à mídia do score.",
            )
        record = RevenueLedgerEntry(
            id=str(uuid4()), institution_id=score.institution_id, program_id=score.program_id,
            creator_score_id=score.id,
            creator_user_id=score.creator_user_id, media_id=score.media_id,
            source_event_id=payload.source_event_id, rule_version=score.rule_version,
            entry_type=payload.entry_type, amount_minor=payload.amount_minor,
            currency=payload.currency, status="simulated",
            idempotency_key=payload.idempotency_key,
            calculation_snapshot={
                "creator_score_id": score.id,
                "score_basis_points": score.score_basis_points,
                "mode": "simulated",
                "payment_adapter": "disabled",
            },
            approved_by=None, approved_at=None, external_reference=None,
        )
        session.add(record)
        _commit(session, "Conflito de idempotência ou origem já lançada.")
        return _ledger_response(record)


@router.get("/admin/ledger", response_model=list[LedgerResponse])
def list_ledger(
    request: Request,
    program_id: str,
    claims: dict[str, str] = Depends(access_claims),
) -> list[LedgerResponse]:
    if not request.app.state.settings.commercial_simulation_enabled:
        raise HTTPException(status_code=404, detail="Simulação comercial desativada.")
    database: Database = request.app.state.database
    with Session(database.engine) as session:
        _require_program_role(session, claims, program_id, {"finance"})
        records = session.scalars(select(RevenueLedgerEntry).where(
            RevenueLedgerEntry.program_id == program_id
        ).order_by(RevenueLedgerEntry.created_at, RevenueLedgerEntry.id)).all()
        return [_ledger_response(item) for item in records]


def _require_program_role(session: Session, claims: dict[str, str], program_id: str, roles: set[str]) -> None:
    if claims["role"] == "admin":
        return
    membership = session.get(ProgramMembership, (claims["sub"], program_id))
    if membership is None or membership.status != "active" or membership.role not in roles:
        raise HTTPException(status_code=403, detail="Função não autorizada neste programa.")


def _score_response(record: CreatorScore) -> ScoreResponse:
    return ScoreResponse(
        id=record.id, creator_user_id=record.creator_user_id, media_id=record.media_id,
        program_id=record.program_id, rule_version=record.rule_version,
        window_start=record.window_start, window_end=record.window_end,
        score_basis_points=record.score_basis_points,
        calculation_snapshot=record.calculation_snapshot, created_at=record.created_at,
    )


def _ledger_response(record: RevenueLedgerEntry) -> LedgerResponse:
    return LedgerResponse(
        id=record.id, institution_id=record.institution_id, program_id=record.program_id,
        creator_user_id=record.creator_user_id, media_id=record.media_id,
        source_event_id=record.source_event_id, rule_version=record.rule_version,
        entry_type=record.entry_type, amount_minor=record.amount_minor,
        currency=record.currency, status="simulated", idempotency_key=record.idempotency_key,
        calculation_snapshot=record.calculation_snapshot, created_at=record.created_at,
    )


def _commit(session: Session, detail: str) -> None:
    try:
        session.commit()
    except IntegrityError as exc:
        session.rollback()
        raise HTTPException(status_code=409, detail=detail) from exc
