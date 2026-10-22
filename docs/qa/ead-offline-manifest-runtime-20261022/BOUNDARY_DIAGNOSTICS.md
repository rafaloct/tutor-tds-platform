# Preparation boundary diagnostics

## Native runtime attempt 1

- Observed: real WordPress installed, LearnPress activation failed before any test
  because the pinned Git source archive excludes vendor/autoload.php.
- Expected: complete native plugin including generated autoload and runtime dependencies.
- Responsible boundary: upstream source packaging versus built distribution.
- Evidence: attempt-1.json; every run-owned container/volume/network cleaned PASS.
- Likely root cause: GitHub source archive is not the official built plugin ZIP.
- Affected files: cached LearnPress build only; no Tutor production source.
- Structural fix: prepare complete runtime dependencies from upstream composer.json,
  retain generated lock/package commits and archive digest. Do not fake an LP route
  or handwrite an autoloader and claim native acceptance.

## Composer archive transport — two failed endpoint attempts, stopped

- Observed: api.github.com package zipball CONNECT denied; source fallback lacks
  Git in the PHP image. A local lock rewrite initially failed because Composer
  created the lock as root; an unguarded shell continuation repeated the old URL.
- Expected: permitted package transport with unchanged exact source commits and TLS.
- Responsible boundary: build-only download URL and local file ownership.
- Evidence: tool logs for Composer preparation; no native runtime test was rerun.
- Likely root cause: API host absent from enforced egress allowlist; lock rewrite
  did not take effect before the repeated invocation.
- Affected files: external cache composer.lock only, never app/API/WP production.
- Structural fix: stop api.github.com retries; atomically replace the cache lock
  under its writable parent. Use the explicitly permitted codeload.github.com
  archive endpoint for the same GitHub repos/commit references, through the
  inherited proxy and CA. This does not access the denied API destination or
  disable TLS. Freeze the generated lock and built archive hashes for reruns.

## Native HTTP boundary — repeated rest_no_route, stopped

- Observed: attempts 3/4 persisted real LP course/lesson, approved source and zero
  academic rows, but actual HTTP `/learnpress/v1/courses/{id}` returned 404
  `rest_no_route`. Attempt 4 only added diagnostics; it did not change behavior.
- Expected: native LP route registered in the anonymous Apache request lifecycle.
- Responsible boundary: native plugin bootstrap / HTTP route registration in the
  new source-built fixture. No evidence yet that the manifest implementation is
  responsible. WordPress itself answers REST and all resources clean up PASS.
- Evidence: attempt-3.json, attempt-4.json (`native_diagnostic`).
- Likely root cause: lifecycle/configuration or source-package discrepancy; not
  confirmed. Do not replace the missing route with a stub and call it LP proof.
- Affected files: run.py / fixture prerequisites; no Tutor production file changed.
- Structural fix: inspect native bootstrap and compare internal WP-CLI route
  dispatch with the HTTP registration. HTTP acceptance remains FAIL until a
  confirmed boundary correction is separately exercised; no further blind retry.

### Confirmed root and bounded correction

The separate diagnostic run showed native internal dispatch200 with both plugin
namespaces, but anonymous HTTP showed neither LP nor TDS namespace. Cloud source
mode inspection confirmed directories0700/files0600; docker cp preserves these,
so root WP-CLI could load plugins while Apache www-data could not traverse/read.
Normalize permissions only inside the run-owned copies (directories0755,
files0644), preflight plugin entrypoint readability as www-data, and recheck
content SHA. Host/private sources remain untouched. This is a fixture deployment
boundary correction, not a LearnPress/Tutor source change or authority bypass.
The failed HTTP runs remain retained; the next corrected run is separate.

## Attempt 5: republish acceptance precondition

The corrected web-user permissions let 37 assertions pass through native
HTTP200/HEAD/304, metadata persistence, revocation, replacement, shared parents
and protection. The final draft→publish→measure step failed closed. That step
omitted an explicit editorial reapproval/course review after changing publication
state. The revised fixture exercises an authorized synthetic administrator's
existing editor saves and course publication before measurement, records those
states, and still requires the original manifest constraints. It does not relax
source authorization or change plugin code. Failure of that reviewed state will
remain a separate diagnostic, not be converted to PASS or bypassed.

## Republish measurement — two failed states, acceptance front STOP

Attempts 5 and 6 both reached the final republish step and preparation failed
closed. Attempt6 additionally confirmed course=publish, lesson=publish,
rights=1, and current source fingerprint matches the approved one, so the
hypothesis that explicit review alone was missing is **not sufficient**. No
manifest producer authorization is relaxed and no third blind acceptance retry
is authorized by this harness. Retain both FAIL receipts, including 39 PASS
assertions in attempt6, rather than reporting a green full runtime result.

Observed: native HTTP publication/revalidation/revision/replacement/revocation,
shared-parent/protected-course rejection and metadata immutability succeeded.
Expected: reviewed republished lesson can be remeasured if parent/outline and
all file invariants still hold.
Responsible boundary: remaining native LP outline/association/cache or file
identity invariant after draft→publish. Exact root still UNKNOWN.
Evidence: attempt-5.json and attempt-6.json (both cleanup PASS).
Affected files: fixture.php/run.py and possibly the existing editorial adapter's
native-outline dependency; no production plugin code has been changed.
Structural next step: read-only diagnostic of actual parent rows, anonymous
native outline and editorial lesson result after republish. Distinguish a
fixture lifecycle omission from a product cache-invalidation defect before any
fix. Keep the failed integration result explicit until a scoped correction is
justified and independently verified.

### Read-only republish diagnosis and contract correction

`diagnostic-republish.json` proved parents=[], native course sections.items=[],
editorial404 `tds_editorial_lesson_not_authorized`, with published posts and valid
source approval. The pinned LP source's
`LP_Section_Items_DB::delete_item_not_in_tb_post()` deletes section rows whose
post_status is not publish; `LP_Background_Single_Course::clean_data_invalid()`
invokes it. This is an association lifecycle effect, not a manifest hash/cache
error. Publishing an orphan alone cannot restore its course membership.

The corrected acceptance retains the negative orphan404 assertion and exercises
**explicit authorized native LP editor reattachment** through the existing
`LP_Section_CURD::add_items_section`, then remeasurement. It checks editor
authorization and same original section/lesson, does not patch LP/vendor or
automatically create course relationships in the manifest. Earlier failures are
not erased. This is a newly specified recovery path after a confirmed diagnosis,
not a third blind retry or a relaxed acceptance condition. Actual browser editor
recovery/usability remains a separate NOT_RUN acceptance case.
