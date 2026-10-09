// Verifica overflow horizontal real nas rotas publicas do portal (Issue #165).
//
// Executa no HOST (fora do container) com Node >= 22 e Microsoft Edge.
// Usa CDP Emulation.setDeviceMetricsOverride: o viewport emulado e exato,
// diferente de `msedge --headless --screenshot --window-size=W,H`, que no
// Windows respeita a largura minima de janela (~500px) e produz PNG cortado.
//
// Uso:
//   node scripts/check-viewport-overflow.mjs [--base URL] [--out DIR]
//     [--widths 360,390,768,1024,1440] [--routes /portal,/cursos]
// Env: EDGE_BIN (caminho do msedge.exe), BASE_URL.
// Saida 0 = sem overflow; 1 = overflow ou falha de captura.

import { spawn } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

const args = process.argv.slice(2);
const opt = (name, fallback) => {
  const i = args.indexOf(`--${name}`);
  return i >= 0 && args[i + 1] ? args[i + 1] : fallback;
};

const BASE = process.env.BASE_URL || opt('base', 'http://127.0.0.1:8080');
const EDGE = process.env.EDGE_BIN || 'C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe';
const WIDTHS = opt('widths', '360,390,768,1024,1440').split(',').map(Number);
// Git Bash/MSYS converte args iniciados por '/' (ex.: '/portal') em caminhos
// Windows; normaliza para rota absoluta independente da shell de origem.
const ROUTES = opt('routes', '/portal,/cursos').split(',')
  .map((r) => (r.startsWith('/') ? r : `/${r.split('/').pop()}`));
const OUT = opt('out', '');
const PORT = 9333;

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function waitDebugger() {
  for (let i = 0; i < 40; i++) {
    try {
      const res = await fetch(`http://127.0.0.1:${PORT}/json/list`);
      const targets = await res.json();
      const page = targets.find((t) => t.type === 'page');
      if (page) return page.webSocketDebuggerUrl;
    } catch {}
    await sleep(250);
  }
  throw new Error('DevTools endpoint nao respondeu');
}

function connect(wsUrl) {
  const ws = new WebSocket(wsUrl);
  let seq = 0;
  const pending = new Map();
  const listeners = [];
  ws.onmessage = (ev) => {
    const msg = JSON.parse(ev.data);
    if (msg.id && pending.has(msg.id)) {
      const { resolve, reject } = pending.get(msg.id);
      pending.delete(msg.id);
      msg.error ? reject(new Error(msg.error.message)) : resolve(msg.result);
    } else if (msg.method) {
      listeners.forEach((fn) => fn(msg));
    }
  };
  const ready = new Promise((resolve, reject) => {
    ws.onopen = resolve;
    ws.onerror = () => reject(new Error('falha no WebSocket CDP'));
  });
  const send = (method, params = {}) =>
    new Promise((resolve, reject) => {
      const id = ++seq;
      pending.set(id, { resolve, reject });
      ws.send(JSON.stringify({ id, method, params }));
    });
  const once = (method, timeout = 15000) =>
    new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error(`timeout ${method}`)), timeout);
      listeners.push((msg) => {
        if (msg.method === method) { clearTimeout(timer); resolve(msg); }
      });
    });
  return { ready, send, once, close: () => ws.close() };
}

const OVERFLOW_EXPR = `(() => {
  const vw = document.documentElement.clientWidth;
  const over = [];
  document.querySelectorAll('body *').forEach((el) => {
    const r = el.getBoundingClientRect();
    if (r.right > vw + 0.5 || r.left < -0.5) {
      over.push(el.tagName + '.' + String(el.className).split(' ')[0]);
    }
  });
  return JSON.stringify({
    scrollWidth: document.documentElement.scrollWidth,
    clientWidth: vw,
    overflowing: over.slice(0, 10),
  });
})()`;

const proc = spawn(EDGE, [
  '--headless', '--disable-gpu', `--remote-debugging-port=${PORT}`,
  '--window-size=1440,900', 'about:blank',
], { stdio: 'ignore' });

let fails = 0;
try {
  const ws = await connect(await waitDebugger());
  await ws.ready;
  await ws.send('Page.enable');
  if (OUT) mkdirSync(OUT, { recursive: true });
  for (const route of ROUTES) {
    for (const width of WIDTHS) {
      await ws.send('Emulation.setDeviceMetricsOverride', {
        width, height: 900, deviceScaleFactor: 1, mobile: true,
      });
      const loaded = ws.once('Page.loadEventFired');
      await ws.send('Page.navigate', { url: BASE + route });
      await loaded;
      await sleep(400);
      const { result } = await ws.send('Runtime.evaluate', {
        expression: OVERFLOW_EXPR, returnByValue: true,
      });
      const m = JSON.parse(result.value);
      const ok = m.scrollWidth <= m.clientWidth + 0.5 && m.overflowing.length === 0;
      if (!ok) fails++;
      console.log(`${ok ? 'PASS' : 'FAIL'} ${route} @${width}px scroll=${m.scrollWidth} client=${m.clientWidth}` +
        (m.overflowing.length ? ` over=${m.overflowing.join(',')}` : ''));
      if (OUT) {
        const shot = await ws.send('Page.captureScreenshot', { format: 'png' });
        const name = `${route.replace(/\//g, '').replace(/^$/, 'home')}-${width}.png`;
        writeFileSync(join(OUT, name), Buffer.from(shot.data, 'base64'));
      }
    }
  }
  ws.close();
} finally {
  proc.kill();
}
console.log(fails === 0 ? 'VIEWPORT OVERFLOW: PASS' : `VIEWPORT OVERFLOW: FAIL (${fails})`);
process.exit(fails === 0 ? 0 : 1);
