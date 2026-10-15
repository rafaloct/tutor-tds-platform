/**
 * Remove private certificate DOM before history restoration can reuse it.
 */
(function (Drupal, once) {
  'use strict';
  Drupal.behaviors.tdsPrivateCertificates = {
    attach(context) {
      once('tds-private-certificates', '[data-private-certificates]', context).forEach((root) => {
        const clear = () => {
          root.replaceChildren();
          root.textContent = Drupal.t('Consulte novamente os certificados após entrar na sua conta TDS.');
        };
        window.addEventListener('pagehide', clear);
        window.addEventListener('tds:session-ended', clear);
        window.addEventListener('pageshow', (event) => {
          if (event.persisted) {
            clear();
            window.location.reload();
          }
        });
      });
    },
  };
})(Drupal, once);
