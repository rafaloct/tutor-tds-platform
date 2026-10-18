/**
 * Runs in an opaque-origin sandbox; browser storage is intentionally unavailable.
 */
(function () {
  'use strict';
  const nonce = window.location.hash.slice(1);
  const parentOrigin = window.location.origin;
  let started = false;
  let identity = null;
  const send = (type) => window.parent.postMessage({type, nonce}, parentOrigin);
  if (window.parent === window || !/^[a-f0-9]{32}$/.test(nonce)) return;
  window.addEventListener('message', (event) => {
    if (started || event.source !== window.parent || event.origin !== parentOrigin || !event.data || event.data.nonce !== nonce || event.data.type !== 'tds-support-init') return;
    const config = event.data.identity;
    if (!config || typeof config.identifier !== 'string' || !/^[a-f0-9]{64}$/.test(config.identifier_hash) || !/^https:\/\/[^/?#\s]+$/.test(config.base_url) || !/^[A-Za-z0-9_-]{1,256}$/.test(config.website_token)) {
      send('tds-support-failed');
      return;
    }
    started = true;
    identity = {identifier: config.identifier, identifier_hash: config.identifier_hash};
    window.chatwootSettings = {hideMessageBubble: true, locale: 'pt_BR', position: 'right'};
    window.addEventListener('chatwoot:ready', () => {
      try {
        if (!identity || !window.$chatwoot) throw new Error('unavailable');
        window.$chatwoot.setUser(identity.identifier, {identifier_hash: identity.identifier_hash});
        identity = null;
        window.$chatwoot.toggle('open');
        send('tds-support-open');
      }
      catch (error) { send('tds-support-failed'); }
    }, {once: true});
    const script = document.createElement('script');
    script.src = `${config.base_url}/packs/js/sdk.js`;
    script.referrerPolicy = 'no-referrer';
    script.onerror = () => send('tds-support-failed');
    script.onload = () => {
      try {
        window.chatwootSDK.run({websiteToken: config.website_token, baseUrl: config.base_url});
      }
      catch (error) { send('tds-support-failed'); }
    };
    document.head.appendChild(script);
  });
  window.addEventListener('pagehide', () => {
    identity = null;
    try { if (window.$chatwoot) window.$chatwoot.reset(); }
    catch (error) { /* Opaque sandbox can reject SDK persistence on teardown. */ }
  });
  send('tds-support-ready');
})();
