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

function scopeKey(context) {
  return [
    context.course_id,
    context.course_version_id,
    context.module_id || '',
    context.experience_id || '',
    context.experience_type || '',
  ].join('|');
}

function scopedEnv() {
  return {
    ...env,
    TUTOR_RAG_SCOPE_MAP: JSON.stringify({
      [scopeKey(learningContextA)]: 'course-a-v1-a1',
      [scopeKey(learningContextB)]: 'course-b-v3-b1',
      [scopeKey({
        ...learningContextA,
        experience_id: 'scenario-1',
        experience_type: 'scenario',
      })]: 'course-a-v1-a1-scenario-1',
    }),
  };
}

function vectorSource(context, title, metadata = {}, fields = {}) {
  return {
    id: 'private-storage-id',
    text: `${title} synthetic QA content`,
    metadata: {
      title,
      url: 'file:///private/documents/internal.pdf',
      course_id: context.course_id,
      course_version_id: context.course_version_id,
      module_id: context.module_id,
      ...metadata,
    },
    score: 0.94123,
    ...fields,
  };
}

function contextualFetch(results, citations = [{ title: results[0]?.metadata?.title }], capture = {}) {
  return async (url, options) => {
    const requestUrl = String(url);
    const body = JSON.parse(options.body);
    if (requestUrl.endsWith('/vector-search')) {
      capture.search = { url: requestUrl, body };
      return Response.json({ results });
    }
    capture.chat = { url: requestUrl, body };
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

test('contextual chat selects an exact workspace, queries only it, and sanitizes sources', async () => {
  const capture = {};
  const response = await handleRequest(
    post('/v1/chat', {
      message: 'Pergunta A',
      context: 'private reflection text',
      learning_context: learningContextA,
    }),
    scopedEnv(),
    {},
    contextualFetch(
      [vectorSource(learningContextA, 'TDS_CTX_A_v1')],
      [{ title: 'TDS_CTX_A_v1', chunk: 'private chunk text' }],
      capture,
    ),
  );

  assert.equal(response.status, 200);
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
  assert.equal(capture.search.url, 'https://anything.example/api/v1/workspace/course-a-v1-a1/vector-search');
  assert.deepEqual(capture.search.body, { query: 'Pergunta A', topN: 4 });
  assert.equal(capture.chat.url, 'https://anything.example/api/v1/workspace/course-a-v1-a1/chat');
  assert.equal(capture.chat.body.mode, 'query');
  assert.equal('sessionId' in capture.chat.body, false);
  assert.equal(JSON.stringify(capture).includes('private reflection text'), false);
  assert.equal(JSON.stringify(capture).includes('course_id'), false);
});

test('context A and B accept only their own contextual sentinel sources', async () => {
  const cases = [
    { context: learningContextA, source: learningContextA, title: 'TDS_CTX_A_v1', status: 200 },
    { context: learningContextA, source: learningContextB, title: 'TDS_CTX_B_v3', status: 503 },
    { context: learningContextB, source: learningContextB, title: 'TDS_CTX_B_v3', status: 200 },
    { context: learningContextB, source: learningContextA, title: 'TDS_CTX_A_v1', status: 503 },
  ];

  for (const scenario of cases) {
    let chatCalled = false;
    const response = await handleRequest(
      post('/v1/chat', { message: 'Sentinel', learning_context: scenario.context }),
      scopedEnv(),
      {},
      async (url, options) => {
        if (String(url).endsWith('/vector-search')) {
          return Response.json({
            results: [vectorSource(scenario.source, scenario.title)],
          });
        }
        chatCalled = true;
        assert.match(
          String(url),
          scenario.context === learningContextA ? /course-a-v1-a1\/chat$/ : /course-b-v3-b1\/chat$/,
        );
        assert.equal(JSON.parse(options.body).mode, 'query');
        return Response.json({
          textResponse: 'Sentinel answer',
          sources: [{ title: scenario.title }],
        });
      },
    );
    assert.equal(response.status, scenario.status);
    assert.equal(chatCalled, scenario.status === 200);
    if (scenario.status !== 200) {
      assert.deepEqual(await response.json(), { error: 'rag_context_unresolved' });
    }
  }
});

test('ambiguous, missing, or unlinked contextual sources fail closed before chat', async () => {
  const invalidResultSets = [
    [],
    [vectorSource(learningContextA, 'TDS_CTX_A_v1'), vectorSource(learningContextB, 'TDS_CTX_B_v3')],
    [vectorSource(learningContextA, 'TDS_CTX_A_v1', { course_version_id: 'old-version' })],
    [vectorSource(learningContextA, '/private/internal.pdf')],
    [{ text: 'unlinked source', metadata: { title: 'unlinked' } }],
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

test('scope mappings cannot alias multiple learning contexts to one workspace', async () => {
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
  const response = await handleRequest(
    post('/v1/chat', { message: 'Pergunta A', learning_context: learningContextA }),
    scopedEnv(),
    {},
    contextualFetch(
      [vectorSource(learningContextA, 'TDS_CTX_A_v1')],
      [{ title: 'TDS_CTX_B_v3', chunk: 'must not leave gateway' }],
    ),
  );

  assert.equal(response.status, 503);
  assert.deepEqual(await response.json(), { error: 'rag_context_unresolved' });
});

test('experience IDs are part of exact workspace selection without sending context text', async () => {
  const context = {
    ...learningContextA,
    experience_id: 'scenario-1',
    experience_type: 'scenario',
  };
  let chatUrl;
  const response = await handleRequest(
    post('/v1/chat', { message: 'Pergunta da experiência', learning_context: context }),
    scopedEnv(),
    {},
    async (url) => {
      if (String(url).endsWith('/vector-search')) {
        return Response.json({
          results: [vectorSource(learningContextA, 'TDS_CTX_A_v1')],
        });
      }
      chatUrl = String(url);
      return Response.json({
        textResponse: 'Experience answer',
        sources: [{ title: 'TDS_CTX_A_v1' }],
      });
    },
  );

  assert.equal(response.status, 200);
  assert.equal(
    chatUrl,
    'https://anything.example/api/v1/workspace/course-a-v1-a1-scenario-1/chat',
  );
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
