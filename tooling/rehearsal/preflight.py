"""READ-ONLY preflight for the 20260920_0005 -> Alembic HEAD rehearsal.

Parses versioned migration files statically (never imports or executes them,
never connects to a database) and emits a deterministic, sanitized manifest.
"""
from __future__ import annotations

import argparse
import ast
import json
from pathlib import Path
import sys

SOURCE_REVISION = "20260920_0005"
DEFAULT_MIGRATIONS = Path(__file__).resolve().parents[2] / "api" / "migrations" / "versions"
ALLOWED_INPUT_KEYS = ("revision", "alembic_version")


class PreflightError(Exception):
    pass


def _literal_assignments(path: Path) -> dict:
    values = {}
    for node in ast.parse(path.read_text(encoding="utf-8")).body:
        if isinstance(node, ast.Assign) and len(node.targets) == 1 \
                and isinstance(node.targets[0], ast.Name) \
                and node.targets[0].id in ("revision", "down_revision"):
            try:
                values[node.targets[0].id] = ast.literal_eval(node.value)
            except ValueError:
                raise PreflightError(f"non-literal {node.targets[0].id} in {path.name}")
    return values


def load_graph(migrations_dir: Path) -> dict:
    """Return {revision: tuple(down_revisions)} from versioned migrations."""
    graph = {}
    for path in sorted(Path(migrations_dir).glob("*.py")):
        values = _literal_assignments(path)
        if "revision" not in values:
            continue
        rev, down = values["revision"], values.get("down_revision")
        if not isinstance(rev, str) or not rev:
            raise PreflightError(f"invalid revision in {path.name}")
        if down is None:
            down = ()
        elif isinstance(down, str):
            down = (down,)
        else:
            down = tuple(down)
        if rev in graph:
            raise PreflightError(f"duplicate revision {rev}")
        graph[rev] = down
    if not graph:
        raise PreflightError("no migrations found")
    return graph


def resolve_head(graph: dict) -> str:
    referenced = {d for downs in graph.values() for d in downs}
    missing = sorted(referenced - set(graph))
    if missing:
        raise PreflightError(f"down_revision references unknown revision(s): {missing}")
    heads = sorted(set(graph) - referenced)
    if not heads:
        raise PreflightError("zero heads")
    if len(heads) > 1:
        raise PreflightError(f"multiple heads: {heads}")
    return heads[0]


def upgrade_path(graph: dict, source: str, head: str) -> list:
    if source not in graph:
        raise PreflightError(f"source revision {source} not in migrations")
    children = {}
    for rev, downs in graph.items():
        for d in downs:
            children.setdefault(d, []).append(rev)
    path, current = [], source
    while current != head:
        nxt = sorted(children.get(current, []))
        if len(nxt) != 1:
            raise PreflightError(f"non-linear or broken path at {current}")
        current = nxt[0]
        path.append(current)
    return path


def read_input_revision(input_path: Path) -> str:
    try:
        data = json.loads(Path(input_path).read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        raise PreflightError(f"unreadable input: {type(exc).__name__}")
    if not isinstance(data, dict):
        raise PreflightError("input must be a JSON object")
    declared = next((data[k] for k in ALLOWED_INPUT_KEYS if k in data), None)
    if declared != SOURCE_REVISION:
        raise PreflightError(
            f"input revision must be {SOURCE_REVISION}, got {declared!r}"
            if isinstance(declared, (str, type(None))) else "invalid input revision")
    return declared


def build_manifest(input_path: Path, migrations_dir: Path = DEFAULT_MIGRATIONS) -> dict:
    declared = read_input_revision(input_path)
    graph = load_graph(migrations_dir)
    head = resolve_head(graph)
    steps = upgrade_path(graph, declared, head)
    return {
        "task_id": "REHEARSAL_PREFLIGHT",
        "source_revision": declared,
        "target_head": head,
        "pending_migrations": steps,
        "pending_count": len(steps),
        "migrations_executed": False,
        "database_connected": False,
        "real_rehearsal_run": False,
        "merge_allowed": False,
    }


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path,
                        help="JSON file declaring the snapshot revision")
    parser.add_argument("--migrations-dir", type=Path, default=DEFAULT_MIGRATIONS)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args(argv)
    try:
        manifest = build_manifest(args.input, args.migrations_dir)
    except PreflightError as exc:
        print(f"PREFLIGHT_FAILED: {exc}", file=sys.stderr)
        return 1
    text = json.dumps(manifest, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.write_text(text, encoding="utf-8")
    else:
        sys.stdout.write(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
