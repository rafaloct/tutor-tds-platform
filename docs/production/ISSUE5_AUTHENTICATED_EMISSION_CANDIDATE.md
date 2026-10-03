# Issue #5 — authenticated local emission candidate, 2026-10-03

## 2026-10-03 — contrato institucional autorizado, candidato v2

Decisões diretas do usuário registradas na Issue #5, comentário 5965837795,
substituem o bloqueio por indefinição de negócio nesta fatia. O Plano de Trabalho
citado não foi anexado nem lido. Cada curso possui 80h formais; cronômetro não é
prova desse requisito. Duas unidades de 80h totalizam 160h, mas Classroom atual
vincula um curso/edição: este candidato projeta por curso/matrícula contextual,
sem inventar agregação de dois cursos ou atribuir créditos históricos ambíguos.

Política aditiva e congelada por oferta configura encontros (zero bloqueia),
checkpoints obrigatórios e responsável operacional autorizado. Apenas presença
confirmed_present conta: 10 × presentes >= 7 × encontros configurados.
Ausência justificada e exceção accepted não criam presença; exceções mantêm
pending_human_validation, justificativa e responsável até decisão humana.

EvidenceItem/ReviewDecision servem como EvidenceRecord contextual de tipo,
origem, status, participante, edição e hash da política. Baseline aceita origens
Google Forms, Jotform, app ou ficha digitalizada sem integração fictícia;
StudentBaseline contextual existente também é aceito. Fichas assinadas pelo
instrutor precisam cobrir todos os encontros configurados do participante.
Referências documentais privadas/hash são atestação humana auditável, não leitura
externa nem assinatura criptográfica de PDF.

Todos os checkpoints configurados são avaliados no backend. O adaptador inicial
suporta assessment editorial imutável, com todas as respostas determinísticas;
não impõe nota mínima nova. Tipos ainda sem representação determinística falham
explicitamente. Quiz não é requisito universal: o discriminador admite novos
adaptadores futuros sem alterar retroativamente a política. IDs configurados
são requisitos distintos; reutilizar uma fonte exige conclusão explícita de
cada ID, sem aproveitar evento agregado lesson_completed ou tentativa antiga.

Pedido rejected bloqueia mutações e geração; resubmit existente volta a pending.
Revogação contextual ou do responsável operacional impede emissão.

O último checkpoint gera automaticamente pelo API→adaptador→Worker candidato,
antes de baseline, frequência ou assinaturas. O comando v2 fixa carga formal,
hash da política e prova dos checkpoints, sem depender da baseline posterior.
Preservados reserva durável, autenticação, idempotência e reconciliação somente
por lookup após timeout. Crash após reserva antes do primeiro envio conserva
estado indeterminado; ausência no KV não autoriza reenviar nem reset automático.

CAPACITADO = baseline registrada AND frequência >=70% AND trilha obrigatória
concluída AND certificado de trilha gerado. CERTIFICADO_VALIDO = CAPACITADO AND
fichas regularizadas/assinadas pelo instrutor AND assinatura da coordenação.
Estados: GENERATED → PENDING_INSTRUCTOR_VALIDATION →
PENDING_COORDINATOR_SIGNATURE → VALID. VALID aqui é projeção sintética do contrato;
institutional_release permanece blocked. Geração registra responsável operacional
configurado (rótulo da responsável Eliza separado do papel técnico, sem mapear identidade real) e evidência de fluxo para
tdsdados@gmail.com em pending_dispatch, sent=false, recibo=null. Nenhum SMTP/VPS
foi chamado e nenhum envio foi inventado. Comportamento legado é preservado.

Ativação exige development e opt-in; transporte HTTP isolado em loopback sem
proxy/redirecionamento, Worker com namespace/binding candidato separados. O novo
/emit permanece bloqueado por gate deliberado de homologação/ativação real, não
por falta de decisão sobre horas/Jotform. Rotas oficiais legadas seguem contrato
anterior; candidato nunca aparece em carteira/export oficial. Migração0022 apenas
adiciona política JSON/lifecycle nullable; recusa downgrade com dados novos.
SQLite descartável não homologa PostgreSQL, deploy, provedor instalado ou PDF.

## Histórico da primeira fatia v1

