# Tutor TDS | Cloudflare + GitHub zero-config environments

**Snapshot:** 2026-10-08 | **Status:** deployment artifacts prepared; production unchanged; staging upstream isolation still needs first-time provisioning. These are not proof of production acceptance.

## 1. Observed services (not the target)

| Component | Production today | Staging today | Risk |
|---|---|---|---|
| Worker | `tutor-tds-gateway.tdsipex.workers.dev` | `tutor-tds-gateway-staging.tdsipex.workers.dev` | Separate deployed scripts and secrets |
| FastAPI | `ead.ipexdesenvolvimento.cloud/tutor-api` | `ead.ipexdesenvolvimento.cloud/tutor-staging-api` | Both healthy, both reported `compatibility_verified=false` |
| PostgreSQL | `tutor-tds-api-db-1` on VPS | `tutor-tds-staging-db-staging-1` on VPS | Distinct containers/volumes; host shared; verify ACLs |
| AnythingLLM | `ia-tutor.ipexdesenvolvimento.cloud` | QA workspaces A/B inside the production AnythingLLM instance | **Not isolated** |
| Certificate KV | Production `CERTIFICATES` namespace present | No `CERTIFICATES` binding observed | Must stay separate |
| CI/CD | GitHub repo `rafaloct/tutor-tds-platform` (private) | `staging` branch exists | Default branch is `codex/onda-0-consolidacao`, **not** `main` |

Two GitHub deployment environments were created:

- `tds-worker-staging` restricted to the `staging` branch.
- `tds-worker-production` restricted to tags matching `v*`.

Attempt to enable a required reviewer on the private repository returned GitHub 422 (plan does not allow this protection). A release tag is therefore a controlled human promotion action. **No automatic merge, no production deploy by ordinary branch push.** API compatibility and tag ancestry are checked before any deployment.

## 2. Approved architecture target

```text
GitHub pull_request (any feature branch)
       -> tests only; no credential-bearing deploy
GitHub push to staging
       -> validate + choose 'staging' deterministically
       -> protected environment tds-worker-staging
       -> tutor-tds-gateway-staging.tdsipex.workers.dev
       -> HTTPS Cloudflare Tunnel hostname ia-tutor-staging.ipexdesenvolvimento.cloud
       -> cloudflared-staging -> AnythingLLM-staging (NEW isolated volume/net)
GitHub immutable tag vMAJOR.MINOR.PATCH already in staging history
       -> validate + choose 'production' deterministically
       -> protected environment tds-worker-production
       -> production API compatibility gate
       -> tutor-tds-gateway.tdsipex.workers.dev
       -> HTTPS ia-tutor.ipexdesenvolvimento.cloud
       -> existing production AnythingLLM + existing certificate KV
Flutter staging config: ead.../tutor-staging-api + staging Worker only
Flutter production config: ead.../tutor-api + production Worker only
```

**Do not point either Worker as a Custom Domain at the whole `ead.ipexdesenvolvimento.cloud` hostname.** It must continue serving the WordPress portal and API prefixes. Keep the currently-approved `workers.dev` URL frozen in Play release builds. Changing it later is a separate signed app release requiring Android gate updates.

**No Cloudflare Pages project is needed to run a native Flutter APK.** Pages production/preview branch variables apply only to the future web portal, not to mobile builds. The Android CI selects its `--dart-define-from-file` based on the GitHub ref, and the Worker CI selects Wrangler environment similarly. Ref from pull requests never publishes a Worker.

## 3. One-time credential entry: exact destinations

**A. Cloudflare account:** `Tdsdados@gmail.com`, Account ID `8b1d9dad829dd6927091666a1f186717`, zone `ipexdesenvolvimento.cloud` (zone ID `1e8289647f4d3a4232baef2f91715f2f`).

**B. New staging AnythingLLM + Cloudflare Tunnel (required for isolation).**

