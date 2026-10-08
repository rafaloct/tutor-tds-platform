/**
 * Sinal publico local e sanitizado. Nao transmite rede, URL, IDs ou texto.
 * Um provider futuro precisa de Issue/gate proprio e pode consumir o evento.
 */
(function (Drupal, once) {
  'use strict';

  Drupal.behaviors.tdsPublicAnalytics = {
    attach(context) {
      once('tds-public-analytics', '[data-tds-analytics]', context).forEach((element) => {
        element.addEventListener('click', () => {
          const eventName = element.dataset.tdsAnalytics;
          const view = element.dataset.tdsView || 'public';
          if (!/^[a-z_]{1,40}$/.test(eventName) || !/^[a-z_]{1,40}$/.test(view)) {
            return;
          }
          window.dispatchEvent(new CustomEvent('tds:public', {
            detail: {event: eventName, view},
          }));
        });
      });
    },
  };
})(Drupal, once);
