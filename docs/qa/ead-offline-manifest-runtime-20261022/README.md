# #336 native WordPress/LearnPress manifest integration

**TESTED-LOCAL: 44/44 assertions PASS**, 5/5 run-owned resource removals PASS.
This is actual WordPress **6.7.2**, LearnPress **4.3.6**, PHP **8.3.20**, MariaDB
**11.4** and Apache HTTP with disposable synthetic records. No LearnPress REST
route, database, source approval or file-stat function was stubbed. Source:
PR #337 plugin at `6e4aab96c7bc53bad5eba17f10498bc667979188`, exact copied PHP
hashes in [acceptance.json](acceptance.json). The tested harness/fixture hashes
are recorded in the receipt and match the committed source files.

**Not established:** institutional staging or production installation, public
HTTPS/TLS, browser editor form/nonce submission, authenticated learner/teacher
journeys, playable video/audio/captions UI, Flutter client wiring, airplane mode,
SSO, release or Play readiness. The MP4 is deliberately non-playable synthetic
ASCII bytes. HTTP media delivery verifies bytes/integrity, not decoding.

## What passed

The receipt's 44 rows comprise 10 deployment/source checks and 34 native
integration checks: real LP save hooks and source approval; zero seeded academic
records; native course REST; no manifest before measurement; persisted lengths
and digests; strict Flutter JSON keys/IDs; actual HTTP asset bytes matching
SHA-256; no-store/nosniff; HEAD; strong/weak/unknown ETags; no metadata/academic
writes from GET/HEAD/conditional requests; revocation before304; editorial
revision and atomic file replacement invalidation/new ETag after remeasurement;
multiple-parent and protected-course rejection; draft rejection; republished
orphan rejection; explicit native reattachment; remeasurement and final unchanged
academic-table readback. No new user/enrollment/progress/grade/order/certificate
was created by the editorial requests.

Both plugin entrypoints were checked for readability **as Apache www-data**.
Every copied PHP file's SHA matched the candidate. The network was created
`--internal`, with no published ports; all requests used loopback inside the
run-owned WordPress container with a canonical Host header. The real public
IPEX domain was never contacted. WordPress external HTTP/cron/automatic updates
were disabled in the disposable configuration. Only run-labeled containers,
volumes and network were removed; cached source packages remain reusable.

## New product finding: republish does not restore course membership

The initially expected `draft → publish → measure` recovery failed even with
published posts and source approval. Read-only [diagnosis](diagnostic-republish.json)
showed `parents=[]` and empty native section items. At the pinned LP commit:

- `inc/Databases/class-lp-section-items-db.php`,
  `delete_item_not_in_tb_post()`, deletes section items whose post is not
  `publish`, despite its name/comment describing missing posts.
- `inc/background-process/class-lp-background-single-course.php`,
  `clean_data_invalid()`, invokes that cleanup.

The manifest's refusal was correct: it must not infer membership from the old
measured record, a published lesson or an approved URL. Recovery requires the
editor to explicitly reattach the lesson to the intended course/section through
LearnPress, then review/measure the current source. The accepted fixture uses
`LP_Section_CURD::add_items_section` under the synthetic administrator's existing
course+lesson permissions. No LP/core/vendor patch or automatic production
reattachment was added. Browser-based recovery and UX remain NOT_RUN; audit G25
tracks that remaining product gap.

## Preserved failures and boundary corrections

All runs are retained; do not describe them as a clean first attempt:

| Receipt | Outcome / responsible boundary |
|---|---|
| [attempt-1](attempt-1.json) | FAIL before assertions: upstream Git archive excludes Composer vendor/autoload |
| [attempt-2](attempt-2.json) | FAIL after8 source checks: fixture passed an array literal to native LP's by-reference create() |
| [attempt-3](attempt-3.json), [attempt-4](attempt-4.json) | FAIL after10 checks: HTTP rest_no_route; repeated boundary stopped |
| [diagnostic-1](diagnostic-1.json) | BLOCKED diagnostic only: root CLI saw plugins, Apache did not; host private permissions copied into container |
| [attempt-5](attempt-5.json) | FAIL after37 checks: naive republish measurement; earlier native transitions passed |
| [attempt-6](attempt-6.json) | FAIL after39 checks: explicit source/course review alone insufficient; acceptance retry stopped |
| [diagnostic-republish](diagnostic-republish.json) | BLOCKED diagnostic only: native association deletion confirmed; no acceptance retry |
| [acceptance](acceptance.json) | PASS44/44 after contract correction: orphan stays denied, authorized explicit native reattachment then succeeds |

