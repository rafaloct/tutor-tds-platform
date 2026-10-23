# #335 widget recovery — TESTED-LOCAL

Base041d1cc (#336 authority); tested Windows source base81ec0ed plus exactly
screen/test/scoped asset attributes. #336 adapter is opt-in and unrelated to
these tests; exact composed head CI remains required. Original uncommitted
repair at D:/AI-Shared/work/tds-issue335-qa-widget-fix-20261022 was read/copied,
never overwritten. No active writer process/published repair observed at recovery.

Root causes and attempted corrections are retained in BOUNDARY_DIAGNOSTICS.md
and attempt-1/2/3 receipts. Attempt1 receipt captures first failure; its eventual
result was29 PASS/2 FAIL. Attempt2 terminated after first equivalent failure.
Attempt3 resolves scheduling but exposes real Windows fixture byte mismatch.

Final correction: test-only operation hook receives deferred work; tests start
native I/O in Zone.root and await in runAsync before pump/assert/teardown. Without
a test hook, normal screen operations start immediately in the caller zone as
before. Open/install/remove all covered. No store semantics changed. Tests use
actual fixture files, verify exact lengths/hashes and UTF-8 captions, zero network
on reopened store, removal and failed stream with no ready file. Synthetic
fixture attributes -text preserve exact byte identity on Windows (VTT148 bytes,
not155 after autocrlf); manifest digests and assets themselves unchanged.

LARGeo Flutter3.44.9 / Dart3.12.2, new isolated worktree:
D:/AI-Shared/work/tds-issue335-recovery-20261023.

- flutter pub get --enforce-lockfile: PASS, no lock change.
- dart format screen/test: PASS.
- dart analyze screen/test: PASS, no issues (final Dart source same as analyzed; later attribute-only correction).
- flutter test --no-pub test/ead_offline_qa_widget_test.dart test/ead_offline_package_test.dart test/ead_offline_http_test.dart --reporter expanded: PASS31, exit0; final receipts adjacent.
- cloud git diff --check: PASS.

This proves widget/filesystem/transport contracts, not actual Android decoding,
connectivity, service integration, role acceptance or distribution. API35
emulator-5580 started run-owned; physical Samsung was discovered and untouched.
Android synthetic player QA is next; production default denial stays unchanged.
Rollback screen/test/attribute changes together; no database/dependency/version
change. Public1.4.1+14; MERGE_ALLOWED=NO; no production/signing/publication.
