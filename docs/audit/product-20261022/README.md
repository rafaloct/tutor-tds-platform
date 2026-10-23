# Tutor TDS: product recovery and distribution audit, 22 October 2026

## Finding and scope

**OBSERVED: no single verified distribution candidate covers the intended product.**
The strongest common problem is disconnected work and evidence tied to different
SHAs, authorities and environments. More replacement services would compound it.
Preserve the Flutter/FastAPI/WordPress/LearnPress/Worker stack. Use existing
role, enrollment, edition, receipt and certificate models.

This is a reproducible **first audit increment**, not acceptance of the whole
product. The product source base examined is PR #334 `a0db10254642223dad192326f88d676aaba09553`.
The continuation tests the unchanged #337 plugin at `6e4aab96` in a real
disposable WordPress/LearnPress/MariaDB runtime; its receipt covers44 assertions.
The original cloud worktree remains at `b6f3f0f`, clean and untouched. A separate
writer worktree is `/workspace/tds-product-audit`, branch
`agent/product-audit-20261022`. Exact remote heads, selected CI and the bounded
issue inventory are in [state-recovery.json](state-recovery.json).

Reconstruction uses `docs/product/PUBLIC_ENTRY_AND_ENROLLMENT_CONTRACT.md`,
`docs/{DOMAIN_CONTRACT,DECISIONS,ARCHITECTURE}.md`, the program roadmap/flows,
production contracts, source, tests, retained receipts and current GitHub
conversations. PR #250's authority ADR and acceptance matrix were fetched at
`51d485dcb0de3dc2a061579a0e2bd3488f421747`; they are an existing consolidation
proposal to reuse, not a reason to write a second ADR. A separate original grant
proposal/complete original requirements attachment was not located. Its
unexamined promises cannot be claimed covered.

Current GitHub Discussions are not exposed by the available connector; selected
issue/PR conversations were inspected instead. Search was bounded to the latest
60 open PRs and 100 open issues, not the entire repository history. An open issue
is a discovery pointer, not proof its defect remains in the selected code.

## Recovered product vision and accepted constraints

The intended audience includes public visitors, spontaneous self-paced learners,
institutional participants, instructors/monitors, creators, coordinators,
program operators, finance and administrators. The product addresses access to
practical education, weak connectivity, continuity of participation and reliable
institutional records. It is more than a media catalog or an identity broker.

