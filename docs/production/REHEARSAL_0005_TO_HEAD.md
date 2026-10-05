# Rehearsal preflight 0005 → HEAD (read-only)

**Status:** preparation only. `REAL_REHEARSAL_RUN=NO`, `MERGE_ALLOWED=NO`.

- **OBSERVED:** `tooling/rehearsal/preflight.py` parses `api/migrations/versions/*.py`
  statically (AST; no import, no execution, no database connection).
- **TARGET:** a human-gated rehearsal restoring a snapshot at `20260920_0005`
  and upgrading to the dynamic Alembic HEAD.

## Usage

```
python tooling/rehearsal/preflight.py --input snapshot.json [--output manifest.json]
```

`snapshot.json` must declare `{"revision": "20260920_0005"}`. Any other value fails closed.
HEAD is resolved from the migration graph; zero or multiple heads, unknown
`down_revision`, or a non-linear path from 0005 fail closed (exit 1). Nothing is
hardcoded: a later migration added by another PR becomes the reported HEAD.

## Manifest

Deterministic (sorted keys) JSON: `source_revision`, `target_head`,
`pending_migrations`, `pending_count`, and flags `migrations_executed=false`,
`database_connected=false`, `real_rehearsal_run=false`, `merge_allowed=false`.
Input contents other than the revision are never copied (no secrets).

## Tests

`python -m pytest tooling/rehearsal -q`

## Human gate

Executing the real rehearsal (via `api/ops/rehearse_production_upgrade.py` on isolated
infrastructure) requires explicit human approval; not performed here.
