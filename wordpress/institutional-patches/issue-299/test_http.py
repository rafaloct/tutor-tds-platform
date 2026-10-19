"""Real HTTP/cookies/nonces; readback via WP-CLI only. No privileged behavioral writes."""
import http.cookiejar
import json
import os
import re
import secrets
import socket
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from html.parser import HTMLParser
from pathlib import Path

HOST = 'tds-registration-299'
BASE = 'http://' + HOST
IP, CONTAINER, EVIDENCE, MODE = sys.argv[1:]
original_resolver = socket.getaddrinfo
def resolve(host, *args, **kwargs):
    if host != HOST:
        raise RuntimeError('External network forbidden')
    return original_resolver(IP, *args, **kwargs)
socket.getaddrinfo = resolve

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args):
        return None

class Browser:
    def __init__(self):
        self.jar = http.cookiejar.CookieJar()
        self.opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect(), urllib.request.HTTPCookieProcessor(self.jar))
    def request(self, path, data=None, headers=None):
        url = urllib.parse.urljoin(BASE, path)
        if urllib.parse.urlsplit(url).netloc != HOST:
            raise RuntimeError('External request refused')
        request = urllib.request.Request(url, data=None if data is None else urllib.parse.urlencode(data).encode(), headers=headers or {})
        try:
            response = self.opener.open(request, timeout=30)
        except urllib.error.HTTPError as error:
            response = error
        return response.code, response.headers, response.read().decode('utf-8', errors='replace')

class Forms(HTMLParser):
    def __init__(self, body):
        super().__init__(); self.fields = {}; self.links = []; self.forms = []; self.current = None; self.feed(body)
        registration = next((f for f in self.forms if f.get('action') == 'tds_cadastro'), None)
        if registration is not None:
            self.fields = registration
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == 'form':
            self.current = {}; self.forms.append(self.current)
        if tag == 'input' and attrs.get('name'):
            self.fields[attrs['name']] = attrs.get('value', '')
            if self.current is not None:
                self.current[attrs['name']] = attrs.get('value', '')
        if tag == 'a' and attrs.get('href'):
            self.links.append(attrs['href'])
    def handle_endtag(self, tag):
        if tag == 'form':
            self.current = None

results = []
def check(name, condition):
    results.append({'test': name, 'status': 'PASS' if condition else 'FAIL'})
    Path(EVIDENCE, 'http-' + MODE + '.json').write_text(json.dumps(results, indent=2) + '\n')
    print(('PASS ' if condition else 'FAIL ') + name, flush=True)
    if not condition:
        raise SystemExit(1)

def wp(code):
    return subprocess.check_output(['docker','exec',CONTAINER,'php','/tmp/wp-cli.phar','--allow-root','eval',code], stderr=subprocess.DEVNULL).decode().strip()

course = wp('echo get_permalink(614);')
def count_users():
    return int(wp('echo count_users()["total_users"];'))
def enrollment_count():
    return int(wp('global $wpdb; echo $wpdb->get_var("SELECT COUNT(*) FROM {$wpdb->prefix}learnpress_user_items");'))

visitor = Browser()
code, headers, body = visitor.request('/cadastro/?tds_curso=614')
fields = Forms(body).fields
print('REGISTRATION_DIAGNOSTIC=' + json.dumps({'http':code, 'field_names':list(fields), 'form_count':len(Forms(body).forms), 'template_marker':'cad_nome' in body}), flush=True)
check('registration page uses real institutional template HTTP200', code == 200 and fields.get('action') == 'tds_cadastro')
if MODE == 'before':
    check('baseline reproduces missing course hidden field', 'tds_curso' not in fields)
    check('baseline login loses course context', any('/minha-area/' in urllib.parse.unquote(x) for x in Forms(body).links if 'wp-login.php' in x))
    raise SystemExit(0)

check('course614 preserved in native form', fields.get('tds_curso') == '614')
login_links = [x for x in Forms(body).links if 'wp-login.php' in x and urllib.parse.parse_qs(urllib.parse.urlsplit(x).query).get('redirect_to') == [course]]
check('existing account native login retains course', bool(login_links))
before_users = count_users()
bad = dict(fields, nome='QA Invalid', email='qa-invalid@qa-synthetic.test', senha=secrets.token_hex(20), tds_cadastro_nonce='invalid')
code, _, _ = visitor.request('/wp-admin/admin-post.php', bad)
check('invalid nonce HTTP403 without account creation', code == 403 and count_users() == before_users)
for invalid in ('99999999', '0', '-614', 'https://evil.invalid/', '614x', '99999999999999999999999'):
    code, headers, _ = visitor.request('/cadastro/?' + urllib.parse.urlencode({'tds_curso':invalid}))
    check('invalid course safe catalog redirect: ' + invalid, code == 302 and headers.get('Location') == BASE + '/cursos/?inscricao=curso-indisponivel')