> Parágrafos abaixo preservam a decisão/testes anteriores à retomada. Exigência
> de aprovação e baseline pré-geração pertence ao adaptador técnico v1, não ao
> contrato institucional v2. A antiga indefinição de carga/Jotform foi superada
> pela decisão direta do usuário acima; gate atual é homologação/ativação real.

Status: implemented synthetic protocol candidate, **final issuance blocked**.
This is a local API/Worker producer-consumer test, not installed end-to-end,
institutional signature, staging acceptance, public verification or a certificate
for a real person. No existing KV, service, deployment or release gate changed.

## Directed decision before implementation

Base `ab409f168175e764ba4995a9f06c596084b940c2`, branch
`agent/issue-5-authenticated-emission-20261003`; implementer is sole writer.
Coordinator owns publication/CI; independent reviewer owns acceptance review.
Existing request, human approval, contextual enrollment, baseline, reference and
Worker domains are reused. PR #14 protection, CW-1/PR #23 and PR #38 were not
reimplemented. PR #24 was still open/draft; its proposed program documents do not
supersede approved decisions. Issue #5 and all four comments were read directly.

The smallest independent slice is a development-only authenticated synthetic
command, persistent reservation, Worker confirmation and reference recovery.
Final institutional issuance is a separate fail-closed route. No fixture,
transport adapter, payload boolean, 60-second test offering or runtime flag can
authorize the missing institutional evidence. This deliberately leaves an
essential Issue #5 acceptance criterion blocked.
The blocking statement applies to the new `/emit` route only. Historical Worker
issuance and the legacy `POST /certificates/references` compatibility route remain
unchanged apart from rejecting candidate replay; this slice does not close every
legacy bypass or declare a global issuance freeze implemented.

## Current authority and institutional gate

FastAPI/SQL academic state remains the authorization authority. Worker/KV is only
a candidate document consumer, not enrollment, baseline or pedagogy authority.
The candidate's HMAC protocol is a proposed technical contract, not approval of
the final issuer, signing policy, public origin or production key custody.

Approved comment
<https://github.com/rafaloct/tutor-tds-platform/issues/5#issuecomment-5965299815>
requires 80h for the formation, desired 40h physical + 40h digital with validated
exceptions, baseline before final issuance and combined evidence. It does not
assign 80h to every course. The existing `StudentBaseline` can be checked; current
course-specific hours/completion remain an independent legacy technical test.
Validated representations of total formation, proportions/exceptions, mandatory
app usage, wallet/print and the still-unbuilt Jotform assessment do not exist in
this slice. `POST /certificate-requests/{id}/emit` therefore always refuses final
issuance after checking owner/current context/baseline. It never calls Worker.

Exact next institutional decisions: approve representations and provenance for
each combined evidence requirement and its formation scope; approve exception
review rules; choose final issuer, signed protocol and verification/key custody.
Then implement these checks before considering any final-issuance activation.
Local protocol/security work and synthetic review remain unblocked.

## Candidate behavior and boundaries

`POST /certificate-requests/{id}/emission-candidate` requires the authenticated
owner, human approved request, current eligibility, exact institution/program,
class and published edition, contextual baseline and the existing canonical
`resolve_student_context`. It validates active `CohortMembership`, persisted
context/membership/course-version IDs and legacy enrollment lineage. Command
contains canonical enrollment ID, legacy enrollment ID, membership ID, request,
person, institution, program, course, version, class and baseline revision.

Activation requires `CERTIFICATE_CANDIDATE_ENABLED=true`, explicit development
environment, a candidate-only key and a loopback HTTP URL. Both API and Worker
reject staging/production even with the flag enabled. API transport disables
environment proxies and redirects. Worker uses a separate unconfigured
`CERTIFICATE_CANDIDATES` binding; no deployment binding was added and legacy
`CERTIFICATES` access remains untouched. No real secret was obtained or used.

Worker internal route `/internal/certificate-candidates/{id}` accepts signed GET
lookup or signed POST command. HMAC binds method/path/time/body digest; request
freshness is bounded to 60 seconds. Responses (including absence/errors for an
authenticated request) bind method/path/request time/status/body. Producer
verifies signature, exact command, SHA-256 and fixed synthetic URL. Stored
candidate envelope is separately authenticated. Read/storage failures and
corrupt records never become an absent result. The URL uses `synthetic.invalid`
and provides **no public certificate or verification page**.

