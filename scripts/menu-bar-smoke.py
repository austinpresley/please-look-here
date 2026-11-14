#!/usr/bin/env python3
"""Guarded native S-023 checks. Requires isolated LaunchServices app and public fixture."""
import json,pathlib,subprocess,os,time
root=pathlib.Path.cwd();out=pathlib.Path(os.environ.get('TINYHAND_VERIFICATION_DIR',root/'dist/verification/s023'));env=json.loads((out/'environment.json').read_text());os.environ.update(env)
binary=pathlib.Path.home()/'Applications/Look Here Please.app/Contents/MacOS/TinyHand';probe=out/'MenuBarProbe'
def request(op,**kw):
 p=subprocess.run([str(binary),'--ctl',json.dumps({'version':1,'operation':op,**kw})],capture_output=True,text=True,timeout=8);v=json.loads(p.stdout)
 assert p.returncode==0 and v['ok'],v
 return v
def ctl(op,**kw):return request(op,**kw)['state']
def controls(**kw):return request('test-menu-bar',request=kw)['controls']
def native(*a):return json.loads(subprocess.check_output([str(probe),*map(str,a)],env=dict(os.environ,**env),timeout=8))
def events(*a):native('events',json.dumps(a));time.sleep(.12)
def key(k,flags=0):events({'type':10,'key':k,'flags':flags},{'type':11,'key':k,'flags':flags})
def mouse(x,y,button=0):events({'type':1 if button==0 else 3 if button==1 else 25,'x':x,'y':y,'button':button},{'type':2 if button==0 else 4 if button==1 else 26,'x':x,'y':y,'button':button})
def counts():
 d=json.loads(pathlib.Path(env['TINYHAND_FIXTURE_STATE']).read_text())['events'];return {k:d.get(k,0) for k in ['1','2','3','4','6','7','25','26','27','10','11']}
def opened():
 c=controls();assert c['visible'],c
 for _ in range(10):
  if c['key']:break
  time.sleep(.05);c=controls()
 assert c['key'],c
 n=native('state');w=next(w for w in n['appWindows'] if w['kCGWindowNumber']==c['window']);assert w['kCGWindowAlpha']>.01 and w['kCGWindowLayer']==25,(c,n)
 return c
def open_panel():
 controls(open=True);time.sleep(.15);return opened()
def press(name):
 a=native('press',name);r=[x for x in a if 'pressResult' in x];assert r and all(x['pressResult']==0 for x in r),r;time.sleep(.15);return r

rows=[]
def passed(name,**detail):
 rows.append({'name':name,'state':ctl('status'),'controls':controls(),'native':native('state'),**detail});print('PASS',name,flush=True)
def unchanged(before):assert counts()==before,(before,counts())
def settle():time.sleep(.2)
def status_click(button=0):
 c=controls();x,y,w,h=c['statusFrame'];mouse(x+w/2,1080-y-h/2,button)
