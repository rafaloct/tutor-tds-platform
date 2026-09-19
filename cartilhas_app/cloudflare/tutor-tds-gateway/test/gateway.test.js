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
