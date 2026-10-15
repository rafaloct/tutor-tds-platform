#!/usr/bin/env python3
"""Read-only portal smoke. Run on VPS; emits only routes/status assertions."""
import json
import urllib.request
import urllib.error

BASE = 'http://127.0.0.1:18088'
HOST = 'portal.ipexdesenvolvimento.cloud'


def get(path, host=HOST):
    req = urllib.request.Request(BASE + path, headers={'Host': host, 'User-Agent': 'TutorTDS-Deployment-Smoke/1.0'})
    try:
        response = urllib.request.urlopen(req, timeout=20)
    except urllib.error.HTTPError as error:
        response = error
    return response.status, response.headers, response.read().decode('utf-8', errors='replace')


checks = 0
for path in ['/', '/cursos', '/programa', '/noticias', '/agenda', '/materiais', '/faq', '/privacidade', '/direitos-e-exclusao', '/acessibilidade', '/contato', '/sitemap.xml']:
    code, headers, body = get(path)
    assert code == 200, (path, code)
    assert 'The website encountered an unexpected error' not in body, path
    checks += 1
    print(path, 'PASS')
code, headers, body = get('/health')
health = json.loads(body)
assert code == 200 and health['environment'] == 'production' and health['database'] == 'up'
assert 'no-store' in headers['Cache-Control']
checks += 1
code, headers, body = get('/tds/session/context')
assert code == 403 and json.loads(body)['error'] == 'production_sessions_disabled'
assert 'no-store' in headers['Cache-Control']
checks += 1
assert get('/health', 'untrusted.invalid')[0] == 400
checks += 1
for path in ['/core/install.php', '/update.php']:
    assert get(path)[0] == 403
    checks += 1
print(json.dumps({'checks': checks, 'result': 'PASS', 'scope': 'isolated-origin-not-public-https'}))
