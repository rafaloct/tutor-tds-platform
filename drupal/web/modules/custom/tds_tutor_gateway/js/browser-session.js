(function (Drupal, once) {
  'use strict';
  const request = async (url, payload, bootstrap = false) => {
    const response = await fetch(url, {
      method: 'POST', credentials: 'same-origin', mode: 'same-origin',
      cache: 'no-store', redirect: 'error',
      headers: {'Content-Type': 'application/json', ...(bootstrap ? {'X-TDS-Bootstrap': '1'} : {})},
      body: JSON.stringify(payload || {}), signal: AbortSignal.timeout(15000)
    });
    if (!response.ok) throw new Error(String(response.status));
    return response.json();
  };
  const withToken = (path, token) => {
    const url = new URL(path, window.location.origin);
    url.searchParams.set('token', token);
    return url.toString();
  };
  Drupal.behaviors.tdsBrowserSession = {
    attach(context) {
      once('tds-login', '[data-tds-login]', context).forEach((form) => {
        const status = form.querySelector('[data-tds-login-status]');
        const button = form.querySelector('button');
        const cpf = form.querySelector('#tds-cpf');
        const password = form.querySelector('#tds-password');
        // No token or credential is retained beyond the current request.
        button.disabled = false;
        status.textContent = '';
        form.addEventListener('submit', async (event) => {
          event.preventDefault();
          if (button.disabled) return;
          button.disabled = true;
          status.textContent = 'Entrando…';
          try {
            const tokens = await request(form.dataset.bootstrap, null, true);
            await request(withToken(form.dataset.login, tokens.login_token), {cpf: cpf.value, password: password.value});
            cpf.value = '';
            password.value = '';
            window.location.assign(form.dataset.destination);
          } catch (error) {
            password.value = '';
            status.textContent = error.message === '401' || error.message === '422'
              ? 'Confira seu CPF e sua senha e tente novamente.'
              : 'Não foi possível entrar agora. Tente novamente.';
            button.disabled = false;
          }
        });
      });
      once('tds-logout', '[data-tds-logout]', context).forEach((button) => {
        button.addEventListener('click', async () => {
          button.disabled = true;
          const status = document.querySelector('[data-tds-logout-status]');
          try {
            // Always obtain the current session token immediately before logout.
            const tokens = await request(button.dataset.bootstrap, null, true);
            await request(withToken(button.dataset.logout, tokens.logout_token));
            window.dispatchEvent(new Event('tds:session-ended'));
            window.location.assign(button.dataset.destination);
          } catch (_) {
            status.textContent = 'Não foi possível sair agora. Tente novamente.';
            button.disabled = false;
          }
        });
      });
    }
  };
})(Drupal, once);
