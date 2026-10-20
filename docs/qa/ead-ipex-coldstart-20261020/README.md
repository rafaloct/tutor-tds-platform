# Issue #309 — Android WebView cold start, 2026-10-20

Status: **Android emulator QA PASS; production/publishing gate BLOCKED**. The cold-start timeout defect has a tested candidate. The earlier intermittent zero-time media behavior has not been reproduced with CDP and its cause remains unknown.

## Lineage and controls

Worktree `D:/AI-Shared/work/tds-issue309-webview-coldstart-20261020`, branch `agent/issue-309-webview-coldstart-20261020`, base `184d7616a6ca2157f8977b1bb2f7052f387822d1` (PR #307 head). PR #310 is a docs branch from PR #307. The #308 pilot media was previously authorized; the test uses those files directly and does not republish lesson 1420. No merge, production deploy, Play Store, signing, academic record or WordPress change occurred.

## OBSERVED / TARGET / DECISION / UNKNOWN

- **OBSERVED:** the original 20-second timer began in `initState`, before native WebView setup. In an earlier API 35 run, JavaScript setup alone took 105.869 seconds with a SafeBrowsing `TimeoutException` and ANR. This is sufficient to exhaust the original timer before HTML loading starts.
- **OBSERVED:** the candidate separates a 120-second native setup deadline from the 20-second local HTML deadline, logs sanitized stages and provides retry. Limiting Gradle to 3 GiB heap, 768 MiB Metaspace and two workers allowed the runner to complete under LARGeo memory pressure (0.806 GiB minimum free in the first CDP run).
- **OBSERVED:** earlier runs after valid HTML, VTT and metadata had one playback advance to 4.033814 seconds and two real-wait attempts remain at zero after `mp4_playing`. One advancing run failed only because a JavaScript return type was misrepresented in the assertion. The integration test now normalizes JavaScript values.
- **OBSERVED:** the CDP instrumented runs subsequently passed cold process launch and warm reopen on emulator-5554, API 35. The final run showed time 3.279 seconds/17 frames on cold playback, time 2.248 seconds/23 frames on warm playback, then 35 cues, caption show/hide, pause, advancing time and frames after resume, and return to the lesson. The cold screenshot captures the video at 0:09 with Portuguese caption text outside the image.
- **OBSERVED:** CDP Network matched MP4 subresource error `-1` to `Network.loadingFailed` with `net::ERR_ABORTED`, `canceled=true`, no `blockedReason`, after an initial HTTP 206 MP4 response. A later MP4 Range request also returned 206 and playback advanced. The same cancellation occurs when leaving a functioning player. This makes `-1` insufficient evidence of a Safe Browsing block or failed playback. CDP Media showed transient `DECODER_UNDERFLOW`/`DEMUXER_UNDERFLOW` followed by buffering recovery. `Media.playerErrorsRaised` carried empty error arrays; the HTMLMediaElement `error` remained null.
- **TARGET:** robust first launch, MP4/VTT playback and accessible controls without weakening URL policy, CSP or access checks.
- **DECISION:** media rights are already accepted in #308. Merge, production, signature, Play Store and publication remain human gates.
- **UNKNOWN/BLOCKED:** the zero-time occurrence did not recur under CDP, so its first distinguishing condition and exact cause are unproven. A direct Android Chrome comparison was blocked by automatic review of the ADB launch command. The physical tablet was not used because emulator-only causation has not been established. Do not infer production readiness from `onPageFinished` or `mp4_playing` alone.

## Reproduction and evidence

The QA integration test enables `AndroidWebViewController.enableDebugging(true)` only when `kDebugMode` and `DYNAMIC_QA_ISOLATED_PACKAGE=true`. Production code does not enable Chromium debugging. The probe at `cartilhas_app/tool/ipex_cdp_probe.py` captures Network request/response/Range/cancellation, Media pipeline events, time, buffered ranges, ready/network state, first and total frames, decoder/media error, cue count and caption state. URLs, cookies and opaque request/player IDs are removed or hashed. Preserve Safe Browsing, allowlist, CSP, captions outside the image, playback controls and academic isolation.

| Gate | Result | Evidence |
| --- | --- | --- |
| `flutter pub get --enforce-lockfile` | PASS | pinned Android WebView dev dependency |
| Focal `flutter analyze --no-pub` | PASS | 0 issues |
| `flutter test --no-pub test/ead_ipex_mp4_player_test.dart` | PASS | 13/13, including native/document deadlines and retry |
| Android process cold + warm reopen, API 35 | PASS | final integration runner `cdp-run4-flutter.log`: `All tests passed!` |
| MP4 effective advance, decoded frames, 35 VTT cues, captions show/hide, pause/resume, return | PASS on emulator | JS assertions and CDP samples; screenshot |
| Catalog/lesson access | PASS in focal tests | mobile content gate and editorial revocation remain enforced |
| Compare progressing vs zero-time CDP traces | INCOMPLETE | progressing trace captured; zero-time condition did not recur |
| Direct Android Chrome media comparison | BLOCKED | automatic review rejected ADB URL launch |
| Physical QA/production/publishing | NOT_RUN | human/release gate; no emulator-only conclusion |

Local evidence directory: `D:/AI-Shared/test-results/tutor-tds/issue309-webview-coldstart-20261020/`. Share sanitized `cdp-run4.jsonl` (SHA-256 `D5F21297E70908F4430110573B30EE7BD6AAB02E80786F823CA20E87835F670F`) and `cdp-run4-cold-playing.png` (SHA-256 `97B18CAAFD1D775FFDE94460DC1ACFD14B8A42CFD5B7527714EC5A1B340C9A61`). Full Flutter runner logs include local VM service URIs and stay local. The older `issue309-uncommitted-integration-qa-debug.apk` predates this continuation and must not be used for acceptance.

The Android candidate can be reviewed in a draft PR. #308 remains blocked for progressive production publication until the residual intermittent playback risk and release gates are resolved. No new Issue was opened.