Reservation commits before any network call. Only the reservation winner can
send one POST after authenticated absence. Repeated calls and
`POST /certificate-requests/{id}/reconcile-candidate` perform lookup only.
Timeout/response loss persists `indeterminate`; a later signed matching receipt
confirms the same deterministic UUID/reference. An eventually invisible lookup
does not authorize another POST. A crash after reservation but before first POST
also remains indeterminate, sacrificing availability conservatively. No reset
or resend command was added; resolving absence requires evidence and a future
reviewed recovery decision, never automatic reservation deletion.

Context is revalidated before reservation and after confirmation; relevant SQL
rows are selected for update on PostgreSQL. Unique reservation and request-linked
output constraints anchor one logical emission in SQL. KV eventual consistency
does not guarantee atomic uniqueness or exactly-once transport. Uncoordinated
producers, installed Worker behavior and PostgreSQL concurrency are unverified.

Candidate reference `is_candidate=true` remains outside official certificate
listing, official reference replay and journey export. It is returned only by
the owner-authorized candidate command. Approval remains approved; no issued
request status or offline issuance was invented.
The reference date records local candidate confirmation time, not an authenticated
institutional issuance date. Existing candidate reference fields must match the
approved snapshot/context and authenticated receipt before any replay returns it.

## Additive persistence, privacy and recovery

Migration `20261003_0021` adds a transport ledger (not a duplicate certificate)
keyed by the existing request. It is necessary to distinguish a fresh command
from response loss/process restart; deterministic IDs alone cannot tell whether
an absent KV read means no prior issuance. Command/receipt/state persist there.
Existing `certificates` gains nullable unique `request_id` for edition/context
lineage through the existing request, plus `is_candidate=false` for legacy data.
There is no central-domain backfill and no modification of request/history
triggers. Existing owner erasure explicitly removes ledger data even where SQLite
FK enforcement is off. Request FK deletion sets reference linkage null, consistent
with legacy reference retention; normal owner erasure removes references first.

Empty-history rollback is tested. Downgrade refuses a nonempty ledger rather than
discarding reconciliation history. Forward recovery is leave migration/data in
place, disable the candidate flag, preserve SQL command/receipt and investigate
through authenticated read-only reconciliation. No migration ran on a real DB.
Remote candidate retention/erasure has no deployed implementation: the simulator
lives only for a test. Real external storage deletion is a future activation gate.

## Reproducible verification

Python 3.13.9, isolated venv, uv 0.12.18, `uv sync --locked --extra test
--no-install-project --no-python-downloads`; Node 24.13.1. No global install or
SDK update. `test_certificate_emission_candidate.py` uses actual FastAPI commands,
transport/signature validation and actual Worker `handleRequest` in Node. Only
HTTP exchange and external KV are replaced by explicit simulators. SQLite DBs
are disposable; migrations run from zero in fixtures, plus populated 0020 upgrade,
guard/data preservation, unique reference lineage and rollback checks.

Cases include exact contextual lineage, approval versus emission, baseline/
membership/edition failures, other person, signed divergent receipt, bad request/
receipt signature, corrupted/read-failed KV, timeout after write, eventual absent
reads, pre-send crash reservation, concurrent calls, revocation after processing,
candidate exclusion, owner erasure and legacy metadata default preservation.
Node is mandatory; tests do not skip the consumer when unavailable. API CI also
runs Worker regressions. Final counts, commit and independent review/CI status
belong in the PR/Issue checkpoint for the exact SHA.

Observed initial collection failure: system Python lacked Alembic/pwdlib; changed
to the isolated lock-based venv. First new test expected edition mismatch 409 but
the canonical resolver correctly rejects it at authorization with 403; expectation
now matches that boundary without relaxing rejection. A temporary test-placement
error mixed recovery-after-write into the crash-before-send test; those scenarios
were separated again, preserving both assertions. No production claim follows
from these tests. PostgreSQL migration/concurrency, real transport/provider,
institutional evidence, physical wallet/offline and release acceptance remain gates.

Final local run: **78/78 focal API tests PASS**, exit0 in78.75s (31 new candidate
cases plus existing requests/references/approval/auth/journey coverage); **14/14
Worker regressions PASS**, exit0. Compileall and staged diff check exited0. Two
known dependency deprecation warnings remain. No full local suite was claimed.
Sanitized evidence: `evidence/issue5-emission-candidate-2026-10-03.json`.
