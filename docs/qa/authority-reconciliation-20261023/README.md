# G02 — reuse #250, no new authority design

IMPLEMENTED, documentation checked locally. Base16e30de7bf7ace60f34ecc5458e4a0a728240984.
Source #250 exact51d485dcb0de3dc2a061579a0e2bd3488f421747 remains an open draft;
this change reuses its seven program documents in the current composition,
without merging/closing the PR or replacing newer state/domain/decisions.

Observed conflict: current DOMAIN_CONTRACT already assigns EAD account,
enrollment, lessons/quizzes/progress to LearnPress; program README and portal
rules still broadly prohibited these facts. Existing approved #249 ADR resolves
this boundary. Seven program files are byte-identical to the source above:
README, TARGET_ARCHITECTURE, PORTAL_AND_CONTENT, INTEROPERABILITY, ADR,
LEARNPRESS_TDS_DELIVERY_RUNBOOK and LEARNPRESS_TDS_ACCEPTANCE_MATRIX. Added
canonical pointers only to AGENTS/ARCHITECTURE. Newer domain/state preserved.

Checks: seven byte comparisons PASS; all11 relative Markdown links in copied
files resolve; diff whitespace check PASS. Semantic review preserves FastAPI
institutional identity/class/attendance/official certificate authority, LearnPress
EAD authority, explicit non-equivalence and no inferred academic credit. SSO,
identity linking and hypothetical broker paths remain TARGET. A historical
statement that the ADR itself did not authorize implementation does not cancel
the user's current authorization for development/testing; production/merge/
publication gates stay separate. No routine approval requested.

No runtime/dependency/version/signature change, no new tests or APK warranted
for documentation alone. The Android artifact and full940-test CI belong to
16e30de; later documentation does not re-label those receipts as a new source
execution. Native/player/user journey limits remain independently recorded.
Rollback only this documentation reconciliation; no data migration.