def run():
 ready=request('test-shortcuts',request={});assert ready['shortcuts']['defaultsSuite']==env['TINYHAND_DEFAULTS_SUITE']
 controls(open=False);ctl('off');ctl('interact',enabled=True)
 ctl('configure',settings={'showToolbar':False,'radialTrigger':'option','handSound':False,'laserSound':False,'captureCopies':False,'captureSaves':True,'captureFolder':str(out/'captures')})
 native('activate-fixture');settle();before=counts();status_click();opened();assert not ctl('status')['active'];unchanged(before);status_click();assert not controls()['visible'];unchanged(before)
 passed('physical status left click opens controls and closes without toggling Pointer or fixture input',counters=before)
 # Right/Control-click entry must keep control clients serviceable while native
 # tracking runs, including when the opening originated in an event-tap callback.
 for kind in ['right-closed','right-open','control-open']:
  if kind!='right-closed':open_panel()
  before=counts();c=controls();x,y,w,h=c['statusFrame'];x+=w/2;y=1080-y-h/2
  if kind.startswith('right'):mouse(x,y,1)
  else:events({'type':1,'x':x,'y':y,'flags':1<<18},{'type':2,'x':x,'y':y,'flags':1<<18})
  assert controls()['tracking']>0
  ctl('style',style='laser');observed=ctl('toggle-current-sound');c=controls();group=next(x for x in c['menus'] if x['title']=='Pointer')['children']
  assert next(x for x in group if x['title']=='Tap Sound')['selected']==observed['settings']['laserSound']
  assert any(x['title']=='Laser dot' and x['selected'] for x in next(x for x in group if x['title']=='Choose Pointer')['children'])
  key(53);events({'type':12,'key':59,'flags':0});unchanged(before);assert controls()['tracking']==0 and not controls()['visible']
  passed('secondary status entry keeps automation live and mouse Escape pairs owned '+kind,before=before,after=counts())
 ctl('configure',settings={'laserSound':False})
 open_panel();pins=ctl('status')['pinned'];ctl('style',style='custom-s023');settle();c=controls();assert c['choice']=='custom-s023' and not c['pointer'] and c['interact'];assert c['choices']==ctl('status')['enabledPointers'];assert ctl('status')['pinned']==pins
 passed('full enabled unpinned custom selection is independent of pins activation and Interact')
 press('Choose Pointer');assert controls()['tracking']>0;key(119);key(36);settle();assert ctl('status')['style']=='laser' and controls()['choice']=='laser' and not ctl('status')['active']
 press('Choose Pointer');key(119);key(126);key(36);settle();assert ctl('status')['style']=='custom-s023';passed('native chooser End arrows Return selects Laser and long custom name without activating')
 press('Pointer');assert ctl('status')['active'];press('Interact');assert not ctl('status')['interact'];press('Arrow');assert ctl('status')['tool']=='arrow' and ctl('status')['active'];passed('AX Pointer Interact and tool actions use real validation and acknowledged state')
 # External commands arrive while controls remain open.
 ctl('off');ctl('interact',enabled=True);ctl('style',style='laser');ctl('toggle-current-sound');settle();c=controls();assert not c['pointer'] and c['interact'] and c['choice']=='laser' and c['buttons']['sound']['value']=='On';passed('external automation refreshes observed activation Interact pointer and laser sound')
 ctl('toggle-current-sound');ctl('style',style='custom-s023');ctl('interact',enabled=False);ctl('on')
 for button,down,drag,up in [(0,1,6,2),(1,3,7,4),(2,25,27,26)]:
  open_panel();before=counts();ink=ctl('status')['annotations'];events({'type':down,'x':600,'y':600,'button':button})
  held=ctl('status');assert not controls()['visible'] and held['input']['controls']['buttons']==[button] and held['input']['enabled'];ctl('off')
  events({'type':down,'x':600,'y':600,'button':button},{'type':drag,'x':650,'y':640,'button':button},{'type':up,'x':650,'y':640,'button':button})
  unchanged(before);s=ctl('status');assert not s['input']['controls']['buttons'] and not s['input']['capturedButtons'] and not s['input']['enabled'];assert s['annotations']==0
  passed('outside dismissal owns repeated down drag and release through pointer off button '+str(button),before=before,held=held['input'],after=counts());ctl('on')
 open_panel();before=counts();events({'type':10,'key':53});assert not controls()['visible'];ctl('off');events({'type':10,'key':53,'repeat':True},{'type':10,'key':53,'repeat':True},{'type':11,'key':53});unchanged(before);assert not ctl('status')['input']['controls']['keys'];passed('Escape initial down repeats and release stay owned after close and pointer off',counters=before)
 # An older radial owner must win even after a different surface opens.
 ctl('interact',enabled=True);ctl('on');ctl('configure',settings={'radialTrigger':'option'});native('activate-fixture');settle();events({'type':5,'x':900,'y':500});before=counts()
 assert ctl('status')['input']['radial']['eligible'];events({'type':12,'key':58,'flags':1<<19});assert ctl('status')['radial']['visible']
 events({'type':10,'key':53,'flags':1<<19},{'type':12,'key':58,'flags':0});assert ctl('status')['input']['radial']['keys']==[53]
 open_panel();events({'type':10,'key':53,'repeat':True},{'type':10,'key':53,'repeat':True});s=ctl('status');assert controls()['visible'] and s['input']['radial']['keys']==[53] and not s['input']['controls']['keys']
 events({'type':11,'key':53});s=ctl('status');assert not s['input']['radial']['keys'] and not s['input']['controls']['keys'];unchanged(before)
 controls(open=False);ctl('off');ctl('configure',settings={'radialTrigger':''});native('activate-fixture');settle();positive_before=counts();key(53);positive_after=counts();assert positive_after['10']==positive_before['10']+1 and positive_after['11']==positive_before['11']+1
 passed('original radial Escape pair survives controls opening and repeats; fresh Escape reaches fixture',before=before,afterOwned=positive_before,positiveAfter=positive_after)
 # A captured annotation pair likewise cannot become an outside-dismiss pair.
 ctl('on');ctl('tool',tool='pen');native('activate-fixture');settle();before=counts();events({'type':1,'x':500,'y':500});assert ctl('status')['input']['capturedButtons']==[0]
 open_panel();events({'type':1,'x':500,'y':500},{'type':6,'x':620,'y':580},{'type':2,'x':620,'y':580});s=ctl('status');assert controls()['visible'] and not s['input']['capturedButtons'] and not s['input']['controls']['buttons'];unchanged(before)
 passed('original captured drawing pair survives controls opening repeated down drag and release',before=before,after=counts());controls(open=False);ctl('off')
 # A fresh, ordinary pair proves controls did not leave input captured/suspended.
 ctl('interact',enabled=True);ctl('on');native('activate-fixture');settle();before=counts();mouse(600,600);after=counts();assert after['1']==before['1']+1 and after['2']==before['2']+1;passed('native positive control pair reaches fixture after close',before=before,after=after)
 # A native drag that began before opening retains its original mouse pair.
 before=counts();events({'type':1,'x':600,'y':600});open_panel();events({'type':6,'x':680,'y':640},{'type':2,'x':680,'y':640});after=counts()
 assert after['1']==before['1']+1 and after['2']==before['2']+1 and after['6']>before['6'];passed('pre-existing native drag retains fixture down drag up across controls opening',before=before,after=after)
 controls(open=False);native('activate-fixture');settle()
 # Draw a real annotation then exercise UI history.
 ctl('interact',enabled=False);ctl('tool',tool='pen');before=counts();events({'type':1,'x':500,'y':500},{'type':6,'x':620,'y':580},{'type':2,'x':620,'y':580});unchanged(before);assert ctl('status')['annotations']==1;open_panel();assert controls()['buttons']['undo']['enabled'];press('Undo Annotation');assert ctl('status')['annotations']==0 and controls()['buttons']['redo']['enabled'];press('Redo Annotation');assert ctl('status')['annotations']==1;press('Clear Drawing');assert ctl('status')['annotations']==0 and not controls()['buttons']['clear']['enabled'];passed('native drawing and AX Undo Redo Clear agree with real history availability')
 # Trigger is suppressed for the whole control session, and a fresh gesture works after close.
 ctl('configure',settings={'radialTrigger':'option'})
 before=counts();events({'type':12,'key':58,'flags':1<<19});assert not ctl('status')['radial']['visible'];key(53,1<<19);assert not controls()['visible'];assert not ctl('status')['radial']['visible'];events({'type':12,'key':58,'flags':0});native('activate-fixture');settle();events({'type':5,'x':900,'y':500});s=ctl('status');assert s['input']['radial']['eligible'],s
 events({'type':12,'key':58,'flags':1<<19});s=ctl('status');assert s['radial']['visible'];events({'type':12,'key':58,'flags':0});assert not ctl('status')['radial']['visible'];unchanged(before);passed('radial blocked over controls and held dismissal; fresh post-close gesture opens')
 # Outside a native secondary menu must not replay a click to the fixture.
 open_panel();before=counts();a=next(a for a in native('ax') if a['description']=='More Commands');x,y,w,h=a['frame'];mouse(x+w/2,y+h/2);assert controls()['tracking']>0
 events({'type':1,'x':600,'y':600});held=ctl('status');assert held['input']['controls']['buttons']==[0]
 events({'type':2,'x':600,'y':600});unchanged(before);assert not controls()['visible'] and controls()['tracking']==0;passed('native secondary outside dismissal owns pair instead of replaying fixture click',before=before,held=held['input'],after=counts())
 # Accessibility Press must return success before the native tracking loop.
 open_panel();ax_more=press('More Commands');assert controls()['tracking']>0
 passed('AX More Commands replies successfully and opens native tracking',axPress=ax_more)
 # Native More menu, chooser and Settings handoff keep the same suspension lease.
 ctl('style',style='laser');ctl('toggle-current-sound');c=controls();pointer=next(x for x in c['menus'] if x['title']=='Pointer')['children'];assert next(x for x in pointer if x['title']=='Tap Sound')['selected'];passed('native secondary menu observes external state while tracking')
 key(53);assert controls()['visible'] and controls()['tracking']==0;press('Settings…');settle();assert not controls()['visible'] and any(w['title']=='Look Here Please Settings' for w in ctl('status')['windows']);assert not ctl('status')['input']['active'];key(13,1<<20);events({'type':12,'key':55,'flags':0});native('activate-fixture');settle();assert ctl('status')['input']['active'];passed('Settings handoff closes controls preserves independent key-window guard and resumes drawing after close')
 # Enter and edit native annotation text after returning from the controls.
 ctl('tool',tool='text');mouse(620,650);settle();assert any(w['title']=='Add Text' for w in ctl('status')['windows'])
 events({'type':10,'key':0,'text':'Public fixture text'},{'type':11,'key':0});key(0,1<<20);key(51);events({'type':12,'key':55,'flags':0});events({'type':10,'key':0,'text':'Edited'},{'type':11,'key':0});key(36);settle();assert ctl('status')['annotations']==1;passed('native text input Select All Delete and Return remain in responder chain')
 ctl('clear');ctl('tool',tool='pen');ctl('configure',settings={'radialTrigger':''});native('activate-fixture');settle();r=request('capture');assert r['state']['capturing'];r=request('test-menu-bar',request={'open':True});c=r['controls'];assert r['state']['capturing'] and not c['buttons']['capture']['enabled'] and all(not c['buttons'][i]['enabled'] for i in ['undo','redo','clear']);passed('pending capture is observed and disables affected controls')
 for _ in range(60):
  if not ctl('status')['capturing']:break
  time.sleep(.1)
 else:raise AssertionError('Capture did not finish')
 assert not ctl('status')['lastCaptureError'];settle();assert controls()['buttons']['capture']['enabled'];passed('capture completion restores actual availability')
 controls(open=False);ctl('off');ctl('configure',settings={'radialTrigger':''})

