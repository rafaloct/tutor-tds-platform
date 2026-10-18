/** Local integration smoke: real Drupal routes, synthetic identity and widget. */
const assert = require('node:assert/strict');
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const base = process.env.DR7_BASE_URL;
if (!base || !['localhost', '127.0.0.1', '172.17.0.2'].includes(new URL(base).hostname)) {
  throw new Error('DR7_BASE_URL must identify the isolated local fixture site.');
}
(async () => {
  const browser = await chromium.launch({executablePath: process.env.CHROMIUM_PATH, headless: true, args: ['--no-sandbox', '--no-proxy-server']});
  let checks = 0;
  try {
    const page = await browser.newPage();
    const errors = [];
    const headerFailures = [];
    page.on('pageerror', (error) => errors.push(error.message));
    // The real endpoints are tested before intercepting any private data.
    for (const route of ['/suporte', '/meus-certificados', '/verificar-certificado']) {
      const response = await page.goto(base + route);
      assert.equal(response.status(), 200);
      if (!/no-store/.test(response.headers()['cache-control'])) headerFailures.push(route);
      checks += 2;
    }
    await page.goto(base + '/meus-certificados');
    await page.evaluate(() => window.dispatchEvent(new Event('pagehide')));
    assert.match(await page.locator('[data-private-certificates]').textContent(), /Consulte novamente/); checks++;
    const identity = await page.request.get(base + '/tds/support/identity');
    assert.equal(identity.status(), 401);
    assert.match(identity.headers()['cache-control'], /no-store/);
    checks += 2;
    let calls = 0;
    let failIdentity = false;
    let failWidget = false;
    const signature = 'a'.repeat(64);
    await page.route('**/tds/support/identity', async (route) => {
      calls++;
      await route.fulfill({status: failIdentity ? 401 : 200, contentType: 'application/json', headers: {'Cache-Control': 'no-store'}, body: JSON.stringify(failIdentity ? {error: 'session_required'} : {
        identifier: 'synthetic:participant-a', identifier_hash: signature,
        base_url: 'https://chatwoot.example.test', website_token: 'synthetic_inbox',
      })});
    });
    await page.route('https://chatwoot.example.test/**', async (route) => {
      if (failWidget) return route.abort();
      assert.equal(new URL(route.request().url()).pathname, '/packs/js/sdk.js');
      await route.fulfill({contentType: 'application/javascript', body: `
        window.chatwootSDK = {run() {
          window.$chatwoot = {
            setUser(id, data) {
              if (id !== 'synthetic:participant-a' || data.identifier_hash !== '${signature}') throw new Error('identity mismatch');
              let blocked = 0;
              try { localStorage.setItem('forbidden', 'x'); } catch (_) { blocked++; }
              try { parent.document.body; } catch (_) { blocked++; }
              if (blocked !== 2) throw new Error('sandbox isolation missing');
            }, toggle() {}, reset() {}
          };
          window.dispatchEvent(new Event('chatwoot:ready'));
        }};`});
    });
    await page.goto(base + '/suporte');
    assert.equal(calls, 0, 'No identity fetch without explicit start'); checks++;
    await page.locator('[data-support-start]').click();
    await page.waitForFunction(() => document.querySelector('[data-support-status]').textContent === 'Atendimento aberto.');
    const frame = page.locator('[data-support-frame] iframe');
    assert.equal(await frame.getAttribute('sandbox'), 'allow-scripts allow-forms');
    assert.equal(await page.evaluate(() => localStorage.length + sessionStorage.length), 0);
    assert.ok(!(await page.content()).includes(signature));
    checks += 3;
    // Forged messages from the portal are not accepted as sandbox messages.
    await page.evaluate(() => window.postMessage({type: 'tds-support-failed', nonce: 'bad'}, '*'));
    assert.equal(await frame.count(), 1); checks++;
    await page.locator('[data-support-stop]').click();
    assert.equal(await frame.count(), 0); checks++;
    // Failed identity never instantiates the third-party runtime.
    failIdentity = true;
    await page.locator('[data-support-start]').click();
    await page.waitForFunction(() => document.querySelector('[data-support-status]').textContent.includes('indisponível'));
    assert.equal(await frame.count(), 0); checks++;
    failIdentity = false;
    failWidget = true;
    await page.locator('[data-support-start]').click();
    await page.waitForFunction(() => document.querySelector('[data-support-status]').textContent.includes('indisponível'));
    assert.equal(await frame.count(), 0); checks++;
    failWidget = false;
    await page.locator('[data-support-start]').click();
    await page.waitForFunction(() => document.querySelector('[data-support-status]').textContent === 'Atendimento aberto.');
    await page.evaluate(() => window.dispatchEvent(new Event('tds:session-ended')));
    assert.equal(await frame.count(), 0); checks++;
    // An active widget is removed when the server rejects a later session check.
    await page.locator('[data-support-start]').click();
    await page.waitForFunction(() => document.querySelector('[data-support-status]').textContent === 'Atendimento aberto.');
    failIdentity = true;
    await page.waitForFunction(() => document.querySelector('[data-support-status]').textContent.includes('indisponível'), null, {timeout: 22000});
    assert.equal(await frame.count(), 0); checks++;
    assert.deepEqual(errors, []); checks++;
    assert.deepEqual(headerFailures, [], 'HTML routes must retain no-store');
    console.log(`PASS: ${checks} browser checks; Chromium ${browser.version()}; real Drupal routes + synthetic widget (not real Chatwoot).`);
  }
  finally { await browser.close(); }
})().catch((error) => { console.error(error); process.exitCode = 1; });
