# #335 recovery boundary

Observed: CI81ec0ed fails polling then10minute timeout; recovered uncommitted
repair still times out30s at installation operation1 and teardown. Raw first
attempt retained. Expected: real filesystem operation concludes before UI/asserts
or temp cleanup. Responsible boundary: Flutter widget fake-async zone versus
native filesystem streams/async authorization. Likely root: awaiting an existing
future inside runAsync does not move the zone in which it was initiated.
Affected files: synthetic QA screen test operation observer; widget test.
Structural correction under verification: initiate button tap AND await the
tracked operation inside the same runAsync; keep pump outside; bound teardown.
No storage/domain changes. Original source worktree preserved. UTF-8 caption
assertion also corrected in the copied test; source fixture is UTF-8, not Latin1.

Second attempt: initiating tap in runAsync did not resolve the failure. Stop
blind retries. The trace still reports awaitOperation, not tapOperation; inspect
exact line and initial mount lifecycle before further changes. Existing fake
zone origin remains a hypothesis, not an accepted root cause. Failed test run
terminated after first failure was captured to avoid another redundant timeout.

Exact second trace line98 is initial awaitOperation0, so changing tap origin
cannot fix initial _open(). Structural correction: test hook accepts a deferred
operation callback instead of an already-started future; test starts that work
in Zone.root and tracks its future. This includes init/open, prepare and remove;
without a test runner the screen invokes the same operation immediately as
before. No production I/O is moved to a new zone. Test runAsync awaits actual
completion and pump remains in fake-async. This is a test scheduling boundary.

Third attempt: fake-zone timeout eliminated, failed-stream test PASS; valid
install now fails size_mismatch. Proven new root: Linux/Git VTT148 bytes SHA
7dd0700f14781baace675332cab287a59bd3156593edde696a5f4c69589df19a;
Windows checkout155 bytes SHA25d7ebe12a2530a17e0e307e4eaaaa2e0b6bd86e7b781e37c244f644b6aedca6.
MP4 unchanged9031 bytes/b1c2ca... on both. Git autocrlf modifies seven line endings
of VTT. Correct scoped attributes preserve exact stored bytes (-text), restore
only the run-owned fixture to its original Git bytes. Do not loosen manifest
integrity or alter the original writer worktree. This also protects APK assets.
