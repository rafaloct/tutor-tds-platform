# Tutor TDS repository instructions

Follow the root `AGENTS.md` as the authoritative execution contract.

Keep changes narrow, evidence-backed and reversible. GitHub Issues and PRs are
project memory. Never infer authorization from chat history.

Never merge, deploy production, force-push, expose secrets, or start a second
task automatically.

Before changing code, check the canonical branch and overlapping open PRs.
Prefer existing architecture/contracts over parallel systems.

Boundaries:
- FastAPI/PostgreSQL = transactional authority.
- Flutter = authenticated/offline client.
- WordPress = public/editorial only.
- Chatwoot = support only.
- Sheets/BI = projections only.
- Drive = master/acervo when documented.
- VPS/Dokploy = operations, not media CDN.

Stop at a human gate for production, credentials, billing, destructive
operations, permissions, legal/editorial approval, privacy decisions, or
ambiguous institutional rules.
