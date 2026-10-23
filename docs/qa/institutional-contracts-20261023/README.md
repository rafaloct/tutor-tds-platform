# Institutional lifecycle / attendance / certification — 23 October 2026

**TESTED-LOCAL**, source `f345cc805d04c0e9ca1a1778be9e00f7e52e9002`, unchanged
runtime `cf997d33eee5335469e0b45e906b83e1dc9304ab`. Issue #138 reservation
comment6371269522, isolated `agent/issue-138-institutional-qa-20261023` worktree.
No application, API, migration, dependency or deployment changes in this slice.

Decision32 supersedes the older issue's hard30/operator restriction: an operator
may prepare/activate/close within their program;30 is advisory; coordinator-only
team changes after activation, contextual authority and open-session close guard
remain. No older test expectation was restored.

| Evidence | Result | What it establishes |
|---|---|---|
| `sqlite-contracts.xml` | PASS50 | Class lifecycle, operator, presence, official attendance API contracts; identity override |
| `lifecycle-postgres.xml` | PASS4 | Real16.15 persistence, prepare receipt/replay, advisory capacity, scoped assignment, open-session guard,0027→0028 migration/downgrade guard |
| `attendance-postgres16.xml` | PASS13 | Real16.15 attendance/certificate candidate and policy, concurrency, migration lineage; identity override |
| `migration-postgres1711.xml` | PASS1 | Exact historic17.11 empty upgrade/downgrade/re-upgrade gate to0030 |
| `native-http.json` / `.log` | PASS3 scenarios | Real Uvicorn sockets, password verification, JWT validation, contextual RBAC and PostgreSQL16.15; no server identity override |

Native HTTP reuses the existing lifecycle seeds/assertions, removes the fixture
auth override before serving, and logs in each of8 seeded identities in each
scenario (24 logins). It performs35 business operations and9 additional
unauthenticated/forged-X-User/invalid-token negatives. The client adapter translates
the old assertion helpers' role markers into real Bearer tokens; **X-User is
never an accepted identity on the native server**. Each scenario has a new owned
database, dropped in `finally`; each listener is loopback on an ephemeral port.

This is not a complete educational journey. Seeds,30-seat boundary data and
session-open/closed transitions are set directly in fixtures; session UI and
check-in end-to-end are not established by these three scenarios. There is no
Android institutional acceptance, deployed staging, SSO/LP linkage, refresh/
revocation/recovery lifecycle, creator/finance workspace, official certificate
issuance or all-role downstream UI proof here. The candidate tests execute real
Worker JS through Node but substitute HTTP/KV; they do not call Cloudflare or
issue production certificates. G07/G08 remain open.

## Reproduction

Use the checked-in `api/uv.lock` (SHA in `receipt.json`), Python3.13, and
`uv sync --locked --extra test --python /usr/bin/python3.13` from `api/`.
Host Python3.13.5 and Node24.19.0 were used; the first accepted lifecycle lane
used the pinned project Python base3.13.15 in a private container namespace.
Image digests and all JUnit counts are in `receipt.json`.

From `api/`:

```sh
.venv/bin/python -m pytest tests/test_class_lifecycle.py tests/test_operator_operations.py tests/test_presence.py tests/test_official_attendance.py --junitxml=../docs/qa/institutional-contracts-20261023/sqlite-contracts.xml
```

Use **new disposable databases only**. The existing fixture guards intentionally
require exact loopback ports/roles and reject shared or remote targets:

```sh
# Fresh isolated PostgreSQL16.15, qa_class_lifecycle role on loopback15438:
TDS_CLASS_LIFECYCLE_PG_ADMIN_URL=postgresql://qa_class_lifecycle@127.0.0.1:15438/postgres .venv/bin/python -m pytest tests/test_class_lifecycle_postgres.py --junitxml=../docs/qa/institutional-contracts-20261023/lifecycle-postgres.xml
# Fresh isolated PostgreSQL16.15, qa_attendance role on loopback15406; Node on PATH:
TDS_ATTENDANCE_PG_ADMIN_URL=postgresql://qa_attendance@127.0.0.1:15406/postgres .venv/bin/python -m pytest tests/test_attendance_postgres.py -k 'not test_postgres_empty_upgrade_downgrade_and_reupgrade' --junitxml=../docs/qa/institutional-contracts-20261023/attendance-postgres16.xml
.venv/bin/python ../docs/qa/institutional-contracts-20261023/verify_native_http.py
# Stop/remove16 first; separate disposable17.11 on the same guarded endpoint:
TDS_ATTENDANCE_PG_ADMIN_URL=postgresql://qa_attendance@127.0.0.1:15406/postgres .venv/bin/python -m pytest tests/test_attendance_postgres.py -k test_postgres_empty_upgrade_downgrade_and_reupgrade --junitxml=../docs/qa/institutional-contracts-20261023/migration-postgres1711.xml
```

The successful host lanes use Docker bridge publication **only127.0.0.1**, tmpfs
database storage,512MiB limit, synthetic trust-auth role, no persistent volume or
external exposure. Example disposable server (stop/remove it after testing):

```sh
docker run --detach --rm --name tds-inst-local-proof --memory 512m --tmpfs /var/lib/postgresql/data:rw,size=512m --publish 127.0.0.1:15406:5432 --env POSTGRES_USER=qa_attendance --env POSTGRES_HOST_AUTH_METHOD=trust postgres@sha256:f4610795587492cd4fb887c2dc3de301b813278bb6f616992061141b5f15ac36
```

To reproduce lifecycle locally use its required role/15438. The original
accepted lifecycle transport shared a private database container's namespace;
the server itself listened on15438. This avoids relying on Docker publication
from an `--internal` network. No fixture guard was weakened.

## Retained failures and cleanup

`lifecycle-postgres-port-boundary.xml`:4 setup ERRORs, unreachable published port
on an internal Docker network. Corrected namespace transport:4 PASS.
`attendance-postgres16-missing-node.xml`:11 PASS/3 FAIL; one deliberate17.11
version assertion and two Worker bridge503s caused by missing Node in the
Python-only test runner. Corrected16 business lane13 PASS; exact17.11 lane1 PASS.
See `BOUNDARY_DIAGNOSTICS.md`. These are environment-boundary failures, not
confirmed new product defects. No production dependency was added to compensate.

`cleanup.txt` records zero owned fixture databases before final server removal,
the stopped final owned container and removed owned internal network. Each
earlier cluster's fixture databases were checked empty and its server removed
before the next lane. No owned containers remain. Other worktrees, physical
devices, public1.4.1+14, production, signing and publication remain untouched;
`MERGE_ALLOWED=NO`. The next product acceptance gap is the same institutional
state transitions through Flutter against isolated institutional staging, with
authoritative student/teacher/monitor readback; passing this backend slice
does not waive that requirement.
