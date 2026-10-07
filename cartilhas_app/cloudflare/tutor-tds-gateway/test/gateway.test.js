import assert from 'node:assert/strict';
import test from 'node:test';

import { handleRequest } from '../src/index.js';

const env = {
  ANYTHING_LLM_API_KEY: 'test-secret',
  ANYTHING_LLM_BASE_URL: 'https://anything.example',
  ANYTHING_LLM_WORKSPACE: 'cartilhas',
};

function certificateEnv() {
  const values = new Map();
  return {
    ...env,
    CERTIFICATE_SIGNING_SECRET: 'certificate-test-secret',
    CERTIFICATES: {
      get: async (key) => values.get(key) ?? null,
      put: async (key, value) => values.set(key, value),
    },
    _certificateValues: values,
  };
}

const validCertificateRequest = {
  holderName: 'Maria da Silva',
  cpf: '529.982.247-25',
  courseId: 'cooperativismo',
  answeredQuestions: 4,
  totalQuestions: 4,
};

function post(path, body) {
  return new Request(`https://gateway.example${path}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
}

const learningContextA = {
  course_id: 'course-a',
  course_version_id: 'version-1',
  module_id: 'module-a1',
};
const learningContextB = {
  course_id: 'course-b',
  course_version_id: 'version-3',
  module_id: 'module-b1',
};
const learningContextA2 = {
  course_id: 'course-a',
  course_version_id: 'version-1',
  module_id: 'module-a2',
};

function scopeKey(context) {
  return [context.course_id, context.course_version_id].join('|');
}

function scopedEnv() {
  return {
    ...env,
    TUTOR_RAG_SCOPE_MAP: JSON.stringify({
      [scopeKey(learningContextA)]: 'course-a-v1',
      [scopeKey(learningContextB)]: 'course-b-v3',
    }),
  };
}

function moduleScopedEnv() {
  return {
    ...env,
    TUTOR_RAG_SCOPE_MAP: JSON.stringify({
      [`${scopeKey(learningContextA)}|${learningContextA.module_id}`]: 'course-a-v1-m1',
      [`${scopeKey(learningContextA)}|${learningContextA2.module_id}`]: 'course-a-v1-m2',
      [scopeKey(learningContextB)]: 'course-b-v3',
    }),
  };
}

function vectorSource(title, overrides = {}) {
  const id = overrides.id ?? `vector-${title}`;
  const metadata = {
    title,
    url: 'file:///private/documents/internal.pdf',
    author: 'QA',
    description: 'Synthetic QA source',
    docSource: `doc:${title}`,
    chunkSource: `chunk:${title}`,
    published: '10/5/2026',
    wordCount: 8,
    tokenCount: 9,
    ...(overrides.metadata ?? {}),
  };
  return {
    id,
    text: `${title} synthetic QA content`,
    metadata,
    score: 0.94123,
    ...(overrides.fields ?? {}),
  };
}

function chatSource(source, overrides = {}) {
  return {
    id: source.id,
    title: source.metadata.title,
    docSource: source.metadata.docSource,
    chunkSource: source.metadata.chunkSource,
    text: 'private chunk text',
    ...overrides,
  };
}

function contextualFetch(
  results,
  citations = results[0] ? [chatSource(results[0])] : [],
  capture = {},
) {
  return async (url, options) => {
    const requestUrl = String(url);
    const body = JSON.parse(options.body);
    if (requestUrl.endsWith('/vector-search')) {
      capture.search = { url: requestUrl, body, options };
      return Response.json({ results });
    }
    capture.chat = { url: requestUrl, body, options };
    return Response.json({ textResponse: 'Contextual answer', sources: citations });
  };
}

test('encaminha chat sem expor a chave na resposta', async () => {
  let captured;
  const fakeFetch = async (url, options) => {
    captured = { url: String(url), options };
    return Response.json({ textResponse: 'Resposta segura' });
  };
  const response = await handleRequest(
    post('/v1/chat', { message: 'Como começo?', mode: 'tutor' }), env, {}, fakeFetch,
  );
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { text: 'Resposta segura' });
  assert.equal(captured.url, 'https://anything.example/api/v1/workspace/cartilhas/chat');
  assert.equal(captured.options.headers.Authorization, 'Bearer test-secret');
});

test('legacy chat still uses the configured workspace and chat mode', async () => {
  let captured;
  const response = await handleRequest(
    post('/v1/chat', { message: 'Pergunta legada', mode: 'tutor', context: 'Cartilha' }),
    env,
    {},
    async (url, options) => {
      captured = { url: String(url), body: JSON.parse(options.body) };
      return Response.json({ textResponse: 'Legacy answer' });
    },
  );

  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { text: 'Legacy answer' });
  assert.equal(captured.url, 'https://anything.example/api/v1/workspace/cartilhas/chat');
  assert.equal(captured.body.mode, 'chat');
});

test('contextual chat selects the course-version workspace, queries it, and sanitizes sources', async () => {
  const capture = {};
  const result = vectorSource('TDS_CTX_A_v1');
  const response = await handleRequest(
    post('/v1/chat', {
      message: 'Pergunta A',
      context: 'private reflection text',
      learning_context: learningContextA,
    }),
    scopedEnv(),
    {},
    contextualFetch([result], [chatSource(result)], capture),
  );

  assert.equal(response.status, 200);
  const payload = await response.json();
  assert.deepEqual(payload, {
    text: 'Contextual answer',
    sources: [{
      title: 'TDS_CTX_A_v1',
      course_id: 'course-a',
      course_version_id: 'version-1',
      score: 0.941,
    }],
  });
  assert.equal(capture.search.url, 'https://anything.example/api/v1/workspace/course-a-v1/vector-search');
  assert.deepEqual(capture.search.body, { query: 'Pergunta A', topN: 4 });
  assert.equal(capture.chat.url, 'https://anything.example/api/v1/workspace/course-a-v1/chat');
  assert.equal(capture.chat.body.mode, 'query');
  assert.equal(
    capture.search.options.headers['X-Request-Id'],
    capture.chat.options.headers['X-Request-Id'],
  );
  assert.equal(
    capture.chat.options.headers['X-Request-Id'],
    response.headers.get('X-Request-Id'),
  );
  assert.equal('sessionId' in capture.chat.body, false);
  assert.equal(JSON.stringify(capture).includes('private reflection text'), false);
  assert.equal(JSON.stringify(capture).includes('course_id'), false);
  assert.equal(JSON.stringify(payload).includes('docSource'), false);
});

test('contextual vector-search and chat requests both use the configured bearer token', async () => {
  const upstreamEnv = scopedEnv();
  const result = vectorSource('TDS_CTX_A_v1');
  const calls = [];
  const response = await handleRequest(
    post('/v1/chat', { message: 'Pergunta A', learning_context: learningContextA }),
    upstreamEnv,
    {},
    async (url, options) => {
      const requestUrl = String(url);
      calls.push({ url: requestUrl, authorization: options.headers.Authorization });
      if (requestUrl.endsWith('/vector-search')) {
        return Response.json({ results: [result] });
      }
      return Response.json({
        textResponse: 'Contextual answer',
        sources: [chatSource(result)],
      });
    },
  );

  assert.equal(response.status, 200);
  assert.deepEqual(
    calls.map(({ url }) => new URL(url).pathname),
    [
      '/api/v1/workspace/course-a-v1/vector-search',
      '/api/v1/workspace/course-a-v1/chat',
    ],
  );
  assert.equal(calls.length, 2);
  for (const call of calls) {
    assert.equal(call.authorization, `Bearer ${upstreamEnv.ANYTHING_LLM_API_KEY}`);
  }
});

test('context A and B route to distinct CourseVersion workspaces with real AnythingLLM source shapes', async () => {
  const cases = [
    {
      context: learningContextA,
      workspace: 'course-a-v1',
      title: 'TDS_CTX_A_v1',
      courseId: 'course-a',
      versionId: 'version-1',
    },
    {
      context: learningContextB,
      workspace: 'course-b-v3',
      title: 'TDS_CTX_B_v3',
      courseId: 'course-b',
      versionId: 'version-3',
    },
  ];

  for (const scenario of cases) {
    const result = vectorSource(scenario.title);
    const calls = [];
    const response = await handleRequest(
      post('/v1/chat', { message: 'Sentinel', learning_context: scenario.context }),
      scopedEnv(),
      {},
      async (url, options) => {
        calls.push(String(url));
        if (String(url).endsWith('/vector-search')) {
          return Response.json({ results: [result] });
        }
        assert.equal(JSON.parse(options.body).mode, 'query');
        return Response.json({
          textResponse: 'Sentinel answer',
          sources: [chatSource(result)],
        });
      },
    );

    assert.equal(response.status, 200);
    assert.deepEqual(calls, [
      `https://anything.example/api/v1/workspace/${scenario.workspace}/vector-search`,
      `https://anything.example/api/v1/workspace/${scenario.workspace}/chat`,
    ]);
    assert.deepEqual(await response.json(), {
      text: 'Sentinel answer',
      sources: [{
        title: scenario.title,
        course_id: scenario.courseId,
        course_version_id: scenario.versionId,
        score: 0.941,
      }],
    });
  }
});

