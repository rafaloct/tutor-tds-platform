/* QA real em Chrome do site público, SEM instalação/deploy ou envio de formulário. */
const assert = require('node:assert/strict');
const path = require('node:path');
const fs = require('node:fs');
const puppeteer = require('puppeteer-core');

const CHROME = process.env.CHROME_PATH || 'C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe';
const ROOT = process.env.SITE_URL || 'https://ead.ipexdesenvolvimento.cloud';
const ARTIFACTS = path.join(__dirname, '..', 'qa-results');
const JS = path.join(__dirname, '..', 'assets', 'site-stt.js');
const CSS = path.join(__dirname, '..', 'assets', 'site-stt.css');

(async () => {
  fs.mkdirSync(ARTIFACTS, { recursive: true });
  const browser = await puppeteer.launch({
    headless: true, executablePath: CHROME,
    args: ['--disable-dev-shm-usage', '--no-first-run'],
  });
  const report = [];
  try {
    for (const [label, url, viewport] of [
      ['contato-mobile', ROOT + '/contato/', {width:390,height:844}],
      ['contato-desktop', ROOT + '/contato/', {width:1366,height:768}],
    ]) {
      const page = await browser.newPage();
      page.setDefaultNavigationTimeout(25000);
      await page.setViewport({ ...viewport, deviceScaleFactor: 1 });
      await page.setBypassCSP(true);
      const response = await page.goto(url, {waitUntil:'domcontentloaded'});
      assert.equal(response.status(), 200, label + ': HTTP != 200');
      await page.evaluate(() => {
        window.__tdsSttInstances = [];
        window.__tdsSubmitCount = 0;
        class MockSpeech {
          constructor() { this.processLocally=false; window.__tdsSttInstances.push(this); }
          start() {this.started=true;}
          stop() {if (this.onend) this.onend();}
        }
        MockSpeech.prototype.processLocally = false;
        MockSpeech.available = async () => 'available';
        MockSpeech.install = async () => true;
        window.SpeechRecognition = MockSpeech;
        document.querySelectorAll('form').forEach(form =>
          form.addEventListener('submit', e => {e.preventDefault();window.__tdsSubmitCount++;}));
      });
      await page.addStyleTag({path:CSS});
      await page.addScriptTag({path:JS});
      const btns = await page.$$('.tds-site-stt__button');
      assert.ok(btns.length >= 1, label + ': nenhum botão STT no formulário');
      let target = label.startsWith('contato')
        ? await page.$('textarea[name="mensagem"]')
        : await page.$('input[name="s"]');
      assert.ok(target, label + ': alvo da página não encontrado');
      const next = await target.evaluate(el =>
        !!el.nextElementSibling?.matches?.('.tds-site-stt'));
      assert.equal(next, true, label + ': botão fora do campo de voz esperado');

      await target.evaluate(el=> {el.value='';el.focus();});
      const trigger = await target.evaluateHandle(el=>el.nextElementSibling.querySelector('.tds-site-stt__button'));
      await trigger.asElement().evaluate(el => el.scrollIntoView({block:"center",inline:"nearest"}));
      console.log("BUTTON_INSPECT",label,await trigger.asElement().evaluate(el => ({rect:el.getBoundingClientRect().toJSON(), display:getComputedStyle(el).display, visibility:getComputedStyle(el).visibility, hidden:!el.offsetParent, parentDisplay:getComputedStyle(el.parentElement).display})));
      await trigger.asElement().click();
      await page.waitForFunction(() => window.__tdsSttInstances.length > 0,{timeout:5000});
      await page.evaluate(() => {
        const item = window.__tdsSttInstances.at(-1);
        if (!item.processLocally || item.lang !== 'pt-BR') throw Error('Ajuste local/idioma ausente');
        item.onresult({resultIndex:0,results:[{isFinal:true,0:{transcript:'quero conhecer os cursos gratuitos'}}]});
        item.onend();
      });
      assert.equal(await target.evaluate(el=>el.value),'quero conhecer os cursos gratuitos');
      assert.equal(await page.evaluate(()=>window.__tdsSubmitCount),0,'Formulário enviado sem confirmação');
      const rect = await trigger.asElement().boundingBox();
      assert.ok(rect && rect.x >= 0 && rect.x+rect.width <= viewport.width+2, label+': botão sobreposto fora da tela');
      await page.screenshot({path:path.join(ARTIFACTS,label+'.png'),fullPage:false});
      report.push({label,http:response.status(),buttons:btns.length,submitted:0,
        microphone:'mocked',ptBR:true,insertedText:true,viewport});
      await page.close();
    }
    fs.writeFileSync(path.join(ARTIFACTS,'browser-smoke.json'), JSON.stringify(report,null,2)+'\n');
    console.log('SITE_STT_CHROME_SMOKE_PASS',JSON.stringify(report));
  } finally {await browser.close();}
})().catch(err=>{console.error('SITE_STT_CHROME_SMOKE_FAIL',err.stack||err.message);process.exitCode=1});
