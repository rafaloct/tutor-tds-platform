"""Build an offline QA restore source from pinned retained data and verified packages.

No live database, WordPress bootstrap, cron or production endpoint is consulted.
"""
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import socket
import subprocess
import tarfile
import urllib.request
import zipfile

ROOT=Path('/opt/tds-learning-qa-20261017')
OLD=ROOT/'backups/20261019T233038Z-registration-299-resume'
DEST=ROOT/'immutable-qa-4dc75881-20261019'
SQL='4dc75881fb3f2df0c01a9fa65f1e99973cb231a35ee84ddd0ee34a1ccbc81a16'
LP='1230172064c3065e131f95f25d5a8772255e85b725842eade28bf24b0ff61a20'
CLI='ce34ddd838f7351d6759068d09793f26755463b4a4610a5a5c0a97b68220d85c'
PLUGIN={
 'tds-learnpress-editorial.php':'0634e24dd1503e8e30904cf026540e7a1d89dad3c1bb1ffcfbc88144a17ec1d9',
 'includes/class-tds-learnpress-editorial-admin.php':'eedf01c063ea3cd1718f92cc3e621b50b79705d374449d083701e1a7458be4da',
 'includes/class-tds-learnpress-editorial.php':'97e6dfd30376dd506f993980d7df9935007987f8b40eadc003b2b6b1f5dc1560'}

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def require(ok,label):
    if not ok: raise RuntimeError(label)
    print('PASS '+label,flush=True)
def safe(name):
    p=PurePosixPath(name)
    require(not p.is_absolute() and '..' not in p.parts,'safe archive path') if p.is_absolute() or '..' in p.parts else None
    return p
def download(url,path):
    with urllib.request.urlopen(url,timeout=60) as r, path.open('xb') as out: shutil.copyfileobj(r,out)

require(socket.gethostname()=='srv1533541','host identity')
require(not DEST.exists(),'exclusive immutable source path')
require(sha(OLD/'source-before.sql')==SQL and sha(OLD/'source-after.sql')==SQL,'retained SQL matches both gate299 hashes')
require(sha(OLD/'theme-provenance.json')=='32b5be5a88f40bcd04759c2266f222dd5ae4d67b477e1c9686318bacfa32b31d','retained theme manifest')
require(sha(ROOT/'wp-cli')==CLI,'WP CLI official package hash')
os.umask(0o077)
DEST.mkdir(mode=0o700)
shutil.copyfile(OLD/'source-before.sql',DEST/'database.sql')
shutil.copyfile(ROOT/'wp-cli',DEST/'wp-cli.phar')
download('https://wordpress.org/wordpress-6.7.2.zip',DEST/'wordpress-6.7.2.zip')
download('https://api.wordpress.org/core/checksums/1.0/?version=6.7.2&locale=en_US',DEST/'core-checksums.json')
download('https://downloads.wordpress.org/plugin/learnpress.4.3.6.zip',DEST/'learnpress.4.3.6.zip')
require(sha(DEST/'learnpress.4.3.6.zip')==LP,'LearnPress archive matches historical tested package')
checks=json.loads((DEST/'core-checksums.json').read_text())['checksums']
with zipfile.ZipFile(DEST/'wordpress-6.7.2.zip') as z:
    for name in z.namelist(): safe(name)
    for name,md5 in checks.items():
        if hashlib.md5(z.read('wordpress/'+name)).hexdigest()!=md5: raise RuntimeError('core checksum mismatch '+name)
    print('PASS official core checksums '+str(len(checks)),flush=True)
    z.extractall(DEST/'files')
docroot=DEST/'files/wordpress'
with zipfile.ZipFile(DEST/'learnpress.4.3.6.zip') as z:
    for name in z.namelist(): safe(name)
    z.extractall(docroot/'wp-content/plugins')
with tarfile.open(ROOT/'incoming/tds-learnpress-editorial-c853db0.tar') as t:
    for name,expected in PLUGIN.items():
        data=t.extractfile('wordpress/tds-learnpress-editorial/'+name).read()
        require(hashlib.sha256(data).hexdigest()==expected,'editorial source '+name)
        target=docroot/'wp-content/plugins/tds-learnpress-editorial'/name
        target.parent.mkdir(parents=True,exist_ok=True); target.write_bytes(data)
# The institutional theme snapshot is provenance-checked, not recaptured from a live site.
with tarfile.open(OLD/'sanitized-institutional-theme-before.tgz') as t:
    for item in t.getmembers():
        safe(item.name)
        require(not(item.issym() or item.islnk() or item.isdev()),'regular theme archive member') if item.issym() or item.islnk() or item.isdev() else None
    for row in json.loads((OLD/'theme-provenance.json').read_text()):
        data=t.extractfile('tds-child-theme/'+row['file']).read()
        require(hashlib.sha256(data).hexdigest()==row['fixture_sha256'],'retained sanitized theme '+row['file'])
    t.extractall(docroot/'wp-content/themes',filter='data')
require(not(docroot/'wp-config.php').exists(),'source contains no runtime database configuration')
manifest={'source_sql':SQL,'source_gate':'20261019T233038Z-registration-299-resume',
 'code_origin':'Reconstructed from official WP6.7.2 checksums, historically pinned LP4.3.6 ZIP, retained themes and Git-pinned adapter; not a historical full filesystem backup',
 'files':{str(p.relative_to(DEST)):sha(p) for p in sorted(DEST.rglob('*')) if p.is_file()}}
(DEST/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
for p in DEST.rglob('*'): p.chmod(0o500 if p.is_dir() else 0o400)
DEST.chmod(0o500)
subprocess.run(['chattr','-R','+i',str(DEST)],check=True)
require(all(sha(DEST/name)==value for name,value in manifest['files'].items()),'immutable source readback hashes')
print('IMMUTABLE_MANIFEST_SHA256='+sha(DEST/'manifest.json'))
print('IMMUTABLE_SOURCE='+str(DEST))
