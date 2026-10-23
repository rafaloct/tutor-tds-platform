import pathlib,json,datetime
R=pathlib.Path(__file__).parent
checks=[]
def read(n):return json.loads((R/n).read_text(encoding='utf-8-sig'))
def text(step):return '\n'.join(r.get('content-desc','')+' '+r.get('text','') for r in read(step+'.json'))
def button(step,label,enabled):return any(r.get('content-desc')==label and r.get('enabled')==str(enabled).lower() for r in read(step+'.json'))
def check(name,value):
 assert value,name
 checks.append({'case':name,'result':'PASS'})
a=read('corrected-artifact.json'); installed=read('installed-apk.json')
check('installed APK equals clean corrected-source build',installed['matches_built'] and installed['installed_apk_sha256']==a['sha256'] and a['source_status']=='')
check('fresh empty UI watch disabled','ainda não preparado' in text('16-corrected-empty') and button('16-corrected-empty','Assistir offline',False))
check('first preparation ready without manual mkdir','Pronto para modo avião' in text('19-watch-before') and button('19-watch-before','Assistir offline',True))
private=read('private-files.json')['files']
check('private MP4 exact length and SHA256',private['video.mp4']==a['assets']['synthetic.mp4'])
check('private VTT exact length and SHA256',private['captions.vtt']==a['assets']['synthetic.vtt'])
check('native player initialized with Portuguese first cue','Vídeo sintético para teste offline.' in text('21-player-ready') and '0 de 3 segundos' in text('21-player-ready'))
check('native playback progresses to end and second cue','3 de 3 segundos' in text('23-played') and 'Nenhum conteúdo de aluno' in text('23-played'))
check('captions can be hidden','Nenhum conteúdo de aluno' not in text('25-captions-hidden') and 'Mostrar legendas' in text('25-captions-hidden'))
check('captions can be restored','Nenhum conteúdo de aluno' in text('27-captions-restored'))
n=read('network-disabled-confirmed.json')
check('airplane on WiFi off no default network',n['airplane_mode_on']=='1' and n['wifi_on']=='0' and all('none' in x.lower() for x in n['default_network']))
p=read('process-restart.json')
check('force stop removes process and relaunch gets distinct PID',p['different_process'] and p['after_force_stop']=='' and p['old_pid']!=p['new_pid'])
check('package reopens verified after process death offline','Pronto para modo avião' in text('31-offline-reopened'))
check('native playback and second caption work offline','3 de 3 segundos' in text('35-offline-played') and 'Nenhum conteúdo de aluno' in text('35-offline-played'))
check('remove returns empty UI and disables watch/remove','ainda não preparado' in text('38-removed') and button('38-removed','Assistir offline',False) and button('38-removed','Remover offline',False))
check('remove leaves no package files',read('removal.json')['no_remaining_package_files'])
r=read('network-restored-confirmed.json');b=read('network-before.json')
check('original radios and active network restored',r['airplane_mode_on']==b['airplane_mode_on'] and r['wifi_on']==b['wifi_on'] and all('none' not in x.lower() for x in r['default_network']))
check('manual catalog refresh recovers eleven public offers','Ofertas publicadas: 11' in text('41-catalog-restored'))
c=read('cleanup.json')
check('original viewport restored and owned emulator stopped',c['emulator_absent_from_adb'] and 'Override' not in c['viewport_size'] and 'Override' not in c['viewport_density'])
out={'source_sha':a['source_sha'],'apk_sha256':a['sha256'],'generated_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'scope':'one actual Android synthetic public-media journey; not real media download or academic integration','checks':checks,'pass':len(checks),'fail':0,'limits':['resume position persistence not accepted','no production manifest reader/download binding','no institutional role/academic integration','emulator resource constraints prevent performance/cold-start acceptance']}
(R/'acceptance.json').write_text(json.dumps(out,indent=2),encoding='utf-8');print(json.dumps({'source':out['source_sha'],'PASS':len(checks),'FAIL':0}))