test('module and experience context stay structured without claiming unsupported source isolation', async () => {
  const contexts = [
    learningContextA,
    learningContextA2,
    {
      ...learningContextA,
      experience_id: 'scenario-1',
      experience_type: 'scenario',
    },
  ];

  for (const context of contexts) {
    const result = vectorSource('TDS_CTX_A_v1');
    let searchUrl;
    const response = await handleRequest(
      post('/v1/chat', {
        message: 'Pergunta contextual',
        learning_context: context,
      }),
      scopedEnv(),
      {},
      async (url) => {
        if (String(url).endsWith('/vector-search')) {
          searchUrl = String(url);
          return Response.json({ results: [result] });
        }
        return Response.json({
          textResponse: 'CourseVersion-scoped answer',
          sources: [chatSource(result)],
        });
      },
    );

    assert.equal(searchUrl, 'https://anything.example/api/v1/workspace/course-a-v1/vector-search');
    assert.equal(response.status, 200);
    const payload = await response.json();
    assert.equal(payload.sources[0].course_id, 'course-a');
    assert.equal(payload.sources[0].course_version_id, 'version-1');
    assert.equal('module_id' in payload.sources[0], false);
    assert.equal('experience_id' in payload.sources[0], false);
    assert.equal('experience_type' in payload.sources[0], false);
  }
});

