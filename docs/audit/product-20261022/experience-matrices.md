# Intended, documented, implemented and verified experience

## Capability inventory

Notation: **I** = implemented source; **H** = retained historical proof, scoped to
its recorded SHA/environment; **U** = current integrated behavior unknown.
Verification column uses PASS/FAIL/BLOCKED/NOT_RUN only. PASS with a historical
qualifier does not accept today's candidate. Paths are repository-relative.

| Capability / intended experience | Documented target | Implemented evidence | Verified experience / discrepancy | Action |
|---|---|---|---|---|
| Visitor understands purpose and studies before registration | `docs/product/PUBLIC_ENTRY_AND_ENROLLMENT_CONTRACT.md` | Welcome, bundled 9 cartilhas, EAD catalog and official portal links in Flutter | H: #324/#326 registration entry QA; current whole first-install acceptance NOT_RUN | REUSE + INTEGRATE |
| Discover EAD opportunities, details, prerequisites | #229/#230; #249 ADR | `ead_catalog`, `ead_learning_path_screen`; 11 LP offers | H: public Android catalog/fallback tests; prerequisites and every real offering NOT_RUN | REUSE + FIX evidence gaps |
| Discover cohort, express interest without formal enrollment | public entry contract waves B/C | Public contract explicitly distinguishes interest/application; institutional operator enrollment exists | Public cohort application/lead journey not established by this audit; NOT_RUN, do not infer from EAD signup | IMPLEMENT only after inventory |
| Create/login EAD account and return to chosen course | #299/#324 | Fixed official HTTPS links; WP institutional handler/patch299 | H: 32/32 synthetic HTTP #301; #326 Android form; no real-user creation this cycle | REUSE |
| Institutional account, refresh/recovery/logout/privacy | `auth.py`, identity/recovery contracts | API auth/activation/recovery, secure Flutter token store and deletion service | Current deployed A/B lifecycle and cross-browser logout NOT_RUN; #323 invitation path candidate | REUSE + FIX if reproduced |
| Link existing WP and institutional accounts safely | #249, #330 | Authentik lab blueprint/policy #332; separate-account notice #324 | Discovery proof only; PKCE/code exchange/link/recovery BLOCKED pending adapter/staging | INTEGRATE |
| EAD Minha Área: courses, resume, progress, history | #250/#262/#265 | Separate #260 action policy, #263 UI, #266 controller | #266 reports 152 combined tests but explicitly no HTTP reader/Home wiring; integrated journey BLOCKED | INTEGRATE existing components |
| Cohort planning, scheduling, activation, closure | `class_lifecycle.py`, contract #138 | API, Flutter prepare/activate/close screens, pending prepare receipt | H: 05/10 E2E; 12/10 new-policy Android build blocked; current path NOT_RUN | REUSE + INTEGRATE |
| Participant enrollment, assignment, capacity | operator/classroom contracts | `operator_operations.py`, `classroom_policy.py`, Flutter operations | 30 is advisory under decision 32; older hard-cap assertions superseded; downstream all-role acceptance NOT_RUN | REUSE |
| Teacher/monitor student progress and follow-up | dashboard/context contracts | Scoped classroom dashboards; learning context and follow-up endpoints | Monitor own projection and exclusions require exact-current proof (#119/#97); NOT_RUN | REUSE + FIX if reproduced |
| Edition-preserving dynamic course publication | CourseVersion lifecycle, Wave 2A | `course_editor.py`, promotion, fixed class version, catalog cache | H: 2A Android+POCO 01/10; current combined publish→student→instructor NOT_RUN | REUSE |
| Text, public PDF, module materials | PDF contract, public content policy | Native lesson sanitized HTML, material views, external Drive PDF button | H: real PDF opened after account chooser; open event is not reading credit; current offline PDF NOT_RUN | REUSE |
| Native streaming MP4 and VTT, optional YouTube | media/editorial/player contracts | IPEX WebView player + source-bound WP metadata; optional YouTube | H: Android cold/warm fix #311 and captions #295; audio attested historically; complete current TalkBack NOT_RUN | REUSE + INTEGRATE |
| Download verified revision, restart offline, replace/revoke | #329/#333/#336 | #331 store; #334 downloader/native local player; this #336 producer | #334 Flutter CI FAIL; live manifest/client/button + airplane mode BLOCKED; current source contract PASS | INTEGRATE |
| Restore video position and synchronize pending academic progress | offline/progress contracts | Local cartilha StudyProgress/outbox exists; media store verifies bytes | Video position persistence and LP progress bridge not established; download is not full offline learning; NOT_RUN | INTEGRATE, audit missing pieces |
| Assessments, published blocks, resume and valid attempts | Dynamic 2B / `assessment_sync.py` | Existing assessment tables/lineage, Flutter practice/quiz UI | LP quiz engine separate; current full authorized attempt/result across versions NOT_RUN | REUSE + INTEGRATE |
| Numeric check-in, official attendance and corrections | `presence.py`, attendance policy | Rotating codes, scoped commands/review | #159 code-expiry/session boundary must be reproduced; current operational acceptance NOT_RUN | REUSE + FIX if reproduced |
| Completion statements, official certificate request/sign/verify/history | #5/#68, certificate lifecycle | API policy/request/emission transport; Worker/KV; Flutter wallet | H: request/review emulator + real staging transport; generation ≠ validity; new full policy/candidate NOT_RUN | REUSE + INTEGRATE |
| Mentoring/evidence review and resubmission | `evidence.py`, evidence/offline contracts | Backend+Flutter evidence, review and outbox paths | H: offline receipt 06/10; cross-role review→dashboard→cert criteria on current SHA NOT_RUN | REUSE |
| AI educational help tied to actual edition | #134/#136, RAG audit | Gateway course/version workspace routing; Flutter Tutor UI/sources | H: A/B synthetic edition sentinel 06/10; real pedagogical usefulness, module and LP mapping NOT_RUN | INTEGRATE, no model-stack replacement |
| Creator draft→review→publish→analytics | media/course editor/commercial contracts | `media.py`, `course_editor.py`, creator endpoints; Flutter management | Backend capability is not complete creator UX; current all-role Android acceptance NOT_RUN | REUSE + INTEGRATE |
| Finance score→statement→audit, no automatic payment | `commercial.py`, existing program roles | Creator score and finance statement endpoints/tests | No end-to-end finance workspace/payment acceptance located; NOT_RUN; free educational media does not imply payouts | REUSE; IMPLEMENT only missing approved UI |
| Support, feedback and outage recovery | Chatwoot contract; #319/#321 | Flutter support/controller/WebView; API support config/context | Runtime parity in sibling #319; current signed-identity/live support A/B NOT_RUN | INTEGRATE |
| Reporting, baseline, audit, follow-up | journey export, BI/operating decisions | `journey_export.py`, events, sync/export, baseline lineage | H: 68/65 legacy query errors; current correctness/denominators and follow-up anchor unresolved; NOT_RUN | FIX + REUSE |
| Accessibility, Portuguese, low-connectivity resilience | feature offline policies, #185/#308 | Semantics, captions, TTS, states and tests in selected features | No complete role traversal with TalkBack/large fonts/current build; memory/battery/performance NOT_RUN | FIX from measured evidence |
| Distribution and continuity | release gates, backup/provenance contracts | Version/signing guards, locked builds, restore tools/receipts | Current release_build_allowed false; new exact source/artifact and Play upgrade BLOCKED | REUSE gates |

## Role-based journeys

Actual program roles are the eight literals in `api/app/organizations.py`:
`student, teacher, monitor, creator, coordinator, program_operator, finance,
admin`. `creator` is the implementation spelling of content creator. Global JWT
role and contextual ProgramMembership/CohortMembership are different; a global
admin does not universally bypass program scope (see operations contract).
WP `lp_teacher`, generic editor and administrator are separate capability sets,
not automatic equivalents of program roles.

Each row follows **entry → authentication → home → work → monitor → completion
→ history → exit**. All rows need negative direct API/ID access, expired-session
recovery, account/role switch and cross-system origin labels. Every integrated
row is **NOT_RUN on this increment's candidate**, even where older proofs exist.

| Role | Full intended journey / implementation anchors | Verifiable acceptance criteria | Highest-risk states / current gap |
|---|---|---|---|
| Student | Public entry; optional EAD login; institutional login when relevant; own courses/cohort; study/materials/quiz/check-in; progress; completion/request; wallet/history; both-domain logout | EAD and cohort enrollment stay distinct; same official progress for authorized teacher; numeric check-in records once; requirements/signatures govern official certificate; account B never sees A | Cold offline→reconnect, expired code vs token, revoked enrollment, updated edition; Minha Área reader/link incomplete |
| Teacher | Institutional login + real scoped membership; instructor workspace; assigned classes/schedule; session/attendance/review; participant exceptions/progress; close-related handoff/signatures; audit/history; logout. EAD editing uses legitimate lp_teacher | Only own classes/students and own authorized LP parents; review persists and student projections refresh; cannot issue coordinator signature or change unrelated course; open-session closure correctly blocked | Publish→pending native review, shared lesson parents, new class policy not current-Android accepted |
| Monitor | Scoped login; own monitor workspace; assigned cohort roster/exception tasks; attendance/support actions permitted by policy; monitor follow-up; history; logout | No teacher/coordinator/admin powers inferred from UI; no private assessment answers; only assigned data; revocation removes cached private state | #119 dedicated projection and A/B context-switch proof needs current verification |
| Content creator (`creator`) | Program login; creator workspace; create/update own draft/materials; submit; respond to review; publication result/analytics/score history; logout | Draft never public, immutable published editions preserved; creator cannot self-grant publication/reviewer/finance authority; existing class stays on old edition; only own analytics | Detached backend capability vs UI; LP authorship and TDS edition crosswalk; draft upload/retry/offline recovery |
| Coordinator | Scoped login; management; course/team review; activate/close/assign as authorized; monitor program/attendance/evidence; sign valid certificate at proper stage; audit/report; logout | No cross-program access; teacher/monitor/student observe activation/changes consistently; closing with open session denied; certificate requirements remain deterministic | Interdependent transitions across roles and caches; team changes after activation; partial failure and replay |
| Program operator | Scoped login; operations home; prepare class; search/register/inspect; enroll/assign/revoke; activate/close per decision 32; monitor pending requirements; history; logout | Same User/Enrollment reused; exact-CPF search is confined to approved command body; 31st participant warns without unauthorized bypass; replay doesn't duplicate; no coordinator-only team edit | Lost response/cold restart reconciliation; class closed while command pending; operator role revoke mid-request |
| Finance | Scoped login; finance capability entry; inspect authorized score; generate/review statement; monitor immutable calculation/adjustment; retain ledger/history; logout | Student/teacher/creator cannot read other finance data; statement replay stable and program scoped; no inferred payment, payout or monetization from free media rights | Complete operational UI and institutional applicability not verified; do not fake a finance dashboard or declare role out of scope |
| Administrator | Admin login plus required context; account/program/config surfaces; manage authorized roles/accounts; oversee health/recovery/audit; controlled closure/identity maintenance; history; logout | Global role does not bypass contextual checks where contract requires membership; no privilege from external token strings; recovery leaves audit/provenance; no production secrets in app | Role transitions, account deletion vs institutional history, break-glass and restore on current schema |
| Visitor (additional state) | First install; understand program; public cartilhas/EAD; optional signup; return to selected course; local study; help; exit | No login wall before public value; no fake cohort or official credit; external failure has retry and Portuguese explanation | Weak connectivity, first-run no cache, cancellation of external browser, no account created by reading |

A role passing JWT validation has passed none of these acceptance criteria by
itself. Required evidence is the actual task plus its downstream authoritative
readback and the other affected role's UI/projection.
