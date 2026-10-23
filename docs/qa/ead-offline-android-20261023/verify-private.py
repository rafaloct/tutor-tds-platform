import json,subprocess,pathlib,hashlib
R=pathlib.Path(__file__).parent
A='C:/Users/Rafael/AppData/Local/Android/Sdk/platform-tools/adb.exe'
S='emulator-5580'
r=json.loads((R/'corrected-artifact.json').read_text())
p=r['package']; run=p.split('.r')[-1]
base='files/ead_offline/qa_'+run+'/v1/12/13/'+'a'*64+'/'
out={'source_sha':r['source_sha'],'package':p,'files':{}}
for asset,file in [('synthetic.mp4','video.mp4'),('synthetic.vtt','captions.vtt')]:
 b=subprocess.check_output([A,'-s',S,'exec-out','run-as',p,'cat',base+file],timeout=30)
 actual={'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()}
 assert actual==r['assets'][asset],actual
 out['files'][file]=actual
(R/'private-files.json').write_text(json.dumps(out,indent=2),encoding='utf-8')
print(json.dumps(out))
