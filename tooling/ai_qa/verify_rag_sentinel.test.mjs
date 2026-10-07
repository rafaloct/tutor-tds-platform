import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import test from 'node:test';
import { fileURLToPath } from 'node:url';

const script = fileURLToPath(new URL('./verify_rag_sentinel.mjs', import.meta.url));
const contextA = JSON.stringify({
  course_id: 'qa-course-a',
  course_version_id: 'qa-v1',
});
const contextB = JSON.stringify({
  course_id: 'qa-course-b',
  course_version_id: 'qa-v3',
});
const baseEnv = {
  ...process.env,
  TDS_AI_QA_ENV: 'staging',
  TDS_AI_SENTINEL_URL: 'https://tutor-staging.example',
  TDS_AI_SENTINEL_MARKER_A: 'TDS_CTX_A_v1',
  TDS_AI_SENTINEL_MARKER_B: 'TDS_CTX_B_v3',
  TDS_AI_SENTINEL_CONTEXT_A: contextA,
  TDS_AI_SENTINEL_CONTEXT_B: contextB,
};

function run(env) {
  return spawnSync(process.execPath, [script], {
    env,
    encoding: 'utf8',
  });
}

test('refuses a non-staging hostname before any synthetic request', () => {
  const result = run({
    ...baseEnv,
    TDS_AI_SENTINEL_URL: 'https://tutor-production.example',
  });

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /hostname must carry a staging label/);
});

test('refuses a non-staging environment before any synthetic request', () => {
  const result = run({
    ...baseEnv,
    TDS_AI_QA_ENV: 'production',
  });

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /must be exactly "staging"/);
});

test('requires both markers and contextual scopes before any request', () => {
  const env = { ...baseEnv };
  delete env.TDS_AI_SENTINEL_CONTEXT_B;
  const result = run(env);

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /CONTEXT_A and CONTEXT_B are required/);
});

test('rejects malformed learning context before any request', () => {
  const result = run({
    ...baseEnv,
    TDS_AI_SENTINEL_CONTEXT_A: JSON.stringify({
      course_id: 'qa-course-a',
      course_version_id: 'qa-v1',
      experience_id: 'exp-without-module',
      experience_type: 'scenario',
    }),
  });

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /valid CourseVersion scope/);
});

test('requires distinct A and B scopes before any request', () => {
  const result = run({
    ...baseEnv,
    TDS_AI_SENTINEL_CONTEXT_B: contextA,
  });

  assert.notEqual(result.status, 0);
  assert.match(result.stderr, /scopes A and B must be distinct/);
});