**DECISION:** public existing cartilhas and project-owned media serve a free,
non-monetized educational purpose. The owner approved the existing corpus as one
batch (Issue #336, comment 6352212752); no 48 repeated rights questions. Explicit
third-party restrictions remain asset-specific exceptions. Approval does not
supply missing byte hashes, source associations or a deployment acceptance.

**DECISION:** public discovery/content, interest, EAD enrollment, institutional
enrollment, attendance, completion and certification are distinct states. Public
self-paced courses do not require a fabricated cohort. Institutional education
uses a real program/cohort/membership/enrollment and fixed CourseVersion.

**DECISION:** LearnPress owns EAD users/enrollment/lessons/quizzes/EAD progress;
FastAPI owns institutional users/roles/classes/attendance/baseline/evidence and
official certification. WordPress and FastAPI accounts remain separate until
explicit verified linkage. No account merging by email/name/CPF and no LMS
progress copied into attendance. Authentik is the approved identity direction,
currently a lab, not operational SSO.

**DECISION:** retain public `1.4.1+14`. Candidate metadata is already `1.4.2+15`
from #317; this audit does not modify it or publish it. The release manifest has
`release_build_allowed=false`, `upload_allowed=false`, historical AAB superseded
and source verification pending. `MERGE_ALLOWED=NO; PRODUCTION_ALLOWED=NO`.
QA builds and source corrections remain authorized.

## Deliverables

| Deliverable | Artifact |
|---|---|
| A. Capability inventory | [Experience inventory](experience-matrices.md#capability-inventory) |
| B. Intended/documented/implemented/verified comparison | [Experience inventory](experience-matrices.md) |
| C. Every supported role and acceptance criteria | [Role journeys](experience-matrices.md#role-based-journeys) |
| D. Ownership, interfaces and impacts | [Dependency map](dependency-map.md) |
| E. Prioritized gaps, roots, action and proof | [Gap register](gap-register.md) |
| F. Smallest coherent release sequence | [Critical path](#critical-path-to-distribution) |
| G. Reproducible evidence and risk matrix | [QA evidence](qa-evidence.md), [coverage.csv](coverage.csv) |
| H. Decisions needing authority | [Remaining decisions](#remaining-human-decisions) |

## Environment, ownership and artifacts

LARGeo and DESKTOP-8T5DRBS were online; Avellaria and the historical Linux VM
were offline. Only LARGeo was selected for the Dart contract check. Its actual
SDK is `D:/flutter-3.44.9`, Dart 3.12.2; the AGENTS historical C:/Users/Usuario
paths do not exist on this host. ADB is not on its shell PATH; existing adb
processes alone do not prove an idle emulator or connected POCO. No device was
installed, rebooted or taken over. Physical-device availability is UNKNOWN.

LARGeo's worktree list contains many preserved draft branches and two #333/#335
repair worktrees. In `tds-issue335-qa-widget-fix-20261022`, the QA screen and widget
test are modified. Those files were excluded from this writer. The cloud #336
scope was reserved on GitHub comment 6352420395 before edits. Local release
integration is `8de3570`, while remote #316 is `817432b`: do not equate them or
push the local branch over the remote without reviewing its extra work.

Existing artifacts were located through tracked manifests/QA reports and the
Windows worktrees; the top-level `D:/AI-Shared/builds` listing did not identify a
new current candidate. Historical examples: #284 reused SHA-verified APK
`D3FFAB...AFDB9`; Samsung QA procedure references APK SHA
`2085B5844270E737073E1004D0238921FF9B97998F069522BDC1F79BF8339F7D`;
release manifest retains the superseded `1.4.0+13` AAB. These are provenance
references, not present-byte verification or acceptance of the current source.
Do not rebuild or reuse them for a different SHA by assumption.

## Selected engineering task and result

**INTEGRATE / #336:** existing Flutter offline storage rejects media without
measured length/SHA-256. Existing editorial responses expose URLs and source
fingerprints, not a byte-integrity manifest. The candidate adds one read-only
route and one helper to the existing plugin; no service, DB table, Flutter
dependency, migration or academic write. [Runbook](../../architecture/EAD_OFFLINE_MANIFEST_336.md).

The new route fails closed until a trusted offline preparation record exists
for the exact approved source/revision, unique parent and current local file
identity. It projects the existing strict Flutter schema. Preparation streams
and hashes local bytes; GET checks metadata/stat without hashing a video or
fetching URLs. Local contracts and a real PHP→Dart check pass. The continuation added
**44/44 actual isolated WordPress/LearnPress/MariaDB assertions** plus3 checks
parsing that native HTTP payload with the unchanged Dart parser.
[Runtime evidence and preserved failures](../../qa/ead-offline-manifest-runtime-20261022/README.md).
Institutional staging and Android offline E2E remain **NOT_RUN**; the production
download UI remains disabled. G25 records native unpublish/reassociation recovery. #335 original work was later recovered in isolated copies; see continuation below.

## Critical path to distribution

1. **Freeze scope and authorities:** use existing #250 reconciliation, #316's
   integration graph and the register below. Resolve source drift by explicit
   ancestry/content review, not a blanket merge of all open branches. Establish
   the exact required role/workflow set; do not silently drop finance/creator.
2. **Complete safe source blockers:** #335 owner repairs widget lifecycle and
   Flutter CI; review this #336 manifest contract; reuse #331 store and #334
   native player. Adapt the client to the manifest through the existing
   editorial repository, preserving independent authorization checks.
3. **Exercise separate authorities in isolated staging:** real WP/LearnPress
   publication/save/revoke/manifest; institutional prepare→activate→enroll→
   attend→assess→close→certificate path with all affected personas, retries,
   capacity warning and open-session close blocker. Run A/B negative access.
4. **Identity and cross-domain views:** keep the working official portal login
   route while testing Authentik PKCE/link/revoke/recovery with synthetic
   existing-account A/B fixtures. Reuse #260/#263/#266 instead of a second Minha
   Área; integrate only after a verified identity reader exists. SSO must not be
   represented as operational based on discovery.
5. **Education acceptance:** course crosswalk/quiz associations, exact official
   progress, offline cold restart/update/revocation/reconnect; version-pinned
   RAG real-course relevance, citations and outage handling; institutional
   evidence/certificate validity. No watch-time academic credit.
6. **One frozen candidate:** compose only reviewed compatible heads; repeat
   risk-critical contracts and staging Android journeys on that SHA. Preserve
   historic evidence as historical, not inherited PASS. Performance, TalkBack,
   large fonts, Portuguese states and weak-network recovery cover each critical
   entry point. Review privacy/Data Safety and support/deletion scope.
7. **Release preparation:** prove current restore/provenance/schema compatibility,
   canonical config, dependency lock, signature continuity and version monotonicity;
   create hash-linked QA artifact, emulator acceptance and appropriate POCO
   pre-AAB validation. Prepare signed APK/AAB only through the established gate.
   Merge/production/Play remain separate owner decisions; no action here opens them.

These are a dependency sequence, not a claim that all work can fit into a single
PR or that every desired feature must be rewritten before release. Existing
working implementations are reused; unverified essential journeys stay explicit
release blockers until exercised or explicitly dispositioned by the owner.

## Remaining human decisions

No routine engineering approval is requested. Batch rights, LearnPress authority,
Authentik direction and public version preservation are already decided.

At the appropriate final gates: review the exact candidate for merge; approve
production/publication only after its evidence is reviewable. Institutional
questions still needing evidence/authority include the follow-up anchor
(generation versus validity/reissue), explicit exceptions for any restricted
third-party asset, privacy/retention disclosures across both account controllers,
and any proposed exclusion of an intended role from a distribution scope.
None blocks the source/testing work selected here. Do not ask for production
credentials to perform synthetic contract tests.

## 2026-10-23 continuation

Current runtime source16e30de: full940 Flutter tests/analyze and PHP/quarantine/
secrets CI PASS. Reader25+authority17 focal contracts and #335 widget/store/HTTP31
PASS locally; mock streams remain separate from live integration. Matrix37 rows,
25 gaps. G02 reconciled by reusing seven exact #250 documents, not a new design.
Exact-source synthetic Android QA underway; no institutional/full-role or release
acceptance inferred. See newer CURRENT_STATE and dated QA directories.
