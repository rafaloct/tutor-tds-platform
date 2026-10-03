# Issue 5 — canonical integration and PostgreSQL candidate proof

Base of candidate: `6ae0a664674b24f12e5a8c0a95e6bbb91408b135`.
Integrated canonical commit: `aa6fb88050aa864726e197187487819de303ac65`
(sequential #54/#51/#55). Normal merge, no rebase or force-push. Only real merge
conflicts were CURRENT_STATE and DECISIONS: both historical records preserved,
canonical decisions 26/27 retained, candidate implementation recorded as 28.
Migrations 0021/0022 are unchanged. main.py automatically added the public router
without replacing the certificate routers. There is no new academic rule.

## Environment and integrity limits

Python 3.13.9, isolated api/.venv from `uv sync --locked --extra test`; no global
dependency upgrades. PostgreSQL 17.11 Windows binaries from EDB, linked as the
binary distributor by <https://www.postgresql.org/download/windows/>:
<https://get.enterprisedb.com/postgresql/postgresql-17.11-1-windows-x64-binaries.zip>.
Observed archive SHA256:
`6eabdf00d2893713b75db4336a23c3fdf505f056e217ec6e2e95d901750cfea3`.
This is a locally computed provenance hash, **not a verified vendor checksum**;
no vendor-signed checksum was located and postgres.exe reports NotSigned.
The ZIP was obtained over HTTPS from the official distributor. No installer,
Windows service or Docker daemon was changed.

The cluster is new, outside Git, only 127.0.0.1:15439, synthetic role
qa_certificate, local trust authentication for this short-lived QA only.
Never apply these credentials/authentication settings to an existing service.
Tests reject other host/port/role/database/URL options, create a unique
qa_certificate_<uuid> database per case and drop only that generated database
in finally. No real SMTP, KV, Worker/provider or user data is accessed.

## Reproduction

Extract the official archive into a dedicated QA directory and record its hash.
Use a new data directory; do not reuse a PostgreSQL installation. From api:

```powershell
# pgBin and pgData must point exclusively to the newly extracted QA runtime
# and a new QA data directory. Check that 15439 is not already listening first.
& "$pgBin/initdb.exe" -D $pgData -U qa_certificate --auth=trust --encoding=UTF8 --locale=C
& "$pgBin/pg_ctl.exe" -D $pgData -l "$pgData/server.log" -o '-h 127.0.0.1 -p 15439' -w start
try {
  $env:TDS_CERTIFICATE_PG_ADMIN_URL = 'postgresql://qa_certificate@127.0.0.1:15439/postgres'
  # Node must be available for the synthetic Worker bridge.
  ./.venv/Scripts/python.exe -m pytest tests/test_certificate_postgres_integration.py
} finally {
  Remove-Item Env:TDS_CERTIFICATE_PG_ADMIN_URL -ErrorAction SilentlyContinue
  & "$pgBin/pg_ctl.exe" -D $pgData -m fast -w stop
}
```

The fixture defaults to SQLite everywhere else. PostgreSQL tests skip unless
the explicit disposable URL is supplied. The new fixture only substitutes
database URLs and omits SQLite PRAGMA for PostgreSQL; production code is unchanged.

## Bounded evidence

106 focused API tests passed on the merged candidate: certificate requests,
reference context, policy/emission, approval/default gates, certificates, public
API and journey contract. This is integration regression evidence, not a new BI
workstream. Warnings are existing FastAPI/Starlette deprecations.

PostgreSQL-specific cases cover:
- empty schema through 0022, empty downgrade to 0020 and re-upgrade;
- populated 0020 upgrade preserving request lineage and baseline count;
- policy/emission downgrade guards preserving evidence transactionally;
- actual request row locking, second connection SQLSTATE 55P03 while held,
  and successful SELECT FOR UPDATE NOWAIT after release;
- concurrent candidate calls yielding one synthetic Worker write/reference;
- institutional policy separation of GENERATED, CAPACITADO and candidate VALID.

All five PostgreSQL cases passed (four together, then the added lifecycle case).
One SQLite concurrency regression passed after the fixture URL refactor,
confirming the default fixture still resolves. The disposable database count
was zero after teardown; pg_ctl stopped the owned cluster and port 15439 closed.

The first lock harness control tried to increment revision without a domain
transition. The existing immutability trigger correctly rejected it twice.
Observed: immutable request snapshot/invalid transition. Responsible boundary:
new test only. Structural fix: use competing SELECT FOR UPDATE statements,
not a write that violates the domain. No trigger/runtime rule was weakened.

Candidate VALID remains synthetic; institutional activation stays blocked.
No production, migration of a shared database, signed PDF, real mail/provider,
AAB, physical app gate or deployment is proven by these tests.
