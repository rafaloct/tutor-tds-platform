import pathlib,json,subprocess
R=pathlib.Path(__file__).parent
A='C:/Users/Rafael/AppData/Local/Android/Sdk/platform-tools/adb.exe';S='emulator-5580'
p=json.loads((R/'corrected-artifact.json').read_text())['package']
def adb(*a):return subprocess.run([A,'-s',S,*a],capture_output=True,timeout=40)
old=adb('shell','pidof',p).stdout.decode().strip()
r=adb('shell','am','force-stop',p); assert r.returncode==0
stopped=adb('shell','pidof',p).stdout.decode().strip(); assert not stopped
launch=adb('shell','am','start','-W','-n',p+'/com.tutortds_cartilhas.MainActivity')
new=adb('shell','pidof',p).stdout.decode().strip()
out={'old_pid':old,'after_force_stop':stopped,'new_pid':new,'launch':launch.stdout.decode(),'different_process':bool(old and new and old!=new)}
(R/'process-restart.json').write_text(json.dumps(out,indent=2),encoding='utf-8'); print(json.dumps(out))
assert out['different_process']
