# EAD offline media package v1 — Issue #329

## Contract and status

**OBSERVED:** The editorial bridge checks the LearnPress authority, schema v1,
content revision and matching ETag. Its `mobile_content` opt-in controls mobile
lesson display, and hosted media URLs are restricted to HTTPS IPEX uploads. The
existing player does not install media offline. This issue adds a standalone
Flutter package store and tests; it is not connected to the production UI.

**DECISION:** Only public, user-independent editorial media can be packaged.
The package must not establish enrollment, attendance, completion or certificate
eligibility. Authentik is Issue #330. Blob Flutter awaits performance benchmarks.

**TARGET:** A future trusted adapter reads a currently released editorial lesson,
validates revision provenance against the exact SHA-256 ETag, checks
`mobile_content` and separately verified media rights, and supplies the matching
v1 manifest plus an affirmative `OfflineReleaseCheck`. Manifest fields or a
public URL by themselves never grant installation. A negative, unavailable, or
revoked release check must deny download. The adapter must bind course/lesson,
revision and exact MP4/VTT URLs to its verified server response. The downloader
must reject HTTP redirects (including same-host redirects) unless a later
review explicitly defines safe handling; it must never follow an off-domain
redirect. No default HTTP downloader is provided in this slice.

**UNKNOWN:** Production adapter integration, support-directory wiring,
revocation polling, background downloads, player integration and real-device
storage behavior remain untested and out of scope.

## Manifest

Required JSON fields: `schema_version: 1`, positive bounded numeric `course_id`
and `lesson_id`, lowercase 64-character SHA-256 `content_revision`, true
`mobile_content`, true `rights_approved`, and one `mp4` object. Optional `vtt`
and raw public `title`. Each asset has exact HTTPS IPEX `url`, positive byte
`length`, and lowercase SHA-256 `sha256`. Unknown fields, PII fields, YouTube
IDs, query/fragment, userinfo, ports, encoded paths, traversal, duplicate
assets and non-IPEX hosts fail parsing. MP4 must be strictly below 500 MiB;
combined asset bytes strictly below 700 MiB. Thus a real 706 MB course is split
across multiple lesson packages, not rejected solely because of course total.

## Storage and offline policy

The caller will pass a private application-support directory. The store uses
`v1/<courseId>/<lessonId>/<contentRevision>/`, with fixed asset names. Bytes
stream to a private `.part` directory with incremental size and SHA-256 checks.
The canonical manifest and its SHA-256 are flushed before the directory rename
that makes the revision READY. Reads verify manifest and both asset digests;
incomplete or corrupt revisions return no file. A failed new revision leaves
previous READY revisions intact. Same-root operations serialize across store
instances in one isolate. An explicit quota rejects installs before download;
there is no silent eviction. The caller must also reserve physical free space.
Errors carry stable codes such as `release_denied`, `quota_exceeded`,
`size_mismatch`, `hash_mismatch`, `install_failed`, and `revision_conflict`.

Revocation deletes all revisions of the exact course/lesson. Later offline reads
return no file, and installation requires a new trusted release check. Automatic
server revocation while disconnected is impossible to observe in this slice;
the future UI must define refresh timing and explain any offline access window.
No academic event or account data is stored. Files returned by `read` should be
opened promptly; concurrent external filesystem mutation after verification is
outside the store's process-level guarantee.

## Gate

Feature remains unwired. Before production integration, add a server-backed
release check with revision/ETag and rights provenance, a no-redirect HTTP
transport, support-directory wiring, device storage and interruption tests,
revocation policy, and explicit UI/UX review. No release readiness follows from
these unit tests alone.

## Local validation record — 2026-10-22

Matrix row: Issue #329 | EAD offline public media package v1 | contract and
offline policy above | 25/25 Flutter focal tests PASS on Flutter SDK 3.44.9 | complete
flutter analyze --no-pub PASS 0 issues | six direct Dart VM smokes
previously PASS | production integration and release flags remain OFF.

The specified `D:/flutter-3.44.9/bin/flutter.bat pub get --enforce-lockfile`,
`flutter.bat test --no-pub --concurrency 1 test/ead_offline_package_test.dart`,
and `flutter.bat analyze --no-pub` were attempted. Each batch wrapper remained
silent and was interrupted. Invoking the same SDK's `flutter_tools.snapshot`
made the failure explicit: it cannot open
`D:/flutter-3.44.9/bin/cache/lockfile` in this restricted executor. At that earlier point no Flutter test result was available. A subsequent
independent run with proper SDK-cache access completed all Flutter tests;
see final acceptance result below. No pubspec/lockfile changes were made. Dart format
PASS; `dart analyze lib/features/ead_offline test/ead_offline_package_test.dart`
reported **No issues found**. Direct Dart VM smoke passed verified offline read,
idempotent install, preservation of previous READY after a failed revision,
revocation, denied release, and URL rejection. A separate attempt to run the
25 cases through `package:test` could not resolve a compatible runner from the
existing cache; it is not counted as a test pass.

STOP record after repeated SDK lock error:

- Observed: Flutter snapshot reports access denied opening SDK cache lockfile.
- Expected: Flutter commands start using the pinned SDK and execute the focal
  suite and analysis.
- Responsible boundary: executor filesystem permission on SDK cache.
- Evidence: both focal test and analyze snapshot commands failed at the same
  lockfile before loading project code; batch wrappers remained silent.
- Likely root cause: SDK path is readable but its cache is not writable here.
- Affected files: no source file; SDK cache lockfile is outside this worktree.
- Structural fix: use the same pinned SDK from the authorized host with normal
  filesystem access, without altering SDK protections or code; completed below.

## Final focal acceptance on LARGeo (authorized host execution)

- Flutter SDK: `D:/flutter-3.44.9/bin/flutter.bat` version **3.44.9**.
- `flutter pub get --enforce-lockfile`: **PASS**; `pubspec.lock` unchanged.
- `flutter test --no-pub --concurrency 1 --reporter expanded test/ead_offline_package_test.dart`: **25/25 PASS**, including restart without network, integrity, permissions, quota and revocation.
- `flutter analyze --no-pub`: **PASS — no issues found** (93.8 s).
- Host verification script ended `ALL_GATES_PASS=True`; logs in `D:/AI-Shared/test-results/tutor-tds/issue329-offline-first-20261022/`.
- These are **library tests** only: no real HTTP downloader wired, no `video_player` integration, no airplane-mode device E2E, no real editorial release, no Play merge/upload. Release state unchanged.
