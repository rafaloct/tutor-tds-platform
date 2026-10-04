# Tutor TDS — GitHub-first agent coordination

Status: proposed coordination layer. This document does not enable auto-merge
or production access.

## Goal

Replace chat/Gmail copy-and-paste handoffs with GitHub as the durable task queue
and evidence store.

```
Issue/task
  -> coding agent
  -> isolated branch
  -> draft PR
  -> CI
  -> reviewer/coordinator
  -> technical fix OR human gate
  -> human-authorized integration
```

## Sources of truth

1. Repository code and canonical contracts.
2. Related GitHub Issue.
3. Pull request diff, checks, comments and review threads.
4. Runtime evidence only when explicitly authorized.

Chat history is not project memory.

## Roles

- TDS API: FastAPI/PostgreSQL/domain/RBAC.
- TDS Flutter: client/offline/account-scoped UX.
- TDS WordPress: public/editorial portal.
- TDS Infra: CI, staging, observability, backup/recovery, Cloudflare/Dokploy.
- TDS Reviewer: read-only PR review and next-action routing.

Codex consumes the root `AGENTS.md`. GitHub-compatible reusable profiles live
in `.github/agents/*.agent.md`.

## Task lifecycle

Use one Issue per bounded task. Include TASK_ID, one goal, allowed scope,
do-not-touch scope, acceptance criteria/tests, and human-gate state.

Suggested semantic states (labels can be added later if account/repository
permissions allow them):

- `agent:ready`
- `agent:working`
- `agent:review`
- `human-gate`

If labels are unavailable, persist the state in Issue/PR comments.

## PR lifecycle

Agents open draft PRs with task reference, base/head SHA, changed scope, tests,
CI state, risks, rollback, and remaining human gates.

Green CI is technical evidence, not merge authorization.

## Human-only interventions

Automation stops for production, secrets/credentials, paid services/billing,
destructive persistent-data operations, permissions/OAuth, legal/editorial/
privacy approvals, or ambiguous institutional rules.

Request only the smallest exact action needed.

## CI and branch protection

Native private-repository enforcement may be plan-limited. Until protection is
available:

- keep `MERGE_ALLOWED=NO` in agent instructions;
- preserve secret scan and always-on verification;
- use `required-pr-gate` after its owning PR is integrated;
- never enable auto-merge;
- merge only after explicit human authorization with expected head SHA.

This is a compensating process control, not equivalent to branch protection.

## ChatGPT Work / Codex model

Use Codex for implementation/test/repair loops. Use a coordinator/reviewer for
PR review, routing and human-gate detection.

When repository-scoped PR event tasks are available in the ChatGPT workspace,
configure them to:

1. Read `AGENTS.md` and the related Issue.
2. Inspect PR diff, base/head SHA, CI, comments, and overlap.
3. Never merge or deploy production.
4. If technically fixable, create the smallest next coding task in GitHub.
5. If human action is required, state the exact action and stop.
6. Persist the checkpoint in GitHub; never ask the human to relay agent output.

## Migration from the old worker protocol

- New tasks become GitHub Issues instead of Gmail READY messages.
- Existing CLOUD workers may finish in-flight tasks but must checkpoint in GitHub.
- Do not create new CLOUD-numbered workers once this loop is operational.
- Gmail/PULL remains fallback only.

## Rollback

This layer is instructions/documentation only. Revert these files to remove it.
It does not modify runtime, database schema, production, credentials, or infra.
