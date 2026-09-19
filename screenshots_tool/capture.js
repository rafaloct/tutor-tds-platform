const puppeteer = require('puppeteer');
const path = require('path');
const fs = require('fs');

const BASE_URL = 'http://localhost:8765';
const OUT_DIR = path.join(__dirname, '../screenshots');

if (!fs.existsSync(OUT_DIR)) fs.mkdirSync(OUT_DIR, { recursive: true });

const WIDTH = 1366;
const HEIGHT = 768;

async function wait(ms) { return new Promise(r => setTimeout(r, ms)); }

async function capture(page, name, description) {
  await wait(2500);
  const file = path.join(OUT_DIR, `${name}.png`);
  await page.screenshot({ path: file });
  console.log(`✓ ${description} → ${name}.png`);
}

async function setLoggedIn(page) {
  await page.evaluate(() => {
    localStorage.setItem('flutter.user_name', '"Maria da Silva"');
    localStorage.setItem('flutter.user_phone', '"(63) 99999-1234"');
    localStorage.setItem('flutter.user_cpf', '"123.456.789-00"');
  });
}

async function goHome(page) {
  await page.goto(BASE_URL, { waitUntil: 'networkidle0', timeout: 30000 });
  await setLoggedIn(page);
  await page.reload({ waitUntil: 'networkidle0' });
  await wait(4000);
}

// Correct AppBar icon positions (verified by testing):
// menu_book=1174  help=1222  info=1270  support=1318  person=1346
const ICONS = { glossario: 1174, guide: 1222, about: 1270, support: 1318, cadastro: 1346 };

(async () => {
  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage'],
  });
  const page = await browser.newPage();
  await page.setViewport({ width: WIDTH, height: HEIGHT });

  // ── 1. Boas-vindas / Cadastro inicial ──────────────────────────
  await page.goto(BASE_URL, { waitUntil: 'networkidle0', timeout: 30000 });
  await wait(4000);
  await capture(page, '01_welcome', 'Tela de Boas-vindas');

  // ── 2. Tela Principal (grid de cartilhas) ──────────────────────
  await goHome(page);
  await capture(page, '02_home', 'Tela Principal — Cartilhas');

  // ── 3. Como usar o App ──────────────────────────────────────────
  await goHome(page);
  await page.mouse.click(ICONS.guide, 32);
  await wait(3500);
  await capture(page, '03_guide', 'Como usar o App TDS');

  // ── 4. Glossário ────────────────────────────────────────────────
  await goHome(page);
  await page.mouse.click(ICONS.glossario, 32);
  await wait(3500);
  await capture(page, '04_glossary', 'Glossário TDS');

  // ── 5. Sobre o Programa ─────────────────────────────────────────
  await goHome(page);
  await page.mouse.click(ICONS.about, 32);
  await wait(3500);
  await capture(page, '05_about', 'Sobre o Programa TDS');

  // ── 6. Meu Cadastro (CadÚnico) ─────────────────────────────────
  await goHome(page);
  await page.mouse.click(ICONS.cadastro, 32);
  await wait(3500);
  await capture(page, '06_cadunico', 'Meu Cadastro TDS');

  // ── 7. Suporte TDS ──────────────────────────────────────────────
  await goHome(page);
  await page.mouse.click(ICONS.support, 32);
  await wait(5000);
  await capture(page, '07_support', 'Suporte TDS');

  // ── 8. Cartilha Interativa (chat) ──────────────────────────────
  await goHome(page);
  await page.mouse.click(260, 120);
  await wait(5000);
  await capture(page, '08_chat_experience', 'Cartilha Interativa');

  // ── 9. Tutor de IA ──────────────────────────────────────────────
  // FAB psychology button, bottom-right of chat screen
  await page.mouse.click(1320, 718);
  await wait(5000);
  await capture(page, '09_ai_tutor', 'Tutor de IA');

  await browser.close();
  console.log('\n✅ Screenshots em: ' + OUT_DIR);
})();
