# QA evidence and practical limits

## Results produced in this increment

| Layer / case | Environment | Result | Evidence / practical limit |
|---|---|---|---|
| New manifest producer with filesystem negatives | Cloud Linux Docker PHP 8.3 CLI, no network | PASS, 393 assertions including repeated helper invariants | `tests/test-offline-manifest.php`; temporary actual files, links, lock, sparse oversized file; WP/LP stubs; not 393 independent scenarios |
| Existing editorial contract | Same container | PASS, 63 assertions | Runs as prerequisite to offline fixture; rights/source/caption/editor behavior preserved |
| Existing ETag contract | Same container | PASS, 47 focal assertions (+63 prerequisite) | `tests/test-etag.php` |
| PHP syntax | Same container | PASS, all 8 plugin/test PHP files | `php -l`; helper and entrypoint included |
| Existing gzip/identity/ETag HTTP | LARGeo PHP 8.4.6 + Python 3.13, read-only existing #334 source | PASS, 13 real loopback HTTP requests | `test-etag-http.py`; stubs behind actual PHP HTTP, **not real WP**; unchanged class SHA below |
| Server-generated JSON → real unchanged Dart parser | LARGeo Dart 3.12.2 from Flutter 3.44.9 | PASS, 3 checks | Server payload accepted, round-trip retains revision, unexpected revision JSON key rejected. No Flutter UI/Android |
| Whitespace and exact-change review | Cloud Git | PASS | `git diff --check`; no API/Flutter production source, release or lockfile changes |
| Native WP/LP/DB and actual HTTP manifest/media integration | Disposable cloud WP6.7.2/LP4.3.6/MariaDB11.4/PHP8.3.20 | PASS44/44; cleanup5/5 | `docs/qa/ead-offline-manifest-runtime-20261022/acceptance.json`; synthetic data/bytes, actual engine/hooks/REST, no stubs |
| Native WP HTTP JSON → unchanged Dart | LARGeo Dart3.12.2 | PASS3/3 | Native payload accepted, roundtrip, strict unknown-field negative; parser SHA unchanged |
| Institutional staging / browser form / deployment | Not attempted | NOT_RUN | Disposable runtime does not prove institutional theme/proxy/editor UX |
| Native offline Android cold restart/airplane mode | Existing #335 owner repairing widget fixture | BLOCKED | #334 Flutter CI failure on exact base; no APK claimed or installed here |
| Full eight-role institutional workflow on final SHA | Not exercised | NOT_RUN | Old source/test receipts do not accept a new composition |
| AI real-course relevance / data protection / module isolation | Not exercised | NOT_RUN | Historical CourseVersion sentinel is narrower |
| Accessibility/performance/security E2E/release upgrade | Not exercised | NOT_RUN | No distribution acceptance claimed |

Pinned PHP image used:
`php@sha256:60a100afa8efd88c0f556ce60e891c9bb8b1e8bca15721e4db07eca4fa79c07a`.
Containers ran `--network none`, repository bind-mounted read-only; only a
synthetic manifest output directory was writable in the export run. No daemon
restart or existing service change. Local PHP installation was unavailable
(non-root/no sudo/apt metadata); existing Docker was used instead, following
cloud runtime Docker guidance. No secrets were read or printed.

Producer run command (from repository root):

```sh
docker run --rm --network none \
  --mount type=bind,src="$PWD",dst=/repo,readonly -w /repo \
  php@sha256:60a100afa8efd88c0f556ce60e891c9bb8b1e8bca15721e4db07eca4fa79c07a \
  php wordpress/tds-learnpress-editorial/tests/test-offline-manifest.php
```

The cross-language proof used an exported JSON from that producer's actual
fixture. LARGeo temporary folder:
`D:/AI-Shared/tmp/tds-manifest-contract-cloud-20261022`. The manifest parser was
copied byte-for-byte from the source and confirmed on both hosts:
SHA-256 `4f9c188f0c552385f15d11b72f3dfd4aeafcf1147240adc9789401f4367ed5ac`.
The tiny standalone check only imports that parser and uses Dart IO/JSON. The
committed equivalent, with repository-relative import, is
`wordpress/tds-learnpress-editorial/tests/verify-flutter-manifest.dart`.
The existing editorial class used for Windows HTTP regression has raw Windows
SHA-256 `714c0c9a86d138401c3ab90d21b857be49d8f616e39bf66f4be911ce833c1e64`.
After CRLF→LF normalization its SHA-256 is
`fe83864d4ac082163d493636a88fd044bc54e0529b6e334614986644a8f7ad16`,
matching the unchanged cloud candidate file. Byte-identical files were not
claimed for this HTTP source; the Dart parser copy was byte-identical.

