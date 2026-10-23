import pathlib,json,subprocess
R=pathlib.Path(__file__).parent
A='C:/Users/Rafael/AppData/Local/Android/Sdk/platform-tools/adb.exe';S='emulator-5580'
r=json.loads((R/'corrected-artifact.json').read_text()); p=r['package']; run=p.split('.r')[-1]
root='files/ead_offline/qa_'+run
out=subprocess.check_output([A,'-s',S,'shell','run-as',p,'find',root,'-type','f'],timeout=30).decode().strip()
assert not out,out
receipt={'source_sha':r['source_sha'],'package':p,'namespace_file_list':out,'no_remaining_package_files':True}
(R/'removal.json').write_text(json.dumps(receipt,indent=2),encoding='utf-8');print(json.dumps(receipt))