test('module binding resolves the module workspace and reports the effective scope', async () => {
  const capture = {};
  const result = vectorSource('TDS_CTX_A_v1');
  const response = await handleRequest(
    post('/v1/chat', { message: 'Pergunta A1', learning_context: learningContextA }),
    moduleScopedEnv(),
    {},
    contextualFetch([result], [chatSource(result)], capture),
  );

  assert.equal(response.status, 200);
  assert.equal(
    capture.search.url,
    'https://anything.example/api/v1/workspace/course-a-v1-m1/vector-search',
  );
  assert.equal(
    capture.chat.url,
    'https://anything.example/api/v1/workspace/course-a-v1-m1/chat',
  );
  assert.equal(capture.chat.body.mode, 'query');
  assert.deepEqual(await response.json(), {
    text: 'Contextual answer',
    sources: [{
      title: 'TDS_CTX_A_v1',
      course_id: 'course-a',
      course_version_id: 'version-1',
      module_id: 'module-a1',
      score: 0.941,
    }],
  });
});

test('distinct module bindings of the same CourseVersion do not cross retrieval', async () => {
  for (const [context, workspace] of [
    [learningContextA, 'course-a-v1-m1'],
    [learningContextA2, 'course-a-v1-m2'],
  ]) {
    const result = vectorSource('TDS_CTX_A_v1');
    const calls = [];
    const response = await handleRequest(
      post('/v1/chat', { message: 'Pergunta', learning_context: context }),
      moduleScopedEnv(),
      {},
      async (url) => {
        calls.push(String(url));
        if (String(url).endsWith('/vector-search')) {
          return Response.json({ results: [result] });
        }
        return Response.json({
          textResponse: 'Answer',
          sources: [chatSource(result)],
        });
      },
    );
    assert.equal(response.status, 200);
    assert.equal(calls[0], `https://anything.example/api/v1/workspace/${workspace}/vector-search`);
    assert.equal(calls[1], `https://anything.example/api/v1/workspace/${workspace}/chat`);
    assert.equal((await response.json()).sources[0].module_id, context.module_id);
  }
});

test('unmapped module fails closed when the map declares module granularity', async () => {
  let called = false;
  const response = await handleRequest(
    post('/v1/chat', {
      message: 'Pergunta A3',
      learning_context: { ...learningContextA, module_id: 'module-a3' },
    }),
    moduleScopedEnv(),
    {},
    async () => {
      called = true;
      return Response.json({});
    },
  );
  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), { error: 'rag_context_unresolved' });
  assert.equal(called, false);
});

