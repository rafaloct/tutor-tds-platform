import subprocess,json,pathlib,sys
R=pathlib.Path(__file__).parent
A='C:/Users/Rafael/AppData/Local/Android/Sdk/platform-tools/adb.exe'; S='emulator-5580'
def adb(*a):return subprocess.check_output([A,'-s',S,*a],timeout=30).decode().strip()
def state():
 c=adb('shell','dumpsys','connectivity')
 return {'airplane_mode_on':adb('shell','settings','get','global','airplane_mode_on'),'wifi_on':adb('shell','settings','get','global','wifi_on'),'default_network':[s.strip() for s in c.splitlines() if 'Active default network' in s]}
if sys.argv[1]=='disable':
 before=state(); (R/'network-before.json').write_text(json.dumps(before,indent=2),encoding='utf-8')
 adb('shell','cmd','connectivity','airplane-mode','enable')
 adb('shell','svc','wifi','disable')
 after=state(); (R/'network-disabled.json').write_text(json.dumps(after,indent=2),encoding='utf-8')
 print(json.dumps({'before':before,'after':after}))
 assert after['airplane_mode_on']=='1'
 assert after['default_network'] and all('none' in s.lower() for s in after['default_network']),after
elif sys.argv[1]=='restore':
 before=json.loads((R/'network-before.json').read_text())
 adb('shell','cmd','connectivity','airplane-mode','enable' if before['airplane_mode_on']=='1' else 'disable')
 if before['wifi_on'] in ['0','1']: adb('shell','svc','wifi','enable' if before['wifi_on']=='1' else 'disable')
 now=state(); (R/'network-restored.json').write_text(json.dumps(now,indent=2),encoding='utf-8'); print(json.dumps(now))
elif sys.argv[1]=='probe':
 now=state(); (R/'network-disabled-confirmed.json').write_text(json.dumps(now,indent=2),encoding='utf-8'); print(json.dumps(now))
 assert now['airplane_mode_on']=='1'
 assert now['default_network'] and all('none' in s.lower() for s in now['default_network']),now
elif sys.argv[1]=='restored-probe':
 now=state(); (R/'network-restored-confirmed.json').write_text(json.dumps(now,indent=2),encoding='utf-8'); print(json.dumps(now))
 before=json.loads((R/'network-before.json').read_text())
 assert now['airplane_mode_on']==before['airplane_mode_on'] and now['wifi_on']==before['wifi_on']
 assert now['default_network'] and all('none' not in s.lower() for s in now['default_network']),now
