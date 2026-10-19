"""GET-only Apache gate. Never outputs HTML, nonce values or cookies."""
import json
from pathlib import Path
import subprocess
import sys
from html.parser import HTMLParser

ip, evidence = sys.argv[1:]
host = 'tds-registration-299'
origin = 'http://' + host
def get(path):
    result = subprocess.check_output(['curl', '--noproxy', '*', '--resolve', host + ':80:' + ip,
        '--max-time', '20', '-sS', '-i', origin + path]).decode('utf-8', errors='replace')
    headers, body = result.split('\r\n\r\n', 1)
    return headers, body

headers, body = get('/?tds_qa_probe=1')
probe = json.loads(body)
Path(evidence, 'apache-probe.json').write_text(json.dumps(probe, indent=2) + '\n')
assert '200 OK' in headers and 'apache-isolation-v2' in headers
assert probe['sapi'] == 'apache2handler' and probe['mu_loaded']
assert probe['mail_short_circuit'] and probe['http_short_circuit']
assert not probe['post_gate_open']
assert probe['theme'] == 'tds-child-theme'
assert probe['home'] == origin and probe['siteurl'] == origin
assert probe['page_template'] == 'pages/cadastro.php'
print('PASS Apache MU load, mail/HTTP short circuit, native theme/template and closed POST gate', flush=True)

class Form(HTMLParser):
    names = set()
    action = False
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'input':
            self.names.add(attrs.get('name', ''))
            if attrs.get('name') == 'action' and attrs.get('value') == 'tds_cadastro':
                self.action = True
headers, body = get('/cadastro/?tds_curso=614')
form = Form(); form.feed(body)
summary = {'http200': '200 OK' in headers, 'apache_mu': 'apache-isolation-v2' in headers,
    'template': 'pages/cadastro.php' in headers, 'registration_action': form.action,
    'required_fields': {'tds_cadastro_nonce','nome','email','senha'}.issubset(form.names),
    'html_template_marker': 'cad_nome' in body}
Path(evidence, 'template-preflight.json').write_text(json.dumps(summary, indent=2) + '\n')
print('TEMPLATE_PREFLIGHT=' + json.dumps(summary), flush=True)
assert all(summary.values()), 'Template gate failed; no POST authorized'
print('PASS actual registration template rendered; no form/nonce published', flush=True)
