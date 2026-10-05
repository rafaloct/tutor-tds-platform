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
