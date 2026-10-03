import ast
from collections.abc import Iterator
from pathlib import Path
import re
import sqlite3

import pytest

from ops.export_tds_journey import (
    ACTIVITY_COLUMNS,
    JOURNEY_COLUMNS,
    PARTICIPANT_COLUMNS,
    daily_activity,
    participants,
)

ROOT = Path(__file__).resolve().parents[2]
DATA = ROOT / "tooling" / "data"
WINDOW = {"since": "2026-10-02T00:00:00Z", "until": "2026-10-03T00:00:00Z"}


@pytest.fixture
def snapshot() -> Iterator[sqlite3.Connection]:
    with sqlite3.connect(":memory:") as connection:
        connection.row_factory = sqlite3.Row
        connection.executescript(
            (DATA / "journey_fixture.sql").read_text(encoding="utf-8")
        )
        yield connection


def measures(
    connection: sqlite3.Connection,
    window: dict[str, str] | None = None,
) -> dict[str, tuple[int | float | None, int | None]]:
    daily_activity([
        dict(row) for row in connection.execute("SELECT * FROM activity")
    ])
    rows = connection.execute(
        (DATA / "journey_measures.sql").read_text(encoding="utf-8"),
        WINDOW if window is None else window,
    )
    return {row["medida"]: (row["valor"], row["denominador"]) for row in rows}


def test_person_grain_is_not_cohort_rows_or_event_rows(
    snapshot: sqlite3.Connection,
) -> None:
    result = measures(snapshot)
    assert result["pessoas_snapshot"] == (3, None)
    assert result["participacoes_snapshot"] == (4, None)
    assert result["vinculos_bi_confirmados"] == (2, None)
    assert result["vinculos_bi_pendentes"] == (1, None)
    assert result["vinculos_bi_inconsistentes"] == (1, None)
    assert result["cobertura_vinculo_percentual"] == (50.0, 4)


def test_missing_baseline_keeps_identity_and_consented_activity(
    snapshot: sqlite3.Connection,
) -> None:
    projected = participants([], [{
        "pessoa_id": "SYN-P02",
        "turma_id": "SYN-T01",
        "status": "bi_link_pending",
    }])
    assert projected == [{
        "pessoa_id": "SYN-P02",
        "turma_id": "SYN-T01",
        "registro_id": None,
        "status_vinculo": "bi_link_pending",
    }]
    assert snapshot.execute(
        "SELECT COUNT(*) FROM journey WHERE pessoa_id = 'SYN-P02'"
    ).fetchone()[0] == 0
    assert measures(snapshot)["pessoas_com_atividade"] == (3, None)


def test_replay_deduplicates_before_utc_window_without_cohort_attribution(
    snapshot: sqlite3.Connection,
) -> None:
    result = measures(snapshot)
    assert result["eventos_conta_janela"] == (4, None)
    assert result["segundos_tela_janela"] == (45, None)
    assert snapshot.execute(
        "SELECT COUNT(*) FROM activity WHERE atribuicao_turma IS NOT NULL"
    ).fetchone()[0] == 0
    rows = daily_activity([
        dict(row) for row in snapshot.execute(
            "SELECT * FROM activity WHERE event_id = 'SYN-E01'"
        )
    ])
    assert len(rows) == 1
    assert rows[0]["data_utc"] == "2026-10-02"
    assert rows[0]["eventos_qtd"] == 1


def test_conflicting_replay_fails_instead_of_choosing_one_value(
    snapshot: sqlite3.Connection,
) -> None:
    snapshot.execute(
        "INSERT INTO activity SELECT event_id, pessoa_id, evento, alvo_tipo, "
        "alvo_id, ocorreu_em, 31, escopo, atribuicao_turma "
        "FROM activity WHERE event_id = 'SYN-E01' LIMIT 1"
    )
    with pytest.raises(ValueError, match="Conflicting activity ID"):
        measures(snapshot)


def test_window_start_is_inclusive_and_end_is_exclusive(
    snapshot: sqlite3.Connection,
) -> None:
    result = measures(snapshot, {
        "since": "2026-10-02T11:00:00Z",
        "until": "2026-10-02T12:00:00Z",
    })
    assert result["eventos_conta_janela"] == (1, None)
    assert result["segundos_tela_janela"] == (15, None)


