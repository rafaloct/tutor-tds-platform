#!/usr/bin/env node

// Staging-only, read-only RAG proof. It deliberately prints no prompt or model
// response; its output is safe to attach to an issue or draft PR.
const environment = process.env.TDS_AI_QA_ENV;
const gatewayUrl = process.env.TDS_AI_SENTINEL_URL;
const marker = process.env.TDS_AI_SENTINEL_MARKER;

if (environment !== 'staging') {
  throw new Error('TDS_AI_QA_ENV must be exactly "staging". Refusing to call a non-staging target.');
}
if (!gatewayUrl || !marker) {
  throw new Error('TDS_AI_SENTINEL_URL and TDS_AI_SENTINEL_MARKER are required.');
}

const endpoint = new URL('/v1/chat', gatewayUrl);
if (endpoint.protocol !== 'https:') {
  throw new Error('The sentinel endpoint must use HTTPS.');
}
// Environment variables are not evidence that a target is staging. Require an
// explicit staging label in the hostname as a second, fail-closed guard.
if (!/(^|[.-])staging([.-]|$)/i.test(endpoint.hostname)) {
  throw new Error('The sentinel target hostname must carry a staging label.');
}

const question = `Qual marcador de validação do material TDS está registrado no documento de QA? Responda somente com o marcador completo, incluindo a versão.`;
const startedAt = Date.now();
let response;
try {
  response = await fetch(endpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ message: question, mode: 'tutor' }),
    signal: AbortSignal.timeout(30_000),
  });
} catch (error) {
  console.log(JSON.stringify({
    timestamp: new Date().toISOString(),
    environment,
    gateway: 'FAIL',
    latency_ms: Date.now() - startedAt,
    error_category: error?.name === 'TimeoutError' ? 'client_timeout' : 'network_error',
  }));
  process.exitCode = 1;
  process.exit();
}

let payload = {};
try {
  payload = await response.json();
} catch {
  // The status and request ID remain useful evidence; never emit the raw body.
}

const text = typeof payload.text === 'string' ? payload.text : '';
const sentinelPass = response.ok && text.includes(marker);
const result = {
  timestamp: new Date().toISOString(),
  environment,
  gateway: response.ok ? 'PASS' : 'FAIL',
  http_status: response.status,
  latency_ms: Date.now() - startedAt,
  request_id: response.headers.get('x-request-id') || null,
  rag_sentinel: sentinelPass ? 'PASS' : 'FAIL',
  error_category: typeof payload.error === 'string' ? payload.error : null,
};
console.log(JSON.stringify(result));
if (!sentinelPass) process.exitCode = 1;
