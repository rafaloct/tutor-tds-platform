const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { JSDOM } = require('jsdom');

const script = fs.readFileSync(path.join(__dirname, '..', 'assets', 'site-stt.js'), 'utf8');
const html = `<!doctype html><html lang="pt-BR"><body>
<form id="search"><input name="s" type="search" aria-label="Pesquisar"><button type="submit">Buscar</button></form>
<form id="contact"><input name="nome" type="text"><input name="email" type="email">
<textarea name="mensagem"></textarea><button type="submit">Enviar</button></form>
<input type="password" name="password"></body></html>`;

function create(available = 'available', speechEnabled = true) {
  const dom = new JSDOM(html, { runScripts: 'outside-only', url: 'https://ead.ipexdesenvolvimento.cloud/' });
  const { window } = dom;
  const recognitions = [];
  const submitted = [];
  window.document.querySelector('#contact').addEventListener('submit', e => { e.preventDefault(); submitted.push('contact'); });
  window.document.querySelector('#search').addEventListener('submit', e => { e.preventDefault(); submitted.push('search'); });
  Object.defineProperty(window, 'isSecureContext', { value: true, configurable: true });
  if (speechEnabled) {
    class FakeRecognition {
      constructor() { this.processLocally = false; this.started = false; recognitions.push(this); }
      start() { this.started = true; }
      stop() { this.stopped = true; if (this.onend) this.onend(); }
    }
    FakeRecognition.prototype.processLocally = false;
    FakeRecognition.available = async () => available;
    FakeRecognition.install = async () => true;
    window.SpeechRecognition = FakeRecognition;
  }
  window.eval(script);
  window.TDSSiteSTT.initialize();  // Idempotency and delayed DOM readiness.
  return { window, dom, recognitions, submitted };
}
const tick = async () => new Promise(resolve => setImmediate(resolve));

test('não altera formulário, não grava nem ativa o microfone ao carregar', () => {
  const { window, recognitions, submitted } = create();
  const buttons = window.document.querySelectorAll('.tds-site-stt__button');
  assert.equal(buttons.length, 2);
  assert.equal(recognitions.length, 0);
  assert.equal(submitted.length, 0);
  assert.equal(window.document.querySelectorAll('input[name="password"] + .tds-site-stt').length, 0);
  assert.equal(window.document.querySelectorAll('input[name="nome"] + .tds-site-stt').length, 0);
  assert.equal(window.document.querySelectorAll('input[name="email"] + .tds-site-stt').length, 0);
  assert.equal(window.document.querySelectorAll('button[type="submit"]').length, 2);
});

test('reconhecimento local pt-BR é preferido e texto só é inserido após resultado final', async () => {
  const { window, recognitions, submitted } = create('available');
  const input = window.document.querySelector('input[name="s"]');
  input.value = 'agricultura';
  input.setSelectionRange(11,11);
  window.document.querySelector('.tds-site-stt__button').click();
  await tick();
  assert.equal(recognitions.length, 1);
  assert.equal(recognitions[0].processLocally, true);
  assert.equal(recognitions[0].lang, 'pt-BR');
  assert.equal(input.value, 'agricultura');
  recognitions[0].onresult({
    resultIndex: 0,
    results: [{ isFinal: true, 0: { transcript: 'familiar sustentável' } }]
  });
  assert.equal(input.value, 'agricultura familiar sustentável');
  assert.equal(submitted.length, 0);
  assert.match(window.document.querySelector('.tds-site-stt__status').textContent,/Revise/);
  recognitions[0].onend();
  assert.equal(submitted.length, 0);
});

test('sem reconhecimento local exige escolha explícita antes de potencial envio externo', async () => {
  const { window, recognitions } = create('unavailable');
  const microphone = window.document.querySelector('.tds-site-stt__button');
  microphone.click();
  await tick();
  assert.equal(recognitions.length, 0);
  const choice = window.document.querySelector('.tds-site-stt__choice');
  assert.equal(choice.hidden, false);
  assert.match(choice.textContent, /pode enviar sua voz/);
  assert.equal(choice.querySelector('.tds-site-stt__confirm').type, 'button');
  choice.querySelector('.tds-site-stt__confirm').click();
  assert.equal(recognitions.length, 1);
  assert.equal(recognitions[0].processLocally, false);
  assert.equal(recognitions[0].started, true);
});

test('se o navegador não suporta STT, os formulários continuam funcionais', () => {
  const { window, recognitions } = create('available', false);
  assert.equal(window.document.querySelectorAll('.tds-site-stt__button').length, 0);
  assert.equal(window.document.querySelector('input[name="s"]').type,'search');
  assert.equal(window.document.querySelector('textarea[name="mensagem"]').name,'mensagem');
  assert.equal(recognitions.length, 0);
});

test('campo de contato preserva texto anterior e apenas dispara input', () => {
  const { window } = create();
  const field = window.document.querySelector('textarea[name="mensagem"]');
  field.value = 'Bom dia,';
  field.setSelectionRange(field.value.length,field.value.length);
  let inputs = 0;field.addEventListener('input', () => inputs++);
  assert.equal(window.TDSSiteSTT.insertRecognizedText(field,'gostaria de saber mais'),true);
  assert.equal(field.value,'Bom dia, gostaria de saber mais');
  assert.equal(inputs,1);
});

test('erro de permissão permanece visível após encerrar o reconhecimento', async () => {
  const {window,recognitions} = create('available');
  window.document.querySelector('.tds-site-stt__button').click();
  await tick();
  assert.equal(recognitions.length, 1);
  recognitions[0].onerror({error:'not-allowed'});
  recognitions[0].onend();
  assert.match(window.document.querySelector('.tds-site-stt__status').textContent,/não autorizado/);
  assert.equal(window.document.querySelector('.tds-site-stt__button').getAttribute('aria-pressed'),'false');
});