@pytest.mark.parametrize("table", ["participants", "journey"])
def test_duplicate_dimension_fails_without_silent_deduplication(
    snapshot: sqlite3.Connection, table: str,
) -> None:
    statement = {
        "participants": "INSERT INTO participants SELECT * FROM participants",
        "journey": "INSERT INTO journey SELECT * FROM journey",
    }[table]
    with pytest.raises(sqlite3.IntegrityError):
        snapshot.execute(statement)


def test_two_editions_preserve_separate_study_lineage(
    snapshot: sqlite3.Connection,
) -> None:
    rows = snapshot.execute(
        "SELECT curso_versao_id, matricula_contextual_id, "
        "horas_estudo_validadas FROM journey ORDER BY curso_versao_id"
    ).fetchall()
    assert [tuple(row) for row in rows] == [
        ("SYN-V01", "SYN-M01", 1.0),
        ("SYN-V02", "SYN-M02", 2.0),
    ]
    assert measures(snapshot)["horas_estudo_snapshot"] == (3.0, None)
    with pytest.raises(sqlite3.IntegrityError):
        snapshot.execute(
            "UPDATE journey SET curso_versao_id = NULL "
            "WHERE curso_versao_id = 'SYN-V01'"
        )


def test_baseline_reference_cannot_be_transferred_to_another_person(
    snapshot: sqlite3.Connection,
) -> None:
    with pytest.raises(sqlite3.IntegrityError):
        snapshot.execute(
            "UPDATE journey SET pessoa_id = 'SYN-P02' "
            "WHERE registro_id = 'SYN-B01'"
        )


def test_null_outcomes_never_become_negative_or_implied_followup(
    snapshot: sqlite3.Connection,
) -> None:
    result = measures(snapshot)
    assert result["referencias_certificado_api"] == (1, None)
    assert result["certificado_desconhecido"] == (1, None)
    assert result["capacitados"] == (None, None)
    assert result["elegiveis_mentoria"] == (None, None)
    assert result["followup_30d_concluido"] == (None, None)
    with pytest.raises(sqlite3.IntegrityError):
        snapshot.execute(
            "UPDATE journey SET certificado_flag = 0 "
            "WHERE certificado_flag IS NULL"
        )


def test_revocation_snapshot_filters_people_without_reassigning_events(
    snapshot: sqlite3.Connection,
) -> None:
    snapshot.execute("DELETE FROM journey WHERE turma_id = 'SYN-T01'")
    snapshot.execute(
        "DELETE FROM participants WHERE pessoa_id = 'SYN-P01' "
        "AND turma_id = 'SYN-T01'"
    )
    assert measures(snapshot)["eventos_conta_janela"] == (4, None)
    snapshot.execute("DELETE FROM journey WHERE pessoa_id = 'SYN-P01'")
    snapshot.execute("DELETE FROM participants WHERE pessoa_id = 'SYN-P01'")
    result = measures(snapshot)
    assert result["pessoas_snapshot"] == (2, None)
    assert result["eventos_conta_janela"] == (2, None)
    assert result["segundos_tela_janela"] == (15, None)
    assert result["referencias_certificado_api"] == (0, None)
    assert result["followup_30d_concluido"] == (None, None)


def test_empty_population_has_unknown_percentage(
    snapshot: sqlite3.Connection,
) -> None:
    snapshot.execute("DELETE FROM journey")
    snapshot.execute("DELETE FROM participants")
    result = measures(snapshot)
    assert result["pessoas_snapshot"] == (0, None)
    assert result["cobertura_vinculo_percentual"] == (None, 0)
    assert result["eventos_conta_janela"] == (0, None)
    assert result["capacitados"] == (None, None)


def test_dictionary_covers_current_csv_and_api_item_fields() -> None:
    documented = set(re.findall(
        r"`([a-z_][a-z_0-9]*)`",
        (ROOT / "docs/data/JOURNEY_DATA_DICTIONARY.md").read_text(
            encoding="utf-8"
        ),
    ))
    csv_fields = set(JOURNEY_COLUMNS + ACTIVITY_COLUMNS + PARTICIPANT_COLUMNS)
    assert csv_fields <= documented
    tree = ast.parse(
        (ROOT / "api/app/journey_export.py").read_text(encoding="utf-8")
    )
    item_fields: set[str] = set()
    for node in ast.walk(tree):
        if not isinstance(node, ast.Dict):
            continue
        fields = {
            key.value for key in node.keys
            if isinstance(key, ast.Constant) and isinstance(key.value, str)
        }
        if "pessoa_id" in fields and (
            "registro_id" in fields or "event_id" in fields
        ):
            item_fields.update(fields)
    assert item_fields
    assert item_fields <= documented
