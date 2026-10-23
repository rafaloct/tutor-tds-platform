import subprocess,json,pathlib,re
R=pathlib.Path(__file__).parent
A='C:/Users/Rafael/AppData/Local/Android/Sdk/platform-tools/adb.exe'
S='emulator-5580'
r=json.loads((R/'corrected-artifact.json').read_text())
p=r['package']
def adb(*a): return subprocess.check_output([A,'-s',S,*a],timeout=30).decode().strip()
raw=adb('shell','pm','path',p)
path=raw.removeprefix('package:')
assert re.fullmatch(r'/data/app/[A-Za-z0-9_~=/+.-]+/base.apk',path),path
actual=adb('shell','sha256sum',path).split()[0]
assert actual==r['sha256'],(actual,r['sha256'])
out={'source_sha':r['source_sha'],'package':p,'installed_apk_sha256':actual,'matches_built':True}
(R/'installed-apk.json').write_text(json.dumps(out,indent=2),encoding='utf-8')
print(json.dumps(out))
