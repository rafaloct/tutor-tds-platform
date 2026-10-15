#!/usr/bin/env node
// Synthetic fixture only. Never accepts an arbitrary destination or credentials.
'use strict';
const assert = require('node:assert/strict');
const { chromium } = require('/opt/codex/runtimes/cua/lib/node_modules/playwright');
const origin = 'http://127.0.0.1:18871';
if (process.env.TDS_SESSION_MUTEX_QA !== '1') throw new Error('Explicit QA opt-in required.');
let checks = 0;
let stage = 'launch';
const check = (value, message) => { stage = message; assert.ok(value, message); checks++; };
(async () => {
  const browser = await chromium.launch({executablePath: '/usr/bin/chromium', headless: true, args: ['--no-sandbox']});
  const context = await browser.newContext();
  const other = await browser.newContext();
  try {
    const page = await context.newPage();
    check((await context.cookies()).length === 0, 'fresh browser has no cookies');
    stage = 'anonymous-area-navigation';
    await page.goto(`${origin}/minha-area`);
    await page.getByRole('link', {name: 'Entrar na minha conta'}).waitFor();
    check(true, 'anonymous area offers login');
    stage = 'login-page-navigation';
    const navigation = await page.goto(`${origin}/entrar`);
    check(navigation.status() === 200 && navigation.headers()['cache-control'].includes('no-store'), 'entry is private and available');
    check(!/login_token|[?&]token=/.test(await page.content()), 'no CSRF material in HTML');
    const post = (request, path, headers = {}, data = {}) => request.post(`${origin}${path}`, {headers: {Origin: origin, ...headers}, data});
    const bootstrap = async request => {
      const response = await post(request, '/tds/session/bootstrap', {'X-TDS-Bootstrap': '1'});
      check(response.status() === 200 && response.headers()['cache-control'].includes('no-store'), 'anonymous bootstrap persists private session');
      check(!response.headers()['access-control-allow-origin'], 'bootstrap grants no CORS access');
      return response.json();
    };
    check((await post(context.request, '/tds/session/bootstrap', {Origin: 'https://other.example', 'X-TDS-Bootstrap': '1'})).status() === 403, 'foreign origin rejected');
    check((await post(context.request, '/tds/session/bootstrap')).status() === 403, 'bootstrap requires non-simple header');
    check((await context.request.get(`${origin}/tds/session/bootstrap`)).status() === 405, 'bootstrap is POST only');
    stage = 'anonymous-bootstrap';
    const tokens = await bootstrap(context.request);
    const cookie = (await context.cookies()).find(c => /^S?SESS/.test(c.name));
    check(cookie && cookie.httpOnly && cookie.sameSite === 'Lax', 'anonymous cookie HttpOnly SameSite Lax');
    const before = await context.cookies();
    const credentials = {cpf: 'qa-person-a', password: 'synthetic-valid-password'};
    check((await post(context.request, '/tds/session/login', {}, credentials)).status() === 403, 'missing CSRF rejected');
    check((await post(context.request, '/tds/session/login?token=wrong', {}, credentials)).status() === 403, 'wrong CSRF rejected');
    await bootstrap(other.request);
    check((await post(other.request, `/tds/session/login?token=${tokens.login_token}`, {}, credentials)).status() === 403, 'another session cannot reuse CSRF');
    check((await post(context.request, `/tds/session/login?token=${tokens.login_token}`, {Origin: 'https://other.example'}, credentials)).status() === 403, 'valid token does not bypass origin');
    stage = 'invalid-login-ui';
    await page.locator('#tds-cpf').fill('qa-person-a');
    await page.locator('#tds-password').fill('invalid');
    await page.getByRole('button', {name: 'Entrar', exact: true}).click();
    await page.getByText('Confira seu CPF e sua senha e tente novamente.').waitFor();
    check(await page.locator('#tds-password').inputValue() === '', 'failed login removes password');
    stage = 'valid-login-ui';
    await page.locator('#tds-password').fill('synthetic-valid-password');
    await page.getByRole('button', {name: 'Entrar', exact: true}).click();
    await page.waitForURL(`${origin}/minha-area`);
    stage = 'authenticated-dashboard';
    await page.getByText('Synthetic QA', {exact: true}).waitFor();
    check((await context.cookies()).find(c => c.name === cookie.name).value !== cookie.value, 'first TDS login rotates anonymous ID');
    const replay = await browser.newContext();
    await replay.addCookies(before);
    check((await replay.request.get(`${origin}/tds/session/context`)).status() === 401, 'anonymous old ID cannot read authenticated context');
    await replay.close();
    check(await (await context.request.get(`${origin}/user/login_status?_format=json`)).json() == 0, 'participant has no editorial authentication');
    check((await context.request.get(`${origin}/tds/session/context`)).status() === 200, 'academic context persists');
    check(await page.evaluate(() => localStorage.length === 0 && sessionStorage.length === 0), 'browser storage empty');
    const loggedInCookies = await context.cookies();
    stage = 'logout-ui';
    await page.getByRole('button', {name: 'Sair da minha conta'}).click();
    await page.waitForURL(`${origin}/entrar`);
    check((await context.request.get(`${origin}/tds/session/context`)).status() === 401, 'UI logout ends academic context');
    const revoked = await browser.newContext();
    await revoked.addCookies(loggedInCookies);
    check((await revoked.request.get(`${origin}/tds/session/context`)).status() === 401, 'retained logged-in cookie revoked');
    await revoked.close();
    console.log(`${checks} anonymous browser/bootstrap/login/logout checks PASS; synthetic fixture only.`);
  } finally {
    await context.close();
    await other.close();
    await browser.close();
  }
})().catch((error) => {
  const kind = ['Error', 'TimeoutError', 'AssertionError'].includes(error.name) ? error.name : 'Error';
  console.error(`Anonymous browser proof failed: stage=${stage}; type=${kind}; sensitive details withheld.`);
  process.exitCode = 1;
});