[BOUNDARY_DIAGNOSTICS.md](BOUNDARY_DIAGNOSTICS.md) records Observed, Expected,
Responsible Boundary, Evidence, Likely Root Cause, Affected Files and Structural
Fix, including the build-only endpoint/lock ownership issue. No failure caused a
production change or weakened an authorization/integrity check. All failed and
diagnostic runs also report complete cleanup of their own five resources.

## Reproduction and pinned prerequisites

Python3.12+ and the managed Docker daemon are required. Follow the current
managed-runtime proxy/CA instructions before package downloads/builds. Images
and source archives must already exist locally; the test network needs no egress.

```sh
python docs/qa/ead-offline-manifest-runtime-20261022/run.py \
  --cache /workspace/tds-runtime-cache \
  --output /workspace/tds-runtime-evidence/reproduction.json
```

`--diagnose` stops after bootstrap/route comparison; `--diagnose-republish`
stops before recovery to report native parent/outline state. Both intentionally
exit2 with BLOCKED_DIAGNOSTIC_ONLY, not PASS. Normal invocation exits0 only when
all assertions and cleanup pass. No run retries failed assertions automatically.

| Prerequisite | Pin / custody |
|---|---|
| WordPress image | `wordpress@sha256:10f35d0dd608ee9f907c22aa3f2bbb9ac64fee72726503e53f2afd298d2a09f1` |
| MariaDB image | `mariadb@sha256:250e1609e93c0e6aecf64bfbab2d84d5e89d2481540fe77447ff6c855c3b1873` |
| LearnPress source | upstream commit `84edad0aea35bcac86018a825d0a42f8188d6ead`, release4.3.6 |
| Source archive | `learnpress-4.3.6.tar.gz`, SHA256 `79c9607437a81fd85ae2fd2dcf8902c4607b7d4667659421672b5506329cf715` |
| Complete QA build archive | `learnpress-4.3.6-built.tar.gz`, SHA256 `56f80d7981611c05723c7b45134f2b6d25d8214c52b07c5b338df86dbae6b441` |
| WP-CLI2.12.0 | `wp-cli.phar`, SHA256 `ce34ddd838f7351d6759068d09793f26755463b4a4610a5a5c0a97b68220d85c` |
| Dependency lock | [learnpress-build.composer.lock](learnpress-build.composer.lock), exact generated lock from the QA build |

The cached QA build is **not the earlier official WordPress-plugin ZIP**; do not
claim distribution equivalence from its version string. It contains unchanged
upstream LP source plus Composer-generated autoload and two runtime dependencies:
`css-to-inline-styles v2.3.0@0d72ac1c00084279c1816675284073c5a337c20d` and
`symfony/css-selector v7.4.18@fecf40067fc8d8880ea87b8ac227600b9aadd1d0`.
Dev dependencies in the lock were resolved but **not installed**. No scripts or
Composer plugins were executed. Archive hashing freezes the exact cached build;
a regenerated tarball may have different timestamps and must receive its own
reviewed hash/run, not a relaxed verifier.

Build recipe for a fresh equivalent fixture: fetch the source via the pinned
GitHub codeload commit, extract it, use the committed lock, and run Composer
2.8.12 `install --no-dev --no-scripts --no-plugins --prefer-dist --no-progress`
under the pinned PHP image with its inherited proxy and read-only CA mount.
The lock uses the permitted codeload archive endpoints for unchanged package
commit refs because the API zipball endpoint is blocked in this environment.
Retain the completed build, archive it, record its digest and change the explicit
fixture pin only for a separately recorded run. Never edit production vendor
files or fetch external code from inside the isolated acceptance network.

Rollback: the harness finally block checks each unique `tds.qa.run` label before
removal. Containers are removed before their volumes and network; no existing
service is selected by a shared name/pattern. No institutional backup/restore
claim is inferred from disposal of a fresh synthetic database.
