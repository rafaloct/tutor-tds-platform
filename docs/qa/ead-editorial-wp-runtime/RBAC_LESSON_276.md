# Issue #276 • LearnPress lesson editorial RBAC in isolated MariaDB QA

**Date:** 2026-10-18
**Classification:** OBSERVED / TESTED-SYNTHETIC, **not institutional staging**.
**Parent:** #236 / PR #238. QA-only draft stacked over PR #277.

## Why the first synthetic edit test was blocked

WordPress 6.7.2 / LearnPress 4.3.6 registered a CPT `lp_lesson` with
`map_meta_cap=1`, `edit_post=edit_lp_lesson` and
`edit_posts=edit_lp_lessons`. The original QA WordPress database `tdsqam`
did **not** assign the required capabilities to its administrator or editor
roles. The synthetic lesson id=12 had `post_author=0` and
`post_status=publish`, requiring capabilities for editing another user's
published lesson:

- `edit_lp_lessons`
- `edit_others_lp_lessons`
- `edit_published_lp_lessons`

Observed in the synthetic source via read-only WP-CLI:
`manage_options=1`, `edit_posts=1` but `edit_lp_lessons=0` and
`edit_lp_lesson(12)=0`, even for the administrator. This explains why the
LearnPress model rejected an editor operation.

A separate risk was revealed by the **first** QA attempt: privileged
`wp post update` through WP-CLI could mutate the disposable clone despite
a later LearnPress permission exception (from
`PostModel.php:333`). Therefore, **WP-CLI command failure is not an
authorization test**. Three initially drafted assumptions failed
(19/22 PASS); the ephemeral clone was nevertheless fully destroyed.
No institutional data was touched.

## Corrected test boundary and results

The second run used:
`tooling/qa/ead_editorial_wp_runtime/run.sh`, based on the exact source
plugin from PR #238 at `3856566e97a585c5d30dd8a1b72ca369f1704127`.
The plugin class SHA256 in the clone was
`064c350c544f60c02526b774c96b56d4e3a77e28cf1e279346999d9d489b632c`.

The runner creates a transient MariaDB clone `tdsqa236_*` and WP
filesystem clone, listening **only** at `127.0.0.1:18736`. It proves
five `@qa-synthetic.test` accounts and exact origin
`tdsqam`/`127.0.0.1:18732` before any clone mutation. It grants those
three capabilities **only** to the administrator and editor roles in the
disposable clone, never to subscriber, original QA, public site, or
staging/production.

**Second run actual results:**

| Contract | Result | Details |
| --- | --- | --- |
| Metadata / media runtime | **18/18 PASS** | Published, public opt-in, 304, YouTube synthetic right flags and revocation, no quiz keys |
| Lesson editorial RBAC | **22/22 PASS** | Capabilities, browser sessions, editing title/content, revision, draft removal |
| Browser admin/instructor | **PASS** | Synthetic authenticated sessions could load WP lesson editor page |
| Browser subscriber | **PASS (denied)** | Synthetic learner could not enter the protected lesson editor page |
| Instructor title/body edit | **PASS (clone WP-CLI)** | Legitimately granted synthetic editor modified the lesson without changing its author |
| HTTP revision | **PASS** | Lesson 200; `If-None-Match` 304; text edit invalidated old ETag |
| Draft withdrawal | **PASS** | Lesson 404 and omitted from public curriculum |
| Rollback DB | **PASS** | No `tdsqa236_*` database remains |
| Rollback filesystem | **PASS** | No `tds-editorial236-*` directory remains |
| QA port 18736 | **CLOSED** | No HTTP server left running |

The negative role check **uses real WordPress browser session cookies** and
WordPress admin edit page access, rather than WP-CLI negative writes.
Temporary passwords for the **three synthetic QA accounts** existed only
in process memory/ephemeral clone and were neither printed nor versioned.
No actual HTTP form submission by an instructor was exercised.
Browser authorization does not itself prove the full Gutenberg/classic
editor save workflow in an institutional environment.

The baseline `tdsqam` remained `http://127.0.0.1:18732`, lesson #12
remained published, and administrator/editor `edit_lp_lessons`
remained absent there. No production or original QA role mutations.

## What is proven and what is not

**OBSERVED:** real LearnPress capability mapping and WordPress browser
authorization, with one synthetic published lesson and editor/instructor,
student denial; content was edited through WP-CLI **with** the explicit
synthetic role capabilities, triggering the actual plugin's HTTP projection,
ETag changes, and draft protection. This uses a real WordPress stack but
entirely fictional records, not PHP stubs.

**UNKNOWN:** a real instructor submitting an authenticated WordPress editor
form to update a lesson; production role mappings; live plugin/theme
compatibility; authentic user enrollments, identity mapping, approval
rights for 48 videos, quizzes, grades, certificates or Tutor/RAG.
The first privileged CLI exception should not be projected onto
ordinary WordPress HTTP users or treated as proof of production data risk.

## Institutional staging preflight and human gate

The connected WordPress site
`https://ead.ipexdesenvolvimento.cloud` is the **active institutional
site** (WP 6.7.2, child theme 2.0.0) and the plugin PR #238 is **not**
listed as installed there. Available WPVibe sites exposed only this one
institutional instance. Docker inspection of the authorized VPS showed the
test `tds-learning-qa-*` containers and other applications, but no
verified separate **institutional WP staging** hostname/database with
backup and rollback proof.

The prior user authorization permits continuing staging work, **not**
treating production as staging. Therefore **NO institutional plugin
installation** was performed. Before that operation:

1. Identify distinct WordPress staging URL, database and filesystem,
   prove isolation from the public production site.
2. Create and verify an appropriate backup/snapshot and exact rollback,
   respecting personal data retention/privacy.
3. Install exact plugin PR #238 only on staging, default all editorial
   opt-in **OFF**, and verify no private lesson or media leaks.
4. Test normal instructor/editor/learner accounts in staging with
   real WordPress browser save/nonce, not privileged WP-CLI alone;
   confirm revocation, ETag, 401/403/404, media rights, and rollback.
5. Report separately before any production activation, Play/AAB,
   synchronization of enrollment/progress/grades/certificates, or merge.

**MERGE_ALLOWED=NO; PRODUCTION_ALLOWED=NO.** No WordPress production
mutations, no publication and no credential disclosure were performed.
