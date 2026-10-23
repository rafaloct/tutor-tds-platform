# Native Android QA — original failure #338

Corrected source acceptance: [CORRECTED_ACCEPTANCE.md](CORRECTED_ACCEPTANCE.md). Original results below remain historical.

Runtime source16e30de7bf7ace60f34ecc5458e4a0a728240984, clean worktree. Full940-test/analyze CI PASS; this native journey deliberately remains separate. Later48e0c2b is documentation only; no rebuild for documentation.

## Artifact

LARGeo Flutter3.44.9/Dart3.12.2. Build command from cartilhas_app:
`flutter build apk --debug --target-platform android-x64 --dart-define-from-file=<retained qa-defines.json>`.
Build730.3s PASS; install107.46s PASS on emulator-5580/API35 only.
APK93614921 bytes SHA2565cd76b664dcdb4f9f27fb9ec0052a481c40b06a459b79ebec3bce4e8a5e75814. Retained at D:/AI-Shared/tmp/tds-offline-android-20261023/failing-16e30de.apk (not committed).
Android Debug signer SHA2566af6c35e5ede92952c97861129900eabd297d006ca50db952cb60880deddc4f8; apksigner verify PASS.
AAPT: minSdk24,target/compileSdk36; candidate1.4.2-dev/versionCode15 inherited from branch; public1.4.1+14 untouched. Target build flag x64; bundled native-code list includes arm64-v8a/armeabi-v7a/x86_64 due native dependencies. Not a production artifact.
Both bundled fixture lengths/digests checked from ZIP: MP49031,VTT148; artifact.json records exact hashes/config/source/namespace. No real media, accounts, academic data or production writes.

## Actual journey results

| Journey | Result | Evidence |
|---|---|---|
| Install isolated debug namespace | PASS | artifact.json; Android install Success |
| Welcome public entry | PASS after environment recovery |06-app-welcome PNG/XML/JSON |
| Public EAD catalog | PASS,11 offers displayed |08-catalog PNG/XML/JSON; this is public real catalog read, not enrollment/progress |
| Synthetic offline empty state | PASS, watch/remove disabled |10-offline-empty PNG/XML/JSON |
| First prepare on actual application-support binding | FAIL |12-ready PNG/XML/JSON: PathNotFoundException; files/ead_offline absent in run-as query; #338/G26 |
| Native video decoding/play/VTT | NOT_RUN | preparation failed; no success inferred from widget/file tests |
| Force-stop/reopen/airplane-mode/removal | NOT_RUN | blocked downstream of first prepare |
| Institutional reader/server/download/academic sync | NOT_RUN | synthetic fixture is bundled, no remote media download |

Root: binding returns nested files/ead_offline/qa_<id> without creating the parent; safe store mkdir is intentionally non-recursive. Earlier tests inject roots whose parents already exist. Fix under test separately in #338; do not create the missing parent manually to make QA pass.

Environment: first snapshot/software emulator was unresponsive; two UI dump timeouts recorded. Controlled host-GPU cold boot exited1. Final software cold boot recovered; actual requested2048MB was increased by emulator to minimum3072MB. Own idle Gradle daemon ended, other apps/worktrees/physical Samsung untouched. Android System UI ANR is retained in04-software-coldboot; Wait chosen by actual tree bounds. Settings baseline opened; app eventually rendered with its own PID. Resolution temporarily720x1280/density320, originals1344x2992/480, restore required at cleanup. This constrained session cannot support performance/cold-start acceptance. No security setting changed, no wipe-data/snapshot save.

Tools qa-ui.py/verify-apk.py retained. Every tap center came from fresh UI tree. Earlier launch raced pending install, failed type3, and was corrected only after install Success; no product defect inferred from that race. Boundary diagnostics preserve environment limitations.

Rollback/cleanup: restore emulator wm size/density, then stop only run-owned emulator. Keep failing APK/evidence; no AAB, no merge, no production signing/upload. MERGE_ALLOWED=NO.