def denied():
 controls(open=False);ctl('off');ctl('interact',enabled=True);c=open_panel();assert not ctl('status')['accessibility'] and 'Accessibility' in c['summary'];passed('injected denial is explicit in controls')
 a=native('ax');tools=[x for x in a if x['role']=='AXRadioButton'];assert tools and all(not x['enabled'] for x in tools);assert not next(x for x in a if x['description']=='Interact' and x['frame'][1]<500)['enabled'];passed('drawing controls disabled without Accessibility')
 p=subprocess.run([str(binary),'--ctl',json.dumps({'version':1,'operation':'tool','tool':'arrow'})],capture_output=True,text=True);r=json.loads(p.stdout);assert not r['ok'] and r['error']['code']=='accessibility' and r['state']['interact'];passed('stale drawing request rejects without requested state acknowledgment')
 press('Pointer');assert ctl('status')['active'] and ctl('status')['interact'];controls(open=False);ctl('off');passed('Pointer remains usable in Interact without drawing permission')
try:
 if '--denied' in __import__('sys').argv:denied()
 else:run()
except BaseException as error:
 failure={'error':repr(error),'rows':rows}
 for name,read in [('state',lambda:ctl('status')),('controls',controls),('native',lambda:native('state')),('counters',counts)]:
  try:failure[name]=read()
  except Exception as capture_error:failure[name+'Error']=repr(capture_error)
 (out/f'controls-failure-before-cleanup-{time.monotonic_ns()}.json').write_text(json.dumps(failure,indent=2));raise
finally:
 (out/('controls-denied.json' if '--denied' in __import__('sys').argv else 'controls-smoke.json')).write_text(json.dumps(rows,indent=2))
