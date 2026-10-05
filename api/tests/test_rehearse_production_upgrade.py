from pathlib import Path
import subprocess
import sys

import pytest

from ops.rehearse_production_upgrade import assert_upgraded_schema, parse_alembic_head


def test_parser_accepts_current_canonical_head():
    output = subprocess.check_output(
        [sys.executable, "-m", "alembic", "heads"],
        cwd=Path(__file__).parents[1],
        text=True,
    )
    head = parse_alembic_head(output)
    assert f"{head} (head)" in output.splitlines()


def test_parser_accepts_future_head_without_literal_change():
    assert parse_alembic_head("20991231_9999 (head)\n") == "20991231_9999"


def test_parser_fails_closed_on_multiple_heads():
    with pytest.raises(RuntimeError):
        parse_alembic_head("a_head (head)\nb_head (head)\n")


def test_schema_mismatch_is_fail_closed_contract():
    expected = parse_alembic_head("candidate_42 (head)\n")
    with pytest.raises(RuntimeError, match="diverges"):
        assert_upgraded_schema(expected, "candidate_41")
