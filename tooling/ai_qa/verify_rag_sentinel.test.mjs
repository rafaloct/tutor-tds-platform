import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const script = fileURLToPath(new URL('./verify_rag_sentinel.mjs', import.meta.url));

test('refuses a non-staging hostname before any synthetic request', () => {
  const result = spawnSync(process.execPath, [script], {
    env: {
      ...process.env,
      TDS_AI_QA_ENV: 'staging',
      TDS_AI_SENTINEL_URL: 'https://tutor-production.example',
      TDS_AI_SENTINEL_MARKER: 'TDS_AI_SENTINEL=test',
    },
    encoding: 'utf8',
  });

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /hostname must carry a staging label/);
});

test('refuses a non-staging environment before any synthetic request', () => {
  const result = spawnSync(process.execPath, [script], {
    env: {
      ...process.env,
      TDS_AI_QA_ENV: 'production',
      TDS_AI_SENTINEL_URL: 'https://tutor-staging.example',
      TDS_AI_SENTINEL_MARKER: 'TDS_AI_SENTINEL=test',
    },
    encoding: 'utf8',
  });

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /must be exactly "staging"/);
});