1. Open **Cloudflare Zero Trust → Networks → Connectors → Cloudflare Tunnels → Create a tunnel**. Name it `tds-ai-staging`, select `cloudflared`. Add the **public hostname** `ia-tutor-staging.ipexdesenvolvimento.cloud` with HTTP service `http://anythingllm-staging:3001` (Docker network service). This Tunnel creates the DNS routing when configured. Check the exact-name record first; never overwrite a record you did not create.
2. Put its tunnel token in a **host-only** `/opt/tutor-tds-ai-staging/.env` file as `TDS_STAGING_TUNNEL_TOKEN=...`, permissions `0600`, or use Dokploy's corresponding environment-secret facility. **Do not paste it into Cloudflare Workers vars, GitHub source, or ChatGPT.**
3. Put `infrastructure/docker/anythingllm-staging.compose.yml` in `/opt/tutor-tds-ai-staging/`. Verify `docker compose --env-file .env -f anythingllm-staging.compose.yml config --quiet`; then, only after isolated staging infrastructure approval, run `docker compose --env-file .env -f anythingllm-staging.compose.yml up -d`.
4. Access admin setup through the Tailscale-secured SSH port forward, not a public open Docker port: `ssh -L 3002:127.0.0.1:3002 root@100.90.91.35` from an authorized operator terminal, then `http://localhost:3002`. Create a dedicated **staging-only AnythingLLM API key**, one default QA workspace `tds-qa-default`, and A/B QA workspaces `tds-qa-ctx-a-v1`, `tds-qa-ctx-b-v1` with synthetic documents only. Use a dedicated staging model-provider key/budget in this staging instance. Never copy production workspace documents, production AnythingLLM DB, model-provider secrets, sessions, or keys.
5. Configure Cloudflare Access to restrict the staging UI. If the API is also protected by Access, the Worker must be enhanced to send an Access service-token header securely before enabling this policy. Current gateway code only adds the AnythingLLM API-key header. Do **not** enable an incompatible Access block on `/api/v1/*` before testing.

**C. Staging Worker secret (Cloudflare Dashboard).** Go to **Workers & Pages → `tutor-tds-gateway-staging` → Settings → Variables and Secrets → Add → Type: Secret**:

| Name | Value from | Behavior |
|---|---|---|
| `ANYTHING_LLM_API_KEY` | **New** AnythingLLM staging instance | Replace old staging key only after the isolated instance is ready and just before staging promotion |

`ANYTHING_LLM_BASE_URL`, `ANYTHING_LLM_WORKSPACE`, `TUTOR_ENVIRONMENT` and synthetic `TUTOR_RAG_SCOPE_MAP` are **non-secret** vars managed declaratively by `wrangler.ci.toml`. No KV or production certificate secret is bound to staging.

**D. Production Worker secrets:** Workers & Pages → `tutor-tds-gateway` → Settings → Variables and Secrets. Existing `ANYTHING_LLM_API_KEY`, `CERTIFICATE_SIGNING_SECRET`, secret `TUTOR_RAG_SCOPE_MAP`, and certificate KV must be **preserved**. `keep_vars=true` is used for deployment. Do not rotate or copy values into staging. Keys live in the Worker, never in Flutter/Dart define.

**E. GitHub deployment environments (already created):** `rafaloct/tutor-tds-platform → Settings → Environments`.

| Environment | Add under Environment secrets | Add under Environment variables |
|---|---|---|
| `tds-worker-staging` | `CLOUDFLARE_API_TOKEN` (staging-only Workers Scripts Edit token) | `TDS_STAGING_ORIGIN_READY=true` **only after** the isolated AnythingLLM, Tunnel, workspaces and key are ready |
| `tds-worker-production` | A **different** `CLOUDFLARE_API_TOKEN` for approved production Worker release | No switching variable required |

Create the two **Cloudflare API tokens** under **Cloudflare Dashboard → Account → API Tokens → Create Token**, select `Edit Cloudflare Workers`, scope to only the proper account/resources. Do not grant DNS Edit, global API key or account admin unless a separate approved DNS/IaC task requires it. The Account ID is nonsecret and is fixed in `wrangler.ci.toml`.