test('module-scoped map fails closed for requests without module context', async () => {
  const moduleOnlyEnv = {
    ...env,
    TUTOR_RAG_SCOPE_MAP: JSON.stringify({
      [`${scopeKey(learningContextA)}|${learningContextA.module_id}`]: 'course-a-v1-m1',
    }),
  };
  let called = false;
  const response = await handleRequest(
    post('/v1/chat', {
      message: 'Pergunta sem módulo',
      learning_context: {
        course_id: learningContextA.course_id,
        course_version_id: learningContextA.course_version_id,
      },
    }),
    moduleOnlyEnv,
    {},
    async () => {
      called = true;
      return Response.json({});
    },
  );
  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), { error: 'rag_context_unresolved' });
  assert.equal(called, false);
});

test('module keys cannot alias an existing scope workspace or use malformed keys', async () => {
  const invalidMaps = [
    {
      [scopeKey(learningContextA)]: 'course-a-v1',
      [`${scopeKey(learningContextA)}|${learningContextA.module_id}`]: 'course-a-v1',
    },
    { [`${scopeKey(learningContextA)}|${learningContextA.module_id}|extra`]: 'ws-1' },
    { [`${scopeKey(learningContextA)}|`]: 'ws-1' },
    { 'course-only': 'ws-1' },
  ];
  for (const map of invalidMaps) {
    let called = false;
    const response = await handleRequest(
      post('/v1/chat', { message: 'Pergunta A', learning_context: learningContextA }),
      { ...env, TUTOR_RAG_SCOPE_MAP: JSON.stringify(map) },
      {},
      async () => {
        called = true;
        return Response.json({});
      },
    );
    assert.equal(response.status, 503);
    assert.deepEqual(await response.json(), { error: 'rag_context_unresolved' });
    assert.equal(called, false);
  }
});

test('experience context under module binding resolves the module workspace without claiming experience scope', async () => {
  const context = {
    ...learningContextA,
    experience_id: 'scenario-1',
    experience_type: 'scenario',
  };
  const result = vectorSource('TDS_CTX_A_v1');
  let searchUrl;
  const response = await handleRequest(
    post('/v1/chat', { message: 'Pergunta', learning_context: context }),
    moduleScopedEnv(),
    {},
    async (url) => {
      if (String(url).endsWith('/vector-search')) {
        searchUrl = String(url);
        return Response.json({ results: [result] });
      }
      return Response.json({
        textResponse: 'Answer',
        sources: [chatSource(result)],
      });
    },
  );

  assert.equal(searchUrl, 'https://anything.example/api/v1/workspace/course-a-v1-m1/vector-search');
  assert.equal(response.status, 200);
  const source = (await response.json()).sources[0];
  assert.equal(source.module_id, 'module-a1');
  assert.equal('experience_id' in source, false);
  assert.equal('experience_type' in source, false);
});

test('missing or structurally unsafe vector-search sources fail closed before chat', async () => {
  const invalidResultSets = [
    [],
    [vectorSource('/private/internal.pdf')],
    [{ id: 'unlinked', text: 'unlinked source', metadata: { docSource: 'private' } }],
  ];

  for (const results of invalidResultSets) {
    let chatCalled = false;
    const response = await handleRequest(
      post('/v1/chat', { message: 'Sentinel', learning_context: learningContextA }),
      scopedEnv(),
      {},
      async (url) => {
        if (String(url).endsWith('/vector-search')) return Response.json({ results });
        chatCalled = true;
        return Response.json({ textResponse: 'Must not be returned', sources: [] });
      },
    );
    assert.equal(response.status, 503);
    assert.deepEqual(await response.json(), { error: 'rag_context_unresolved' });
    assert.equal(chatCalled, false);
  }
});

