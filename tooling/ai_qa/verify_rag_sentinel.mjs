#!/usr/bin/env node

// Staging-only, read-only contextual RAG proof. It deliberately prints no
// prompt, model response, source title, marker value, endpoint, or secret.
const environment = process.env.TDS_AI_QA_ENV;
const gatewayUrl = process.env.TDS_AI_SENTINEL_URL;
const markerA = process.env.TDS_AI_SENTINEL_MARKER_A;
const markerB = process.env.TDS_AI_SENTINEL_MARKER_B;
const rawContextA = process.env.TDS_AI_SENTINEL_CONTEXT_A;
const rawContextB = process.env.TDS_AI_SENTINEL_CONTEXT_B;

if (environment !== 'staging') {
  throw new Error('TDS_AI_QA_ENV must be exactly "staging". Refusing to call a non-staging target.');
}
if (!gatewayUrl || !markerA || !markerB || !rawContextA || !rawContextB) {
  throw new Error(
    'TDS_AI_SENTINEL_URL, MARKER_A, MARKER_B, CONTEXT_A and CONTEXT_B are required.',
  );
}
if (markerA === markerB) {
  throw new Error('Contextual sentinel markers A and B must be distinct.');
}

const endpoint = new URL('/v1/chat', gatewayUrl);
if (endpoint.protocol !== 'https:') {
  throw new Error('The sentinel endpoint must use HTTPS.');
}
if (!/(^|[.-])staging([.-]|$)/i.test(endpoint.hostname)) {
  throw new Error('The sentinel target hostname must carry a staging label.');
}

const allowedContextKeys = new Set([
  'course_id',
  'course_version_id',
  'module_id',
  'experience_id',
  'experience_type',
]);
const experienceTypes = new Set([
  'scenario',
  'reveal',
  'reflection',
  'action_challenge',
]);

function stableId(value) {
  return typeof value === 'string' &&
    value.length <= 128 &&
    /^[A-Za-z0-9][A-Za-z0-9._-]*$/.test(value);
}

function parseContext(raw, label) {
  let context;
  try {
    context = JSON.parse(raw);
  } catch {
    throw new Error(`TDS_AI_SENTINEL_CONTEXT_${label} must be valid JSON.`);
  }
  if (!context || typeof context !== 'object' || Array.isArray(context) ||
      Object.keys(context).some((key) => !allowedContextKeys.has(key)) ||
      !stableId(context.course_id) ||
      !stableId(context.course_version_id) ||
      (context.module_id !== undefined && !stableId(context.module_id)) ||
      (context.experience_id !== undefined && !stableId(context.experience_id)) ||
      (context.experience_type !== undefined &&
        !experienceTypes.has(context.experience_type)) ||
      ((context.experience_id === undefined) !==
        (context.experience_type === undefined)) ||
      (context.experience_id !== undefined && context.module_id === undefined)) {
    throw new Error(`TDS_AI_SENTINEL_CONTEXT_${label} is not a valid learning_context.`);
  }
  return context;
}

const contextA = parseContext(rawContextA, 'A');
const contextB = parseContext(rawContextB, 'B');
const scopeKey = (context) => [
  context.course_id,
  context.course_version_id,
  context.module_id ?? '',
  context.experience_id ?? '',
  context.experience_type ?? '',
].join('|');
if (scopeKey(contextA) === scopeKey(contextB)) {
  throw new Error('Contextual sentinel scopes A and B must be distinct.');
}

const question =
  'Qual marcador de validação do material TDS está registrado no documento de QA? ' +
  'Responda somente com o marcador completo, incluindo a versão.';

function sourceMatchesContext(source, context) {
  if (!source || typeof source !== 'object' || Array.isArray(source)) return false;
  if (source.course_id !== context.course_id ||
      source.course_version_id !== context.course_version_id) return false;
  if (context.module_id !== undefined && source.module_id !== context.module_id) {
    return false;
  }
  if (context.experience_id !== undefined &&
      (source.experience_id !== context.experience_id ||
       source.experience_type !== context.experience_type)) {
    return false;
  }
  return true;
}

async function runCase(label, context, expectedMarker, forbiddenMarker) {
  const startedAt = Date.now();
  let response;
  try {
    response = await fetch(endpoint, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message: question,
        mode: 'tutor',
        learning_context: context,
      }),
      signal: AbortSignal.timeout(30_000),
    });
  } catch (error) {
    return {
      context: label,
      gateway: 'FAIL',
      latency_ms: Date.now() - startedAt,
      http_status: null,
      request_id: null,
      source_count: 0,
      scope_sources: 'FAIL',
      rag_sentinel: 'FAIL',
      error_category:
        error?.name === 'TimeoutError' ? 'client_timeout' : 'network_error',
    };
  }

  let payload = {};
  try {
    payload = await response.json();
  } catch {
    // Keep only sanitized status evidence.
  }

  const text = typeof payload.text === 'string' ? payload.text : '';
  const sources = Array.isArray(payload.sources) ? payload.sources : [];
  const scopeSourcesPass =
    sources.length > 0 && sources.every((source) => sourceMatchesContext(source, context));
  const markerPass =
    response.ok &&
    text.includes(expectedMarker) &&
    !text.includes(forbiddenMarker) &&
    scopeSourcesPass;

  return {
    context: label,
    gateway: response.ok ? 'PASS' : 'FAIL',
    http_status: response.status,
    latency_ms: Date.now() - startedAt,
    request_id: response.headers.get('x-request-id') || null,
    source_count: sources.length,
    scope_sources: scopeSourcesPass ? 'PASS' : 'FAIL',
    rag_sentinel: markerPass ? 'PASS' : 'FAIL',
    error_category: typeof payload.error === 'string' ? payload.error : null,
  };
}

const caseA = await runCase('A', contextA, markerA, markerB);
const caseB = await runCase('B', contextB, markerB, markerA);
const passed = caseA.rag_sentinel === 'PASS' && caseB.rag_sentinel === 'PASS';

console.log(JSON.stringify({
  timestamp: new Date().toISOString(),
  environment,
  contextual_rag_sentinel: passed ? 'PASS' : 'FAIL',
  cases: [caseA, caseB],
}));

if (!passed) process.exitCode = 1;
