"""Native administrator HTTP saves in a disposable clone; secrets stay in memory."""
import http.cookiejar
import json
import os
import secrets
import socket
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request
from html.parser import HTMLParser
from pathlib import Path

IP, CONTAINER, EVIDENCE = sys.argv[1:]
HOST = 'tds-registration-299'
BASE = 'http://' + HOST
MEDIA = 'https://ead.ipexdesenvolvimento.cloud/wp-content/uploads/tutor-tds/'
MP4 = MEDIA + 'v2-20261016/agricultura_sustentavel/01_agroecologia_cerrado_v2_acessivel_FHD.mp4'
VTT = MEDIA + 'v2-20261016/agricultura_sustentavel/01_agroecologia_cerrado.vtt'
VTT_OTHER = MEDIA + 'agricultura_sustentavel/01-agroecologia-cerrado.vtt'
resolver = socket.getaddrinfo
def resolve(host, *args, **kwargs):
    if host != HOST: raise RuntimeError('External network forbidden')
    return resolver(IP, *args, **kwargs)
socket.getaddrinfo = resolve

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *args): return None

jar = http.cookiejar.CookieJar()
browser = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect(), urllib.request.HTTPCookieProcessor(jar))
def request(path, data=None, headers=None):
    url = urllib.parse.urljoin(BASE, path)
    if urllib.parse.urlsplit(url).netloc != HOST: raise RuntimeError('External URL refused')
    req = urllib.request.Request(url, data=None if data is None else urllib.parse.urlencode(data).encode(), headers=headers or {})
    try: response = browser.open(req, timeout=30)
    except urllib.error.HTTPError as error: response = error
    return response.code, response.headers, response.read().decode('utf-8', errors='replace')

class Form(HTMLParser):
    def __init__(self, body):
        super().__init__(); self.active=False; self.pairs=[]; self.select=None; self.options=[]; self.option=None; self.textarea=None; self.text=''; self.feed(body)
    def handle_starttag(self, tag, attrs):
        d=dict(attrs)
        if tag=='form' and d.get('id')=='post': self.active=True
        elif self.active and tag=='input' and d.get('name') and 'disabled' not in d:
            typ=d.get('type','text').lower()
            if typ not in ('submit','button','image','file','reset') and (typ not in ('checkbox','radio') or 'checked' in d): self.pairs.append((d['name'],d.get('value','')))
        elif self.active and tag=='select' and d.get('name'): self.select=d['name']; self.options=[]
        elif self.select and tag=='option': self.option=[d.get('value',''),'selected' in d]; self.options.append(self.option)
        elif self.active and tag=='textarea': self.textarea=d.get('name'); self.text=''
    def handle_data(self,data):
        if self.textarea: self.text+=data
    def handle_endtag(self,tag):
        if tag=='form': self.active=False
        elif tag=='select' and self.select:
            chosen=next((x for x in self.options if x[1]),self.options[0] if self.options else ['',False]); self.pairs.append((self.select,chosen[0])); self.select=None
        elif tag=='textarea' and self.textarea: self.pairs.append((self.textarea,self.text)); self.textarea=None

results=[]
def check(name, condition, **facts):
    results.append(dict(test=name,status='PASS' if condition else 'FAIL',**facts))
    Path(EVIDENCE,'editorial-http.json').write_text(json.dumps(results,indent=2)+'\n')
    print(('PASS ' if condition else 'FAIL ')+name,flush=True)
    if not condition: raise SystemExit(1)
def wp(code, env=None):
    args=['docker','exec']
    for key in env or {}: args+=['-e',key]
    return subprocess.check_output(args+[CONTAINER,'php','/tmp/wp-cli.phar','--allow-root','eval',code],env=dict(os.environ,**(env or {})),stderr=subprocess.DEVNULL).decode().strip()