## Historical evidence, not new acceptance

- `production/evidence/wave2a-physical-acceptance-2026-10-01.json`: version-pinned
  course publication/old-cohort continuity on POCO. Not offline native MP4 QA.
- `production/evidence/classroom-access-physical-acceptance-2026-10-01.json`:
  Classroom cache/revocation/PDF, not the new lifecycle policy or every role.
- `production/evidence/certificate-human-approval-emulator-2026-10-06.json`:
  request/review UX and referenced real staging API→Worker proof; do not flatten
  approval, generation and validity.
- `production/evidence/ai-rag-courseversion-sentinel-staging-2026-10-06.json`:
  synthetic A/B CourseVersion isolation, not useful real curricular answers or
  a proved module scope.
- `production/evidence/class-lifecycle-e2e-attempt-20261012.json`: six backend
  checks PASS, Android build blocked by swap pressure, no E2E PASS marker.
- `qa/ead-native-owner-final-20261020/README.md`: actual clone HTTP shared-parent
  ownership guard, not live production permission proof.
- #326: Android registration/form evidence on its exact #324-based artifact,
  not identity federation or conversion measurement.

Current selected GitHub CI: #324 and #316 relevant checks SUCCESS; #332 lab
policy SUCCESS; **#334 Flutter checks FAILURE** run 39851450214. Exact IDs in
`state-recovery.json`. Recheck on the final reviewed head; no inherited green
claim. The PHP workflow runs the new producer tests when this diff reaches PR CI.

## Risk-based coverage strategy

`coverage.csv` enumerates selected combinations of role × journey × system state
× platform × connectivity × permission × version. High-risk transitions combine
multiple dimensions intentionally; it is a planning matrix with honest current
results, not a claim of exhaustive pairwise generation or E2E execution.

Use boundary tests for numeric capacity, attendance thresholds, file sizes,
source/edition changes and TTLs. Pair account A/B with reconnect, late response,
role revoke and stale version. Pair coordinator activation/closure with each
consumer role. Test each platform boundary (portal, API, Flutter, native player)
using actual authoritative readbacks, and preserve one immutable artifact per
run. Synthetic policy/contract results cannot fill real integration cells.

Separate acceptance types:

- Unit/policy: deterministic role and transition rules, no network.
- Contract: typed payload, version/errors, negative authorization and bounds.
- Integration: actual isolated WP/LP+DB, API/Postgres, Worker/RAG interfaces.
- End-to-end: visible user task plus downstream role readback on exact artifact.
- Regression: impacted existing entrypoints and shared auth/cache boundaries.
- Security: identity collision/replay/IDOR, private cache, path/link handling.
- Accessibility: TalkBack actual task and spoken controls, text scaling/focus.
- Performance: measured cold startup, jank, memory/battery on chosen devices.
- Resilience: interruption/kill/restart/storage exhaustion/outage and recovery.
- Product acceptance: useful course outcome and consistent institutional record.

A final release suite is warranted on the frozen composition. Repeated broad
runs before a source change or unresolved failure adds no proof. Preserve
failed runs and honor the two-failure boundary rule on the affected front.

## Continuation: native runtime and republish finding

[Runtime report](../../qa/ead-offline-manifest-runtime-20261022/README.md) retains
all failed/diagnostic attempts and the44-case accepted run. The native server
HTTP payload was additionally checked on LARGeo with the same byte-verified
Dart parser (3 checks PASS), via
`D:/AI-Shared/tmp/tds-manifest-contract-cloud-20261022/check-runtime.dart`.
The committed equivalent is `verify-native-manifest.dart` beside the runtime
receipt. No Android UI, decoding or institutional staging acceptance is implied.
G25 records confirmed native LP cleanup of unpublished lesson associations;
automatic reattachment is forbidden. Recovery used the existing authorized
LearnPress editor model, not a source-policy bypass. The risk matrix now has34
rows and the gap register25 items.

## 2026-10-23 Flutter reader continuation

TESTED-LOCAL:25 unit/contract tests PASS; focal Dart analyze no issues on
LARGeo Flutter3.44.9. See `../../qa/ead-offline-reader-20261023/README.md`.
Mock streams are not real integration. #335 preserved; release authority,
actual HTTP reader and Android offline journey remain NOT_RUN. Coverage35 rows.

## 2026-10-23 #335 recovered repair

31 widget/store/HTTP tests PASS after deferred test scheduling and exact-byte
Windows fixture correction. Original writer work preserved; three failed attempts
and boundary diagnosis retained in `../../qa/ead-offline-widget-recovery-20261023/`.
Full current CI and Android synthetic player pending. Matrix37 rows.
