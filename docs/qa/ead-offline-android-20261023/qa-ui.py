import sys, subprocess, pathlib, xml.etree.ElementTree as ET, re, json
ADB='C:/Users/Rafael/AppData/Local/Android/Sdk/platform-tools/adb.exe'
SERIAL='emulator-5580'
ROOT=pathlib.Path(__file__).parent

def adb(*args):
    return subprocess.run([ADB,'-s',SERIAL,*args],check=True,capture_output=True,timeout=30).stdout

def capture(step):
    adb('shell','uiautomator','dump','/sdcard/tdsqa0598.xml')
    raw=adb('exec-out','cat','/sdcard/tdsqa0598.xml')
    (ROOT/(step+'.xml')).write_bytes(raw)
    (ROOT/(step+'.png')).write_bytes(adb('exec-out','screencap','-p'))
    tree=ET.fromstring(raw)
    rows=[{k:n.get(k) for k in ['text','content-desc','bounds','enabled','clickable']} for n in tree.iter('node') if n.get('text') or n.get('content-desc')]
    (ROOT/(step+'.json')).write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
    print(json.dumps(rows,ensure_ascii=True))
    return tree

if sys.argv[1]=='capture':
    capture(sys.argv[2])
elif sys.argv[1]=='tap':
    tree=capture(sys.argv[2]+'-before')
    label=sys.argv[3]
    nodes=[n for n in tree.iter('node') if label in (n.get('text','')+' '+n.get('content-desc',''))]
    if len(nodes)!=1: raise RuntimeError('ambiguous/missing target: '+str(len(nodes)))
    x1,y1,x2,y2=map(int,re.findall(r'\d+',nodes[0].get('bounds')))
    print('UI-tree target center', (x1+x2)//2,(y1+y2)//2)
    adb('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2))
