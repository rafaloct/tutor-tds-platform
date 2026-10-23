# First-install private parent — #338 / G26

Real Android reproduction: see ../ead-offline-android-20261023/README.md and
12-ready screenshot/XML/JSON, failing source16e30de. Public Welcome/catalog11
and empty synthetic UI worked; first prepare failed PathNotFoundException.
No native decoding or offline acceptance is inferred from build/test success.

Minimal FIX: application binding creates its direct ead_offline parent
non-recursively if absent and rejects any non-directory without following links.
Namespace creation and byte verification stay in existing store; default authority
still denies. No manual Android mkdir to bypass the failing product path.
Private platform support directory remains the trusted parent provided by
path_provider. No generic recursive creation or storage rewrite.

LARGeo Windows Flutter3.44.9/Dart3.12.2, isolated root worktree at48e0c2b plus
binding/test. Platform channel mocked only to return actual temporary support
path; real filesystem and real store install/read exercised. Five new cases PASS:
fresh parent/install/read, default denial no namespace/download, preserve another
namespace, file-parent denial, invalid namespace before parent. One symlink case
SKIPPED Windows (privilege not assumed), MUST run in Linux CI. Combined with17
current-authority tests:22 PASS/1 SKIPPED; analyze no issues, enforced lock stable.
Receipts adjacent. Existing store semantics/digests unchanged.

Source evidence9bd530a docs imported before this runtime fix. Current-head CI
and corrected exact APK native journey remain pending. Earlier940-test result
belongs to16e30de/48e0c2b, not this new binding. Rebuild is warranted by real
runtime change; preserve old failing APK and reuse warm build cache.

Rollback only binding/test; no data migration, dependency/version/signature or
release gate change. MERGE_ALLOWED=NO, public1.4.1+14 untouched.
