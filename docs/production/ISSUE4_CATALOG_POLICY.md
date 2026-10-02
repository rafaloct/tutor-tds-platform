# Issue #4: catalog authority and offline fallback

Decision approved by Rafael in the project conversation on 2026-10-02.
Base: `b701b7869a7736100348db406406f1f69a8a18b4`.
Decision also recorded in GitHub Issue #4, comment `5962161733`.

## Approved behavior with REMOTE_CATALOG_ENABLED=true

| Input | Visible catalog | Persistence |
| --- | --- | --- |
| Valid remote nonempty snapshot | Remote snapshot only, sorted | Save under existing API-scoped v2 key |
| Valid remote empty list | Empty, not bundled assets | Persist empty list as a valid snapshot |
| Network/HTTP/contract failure + valid cache | Last valid snapshot, including empty | Do not replace cache on failure |
| Failure + no valid cache | Bundled bootstrap courses | Do not label assets as remote snapshot |
| Flag false or no API configured | Bundled local catalog | Do not query remote catalog |

`[]` and `{ "courses": [] }` are valid empty publications. Missing/invalid
containers, invalid entries, missing/blank identity or invalid JSON fail the
snapshot as a whole. Silently filtering malformed entries into empty would
misrepresent a contract failure as editorial withdrawal.

The old `fallbackOnEmpty` switch and offline union with bundled courses are
removed. A withdrawn item does not return from bundled assets after a valid
updated snapshot is received and saved. Existing v2 cache keys retain complete
API URL isolation; the unknown-origin v1 cache is neither reused nor deleted.

## Boundaries

- Offline clients cannot know about server changes they have not synchronized.
- Catalog visibility is not revocation of authorization or deletion of downloaded
  content, assets, enrollment, progress, or a classroom's pinned course version.
- A valid remote result remains authoritative for the current repository instance
  even if saving the cache throws. Persistent storage remains best effort: after
  restart, a failed disk write cannot be assumed durable. No durability guarantee
  is claimed for corrupted or reset application storage.
- No schema migration, dependency update, new cache namespace or flag activation.
- The 2026-10-02 V1/V2 physical QA remains historical evidence of its tested build.
  Its old cache-plus-assets behavior is superseded by this decision, not erased
  from its screenshots/receipt. This patch is not a new physical E2E acceptance.

## Focused validation plan

Existing `course_repository_test.dart` retains its regression coverage; only the
approved empty/union expectations change. `course_catalog_policy_test.dart` adds
empty snapshots across reconstructed preferences/repositories, partial withdrawal,
bootstrap transition, malformed snapshots, HTTP errors, API isolation, in-memory
precedence, flag-off behavior, corrupt cache and real repository to Home refresh.
`home_catalog_refresh_test.dart` is unchanged and exercises navigation safety and
preservation of the enrolled edition/progress after catalog refresh.

Run from `cartilhas_app/` with the approved existing Flutter 3.44.9 SDK:
```text
flutter test --no-pub --concurrency=1 --reporter expanded test/course_repository_test.dart test/course_catalog_policy_test.dart test/home_catalog_refresh_test.dart
```
No APK/AAB, device installation, backend request, deployment or production change.
Execution evidence/status is recorded on the PR; a plan alone is not a PASS.

## Execution evidence (2026-10-02)

- 42/42 focused Flutter tests passed across the three files above, exit 0.
- Focused `flutter analyze --no-pub` on the repository and three test files:
  exit 0, `No issues found!` (4 items).
- Formatting and whitespace checks completed for the candidate.
- Dependencies resolved from the existing local cache with `pub get --offline`;
  dependency manifests/lock were not changed.
- The first test-launch attempt failed before tests because this remote shell
  lacked `ProgramFiles(x86)`. It was set only for the subsequent test process to
  the verified existing Windows directory. No global variable, ACL, sandbox,
  execution policy or SDK installation was changed.
- Codex stopped at a policy-rejected source-read command before editing. The
  coordinator prepared the patch from previously inspected GitHub source and
  tested it through the authorized desktop workflow; no Codex PASS is claimed.
- Test and analyzer logs are preserved under this isolated worktree's ignored tmp/.
  No complete Flutter/API suite or physical V1/V2 replay was run.
