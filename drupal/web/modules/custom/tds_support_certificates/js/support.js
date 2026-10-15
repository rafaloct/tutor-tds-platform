/**
 * Signed support identity exists only in this page's transient closure.
 */
(function (Drupal, once) {
  'use strict';
  Drupal.behaviors.tdsSupport = {
    attach(context) {
      once('tds-support', '[data-tds-support]', context).forEach((root) => {
        const start = root.querySelector('[data-support-start]');
        const stop = root.querySelector('[data-support-stop]');
        const status = root.querySelector('[data-support-status]');
        const host = root.querySelector('[data-support-frame]');
        let epoch = 0;
        let frame = null;
        let identity = null;
        let nonce = null;
        let abort = null;
        let timeout = null;
        let heartbeat = null;
        const reset = (message = '') => {
          epoch += 1;
          if (abort) abort.abort();
          abort = null;
          clearTimeout(timeout);
          clearInterval(heartbeat);
          timeout = null;
          heartbeat = null;
          if (frame) frame.remove();
          frame = null;
          identity = null;
          nonce = null;
          start.disabled = false;
          stop.hidden = true;
          status.textContent = message;
        };
        const fetchIdentity = async (signal) => {
          const url = new URL(root.dataset.identityUrl, window.location.href);
          if (url.origin !== window.location.origin) throw new Error('configuration');
          const response = await fetch(url, {credentials: 'same-origin', cache: 'no-store', redirect: 'error', signal: AbortSignal.any([signal, AbortSignal.timeout(10000)])});
          if (!response.ok) throw new Error('unavailable');
          return response.json();
        };
        const unavailable = () => reset(Drupal.t('Atendimento indisponível ou sessão encerrada. Use o canal público abaixo; se já iniciou uma conversa, evite duplicar a solicitação.'));
        start.addEventListener('click', async () => {
          reset();
          const current = epoch;
          start.disabled = true;
          stop.hidden = false;
          status.textContent = Drupal.t('Conectando ao atendimento…');
          abort = new AbortController();
          timeout = setTimeout(unavailable, 15000);
          try {
            const fetchedIdentity = await fetchIdentity(abort.signal);
            if (current !== epoch) return;
            identity = fetchedIdentity;
            const url = new URL(root.dataset.frameUrl, window.location.href);
            if (url.origin !== window.location.origin) throw new Error('configuration');
            nonce = Array.from(crypto.getRandomValues(new Uint32Array(4)), (v) => v.toString(16).padStart(8, '0')).join('');
            url.hash = nonce;
            frame = document.createElement('iframe');
            frame.title = Drupal.t('Atendimento autenticado TDS');
            // No same-origin: third-party scripts cannot access portal storage.
            frame.setAttribute('sandbox', 'allow-scripts allow-forms');
            frame.referrerPolicy = 'no-referrer';
            frame.src = url.href;
            host.appendChild(frame);
          }
          catch (error) {
            if (current === epoch) unavailable();
          }
        });
        window.addEventListener('message', (event) => {
          if (!frame || event.source !== frame.contentWindow || event.origin !== 'null' || !event.data || event.data.nonce !== nonce) return;
          if (event.data.type === 'tds-support-ready' && identity) {
            // Opaque sandbox origins require '*'; source+nonce bind the receiver.
            frame.contentWindow.postMessage({type: 'tds-support-init', nonce, identity}, '*');
          }
          else if (event.data.type === 'tds-support-open') {
            clearTimeout(timeout);
            status.textContent = Drupal.t('Atendimento aberto.');
            if (heartbeat) return;
            const current = epoch;
            heartbeat = setInterval(async () => {
              try {
                const latest = await fetchIdentity(abort.signal);
                if (current !== epoch) return;
                if (!identity || latest.identifier !== identity.identifier || latest.identifier_hash !== identity.identifier_hash) unavailable();
              }
              catch (error) {
                if (current === epoch) unavailable();
              }
            }, 15000);
          }
          else if (event.data.type === 'tds-support-failed') unavailable();
        });
        stop.addEventListener('click', () => reset(Drupal.t('Atendimento fechado nesta página. A conversa existente pode ser retomada pelo mesmo canal.')));
        window.addEventListener('pagehide', () => reset());
        window.addEventListener('pageshow', (event) => { if (event.persisted) reset(); });
        document.addEventListener('visibilitychange', () => { if (document.hidden) reset(); });
        window.addEventListener('tds:session-ended', () => reset());
      });
    },
  };
})(Drupal, once);
