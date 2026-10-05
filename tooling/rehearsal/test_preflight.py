import json
from pathlib import Path
import sys

import pytest

sys.path.insert(0, str(Path(__file__).parent))
import preflight as pf  # noqa: E402


def mig(d, rev, down):
    (d / f"{rev}.py").write_text(f'revision = "{rev}"\ndown_revision = {down!r}\n'
                                 'raise RuntimeError("must never execute")\n')


def inp(tmp_path, rev=pf.SOURCE_REVISION):
    p = tmp_path / "in.json"
    p.write_text(json.dumps({"revision": rev, "password": "secret"}))
    return p


@pytest.fixture
def chain(tmp_path):
    d = tmp_path / "v"
    d.mkdir()
    mig(d, "20260920_0004", None)
    mig(d, "20260920_0005", "20260920_0004")
    mig(d, "20260920_0006", "20260920_0005")
    mig(d, "20261003_0024", "20260920_0006")
    return d


def test_valid_0005_resolves_dynamic_head(tmp_path, chain):
    m = pf.build_manifest(inp(tmp_path), chain)
    assert m["target_head"] == "20261003_0024"
    assert m["pending_migrations"] == ["20260920_0006", "20261003_0024"]
    assert m["migrations_executed"] is False and m["real_rehearsal_run"] is False
    assert "secret" not in json.dumps(m)


def test_new_head_is_reported(tmp_path, chain):
    mig(chain, "20261010_0027", "20261003_0024")
    assert pf.build_manifest(inp(tmp_path), chain)["target_head"] == "20261010_0027"


def test_invalid_revision(tmp_path, chain):
    with pytest.raises(pf.PreflightError):
        pf.build_manifest(inp(tmp_path, "20260920_0004"), chain)


def test_multiple_heads(tmp_path, chain):
    mig(chain, "20261004_0025", "20260920_0006")
    with pytest.raises(pf.PreflightError, match="multiple heads"):
        pf.build_manifest(inp(tmp_path), chain)


def test_zero_heads(tmp_path):
    d = tmp_path / "v"
    d.mkdir()
    mig(d, "a", "b")
    mig(d, "b", "a")
    with pytest.raises(pf.PreflightError, match="zero heads"):
        pf.build_manifest(inp(tmp_path), d)


def test_deterministic_output(tmp_path, chain, capsys):
    args = ["--input", str(inp(tmp_path)), "--migrations-dir", str(chain)]
    assert pf.main(args) == 0
    first = capsys.readouterr().out
    assert pf.main(args) == 0
    assert capsys.readouterr().out == first


def test_real_repo_has_single_head(tmp_path):
    m = pf.build_manifest(inp(tmp_path))
    assert m["target_head"] == pf.resolve_head(pf.load_graph(pf.DEFAULT_MIGRATIONS))
