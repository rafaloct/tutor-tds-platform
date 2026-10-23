import pathlib,json,subprocess,time
R=pathlib.Path(__file__).parent
A='C:/Users/Rafael/AppData/Local/Android/Sdk/platform-tools/adb.exe';S='emulator-5580'
def adb(*a):return subprocess.check_output([A,'-s',S,*a],timeout=30).decode().strip()
size=adb('shell','wm','size'); density=adb('shell','wm','density')
assert '1344x2992' in size and 'Override' not in size,size
assert '480' in density and 'Override' not in density,density
radio={k:adb('shell','settings','get','global',k) for k in ['airplane_mode_on','wifi_on']}
before=json.loads((R/'network-before.json').read_text())
assert all(radio[k]==before[k] for k in radio)
kill=adb('emu','kill')
for i in range(8):
 devices=subprocess.check_output([A,'devices'],timeout=10).decode()
 if S not in devices:break
 time.sleep(1)
assert S not in devices
out={'viewport_size':size,'viewport_density':density,'radio_restored':radio,'emulator_stop_response':kill,'emulator_absent_from_adb':True,'other_device_commands':'none (read-only device listings only)'}
(R/'cleanup.json').write_text(json.dumps(out,indent=2),encoding='utf-8');print(json.dumps(out))
