const puppeteer = require('puppeteer');
const path = require('path');
const fs = require('fs');

const BASE_URL = 'http://localhost:8765';
const OUT_DIR = path.join(__dirname, '../screenshots');

if (!fs.existsSync(OUT_DIR)) fs.mkdirSync(OUT_DIR, { recursive: true });
const WIDTH = 1366, HEIGHT = 768;

async function wait(ms) { return new Promise(r => setTimeout(r, ms)); }
async function capture(page, name, desc) {
  await wait(2200);
  await page.screenshot({ path: path.join(OUT_DIR, `${name}.png`) });
  console.log(`✓ ${desc} → ${name}.png`);
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

// AppBar icon positions (verified)
const ICONS = { glossario: 1174, guide: 1222, about: 1270, support: 1318, cadastro: 1346 };
// FAB positions
const FAB_TUTOR = { x: 1320, y: 718 };

(async () => {
  const browser = await puppeteer.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage'],
  });
  const page = await browser.newPage();
  await page.setViewport({ width: WIDTH, height: HEIGHT });

  // ── GLOSSÁRIO — com filtro ativo ─────────────────────────────────
  await goHome(page);
  await page.mouse.click(ICONS.glossario, 32);
  await wait(3500);
  // Click "Educação Financeira" filter chip (it's in the horizontal scroll)
  // Chips appear at y~128, spaced ~100px each. Order: Todas, Agri, Atend, Audio, Coop, Econ, Educ, IA, SAF, SIM
  // "Educação Financeira" is ~6th item = ~600px from left
  await page.mouse.click(728, 128);
  await wait(1500);
  await capture(page, '04b_glossary_filtro', 'Glossário — filtrado por cartilha');

  // Type a search term
  await page.mouse.click(683, 85); // search field
  await wait(500);
  await page.keyboard.type('compostagem');
  await wait(1500);
  await capture(page, '04c_glossary_busca', 'Glossário — busca por termo');

  // ── GUIA — rolado para ver passo a passo ────────────────────────
  await goHome(page);
  await page.mouse.click(ICONS.guide, 32);
  await wait(3500);
  await page.evaluate(() => window.scrollTo(0, 600));
  await wait(1000);
  await capture(page, '03b_guide_passos', 'Como usar — passo a passo visual');

  // ── SUPORTE — bottom sheet de escolha ───────────────────────────
  // From guide screen there's a "Falar com a equipe TDS" button at bottom
  await page.evaluate(() => window.scrollTo(0, 9999));
  await wait(1000);
  // Click the green button (Falar com a equipe TDS) — it's at ~y=718 centered
  await page.mouse.click(683, 700);
  await wait(2500);
  await capture(page, '07b_support_sheet', 'Suporte — escolha WhatsApp ou Chat');

  // ── CHAT EXPERIENCE — conversation progressed ────────────────────
  await goHome(page);
  await page.mouse.click(260, 120); // click first cartilha card
  await wait(5000);
  await capture(page, '08a_chat_start', 'Cartilha — início da conversa');

  // Click "Continuar" button (centered at bottom, ~y=731)
  await page.mouse.click(683, 731);
  await wait(2500);
  await capture(page, '08b_chat_continued', 'Cartilha — após Continuar (mais conteúdo)');

  // Continue more
  await page.mouse.click(683, 731);
  await wait(2500);
  await capture(page, '08c_chat_more', 'Cartilha — avançando na conversa');

  // Continue more to find question
  await page.mouse.click(683, 731);
  await wait(2500);
  await page.mouse.click(683, 731);
  await wait(2500);
  await page.mouse.click(683, 731);
  await wait(2500);
  await capture(page, '08d_chat_question', 'Cartilha — pergunta interativa com opções');

  // Try to click one of the answer buttons (options appear in bottom panel)
  // Options are rendered as ElevatedButtons in the bottom area, ~y=680-730
  await page.mouse.click(350, 700);
  await wait(3000);
  await capture(page, '08e_chat_answered', 'Cartilha — após responder pergunta');

  // ── AI TUTOR — com modo Minha Realidade ─────────────────────────
  // Navigate to AI tutor from chat
  await page.mouse.click(FAB_TUTOR.x, FAB_TUTOR.y);
  await wait(5000);
  await capture(page, '09a_ai_initial', 'Tutor de IA — estado inicial');

  // Type a question
  await page.mouse.click(580, 735); // text input
  await wait(500);
  await page.keyboard.type('O que é agroecologia?');
  await wait(500);
  await capture(page, '09b_ai_typing', 'Tutor de IA — digitando pergunta');

  // Send message
  await page.keyboard.press('Enter');
  await wait(8000); // wait for AI response
  await capture(page, '09c_ai_response', 'Tutor de IA — resposta do assistente');

  // Click "Minha Realidade" toggle (chip in AppBar)
  await page.mouse.click(200, 28);
  await wait(2000);
  await capture(page, '09d_ai_minha_realidade', 'Tutor de IA — modo Minha Realidade');

  // ── WELCOME — com campos preenchidos ────────────────────────────
  // Open in incognito/fresh context (clear storage)
  const page2 = await browser.newPage();
  await page2.setViewport({ width: WIDTH, height: HEIGHT });
  await page2.goto(BASE_URL, { waitUntil: 'networkidle0', timeout: 30000 });
  await wait(4000);
  // Type in name field
  const inputs = await page2.$$('input');
  if (inputs.length >= 1) {
    await inputs[0].type('João Santos');
    await wait(300);
    if (inputs.length >= 2) await inputs[1].type('(63) 98765-4321');
    await wait(300);
    if (inputs.length >= 3) await inputs[2].type('987.654.321-00');
  }
  await wait(1000);
  await capture(page2, '01b_welcome_filled', 'Boas-vindas — formulário preenchido');
  await page2.close();

  await browser.close();
  console.log('\n✅ Screenshots interativos em: ' + OUT_DIR);
})();
