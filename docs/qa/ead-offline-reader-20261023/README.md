# Flutter offline manifest reader — 2026-10-23 UTC

Status: TESTED-LOCAL. Issue #336 / G03, continuation of draft #337.
Base: `3b4b75a0881dc7e63f39b281fee8c89eca17e3ea`.

OBSERVED: WordPress producer already has native runtime evidence, but Flutter
had no bounded HTTP reader. TARGET: explicitly consume current editorial data
without treating a parsed document as authorization. IMPLEMENTED: opt-in
`OfflineManifestRepository`, canonical anonymous GET, no redirects, no cache,
4096-byte streaming limit, total/stream timeout, exact course/lesson binding,
strict existing parser, operation-owned client closed on success/error.
No UI or production store wiring; existing deny authority is unchanged.

## Verification

LARGeo online; isolated Windows worktree
`D:/AI-Shared/work/tds-issue336-flutter-reader-20261023` at #334
`a0db10254642223dad192326f88d676aaba09553` plus exactly the two new files.
This base contains the same unchanged Dart dependencies/parser as cloud base;
later #337 changes were WordPress/docs/workflow only. No other worktree edited.
The two uncommitted #335 screen/test files were observed and preserved.

Commands from `cartilhas_app` using `D:/flutter-3.44.9/bin`:

- `dart format lib/features/ead_offline/offline_manifest_repository.dart test/offline_manifest_repository_test.dart` — PASS; first fresh-worktree format warned missing lints before dependency resolution.
- `flutter test test/offline_manifest_repository_test.dart --reporter expanded` — PASS, 25 tests, exit0. Dependency resolution kept tracked lock unchanged.
- `dart analyze lib/features/ead_offline/offline_manifest_repository.dart test/offline_manifest_repository_test.dart` — PASS, no issues, exit0.
- cloud `git diff --check` — PASS.

Raw Remote Desktop Commander output retained in adjacent text files. Tests use
MockClient/StreamClient and synthetic metadata. Coverage: canonical anonymous
request, no redirects/auth/cookies, parser and requested identity negatives,
stream byte limit (with/without declared length), truncated length, invalid
UTF-8/JSON, server errors, transport failure, close-on-error, and 200→404 without
stale fallback. Timeout paths are implemented but not exercised by these tests.

NOT_RUN: actual production/staging HTTP→this reader, Android UI/decoding,
release authority adapter, downloads/offline E2E, accessibility/performance.
The earlier 44 native WP assertions and 3 parser checks are separate evidence;
they are not proof of this reader's live integration. #335 remains separate.
No full-suite success is claimed. CI results belong to the exact pushed head.

Rollback: revert the reader/test commit; no database or production changes.
MERGE_ALLOWED=NO; no signing/publication; public version `1.4.1+14` preserved.
NEXT_FRONT: independent current editorial release authority, explicit QA binding,
then Android journey after #335 ownership is resolved.

Exact tested source SHA-256 (cloud and LARGeo agree):

- reader: `1e03881bd83863f19ff23c30a397fffcbd68c9a6370ffc16ee17444c7a2995e1`
- test: `137bbbf78721f62cb34a5b8bda1d31a389a4eca08d3da6c61cad282e4d3fe055`
- tracked normalized pubspec.lock Git blob: `a9af5addb74ab28b87cf8b0f8fc44e36f583a78c`

Windows raw lock hash differs due checkout line endings; both Windows
`git hash-object --path=cartilhas_app/pubspec.lock cartilhas_app/pubspec.lock`
and HEAD blob match cloud HEAD above. No lock modification in Windows status.
`git diff a0db102 HEAD -- cartilhas_app` was empty before these new files.
SDK reported Flutter3.44.9 framework6b182d2c75, Dart3.12.2.