test('unmapped scopes and unknown or malformed learning-context keys fail closed', async () => {
  let called = false;
  const unresolved = await handleRequest(
    post('/v1/chat', { message: 'Unknown course', learning_context: learningContextA }),
    env,
    {},
    async () => {
      called = true;
      return Response.json({});
    },
  );
  assert.equal(unresolved.status, 503);
  assert.deepEqual(await unresolved.json(), { error: 'rag_context_unresolved' });

  const unknownTopLevel = await handleRequest(
    post('/v1/chat', { message: 'x', unexpected: true, learning_context: learningContextA }),
    scopedEnv(),
    {},
    async () => {
      called = true;
      return Response.json({});
    },
  );
  assert.equal(unknownTopLevel.status, 400);
  assert.deepEqual(await unknownTopLevel.json(), { error: 'unknown_key' });

  for (const body of [
    { message: 'x', learning_context: { ...learningContextA, unexpected: 'x' } },
    { message: 'x', learning_context: { course_id: 'course-a', module_id: 'module-a1' } },
    {
      message: 'x',
      learning_context: {
        course_id: learningContextA.course_id,
        course_version_id: learningContextA.course_version_id,
        experience_id: 'scenario-1',
        experience_type: 'scenario',
      },
    },
    {
      message: 'x',
      learning_context: {
        ...learningContextA,
        experience_id: 'scenario-1',
        experience_type: 'unknown',
      },
    },
  ]) {
    const response = await handleRequest(
      post('/v1/chat', body),
      scopedEnv(),
      {},
      async () => {
        called = true;
        return Response.json({});
      },
    );
    assert.equal(response.status, 400);
    assert.deepEqual(await response.json(), { error: 'invalid_learning_context' });
  }
  assert.equal(called, false);
});

test('different CourseVersions cannot alias to one workspace', async () => {
  let called = false;
  const response = await handleRequest(
    post('/v1/chat', { message: 'Pergunta A', learning_context: learningContextA }),
    {
      ...scopedEnv(),
      TUTOR_RAG_SCOPE_MAP: {
        [scopeKey(learningContextA)]: 'shared-workspace',
        [scopeKey(learningContextB)]: 'shared-workspace',
      },
    },
    {},
    async () => {
      called = true;
      return Response.json({});
    },
  );

  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), { error: 'rag_context_unresolved' });
  assert.equal(called, false);
});

test('contextual response rejects citations not present in verified retrieval', async () => {
  const result = vectorSource('TDS_CTX_A_v1');
  const unrelated = vectorSource('TDS_CTX_B_v3');
  const response = await handleRequest(
    post('/v1/chat', { message: 'Pergunta A', learning_context: learningContextA }),
    scopedEnv(),
    {},
    contextualFetch([result], [chatSource(unrelated)]),
  );

  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), { error: 'rag_context_unresolved' });
});

test('contextual response rejects a conflicting private source id even when title matches', async () => {
  const result = vectorSource('TDS_CTX_A_v1', { id: 'vector-a' });
  const response = await handleRequest(
    post('/v1/chat', { message: 'Pergunta A', learning_context: learningContextA }),
    scopedEnv(),
    {},
    contextualFetch(
      [result],
      [chatSource(result, { id: 'different-vector-id' })],
    ),
  );

  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), { error: 'rag_context_unresolved' });
});

test('contextual response can correlate the documented title-only chat citation shape', async () => {
  const result = vectorSource('TDS_CTX_A_v1');
  const response = await handleRequest(
    post('/v1/chat', { message: 'Pergunta A', learning_context: learningContextA }),
    scopedEnv(),
    {},
    contextualFetch(
      [result],
      [{ title: 'TDS_CTX_A_v1', chunk: 'private chunk text' }],
    ),
  );

  assert.equal(response.status, 200);
  const payload = await response.json();
  assert.deepEqual(payload, {
    text: 'Contextual answer',
    sources: [{
      title: 'TDS_CTX_A_v1',
      course_id: 'course-a',
      course_version_id: 'version-1',
      score: 0.941,
    }],
  });
});

test('monta o modo adaptativo no servidor', async () => {
  let upstreamBody;
  const fakeFetch = async (_url, options) => {
    upstreamBody = JSON.parse(options.body);
    return Response.json({ textResponse: 'Ok' });
  };
  const response = await handleRequest(
    post('/v1/chat', { message: 'Preciso de ajuda', mode: 'adaptive', context: 'Crédito rural' }),
    env, {}, fakeFetch,
  );
  assert.equal(response.status, 200);
  assert.match(upstreamBody.system_prompt, /MODO ADAPTATIVO/);
  assert.match(upstreamBody.system_prompt, /Crédito rural/);
});

