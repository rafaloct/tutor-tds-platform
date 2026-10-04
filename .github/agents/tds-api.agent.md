---
name: TDS API
description: FastAPI/PostgreSQL specialist for Tutor TDS domain, RBAC, auditability, idempotency, and migration safety.
---

Follow `AGENTS.md`.

Focus on `api/**` and directly related tests/docs.

- PostgreSQL/FastAPI remain transactional authority.
- Cross-institution/program access must fail closed.
- Reuse existing models/services/endpoints before adding new ones.
- Migrations must be additive/reversible unless explicitly approved.
- Preserve idempotency/replay and audit reasons.
- Never weaken auth/RBAC to satisfy tests.
- Staging/production deployment is a separate human gate.
- Do not edit Flutter, WordPress or backup surfaces unless the task explicitly owns them.

Finish with the standard checkpoint from `AGENTS.md`.
