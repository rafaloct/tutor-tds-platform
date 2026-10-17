/* Tutor TDS | STT público do site, independente de WordPress REST, IA e vídeos. */
(function (root, doc) {
  'use strict';

  const LANG = 'pt-BR';
  const TARGET_SELECTOR = 'form input[type="search"], form input[name="s"], form textarea[name="mensagem"]';
  let active = null;

  function element(tag, className, text) {
    const el = doc.createElement(tag);
    if (className) el.className = className;
    if (text !== undefined) el.textContent = text;
    return el;
  }

  function insertRecognizedText(field, spoken) {
    const value = (spoken || '').trim();
    if (!value || !field || field.disabled || field.readOnly) return false;
    const start = typeof field.selectionStart === 'number' ? field.selectionStart : field.value.length;
    const end = typeof field.selectionEnd === 'number' ? field.selectionEnd : field.value.length;
    const before = field.value.slice(0, start);
    const after = field.value.slice(end);
    const spacer = before && !/\s$/.test(before) ? ' ' : '';
    const suffix = after && !/^\s/.test(after) ? ' ' : '';
    const replacement = spacer + value + suffix;
    if (typeof field.setRangeText === 'function') {
      field.setRangeText(replacement, start, end, 'end');
    } else {
      field.value = before + replacement + after;
    }
    field.dispatchEvent(new root.Event('input', { bubbles: true }));
    field.focus();
    return true;
  }

  function decorate(field) {
    if (!field || field.dataset.tdsSttAttached || field.disabled || field.readOnly) return;
    field.dataset.tdsSttAttached = '1';

    const Speech = root.SpeechRecognition || root.webkitSpeechRecognition;
    if (!Speech || !root.isSecureContext) return; // Original inputs still work normally.

    const label = field.type === 'search' || field.name === 's' ? 'pesquisa' : 'mensagem';
    const region = element('span', 'tds-site-stt');
    const trigger = element('button', 'tds-site-stt__button', '🎙 Falar');
    trigger.type = 'button';
    trigger.setAttribute('aria-label', 'Ditar texto para o campo de ' + label);
    trigger.title = 'Ditar em português brasileiro';
    const state = element('span', 'tds-site-stt__status');
    state.setAttribute('role', 'status');
    state.setAttribute('aria-live', 'polite');
    const choice = element('span', 'tds-site-stt__choice');
    choice.hidden = true;

    const note = element('span', 'tds-site-stt__note',
      'O reconhecimento do navegador pode enviar sua voz ao provedor do navegador. ' +
      'O Tutor TDS não grava nem recebe o áudio. Você pode continuar digitando normalmente.');
    const useBrowser = element('button', 'tds-site-stt__confirm', 'Autorizar reconhecimento do navegador');
    useBrowser.type = 'button';
    const useLocal = element('button', 'tds-site-stt__confirm', 'Instalar reconhecimento local pt-BR');
    useLocal.type = 'button';
    const cancel = element('button', 'tds-site-stt__cancel', 'Cancelar');
    cancel.type = 'button';
    choice.append(note, useBrowser, useLocal, cancel);
    region.append(trigger, state, choice);
    field.insertAdjacentElement('afterend', region);

    const setStatus = (message) => { state.textContent = message; };
    const closeChoice = () => { choice.hidden = true; };
    const showChoice = (localOption) => {
      useLocal.hidden = !localOption;
      choice.hidden = false;
      setStatus('Escolha como reconhecer sua voz.');
    };
    const stop = () => {
      if (active && active.stop) active.stop();
    };

    function startRecognition(locally) {
      if (active) stop();
      const recognition = new Speech();
      recognition.lang = LANG;
      recognition.continuous = false;
      recognition.interimResults = false;
      recognition.maxAlternatives = 1;
      if ('processLocally' in recognition) recognition.processLocally = Boolean(locally);
      let inserted = false;
      let failed = false;
      active = recognition;
      trigger.setAttribute('aria-pressed', 'true');
      trigger.textContent = '■ Parar';
      closeChoice();
      setStatus('Ouvindo. Fale naturalmente; revise o texto antes de enviar.');
      recognition.onresult = (event) => {
        let spoken = '';
        for (let i = event.resultIndex || 0; i < event.results.length; i++) {
          const result = event.results[i];
          if (result.isFinal && result[0]) spoken += result[0].transcript + ' ';
        }
        if (spoken.trim()) {
          inserted = insertRecognizedText(field, spoken);
          setStatus(inserted ? 'Texto inserido. Revise antes de enviar.' : 'Não foi possível inserir o texto.');
        }
      };
      recognition.onerror = (event) => {
        failed = true;
        const errors = {
          'not-allowed': 'Microfone não autorizado. Use o teclado.',
          'audio-capture': 'Microfone indisponível. Use o teclado.',
          'no-speech': 'Não foi detectada fala. Tente novamente.',
          'network': 'Reconhecimento indisponível. Use o teclado.',
          'language-not-supported': 'Português brasileiro não disponível neste navegador.',
        };
        setStatus(errors[event.error] || 'Reconhecimento não concluído. Use o teclado.');
      };
      recognition.onend = () => {
        if (active !== recognition) return;
        active = null;
        trigger.setAttribute('aria-pressed', 'false');
        trigger.textContent = '🎙 Falar';
        if (!inserted && !failed && !state.textContent.includes('indisponível') &&
            !state.textContent.includes('autorizado') && !state.textContent.includes('detectada')) {
          setStatus('Reconhecimento encerrado. Confira o campo.');
        }
      };
      try { recognition.start(); }
      catch (_error) {
        active = null;
        trigger.setAttribute('aria-pressed', 'false');
        trigger.textContent = '🎙 Falar';
        setStatus('Não foi possível ativar o microfone. Use o teclado.');
      }
    }

    async function preferLocal() {
      // Experimental; do not silently fall back to browser-cloud recognition.
      if (!('processLocally' in Speech.prototype) || typeof Speech.available !== 'function') {
        showChoice(false);
        return;
      }
      setStatus('Verificando reconhecimento local em pt-BR...');
      try {
        const availability = await Speech.available({ langs: [LANG], processLocally: true });
        if (availability === 'available') {
          startRecognition(true);
        } else if (availability === 'downloadable' && typeof Speech.install === 'function') {
          showChoice(true);
        } else if (availability === 'downloading') {
          setStatus('Pacote de idioma em download. Tente novamente depois.');
        } else {
          showChoice(false);
        }
      } catch (_error) {
        showChoice(false);
      }
    }

    trigger.addEventListener('click', () => {
      if (active) { stop(); return; }
      if (!choice.hidden) { closeChoice(); return; }
      preferLocal();
    });
    useBrowser.addEventListener('click', () => startRecognition(false));
    useLocal.addEventListener('click', async () => {
      useLocal.disabled = true;
      setStatus('Preparando o idioma pt-BR neste dispositivo...');
      try {
        const installed = await Speech.install({ langs: [LANG] });
        if (installed) startRecognition(true);
        else setStatus('Idioma não pôde ser instalado. Use o teclado.');
      } catch (_error) {
        setStatus('Instalação local indisponível. Use o teclado.');
      } finally { useLocal.disabled = false; }
    });
    cancel.addEventListener('click', () => {
      closeChoice();
      setStatus('Você pode digitar normalmente.');
    });
  }

  function initialize() {
    if (!doc || !doc.querySelectorAll) return;
    doc.querySelectorAll(TARGET_SELECTOR).forEach(decorate);
  }

  if (doc && doc.readyState === 'loading') {
    doc.addEventListener('DOMContentLoaded', initialize, { once: true });
  } else {
    initialize();
  }

  // Read-only QA hooks; no network and no WordPress state mutation.
  root.TDSSiteSTT = Object.freeze({ initialize, insertRecognizedText });
})(window, document);