test('gera e normaliza cartões mesmo com bloco markdown do modelo', async () => {
  const cards = Array.from({ length: 5 }, (_, index) => ({
    front: `Pergunta ${index + 1}`,
    back: `Resposta ${index + 1}`,
    hint: 'Dica',
  }));
  const fakeFetch = async () => Response.json({
    textResponse: `\`\`\`json\n${JSON.stringify({ title: 'Agricultura', items: cards })}\n\`\`\``,
  });
  const response = await handleRequest(
    post('/v1/study', { kind: 'flashcards', topic: 'Agricultura Sustentável', count: 5 }),
    env, {}, fakeFetch,
  );
  assert.equal(response.status, 200);
  const data = await response.json();
  assert.equal(data.kind, 'flashcards');
  assert.equal(data.material.items.length, 5);
  assert.equal(data.material.items[0].front, 'Pergunta 1');
});

test('ignora exemplo de esquema antes do objeto JSON final', async () => {
  const material = {
    title: 'Revisão',
    items: [
      { front: 'P1', back: 'R1', hint: '' },
      { front: 'P2', back: 'R2', hint: '' },
      { front: 'P3', back: 'R3', hint: '' },
    ],
  };
  const fakeFetch = async () => Response.json({
    textResponse:
      'Use o esquema {"title":"...","items":[]} e retorne:\n```json\n' +
      JSON.stringify(material) +
      '\n```',
  });
  const response = await handleRequest(
    post('/v1/study', { kind: 'flashcards', topic: 'Tema', count: 3 }),
    env,
    {},
    fakeFetch,
  );

  assert.equal(response.status, 200);
  assert.equal((await response.json()).material.items.length, 3);
});

test('gera quiz validado com quatro alternativas e explicação', async () => {
  const items = Array.from({ length: 3 }, (_, index) => ({
    question: `Questão ${index + 1}`,
    options: ['A', 'B', 'C', 'D'],
    correctIndex: index % 4,
    explanation: 'Explicação pedagógica',
    topic: 'Crédito',
  }));
  const fakeFetch = async () => Response.json({
    textResponse: JSON.stringify({ title: 'Quiz', durationMinutes: 15, items }),
  });
  const response = await handleRequest(
    post('/v1/study', { kind: 'quiz', topic: 'Cooperativismo', count: 3 }),
    env, {}, fakeFetch,
  );
  assert.equal(response.status, 200);
  const data = await response.json();
  assert.equal(data.material.items.length, 3);
  assert.equal(data.material.items[1].correctIndex, 1);
});

test('recusa tipo de estudo inválido antes de chamar o VPS', async () => {
  let called = false;
  const response = await handleRequest(
    post('/v1/study', { kind: 'admin', topic: 'teste' }), env, {}, async () => {
      called = true;
      return Response.json({});
    },
  );
  assert.equal(response.status, 400);
  assert.equal(called, false);
});

test('recusa material estruturalmente inválido do modelo', async () => {
  const response = await handleRequest(
    post('/v1/study', { kind: 'quiz', topic: 'teste', count: 3 }), env, {},
    async () => Response.json({ textResponse: '{"title":"Incompleto","items":[]}' }),
  );
  assert.equal(response.status, 502);
  assert.deepEqual(await response.json(), { error: 'invalid_study_material' });
});

test('não repassa detalhes de erro do AnythingLLM', async () => {
  const response = await handleRequest(
    post('/v1/chat', { message: 'Teste' }), env, {},
    async () => new Response('token inválido: detalhe interno', { status: 401 }),
  );
  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), { error: 'service_unavailable' });
});

test('expõe um request id opaco e o propaga ao upstream sem expor segredo', async () => {
  let upstreamRequestId;
  const response = await handleRequest(
    post('/v1/chat', { message: 'Teste de correlação' }), env, {},
    async (_url, options) => {
      upstreamRequestId = options.headers['X-Request-Id'];
      return Response.json({ textResponse: 'Ok' });
    },
  );
  const requestId = response.headers.get('X-Request-Id');
  assert.match(requestId, /^[0-9a-f-]{36}$/i);
  assert.equal(upstreamRequestId, requestId);
  assert.equal((await response.text()).includes('test-secret'), false);
});

test('classifica timeout upstream sem revelar detalhes internos', async () => {
  const response = await handleRequest(
    post('/v1/chat', { message: 'Teste' }), env, {},
    async () => { throw new DOMException('deadline interno', 'TimeoutError'); },
  );
  assert.equal(response.status, 504);
  assert.deepEqual(await response.json(), { error: 'upstream_timeout' });
});

test('preserva rate limit como erro observável sanitizado', async () => {
  const response = await handleRequest(
    post('/v1/chat', { message: 'Teste' }), env, {},
    async () => new Response('provider quota internal detail', { status: 429 }),
  );
  assert.equal(response.status, 429);
  assert.deepEqual(await response.json(), { error: 'rate_limited' });
});