check('clone database guard',wp('echo DB_NAME;').startswith('tds_registration_299r_'))
password=secrets.token_hex(24)
wp('$id=wp_create_user("qa-adapter-admin",getenv("QA_PASSWORD"),"qa-adapter-admin@qa-synthetic.test"); if(is_wp_error($id))throw new Exception("fixture user"); (new WP_User($id))->set_role("administrator");',{'QA_PASSWORD':password})
request('/wp-login.php')
code,_,_=request('/wp-login.php',{'log':'qa-adapter-admin','pwd':password,'testcookie':'1','redirect_to':BASE+'/wp-admin/'})
check('native admin login302',code==302 and any(c.name.startswith('wordpress_logged_in_') for c in jar),http=code)
def save(vtt, public='1', nonce=None):
    code,_,body=request('/wp-admin/post.php?post=13&action=edit')
    check('authorized native form200',code==200 and 'tds_mobile_lesson_nonce' in body,http=code)
    pairs=Form(body).pairs
    changes={'action':'editpost','post_ID':'13','post_type':'lp_lesson','post_status':'publish','original_post_status':'publish','post_title':'QA real staging - Agroecologia','content':'<h2>QA sintético</h2><p>Integração real, sem dados de alunos.</p><video controls><source src="'+MP4+'"><track kind="captions" src="'+vtt+'" srclang="pt-BR"></video>','tds_mobile_public':public,'tds_mobile_rights_approved':'1','tds_mobile_youtube_id':'','tds_mobile_poster_url':'','tds_mobile_captions_url':''}
    if nonce: changes['_wpnonce']=nonce
    return request('/wp-admin/post.php',[(k,v) for k,v in pairs if k not in changes]+list(changes.items()))[0]
def rest(suffix, headers=None): return request('/?rest_route=/tds-learning/v1/courses/12/'+suffix,headers=headers)

prior=None
for index,(vtt,expected) in enumerate([(VTT,'0'),(VTT,'1'),(VTT_OTHER,'0')],1):
    code=save(vtt)
    rights=wp('echo get_post_meta(13,"_tds_mobile_rights_approved",true);')
    check('native save rights step '+str(index),code==302 and rights==expected,http=code,rights=rights)
    code,headers,body=rest('lessons/13'); data=json.loads(body)
    check('REST media gate step '+str(index),code==200 and (data.get('media',{}).get('source_url')==MP4 if expected=='1' else data.get('media') is None),http=code)
    etag=headers.get('ETag')
    check('ETag invalidation step '+str(index),bool(etag) and etag!=prior)
    check('conditional REST304 step '+str(index),rest('lessons/13',{'If-None-Match':etag})[0]==304)
    prior=etag
code=save(VTT_OTHER,nonce='invalid-native-nonce')
check('native invalid nonce403',code==403 and wp('echo get_post_meta(13,"_tds_mobile_rights_approved",true);')=='0',http=code)
code=save(VTT_OTHER,public='0')
check('optout public REST404',code==302 and rest('lessons/13')[0]==404)
# Explicit opt-in of exactly one synthetic lesson for Android; changed source first revokes.
for expected in ('0','1'):
    code=save(VTT)
    check('Android fixture reviewed rights '+expected,code==302 and wp('echo get_post_meta(13,"_tds_mobile_rights_approved",true);')==expected)
for suffix,name in [('curriculum','curriculum'),('lessons/13','lesson')]:
    code,headers,body=rest(suffix)
    check('Android live '+name+'200',code==200,http=code)
    Path(EVIDENCE,name+'-live.json').write_text(body+'\n')
    check('Android live '+name+'304',rest(suffix,{'If-None-Match':headers.get('ETag','')})[0]==304)
check('zero academic rows',wp('global $wpdb; echo $wpdb->get_var("SELECT COUNT(*) FROM {$wpdb->prefix}learnpress_user_items");')=='0')
print('EDITORIAL_TOTAL_PASS='+str(len(results)),flush=True)
