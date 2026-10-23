# Current editorial authority — TESTED-LOCAL

Base81ec0edd10f2de319d1e3ab00cb964307c761ff5, #336 continuation.
The existing VerifiedOfflineReleaseAuthority now has an opt-in adapter that
fetches a fresh canonical server manifest for every verification and compares
all typed metadata (identity/revision/URLs/lengths/SHA/captions/title). Local
approval flags alone never authorize installation. Revoked/malformed/mismatched/
unavailable responses deny. Default application authority still denies; no UI
or production download enablement. This is public media authority only.

LARGeo Flutter3.44.9/Dart3.12.2, isolated worktree at the exact base plus three
scoped files. Commands in cartilhas_app:

- flutter pub get --enforce-lockfile: PASS, tracked lock unchanged.
- dart format on the adapter/binding/test: PASS.
- flutter test --no-pub test/editorial_offline_release_authority_test.dart test/offline_manifest_repository_test.dart --reporter expanded: PASS42 (17 adapter +25 reader).
- dart analyze lib/features/ead_offline/editorial_offline_release_authority.dart lib/features/ead_offline/offline_package_binding.dart test/editorial_offline_release_authority_test.dart: PASS, no issues.

Raw receipts adjacent. Adapter tests use actual reader with MockClient;
store boundary test proves rejected release creates no root/download. These are
not staging/Android/live integration proof. A check at install start does not
promise instantaneous revocation during an in-flight download or offline
playback; no new revocation policy is invented. Trusted server validation is
provided by the existing producer/native runtime evidence, not local booleans.

CI on previous81ec0ed: full analyze PASS, PHP/quarantine/secrets PASS;
Flutter unit/widget FAIL with921 passed and exactly2 failures in existing #335
widget tests (waitFor line33 and10min timeout). Job120206409180 inspected.
Current-head CI must be assessed separately. No suite-green claim.

Cloud transport briefly unavailable; LARGeo tests completed independently;
cloud restored without losing files. Original #335 worktree untouched.
Rollback additive adapter/test + binding comment. No migration/dependency/version
or release gate change. MERGE_ALLOWED=NO; public1.4.1+14 preserved.
