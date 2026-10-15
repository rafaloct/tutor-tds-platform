#!/usr/bin/env node
// Real staging API through a disposable Drupal fixture on a fixed SSH tunnel.
// Never accept credentials in argv/env or emit page bodies, IDs or screenshots.
'use strict';
const assert = require('node:assert/strict');
const origin = 'http://127.0.0.1:18872';
let stage = 'configuration';
let checks = 0;
const check = (value, name) => { stage = name; assert.ok(value); checks++; };
const credentialsFromStdin = async () => {
  if (process.stdin.isTTY) throw new Error('Private stdin required.');
  let input = '';
  for await (const chunk of process.stdin) {
    input += chunk.toString('utf8');
    if (Buffer.byteLength(input) > 8192) throw new Error('Input rejected.');
  }
  const value = JSON.parse(input);
  input = '';
  if (!value || Array.isArray(value) || Object.keys(value).some(key => !['cpf', 'password'].includes(key))
      || typeof value.cpf !== 'string' || !value.cpf || typeof value.password !== 'string' || !value.password) {
    throw new Error('Input rejected.');
  }
  return value;
};
(async () => {
  if (process.env.TDS_STAGING_BROWSER_QA !== '1' || process.argv.length !== 2) throw new Error('Opt-in required.');
  const credentials = await credentialsFromStdin();
  const { chromium } = require(process.env.TDS_STAGING_PLAYWRIGHT_MODULE || 'playwright');
  const browser = await chromium.launch({
    ...(process.env.TDS_STAGING_CHROMIUM_PATH ? {executablePath: process.env.TDS_STAGING_CHROMIUM_PATH} : {}),
    headless: true, args: ['--no-sandbox']
  });
  const context = await browser.newContext({serviceWorkers: 'block'});
  await context.route('**/*', route => {
    if (new URL(route.request().url()).origin !== origin) return route.abort('blockedbyclient');
    return route.continue();
  });
  try {
    const page = await context.newPage();
    check((await context.cookies()).length === 0, 'empty-browser');
    stage = 'entry-navigation';
    const entry = await page.goto(`${origin}/entrar`);
    check(entry.status() === 200, 'entry-http');
    check(entry.headers()['cache-control'].includes('no-store'), 'entry-no-store');
    check(!/[?&]token=|login_token/.test(await page.content()), 'entry-no-csrf-html');
    // Create the anonymous browser session, without CMS login or database seed.
    stage = 'anonymous-bootstrap';
    const boot = await page.evaluate(async () => {
      const response = await fetch('/tds/session/bootstrap', {
        method: 'POST', credentials: 'same-origin', mode: 'same-origin',
        redirect: 'error', cache: 'no-store', headers: {'X-TDS-Bootstrap': '1'}
      });
      return {status: response.status, cache: response.headers.get('cache-control')};
    });
    check(boot.status === 200 && boot.cache.includes('no-store'), 'bootstrap-private');
    const before = await context.cookies();
    const anonymous = before.find(cookie => /^S?SESS/.test(cookie.name));
    check(anonymous && anonymous.httpOnly && anonymous.sameSite === 'Lax', 'anonymous-cookie');
    stage = 'login-ui';
    check(new URL(page.url()).origin === origin, 'credential-destination-origin');
    await page.locator('#tds-cpf').fill(credentials.cpf);
    await page.locator('#tds-password').fill(credentials.password);
    credentials.cpf = '';
    credentials.password = '';
    await page.getByRole('button', {name: 'Entrar', exact: true}).click();
    await page.waitForURL(`${origin}/minha-area`, {timeout: 30000});
    stage = 'academic-dashboard';
    await page.locator('section[aria-labelledby="tds-classes-title"] progress').first().waitFor({timeout: 30000});
    const classCount = await page.locator('section[aria-labelledby="tds-classes-title"] .tds-participant-card').count();
    const progressCount = await page.locator('section[aria-labelledby="tds-classes-title"] progress').count();
    check(classCount >= 1 && progressCount >= 1, 'classes-and-progress-visible');
    const authenticated = (await context.cookies()).find(cookie => cookie.name === anonymous.name);
    check(authenticated && authenticated.value !== anonymous.value, 'anonymous-id-rotated');
    check((await context.request.get(`${origin}/tds/session/context`, {maxRedirects: 0})).status() === 200, 'academic-context');
    const editorial = await context.request.get(`${origin}/user/login_status?_format=json`, {maxRedirects: 0});
    check(editorial.status() === 200 && [0, '0'].includes(await editorial.json()), 'no-editorial-login');
    check(await page.evaluate(() => localStorage.length === 0 && sessionStorage.length === 0), 'empty-client-storage');
    stage = 'pre-login-cookie-replay';
    const previous = await browser.newContext();
    try {
      await previous.addCookies(before);
      check((await previous.request.get(`${origin}/tds/session/context`, {maxRedirects: 0})).status() === 401, 'pre-login-cookie-rejected');
    } finally { await previous.close(); }
    const retained = await context.cookies();
    stage = 'logout-ui';
    await page.getByRole('button', {name: 'Sair da minha conta'}).click();
    await page.waitForURL(`${origin}/entrar`, {timeout: 30000});
    check((await context.request.get(`${origin}/tds/session/context`, {maxRedirects: 0})).status() === 401, 'logged-out-context');
    stage = 'revoked-cookie-replay';
    const revoked = await browser.newContext();
    try {
      await revoked.addCookies(retained);
      check((await revoked.request.get(`${origin}/tds/session/context`, {maxRedirects: 0})).status() === 401, 'revoked-cookie-rejected');
    } finally { await revoked.close(); }
    stage = 'history-back-refresh';
    await page.goBack();
    await page.reload();
    await page.getByRole('link', {name: 'Entrar na minha conta'}).waitFor();
    check((await context.request.get(`${origin}/tds/session/context`, {maxRedirects: 0})).status() === 401, 'history-refresh-remains-logged-out');
    check(await page.locator('section[aria-labelledby="tds-classes-title"] progress').count() === 0, 'history-refresh-no-academic-content');
    console.log(JSON.stringify({scope: 'isolated_browser_real_staging_api', gate: 'PASS', checks, counts: {classes_rendered: classCount, progress_rendered: progressCount}}));
  } finally {
    credentials.cpf = '';
    credentials.password = '';
    await context.close();
    await browser.close();
  }
})().catch(error => {
  const type = ['Error', 'TimeoutError', 'AssertionError'].includes(error.name) ? error.name : 'Error';
  const network = String(error.message || '').match(/net::ERR_[A-Z_]+/)?.[0] || 'none';
  console.error(JSON.stringify({scope: 'isolated_browser_real_staging_api', gate: 'BLOCKED', stage, type, network}));
  process.exitCode = 2;
});