GitHub environment production required-reviewer protection is unavailable on the observed private-repository plan (HTTP 422); do not claim it exists. Restrict release-tag creation and require independent review through the repository's release governance. The production deploy additionally demands `compatibility_verified=true` and a tag commit already in staging history.

**F. Tailscale and connected plugins:** Avellaria, LARGeo, authorized desktops and the VPS are already on the `tailscale-net` network. Tailscale is the **administration/SSH/QA plane**, not a publicly routable Worker origin. Cloudflare Workers cannot directly use `100.x` Tailscale addresses without a bridge/connector. The `cloudflared-staging` connector is attached to the staging Docker network, so it reaches the private service **without** any Tailscale OAuth token inside a Worker.

If a **GitHub-runner** later needs tailnet SSH, generate a separate tagged Tailscale OAuth client and store `TAILSCALE_OAUTH_CLIENT_ID` and `TAILSCALE_OAUTH_SECRET` in the dedicated GitHub deployment environment. Add ACLs that grant only required SSH/port reachability, not entire-network access. Do not invent or copy credentials for Chatwoot, Supabase, Remote Desktop Commander, Drive or other ChatGPT plugins into Cloudflare; each stays with the service that consumes it. Cloudflare does not execute those ChatGPT plugins.

## 4. Edge routing, caching and access

- Production Worker address stays `https://tutor-tds-gateway.tdsipex.workers.dev`; staging Worker stays `https://tutor-tds-gateway-staging.tdsipex.workers.dev`.
- No `Transform Rule` or `Page Rule` is needed to infer environment from the HTTP request. **The verified build/ref chooses its Worker and upstream URL.** A public HTTP header, query parameter, cookie, or request path must never be accepted as a staging/production switch.
- On Cloudflare zone `ipexdesenvolvimento.cloud` under **Caching → Cache Rules**, bypass any cache for `http.host eq "ead.ipexdesenvolvimento.cloud" and (starts_with(http.request.uri.path, "/tutor-api/") or starts_with(http.request.uri.path, "/tutor-staging-api/"))`. Do not cache authenticated or mutable API responses. Workers already use API-specific response handling.
- Under **Security → WAF → Rate limiting rules**, apply moderate, tested limits specifically to public chat/API POST routes; observe legitimate QA traffic before enforcing blocks. This requires zone permission not present in the current Wrangler OAuth (403 observed).
- Under **SSL/TLS**, verify `Full (strict)` if the VPS certificates validate. The probe proved valid TLS via Cloudflare and directly at the origin, but **SSL mode configuration has not been read** (403).
- Under **Zero Trust → Access**, protect the staging AnythingLLM admin UI after bootstrap. Do not block the programmatic Worker upstream before the Access token bridge is implemented.
- Restrict production/staging secrets and network egress. Docker bridge separation + distinct volumes prevents accidental internal DNS access but does not absolutely block outbound access to public production hosts. **For a hard guarantee that staging can never contact production, place staging on a dedicated VPS/VPC with default-deny egress to production CIDRs/hosts and separately scoped provider credentials.** Until that is implemented and proved, call the current setup logical isolation, not strict network isolation.

## 5. CI build logic and immutable endpoints

| GitHub event | Android config | Worker deployment | Credentials available? |
|---|---|---|---|
| PR from feature branch | Static tests only | Never deploy | No production secrets |
| Push to `staging` | `tools/ci/config/staging.json` via `tds_env.py` | `npx wrangler deploy --env staging` after readiness gate | Staging environment only |
| Release tag exactly `vMAJOR.MINOR.PATCH` already in staging ancestry | `cartilhas_app/config/production.example.json` via `tds_env.py` | `npx wrangler deploy` after API compatibility check | Production environment only |
| Any other branch/tag | Explicitly rejected | No deploy | None |