test('contextual vector-search preserves sanitized 429, 504 and upstream failures', async () => {
  const cases = [
    { upstream: new Response('private quota detail', { status: 429 }), status: 429, error: 'rate_limited' },
    { upstream: new Response('private timeout detail', { status: 504 }), status: 504, error: 'upstream_timeout' },
    { upstream: new Response('private upstream detail', { status: 503 }), status: 503, error: 'service_unavailable' },
    { upstream: new Response('private client detail', { status: 400 }), status: 502, error: 'invalid_upstream_response' },
  ];

  for (const scenario of cases) {
    let chatCalled = false;
    const response = await handleRequest(
      post('/v1/chat', { message: 'Pergunta A', learning_context: learningContextA }),
      scopedEnv(),
      {},
      async (url) => {
        if (String(url).endsWith('/vector-search')) return scenario.upstream;
        chatCalled = true;
        return Response.json({});
      },
    );

    assert.equal(response.status, scenario.status);
    assert.deepEqual(await response.json(), { error: scenario.error });
    assert.match(response.headers.get('X-Request-Id'), /^[0-9a-f-]{36}$/i);
    assert.equal(chatCalled, false);
  }

  let chatCalled = false;
  const timeout = await handleRequest(
    post('/v1/chat', { message: 'Pergunta A', learning_context: learningContextA }),
    scopedEnv(),
    {},
    async (url) => {
      if (String(url).endsWith('/vector-search')) {
        throw new DOMException('deadline interno', 'TimeoutError');
      }
      chatCalled = true;
      return Response.json({});
    },
  );
  assert.equal(timeout.status, 504);
  assert.deepEqual(await timeout.json(), { error: 'upstream_timeout' });
  assert.equal(chatCalled, false);
});

test('normaliza 5xx upstream e JSON inválido sem vazar o corpo', async () => {
  const upstreamFailure = await handleRequest(
    post('/v1/chat', { message: 'Teste' }), env, {},
    async () => new Response('stack trace', { status: 502 }),
  );
  assert.equal(upstreamFailure.status, 503);
  assert.deepEqual(await upstreamFailure.json(), { error: 'service_unavailable' });

  const malformed = await handleRequest(
    post('/v1/chat', { message: 'Teste' }), env, {},
    async () => new Response('not json', { status: 200 }),
  );
  assert.equal(malformed.status, 502);
  assert.deepEqual(await malformed.json(), { error: 'invalid_upstream_response' });
});

test('recusa corpo maior que o limite, contexto inválido e origem não autorizada', async () => {
  const oversized = await handleRequest(
    post('/v1/chat', { message: 'x'.repeat(16_385) }), env, {},
    async () => assert.fail('não deveria chamar upstream'),
  );
  assert.equal(oversized.status, 413);
  assert.deepEqual(await oversized.json(), { error: 'payload_too_large' });

  const invalidContext = await handleRequest(
    post('/v1/chat', { message: 'Teste', context: 1 }), env, {},
    async () => assert.fail('não deveria chamar upstream'),
  );
  assert.equal(invalidContext.status, 400);
  assert.deepEqual(await invalidContext.json(), { error: 'invalid_context' });

  const corsRequest = new Request('https://gateway.example/v1/chat', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Origin: 'https://untrusted.example' },
    body: JSON.stringify({ message: 'Teste' }),
  });
  const cors = await handleRequest(corsRequest, { ...env, ALLOWED_ORIGINS: 'https://app.example' }, {});
  assert.equal(cors.status, 403);
  assert.deepEqual(await cors.json(), { error: 'origin_not_allowed' });
});

test('aceita contexto vazio sem o inserir no prompt e rejeita resposta vazia', async () => {
  let upstreamBody;
  const contextResponse = await handleRequest(
    post('/v1/chat', { message: 'Teste', context: '   ' }), env, {},
    async (_url, options) => {
      upstreamBody = JSON.parse(options.body);
      return Response.json({ textResponse: 'Ok' });
    },
  );
  assert.equal(contextResponse.status, 200);
  assert.doesNotMatch(upstreamBody.system_prompt, /CONTEXTO DA CARTILHA/);

  const emptyResponse = await handleRequest(
    post('/v1/chat', { message: 'Teste' }), env, {},
    async () => Response.json({ textResponse: '   ' }),
  );
  assert.equal(emptyResponse.status, 502);
  assert.deepEqual(await emptyResponse.json(), { error: 'empty_upstream_response' });
});

