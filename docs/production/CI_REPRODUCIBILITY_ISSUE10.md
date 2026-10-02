# CI reproducibility: Issue #10 (2026-10-02)

Base inspected: `43ef61a3f0c8ece003ac599992ea8e1e7004ffa4`, PR #9.
Failing CI: https://github.com/rafaloct/tutor-tds-platform/actions/runs/37059071100

## Narrow corrections

1. The hierarchy test now freezes only `app.classrooms.datetime` at the first
   course day, 2026-10-01 12:00 UTC. Authentication clocks, production code,
   expected-progress calculation and hierarchy assertions are unchanged.
2. Two historical proofs are restored byte-for-byte from the preserved Windows
   originals, after verifying their SHA-256 against the existing Wave 1 manifest.
   Only CRLF/LF differs from the prior Git blobs; JSON content is identical.
   `.gitattributes` uses `-text` for these exact paths to prevent conversion;
   `whitespace=cr-at-eol` permits their original CRLF representation in diffs.
   No manifest hash, acceptance status or observed field was rewritten.

| Historical proof | Unchanged approved SHA-256 |
| --- | --- |
| `cloud-context-isolation.json` | `8ab1222b51399b600c54d01e8aedb9f4881e85353af7d6b59edb216272a44054` |
| `context-android-gate.json` | `79348f39a8bf90cfb83ae14840ececaf4d18f343cebfc45f5f31a45f7a129139` |

## Local evidence

The two CI failures were reproduced in an isolated LF worktree before correction.
After correction: the two formerly failing tests plus the existing tamper-rejection
`test_approval_requires_successful_gate_and_exact_evidence_hashes` passed (3/3).
The locked Python environment was reused; no full local suite was run.

Verified both staged blobs and Git checkout filters with `core.autocrlf=false`,
`true` and `input`: all six comparisons match the original approved hashes.
`git diff --ignore-space-at-eol` shows no semantic changes in the two proofs.
`wave1-acceptance.json` is unchanged. `git diff --cached --check` passes.

Targeted command, from `api/`, using the already locked Python interpreter:
```text
python -m pytest tests/test_classrooms.py::test_classroom_preserves_teacher_monitor_student_hierarchy tests/test_dynamic_learning_qa.py::test_default_cli_validates_local_gate_without_remote_or_output_writes tests/test_dynamic_learning_qa.py::test_approval_requires_successful_gate_and_exact_evidence_hashes --tb=short -q
```

The original developer worktree and its untracked files remain untouched.
No production/staging deployment, migration, Flutter build or catalog E2E occurred.
Dependencies and CI workflow were not changed. Integration CI must pass before
merging PR #9; its run and final status are recorded on Issues #1/#10 and PR #9.