The environment selector contains no secrets. Staging's URL is `https://ead.ipexdesenvolvimento.cloud/tutor-staging-api` and production's is `https://ead.ipexdesenvolvimento.cloud/tutor-api`. Worker URLs remain the existing `workers.dev` names and **must not change without a new Android release**.

GitHub repository-level Actions variable `TDS_ANDROID_QA_BUILD_READY=true` can be set **once** under `Settings → Secrets and variables → Actions → Variables` after Issue #182 is resolved. Until then, the staging debug APK build is skipped; afterward, staging pushes automatically compile an isolated `com.tutortds_cartilhas.dev.dynamicqa.r<commit-prefix>` APK with a derived run ID. This is not a Play release.

**Android compilation gate:** existing Gradle debug validation erroneously requires the string `staging` in `gatewayUri.path`, but the approved Worker has `staging` in the hostname. It also forces one old FastAPI Cloud URL for isolated QA, despite allowing the canonical EAD staging API elsewhere. See [GitHub Issue #182](https://github.com/rafaloct/tutor-tds-platform/issues/182) and overlapping PRs #125/#130/#176. `tds-zero-config-build.yml` automates config selection and provides a gated automatic isolated QA APK job; it deliberately does **not** pretend a debug APK can be compiled with the current Gradle guard. It must be reconciled before enabling the full Android build step.

**Android signing:** production Play keystore is intentionally under a separate authorized notebook custodian. No action in this bundle moves or uploads it. The production Android AAB cannot be claimed Play-ready merely from CI config selection. The release readiness gates, signing and human promotion remain separate.

## 6. Apply and acceptance sequence

1. Review the zip and stage it in a new Git branch. Do not merge into existing RC worktrees or touch active PRs. Validate `python3 -m unittest discover -s tools/ci -p 'test_*.py' -v` and `npx wrangler deploy --dry-run --config wrangler.ci.toml` (and `--env staging`) from the Worker directory.
2. Provision `anythingllm-staging` and `cloudflared-staging` from the Compose file in an **independent project**, confirm `GET /api/v1/ping`, create QA-only workspaces and secret. Ensure no production DB mounts/network connections.
3. Enter the staging Worker secret, GitHub per-environment tokens and the readiness variable. Keep production Worker secret values intact.
4. Once merged on `staging`, pushing future Worker changes automatically validates, compiles and deploys only staging. Verify `/health` via TLS, followed by authorized synthetic `POST /v1/chat` A/B with matching source scope. Never log prompts, real student data or keys.
5. Resolve Issue #182 to unlock deterministic Android QA builds and run QA on an isolated Android package. Confirm profile/session/offline/role evidence and actual app rendering.
6. Before production tag/promotion: reconcile `/version compatibility_verified` and database/schema; review Worker diff, current KV bindings, signed Android release, restore/rollback evidence, rate limits and risk flags. Never change `PRODUCTION_RELEASE_READY` without true evidence.
7. Rollback Worker by deploying a previously verified immutable Worker version through Cloudflare deployment rollback after inspecting current deployments; for staging origin rollback stop only the dedicated staging Compose project. Do not edit production DNS or rotate production keys during staging incident response.

## 7. What is applied vs what is not

**Applied in the connected GitHub account:** `tds-worker-staging` and `tds-worker-production` environments and deployment branch/tag policies. Existing `staging` GitHub environment for FastAPI is untouched.

**Delivered in this package, not yet merged/deployed:** `wrangler.ci.toml`, two workflows, deterministic selector+tests, binding audit, Docker staging Compose, this runbook.

**Blocked by one-time setup:** staging-only AnythingLLM instance with QA contents, `cloudflared` Tunnel and DNS hostname, staging-only upstream secret, GitHub environment tokens, Cloudflare zone WAF/SSL verification permission; strict network egress isolation; Android Gradle Issue #182; production API compatibility false; release signing gates. Until those pass, **100% production readiness must not be asserted**.