test('health check não revela configuração', async () => {
  const response = await handleRequest(
    new Request('https://gateway.example/health'), env, {},
    async () => assert.fail('não deveria chamar o VPS'),
  );
  assert.equal(response.status, 200);
  assert.deepEqual(await response.json(), { status: 'ok' });
});

test('emite certificado assinado sem persistir ou publicar o CPF', async () => {
  const certificateEnvironment = certificateEnv();
  const response = await handleRequest(
    post('/v1/certificates', validCertificateRequest), certificateEnvironment, {},
  );
  assert.equal(response.status, 201);
  const data = await response.json();
  assert.equal(data.alreadyIssued, false);
  assert.match(data.certificate.id, /^TDS-\d{4}-[A-F0-9]{12}$/);
  assert.equal(data.certificate.courseTitle, 'Cooperativismo e Crédito');
  assert.match(data.certificate.hash, /^[a-f0-9]{64}$/);
  assert.match(data.certificate.signature, /^[a-f0-9]{64}$/);
  assert.equal(JSON.stringify(data).includes('52998224725'), false);
  assert.equal(
    [...certificateEnvironment._certificateValues.values()].some((value) =>
      String(value).includes('52998224725')),
    false,
  );
});

test('reutiliza a mesma emissão para o mesmo CPF e cartilha', async () => {
  const certificateEnvironment = certificateEnv();
  const first = await handleRequest(
    post('/v1/certificates', validCertificateRequest), certificateEnvironment, {},
  );
  const second = await handleRequest(
    post('/v1/certificates', validCertificateRequest), certificateEnvironment, {},
  );
  assert.equal(first.status, 201);
  assert.equal(second.status, 200);
  const firstData = await first.json();
  const secondData = await second.json();
  assert.equal(secondData.alreadyIssued, true);
  assert.equal(secondData.certificate.id, firstData.certificate.id);
});

test('valida certificado por JSON e por página pública', async () => {
  const certificateEnvironment = certificateEnv();
  const issued = await handleRequest(
    post('/v1/certificates', validCertificateRequest), certificateEnvironment, {},
  );
  const certificate = (await issued.json()).certificate;

  const lookup = await handleRequest(
    new Request(`https://gateway.example/v1/certificates/${certificate.id}`),
    certificateEnvironment,
    {},
  );
  assert.equal(lookup.status, 200);
  assert.equal((await lookup.json()).valid, true);

  const page = await handleRequest(
    new Request(`https://gateway.example/verify/${certificate.id}`),
    certificateEnvironment,
    {},
  );
  assert.equal(page.status, 200);
  assert.match(page.headers.get('content-type'), /text\/html/);
  assert.match(await page.text(), /Certificado válido/);
});

test('detecta adulteração no registro armazenado', async () => {
  const certificateEnvironment = certificateEnv();
  const issued = await handleRequest(
    post('/v1/certificates', validCertificateRequest), certificateEnvironment, {},
  );
  const certificate = (await issued.json()).certificate;
  const key = `certificate:${certificate.id}`;
  certificate.courseTitle = 'Título adulterado';
  certificateEnvironment._certificateValues.set(key, JSON.stringify(certificate));

  const lookup = await handleRequest(
    new Request(`https://gateway.example/v1/certificates/${certificate.id}`),
    certificateEnvironment,
    {},
  );
  assert.equal(lookup.status, 409);
  assert.deepEqual(await lookup.json(), { valid: false, error: 'certificate_invalid' });
});

test('recusa CPF inválido e conclusão incompleta', async () => {
  const certificateEnvironment = certificateEnv();
  const invalidCpf = await handleRequest(
    post('/v1/certificates', { ...validCertificateRequest, cpf: '11111111111' }),
    certificateEnvironment,
    {},
  );
  assert.equal(invalidCpf.status, 400);
  assert.deepEqual(await invalidCpf.json(), { error: 'cpf_invalid' });

  const incomplete = await handleRequest(
    post('/v1/certificates', { ...validCertificateRequest, answeredQuestions: 3 }),
    certificateEnvironment,
    {},
  );
  assert.equal(incomplete.status, 400);
  assert.deepEqual(await incomplete.json(), { error: 'course_not_completed' });
});
