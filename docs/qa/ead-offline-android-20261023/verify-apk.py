from pathlib import Path
import json,zipfile,hashlib,subprocess
root=Path('D:/AI-Shared/work/tds-offline-android-20261023')
out=Path(__file__).parent
apk=root/'cartilhas_app/build/app/outputs/flutter-apk/app-debug.apk'
config=out/'qa-defines.json'
def sha(b):return hashlib.sha256(b).hexdigest()
expected={'synthetic.mp4':(9031,'b1c2ca035ff63b2070fb0bcf3d70b963d828226b1f03f1014a5b347de2c16ce6'),'synthetic.vtt':(148,'7dd0700f14781baace675332cab287a59bd3156593edde696a5f4c69589df19a')}
assets={}
with zipfile.ZipFile(apk) as z:
 for n,(size,digest) in expected.items():
  b=z.read('assets/flutter_assets/assets/qa/offline/'+n)
  assert len(b)==size and sha(b)==digest,n
  assets[n]={'bytes':len(b),'sha256':sha(b)}
receipt={'source_sha':subprocess.check_output(['git','-C',str(root),'rev-parse','HEAD'],text=True).strip(),'source_status':subprocess.check_output(['git','-C',str(root),'status','--short'],text=True),'apk':str(apk),'bytes':apk.stat().st_size,'sha256':sha(apk.read_bytes()),'config_sha256':sha(config.read_bytes()),'package':'com.tutortds_cartilhas.dev.dynamicqa.r'+json.loads(config.read_text(encoding='utf-8-sig'))['DYNAMIC_QA_RUN_ID'],'assets':assets,'type':'debug-x64-synthetic-only','device':'emulator-5580 API35'}
(out/'artifact.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8')
print(json.dumps(receipt,indent=2))