code, headers, _ = visitor.request('/wp-admin/admin-post.php', dict(fields, tds_curso='99999999', nome='QA Invalid', email='qa-invalid@qa-synthetic.test', senha=secrets.token_hex(20)))
check('invalid course POST has no user side effect', code == 302 and '/cursos/' in headers.get('Location','') and count_users() == before_users)
password = secrets.token_hex(20)
payload = dict(fields, nome='QA Novato', email='qa-novato@qa-synthetic.test', senha=password, redirect_to='https://evil.invalid/')
code, headers, _ = visitor.request('/wp-admin/admin-post.php', payload)
check('new public registration HTTP302 to course ignoring hostile redirect', code == 302 and headers.get('Location') == course)
check('new account persisted with native session cookie', count_users() == before_users + 1 and any(c.name.startswith('wordpress_logged_in_') for c in visitor.jar))
check('registration itself does not grant enrollment', enrollment_count() == 0)
code, _, body = visitor.request(course)
check('authenticated official course HTTP200', code == 200)
m = re.search(r'var\s+(?:lpData|learn_press_js_localize)\s*=\s*(\{.*?\});', body, re.S)
nonce = json.loads(m.group(1)).get('nonce') if m else None
check('native frontend REST nonce present', bool(nonce))
for attempt, expected in [('first', 'success'), ('duplicate', 'error')]:
    code, _, response = visitor.request('/wp-json/lp/v1/courses/enroll-course', {'id':614}, {'X-WP-Nonce':nonce})
    result = json.loads(response)
    check('native free enrollment ' + attempt, code == 200 and result.get('status') == expected)
    if attempt == 'first':
        lesson_url = result.get('data', {}).get('redirect')
check('native enrollment exactly one persisted row', enrollment_count() == 1)
state = json.loads(wp('global $wpdb; echo wp_json_encode($wpdb->get_results("SELECT item_id,item_type,status,graduation FROM {$wpdb->prefix}learnpress_user_items"));'))
check('enrollment remains in progress without completion/grade', len(state) == 1 and str(state[0]['item_id']) == '614' and state[0]['status'] == 'enrolled' and state[0]['graduation'] == 'in-progress')
Path(EVIDENCE, 'enrollment-readback.json').write_text(json.dumps(state, indent=2) + '\n')
code, headers, _ = visitor.request('/cadastro/?tds_curso=614')
check('already enrolled registration entry returns course without duplicate', code == 302 and headers.get('Location') == course and enrollment_count() == 1)
expired = Browser()
code, _, _ = expired.request('/wp-json/lp/v1/courses/enroll-course', {'id':614}, {'X-WP-Nonce':nonce})
check('expired session native enrollment denied403', code == 403 and enrollment_count() == 1)
# Existing account path, using actual login form and its successful hidden inputs.
code, _, login_body = expired.request(login_links[0])
login_fields = Forms(login_body).fields
login_fields.update(log='qa-novato@qa-synthetic.test', pwd=password, redirect_to=course, testcookie='1')
code, headers, _ = expired.request('/wp-login.php', login_fields)
check('existing account login HTTP302 to requested course', code == 302 and headers.get('Location') == course)
new = Browser()
code, _, default_body = new.request('/cadastro/')
default_fields = Forms(default_body).fields
check('no-course form has no synthetic course field', code == 200 and 'tds_curso' not in default_fields)
code, headers, _ = new.request('/wp-admin/admin-post.php', dict(default_fields, nome='QA Sem Curso', email='qa-semcurso@qa-synthetic.test', senha=secrets.token_hex(20)))
check('no-course registration preserves Minha Area default', code == 302 and headers.get('Location') == BASE + '/minha-area/?cadastro=ok')
existing = Browser()
_, _, existing_body = existing.request('/cadastro/?tds_curso=614')
code, headers, _ = existing.request('/wp-admin/admin-post.php', dict(Forms(existing_body).fields, nome='QA Novato', email='qa-novato@qa-synthetic.test', senha=password))
check('existing email error preserves course for login', code == 302 and 'tds_curso=614' in headers.get('Location','') and 'cadastro=email' in headers.get('Location','') and count_users() == before_users + 2)
if lesson_url and urllib.parse.urlsplit(lesson_url).netloc == HOST:
    code, _, student_body = visitor.request(lesson_url)
    anon_code, _, anon_body = Browser().request(lesson_url)
    check('enrolled lesson available with restricted marker', code == 200 and 'QA_RESTRICTED_LESSON_299_MARKER' in student_body)
    check('visitor cannot read restricted lesson marker', 'QA_RESTRICTED_LESSON_299_MARKER' not in anon_body)
else:
    check('native lesson redirect exists', False)
_, _, course_body = visitor.request(course)
logout = next((x for x in Forms(course_body).links if 'action=logout' in x and '_wpnonce=' in x), None)
check('native logout link present', bool(logout))
code, _, _ = visitor.request(logout)
check('native logout HTTP302', code == 302)
code, _, _ = visitor.request('/wp-json/wp/v2/users/me', headers={'X-WP-Nonce':nonce})
check('logged-out session cannot access account', code in (401,403))
check('global registration policy unchanged', wp('echo get_option("users_can_register");') == '0')
print('HTTP_TOTAL_PASS=' + str(len(results)), flush=True)
