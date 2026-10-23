# Native Android QA environment boundary

Source16e30de clean build730.3s PASS; install107.46s PASS. APK bytes/assets/signature checked independently. Early resolve/launch was issued before install finished and failed type3; corrected after Success. No product failure inferred from that race.

Initial run-owned API35 emulator loaded an old snapshot with software rendering; UI tree dump timed out30s twice; launch request returned0 but no own-app PID or resumed activity was observed; exit-info and AndroidRuntime/Flutter error queries did not identify an app crash. This is BLOCKED/UNKNOWN, not native player PASS or proven application defect. UI capture scripts stop after30s; raw failure receipts retained via coordinator tooling.

Host resource probe:16GB total,1.1GB free. Own Gradle52100 confirmed finished and idle since13:56:26; stopped only that PID, not all Gradle/user apps. Run-owned emulator stopped gracefully, no snapshot saved. No physical device or other workspace changed.

Controlled cold boot: same persisted AVD/userdata/app, no snapshot,2048MB, host RTX3060; free RAM improved to~2.98GB. Renderer confirmed host GPU; boot completed67852ms, then emulator exited1 at105.88s, no explicit crash/error in captured emulator output. Device became offline/disappeared. This prevents product acceptance; no APK rebuild warranted.

Next isolated diagnostic: cold boot same AVD/no snapshots/2048MB/software renderer, with~4GB now free and build daemon gone. Separates snapshot/GPU instability from app behavior. Do not repeat equivalent UI operations before device operationality is proved. No wipe-data/security weakening/system configuration edits.
