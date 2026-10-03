// Only external KV/HTTP are substituted. Execute the actual Worker handler.
import { handleRequest } from '../../../cartilhas_app/cloudflare/tutor-tds-gateway/src/index.js';
import { readFileSync } from 'node:fs';

const input = JSON.parse(readFileSync(0, 'utf8'));
const storage = input.storage || {};
let writes = 0;
const env = {
  TUTOR_ENVIRONMENT: 'development', CERTIFICATE_CANDIDATE_ENABLED: 'true',
  CERTIFICATE_CANDIDATE_SECRET: input.secret,
  CERTIFICATE_CANDIDATES: {
    async get(key) { if (input.failGet) throw new Error('synthetic read failure'); return storage[key] ?? null; },
    async put(key, value) { storage[key] = value; writes += 1; },
  },
  CERTIFICATES: { async get() { throw new Error('legacy KV forbidden'); }, async put() { throw new Error('legacy KV forbidden'); } },
  ...input.env,
};
const request = new Request('http://127.0.0.1:9090' + input.path, {
  method: input.method, headers: input.headers,
  ...(input.method === 'POST' ? { body: input.body } : {}),
});
const response = await handleRequest(request, env, {});
process.stdout.write(JSON.stringify({ status: response.status, headers: Object.fromEntries(response.headers), body: await response.text(), storage, writes }));
