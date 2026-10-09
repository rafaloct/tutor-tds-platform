# Tutor TDS: Zero-Config Build + Cloudflare environment package

This package is an overlay for `rafaloct/tutor-tds-platform`, based on the **staging** branch structure as inspected on 2026-10-08. It contains no credentials and changes no live service by itself.

## Contents
- `.github/workflows/tds-cloudflare-worker.yml`: deterministic staging branch / production release tag Worker deployment, secrets scoped to GitHub environments.
- `.github/workflows/tds-zero-config-build.yml`: automatic selection and validation of public Android config by Git ref, plus an isolated QA APK job enabled once the Gradle guard #182 is fixed; no manual variables per run.
- `cartilhas_app/cloudflare/tutor-tds-gateway/wrangler.ci.toml`: reuses the **existing** Worker identities; production-only certificate KV and secrets, separate staging vars and upstream.
- `tools/ci/tds_env.py`, `tools/ci/config/*.json`, tests, and read-only Cloudflare binding audit.
- `infrastructure/docker/anythingllm-staging.compose.yml`: a NEW staging-only container/volume/network and Cloudflare Tunnel connector, not the production stack.
- `docs/operations/TDS_CLOUDFLARE_ZERO_CONFIG_RUNBOOK.md`: complete architecture, bootstrap locations for secrets, security gates and rollback.

## Check before applying
```bash
python3 -m unittest discover -s tools/ci -p 'test_*.py' -v
python3 tools/ci/tds_env.py --ref refs/heads/staging --validate-only
python3 tools/ci/tds_env.py --ref refs/tags/v1.4.0 --validate-only
```

Run the Wrangler dry-run commands from `cartilhas_app/cloudflare/tutor-tds-gateway` **after overlaying on a repo checkout with `src/index.js`**:
```bash
npx --yes wrangler@4.147.0 deploy --dry-run --config wrangler.ci.toml --env ""
npx --yes wrangler@4.147.0 deploy --dry-run --config wrangler.ci.toml --env staging
```

**Important:** This bundle is not a claim that the staging service is already provisioned or that a Play AAB can be signed on CI. It deliberately fails closed until the bootstrap and project human gates in the runbook are satisfied.
