# Corrected native acceptance — TESTED-LOCAL

Runtime source cf997d33eee5335469e0b45e906b83e1dc9304ab. Original failing16e30de evidence remains in README/12-ready; it is not relabeled PASS. #338 fixes only the real application-support parent bug discovered by that run.

Corrected clean-source APK:93614921 bytes SHA2562f70cda56638a16369c428fb9068d54d00905b4b473f5a439a099157e492e14e. Same isolated QA namespace/config and Android Debug signer as failing build; no version/signing policy change. Build226.46s PASS, install14.08s PASS. Actual installed base.apk SHA matches built APK (installed-apk.json). MP49031/VTT148 hashes match in ZIP and actual private store files (private-files.json). Full Linux CI39993808266/job120552205221:946 tests and analyze PASS, including six new binding cases; PHP/quarantine/secrets also PASS. Windows focal22 PASS/1 symlink SKIPPED was superseded by actual Linux symlink coverage, not counted as Windows PASS.

## Actual UI/filesystem journey

18 checks in one real synthetic-media journey PASS (acceptance.json/check-acceptance.py); not18 independent E2E scenarios. Coordinates came from fresh UI-tree bounds. Android API35,720x1280/density320, final software renderer. No manually created app directories, injected store, test-runner UI, remote media download or academic command.

- Before corrected launch after boot/unlock: run-as ls reports files/ead_offline absent. Welcome→EAD→synthetic empty UI (13/16).
- Prepare→verified ready with watch/remove enabled (19-watch-before). Real private MP4/VTT hashes/lengths checked independently.
- Native decoder initializes, displays first VTT cue and0/3s (21). Play progresses to3/3s and second cue (23). Hide and restore captions succeed (25/27).
- Airplane on/WiFi off initially still showed old default network asynchronously; separate probe confirmed Active default network:none before force stop, and repeated after offline play (network-disabled-confirmed.json). No offline PASS was declared from the immediate radio toggle alone.
- Force stop removes PID2524; cold restart PID4689 (process-restart.json). Public catalog shows a clear connectivity error while QA entry remains available (30). Private package reopens verified (31), native playback again progresses0→3s with VTT while no network exists (34/35).
- Remove returns empty UI, disables watch/remove (38); independent run-as enumeration finds zero remaining package files (removal.json).
- Restore original airplane0/WiFi1, active default network101. Explicit catalog refresh returns11 real public offers (41). Viewport restored to original1344x2992/480, own app force-stopped, own emulator stopped and absent from adb (cleanup.json). Physical Samsung and auxiliary machine were only queried read-only; no app/device changes there.

## Exact scope and limits

This is bundled synthetic-byte copy/integrity/private storage/native decoding/VTT/offline/restart/removal/reconnection acceptance. It is not real institutional manifest→download UI proof. The new canonical reader/current-server authority remain opt-in and default store denial is unchanged. Server producer has separate44-assertion native WP/LP evidence, reader/authority have separate unit contracts. Combining those receipts is not a claim of deployed end-to-end integration.

The3s fixture does not establish educational usefulness, long-video performance, resume-position persistence or academic synchronization. A seek diagnostic landed near the end (28); interruption-position policy was not accepted. Reopened player starts0; source has no persistence; G06 remains open. No enrollment/progress/attendance/certification action was exercised. Full roles, Authentik/linkage, real media revision/revocation/downloading, low storage/app upgrade, screen-reader and physical/Play acceptance remain NOT_RUN.

System UI ANR/host-GPU emulator exit and low host memory are retained as environment limitations. Initial and corrected cold launches had timeout reports before UI eventually rendered. This constrained debug/software session cannot accept cold-start or performance. Requested2048MB was raised to emulator minimum3072MB. Own idle Gradle daemon was stopped only after its run-owned build finished; no other user applications were closed. No snapshot saved or userdata wipe/security weakening.

Raw config hash was originally changed by Git newline normalization in the evidence copy. Scoped .gitattributes now pins original raw qa-defines.json bytes; its SHA must match47ffc848046ebfe6b62edd99dbff4f77ff797ecf19ace08426a98ce8deae01ab. Other readable receipts are not claimed raw-byte attested. PNG screenshot hashes are recorded separately.

Failing APK preserved at D:/AI-Shared/tmp/tds-offline-android-20261023/failing-16e30de.apk; corrected artifact remains at its build output path. APKs are not committed. Public1.4.1+14 untouched; inherited debug candidate1.4.2-dev+15 is not published. MERGE_ALLOWED=NO; no AAB/production/signing-key/upload gate opened. NEXT_FRONT: integrate current-server manifest through an explicitly gated real lesson/download journey in isolated staging, then broaden role-based acceptance; preserve all source-system boundaries.
