/**
 * Navegação recolhível (progressive enhancement).
 * Sem JS a navegação permanece visível; com JS vira menu com botão acessível.
 * Nenhum dado é coletado ou enviado.
 */
(function () {
	'use strict';

	var header = document.querySelector('.tds-header');
	var toggle = header && header.querySelector('.tds-nav-toggle');
	var nav = header && header.querySelector('#tds-primary-nav');
	if (!header || !toggle || !nav) {
		return;
	}

	var mobile = window.matchMedia('(max-width: 899px)');

	function setOpen(open) {
		header.classList.toggle('is-open', open);
		toggle.setAttribute('aria-expanded', open ? 'true' : 'false');
	}

	function enhance() {
		if (mobile.matches) {
			header.setAttribute('data-tds-nav', 'enhanced');
			toggle.hidden = false;
			setOpen(false);
		} else {
			header.setAttribute('data-tds-nav', 'basic');
			toggle.hidden = true;
			setOpen(false);
		}
	}

	toggle.addEventListener('click', function () {
		var open = toggle.getAttribute('aria-expanded') !== 'true';
		setOpen(open);
		if (open) {
			var first = nav.querySelector('a, button');
			if (first) {
				first.focus();
			}
		}
	});

	document.addEventListener('keydown', function (event) {
		if (event.key === 'Escape' && toggle.getAttribute('aria-expanded') === 'true') {
			setOpen(false);
			toggle.focus();
		}
	});

	nav.addEventListener('focusout', function (event) {
		if (mobile.matches && toggle.getAttribute('aria-expanded') === 'true' && event.relatedTarget && !header.contains(event.relatedTarget)) {
			setOpen(false);
		}
	});

	if (typeof mobile.addEventListener === 'function') {
		mobile.addEventListener('change', enhance);
	} else if (typeof mobile.addListener === 'function') {
		mobile.addListener(enhance);
	}
	enhance();

	// Skip link: garante foco programático no destino em todos os navegadores.
	var skip = document.querySelector('.tds-skip-link');
	if (skip) {
		skip.addEventListener('click', function () {
			var target = document.getElementById('tds-main');
			if (target) {
				target.focus();
			}
		});
	}
})();
