#!/usr/bin/env python3
"""S-013 native fixture loop. Requires LaunchServices test app + public fixture.
Never edits real defaults, hands, keys or profiles. Native compositor window
visibility and fixture-received event counters are checked alongside app state.
"""
import json,math,os,pathlib,subprocess,time
root=pathlib.Path(__file__).resolve().parents[1]
out=pathlib.Path(os.environ.get('TINYHAND_VERIFICATION_DIR',root/'dist/verification/s013'))
env=json.loads((out/'environment.json').read_text()); os.environ.update(env)
assert env['TINYHAND_TEST_MODE']=='1' and env['TINYHAND_DEFAULTS_SUITE'].startswith('com.austinpresley.tinyhand.s013.')
binary=pathlib.Path.home()/'Applications/Look Here Please.app/Contents/MacOS/TinyHand'
probe=out/'RadialProbe'; rows=[]; openings=[]
ALT=1<<19

def control(op,**fields):
 p=subprocess.run([str(binary),'--ctl',json.dumps({'version':1,'operation':op,**fields})],text=True,capture_output=True,timeout=8)
 v=json.loads(p.stdout);assert p.returncode==0 and v['ok'],v
 return v

def ctl(op,**fields):return control(op,**fields)['state']
def native(*args):return json.loads(subprocess.check_output([str(probe),*map(str,args)],text=True,env=dict(os.environ,**env),timeout=8))
def events(*events):native('events',json.dumps(events));time.sleep(.12)
def move(x,y,flags=ALT):events({'type':5,'x':x,'y':y,'flags':flags})
def flags(value):events({'type':12,'flags':value,'key':58})
def counters():
 d=json.loads(pathlib.Path(env['TINYHAND_FIXTURE_STATE']).read_text())['events'];return {k:d.get(k,0) for k in ['1','2','3','4','6','7','25','26','27']}
def assert_visibility(s,n,visible):
 actual=any(w.get('kCGWindowNumber')==s['radial']['window'] and w.get('kCGWindowAlpha',0)>.01 for w in n['appWindows'])
 assert s['radial']['visible']==visible and actual==visible,{'expectedVisibility':visible,'state':s,'native':n}
def state(visible=None):
 s=ctl('status');n=native('state')
 if visible is not None:assert_visibility(s,n,visible)
 return s

def passed(name,**details):
 rows.append({'name':name,'state':state(),'native':native('state'),**details});print('PASS',name,flush=True)
def zero_input(before):assert counters()==before,(before,counters())
def open_menu(x=900,y=500):
 flags(0);move(x,y,0)
 before=ctl('status');n=native('state')
 attempt={'number':len(openings)+1,'before':{'state':before,'native':n}};openings.append(attempt)
 try:
  # Fail before posting Option if input eligibility/tap readiness is absent.
  # Do not wait, re-post Option, or turn a lost transition into a retry.
  assert before['input']['radial']['eligible'] and before['input']['enabled'],{'missingReopenPrerequisite':attempt}
  assert 'combinedInput' in n,'Rebuild Tests/Fixtures/RadialProbe.swift for native flags/button diagnostics'
  assert not n['combinedInput']['buttons'] and not n['combinedInput']['flags'] & (15<<17),attempt
  flags(ALT);s=ctl('status');n=native('state')
  attempt['after']={'state':s,'native':n}
  attempt['flagsCallbacks']=s['input']['types'].get('12',0)-before['input']['types'].get('12',0)
  assert attempt['flagsCallbacks']==1,attempt
  assert n['combinedInput']['flags'] & ALT and not n['combinedInput']['buttons'],attempt
  assert s['input']['radial']['held'] and s['input']['radial']['open'],attempt
  assert_visibility(s,n,True)
  return s['radial']['center']
 except BaseException:
  attempt['failureBeforeCleanup']={'state':ctl('status'),'native':native('state')}
  (out/f'reopen-failure-{time.monotonic_ns()}.json').write_text(json.dumps(attempt,indent=2))
  raise
def radial_point(slot,radius,center):
 x,y=center; height=native('state')['bounds'][3]
 a=slot*math.pi/4;return x+math.sin(a)*radius,height-(y+math.cos(a)*radius)
def point(slot,radius,center):move(*radial_point(slot,radius,center))
def close_release():flags(0);state(False)

def run_escape_ownership():
 # Compare real fixture-received keys, not only the radial ownership bool.
 assert control('test-shortcuts',request={})['shortcuts']['defaultsSuite']==env['TINYHAND_DEFAULTS_SUITE']
 def keys():
  received=json.loads(pathlib.Path(env['TINYHAND_FIXTURE_STATE']).read_text())['events']
  return {k:received.get(k,0) for k in ['10','11']}
 ctl('off');ctl('interact',enabled=True)
 ctl('configure',settings={'showToolbar':False,'handSound':False,'laserSound':False})
 for transition in ['cancel','clear','deactivate']:
  ctl('configure',settings={'radialTrigger':'option'});ctl('on');open_menu()
  before=keys();tap_before=state()['input']['types'].get('10',0)
  events({'type':10,'key':53,'flags':ALT});state(False)
  if transition=='clear':ctl('configure',settings={'radialTrigger':''})
  elif transition=='deactivate':ctl('off')
  held=state();assert held['input']['enabled'] and held['input']['radial']['keys']==[53]
  events({'type':10,'key':53,'flags':ALT,'repeat':True},
         {'type':10,'key':53,'flags':ALT,'repeat':True})
  flags(0)
  events({'type':10,'key':53,'repeat':True},{'type':11,'key':53})
  after=keys();drained=state(False)
  detail={'transition':transition,'before':before,'after':after,'heldInput':held['input'],'drainedInput':drained['input']}
  rows.append({'name':'Escape autorepeat ownership '+transition,**detail})
  print('Escape fixture counters',json.dumps({'transition':transition,'before':before,'after':after}),flush=True)
  assert after==before,detail
  assert drained['input']['types']['10']==tap_before+4,detail
  assert not drained['input']['radial']['keys'],detail
  if transition!='cancel':assert not drained['input']['enabled'],detail
  passed('owned Escape down, three autorepeats and up never reach fixture after '+transition,**detail)
 # An ordinary key's initial down, repeat and release must still reach the fixture.
 ctl('on');ctl('configure',settings={'radialTrigger':'option'});open_menu();before=keys()
 events({'type':10,'key':8,'flags':ALT},{'type':10,'key':8,'flags':ALT,'repeat':True},{'type':11,'key':8,'flags':ALT})
 state(False);flags(0);after=keys()
 assert after['10']==before['10']+2 and after['11']==before['11']+1,(before,after)
 assert json.loads(pathlib.Path(env['TINYHAND_FIXTURE_STATE']).read_text())['lastFlags']['10'] & ALT==ALT
 passed('ordinary modified key initial down, autorepeat and release reach fixture unchanged',before=before,after=after)
 ctl('off');ctl('configure',settings={'radialTrigger':''})

def run():
 assert control('test-shortcuts',request={})['shortcuts']['defaultsSuite']==env['TINYHAND_DEFAULTS_SUITE']
 ctl('off');control('test-shortcuts',request={'command':'reset'})
 ctl('configure',settings={'showToolbar':False,'handSound':False,'laserSound':False,'size':.2,'fade':0})
 ctl('on');move(900,500,0)
 before=counters();flags(ALT);state(False);flags(0);zero_input(before)
 assert not state()['input']['enabled'];passed('unassigned trigger installs no invisible interception')
 ctl('configure',settings={'radialTrigger':'option'});before=counters()
 center=open_menu();close_release();zero_input(before);assert state()['style']=='lavender';passed('immediate release cancels without underlying mouse input')
 for policy in [False,True]:
  control('test-radial',request={'releaseSelects':policy})
  ctl('style',style='lavender');before=counters();center=open_menu()
  point(0,128,center);point(1,216,center);assert state(True)['radial']['highlighted']=='glove'
  close_release();zero_input(before)
  assert state()['style']==('glove' if policy else 'lavender')
  passed('native release comparison '+('select' if policy else 'dismiss'),fixtureCounters=before)
 before=counters();center=open_menu();point(0,128,center);point(2,216,center)
 events({'type':1,'x':radial_point(2,216,center)[0],'y':radial_point(2,216,center)[1],'flags':ALT})
 assert state(False)['style']=='coral'
 move(920,520);state(False)
 ctl('off');events({'type':2,'x':920,'y':520,'flags':ALT});flags(0);zero_input(before)
 assert state()['input']['radial']['buttons']==[];passed('click selects and closes while held; deactivation drains paired release')
 ctl('on');before=counters();center=open_menu();point(0,128,center);point(1,216,center);point(0,64,center)
 assert state(True)['radial']['group']=='';point(1,128,center);assert state(True)['radial']['group']=='color'
 point(2,216,center);close_release();assert state()['settings']['ink']=='orange';zero_input(before);passed('movement hierarchy and inward backtracking; color action shares configure')
 before=counters();center=open_menu();point(2,128,center);point(1,216,center);close_release()
 assert state()['tool']=='rectangle' and not state()['interact'] and state()['active'];zero_input(before);passed('Tools uses validated app action, preserves pointer and activation')
 # Outside click and Escape while annotation input is active must not annotate.
 before=counters();ink=state()['annotations'];center=open_menu();point(0,128,center)
 events({'type':10,'key':53,'flags':ALT},{'type':11,'key':53,'flags':ALT});state(False);flags(0);zero_input(before)
 center=open_menu();move(1400,800);events({'type':1,'x':1400,'y':800,'flags':ALT},{'type':2,'x':1400,'y':800,'flags':ALT});state(False);flags(0)
 assert state()['annotations']==ink;zero_input(before);passed('Escape pair and outside click cancel in Draw with no annotation or native leak')
 ctl('interact',enabled=True)
 # Inspect every page and pick the unpinned custom hand.
 all_ids=state()['enabledPointers'];center=open_menu();point(0,128,center);seen=[]
 for page in range(math.ceil(len(all_ids)/6)):
  s=state(True);items=s['radial']['items'];seen += [i['id'] for i in items if i['id'] in all_ids]
  if page+1<math.ceil(len(all_ids)/6):point(7,216,center);point(0,144,center)
 assert seen==all_ids,(seen,all_ids)
 custom=next(i for i in state()['radial']['items'] if i['id']=='custom-s013')
 point(custom['slot'],216,center);close_release();assert state()['style']=='custom-s013' and state()['interact']
 passed('all enabled catalog pages retain stable order including unpinned/custom')
 # Native existing Interact drag ignores trigger through its paired release.
 move(600,600,0);before=counters();events({'type':1,'x':600,'y':600});flags(ALT);state(False)
 events({'type':6,'x':680,'y':640,'flags':ALT},{'type':2,'x':680,'y':640,'flags':ALT});state(False);flags(0)
 after=counters();assert after['1']==before['1']+1 and after['2']==before['2']+1 and after['6']>before['6'];passed('existing native drag remains native and never opens radial',before=before,after=after)
 # A normal modified key cancels and its pair still reaches the underlying app.
 center=open_menu();nativebefore=json.loads(pathlib.Path(env['TINYHAND_FIXTURE_STATE']).read_text())['events']
 events({'type':10,'key':8,'flags':ALT},{'type':11,'key':8,'flags':ALT});state(False);flags(0)
 nativeafter=json.loads(pathlib.Path(env['TINYHAND_FIXTURE_STATE']).read_text())['events']
 assert nativeafter.get('10',0)==nativebefore.get('10',0)+1 and nativeafter.get('11',0)==nativebefore.get('11',0)+1
 assert json.loads(pathlib.Path(env['TINYHAND_FIXTURE_STATE']).read_text())['lastFlags']['10'] & ALT == ALT;passed('ordinary modified key down/up preserved and cancels menu')
 # Safe edge arming and actual large-hand / laser appearances.
 ctl('style',style='lavender')
 for theme in ['light','dark']:
  ctl('configure',settings={'theme':theme})
  center=open_menu();native('shot',out/f'radial-root-large-{theme}.png');control('test-radial',request={'snapshot':str(out/f'radial-root-{theme}.png')});point(0,128,center);point(1,216,center)
  control('test-radial',request={'snapshot':str(out/f'radial-pointer-{theme}.png')});native('shot',out/f'radial-pointer-large-{theme}.png');close_release()
  ctl('style',style='laser');center=open_menu();point(2,128,center);native('shot',out/f'radial-tools-laser-{theme}.png');control('test-radial',request={'snapshot':str(out/f'radial-tools-{theme}.png')});close_release();ctl('style',style='lavender')
 for x,y,name in [(12,40,'top-left'),(native('state')['bounds'][2]-12,40,'top-right'),(12,native('state')['bounds'][3]-12,'bottom-left'),(native('state')['bounds'][2]-12,native('state')['bounds'][3]-12,'bottom-right')]:
  center=open_menu(x,y);assert native('state')['cursor']==[x,y];assert not state(True)['radial']['armed'];point(1,216,center);assert not state(True)['radial']['armed'];native('shot',out/f'radial-edge-{name}.png')
  move(center[0],native('state')['bounds'][3]-center[1]);assert state(True)['radial']['armed'];point(0,128,center);point(1,216,center);close_release()
 passed('four display edges require center arming; real cursor never warped')
 s=state();assert not s['toolbarVisible'] and not s['settings']['showToolbar']
 assert not any(w.get('kCGWindowAlpha',0)>.01 and w.get('kCGWindowBounds',{}).get('Width')==s['toolbarFrame'][2] and w.get('kCGWindowBounds',{}).get('Height')==s['toolbarFrame'][3] for w in native('state')['appWindows'])
 passed('toolbar OFF remains actually hidden through radial gestures')
 flags(0);ctl('off');ctl('configure',settings={'radialTrigger':''});assert not state()['input']['enabled'];passed('cleared trigger and pointer off leave no active tap')
def run_extended():
 from types import SimpleNamespace
 r=SimpleNamespace(**globals())
 r.ctl('configure',settings={'radialTrigger':'option','showToolbar':False,'captureCopies':False,'captureSaves':True,'captureFolder':str(r.out/'captures')});r.ctl('interact',enabled=True);r.ctl('on')
 # Dynamic catalog changes dismiss rather than committing a stale visible entry.
 center=r.open_menu();r.point(0,128,center);r.point(1,216,center);r.ctl('enable-pointer',style='glove',enabled=False);r.state(False);r.flags(0);assert r.state()['style']!='glove';r.ctl('enable-pointer',style='glove',enabled=True);r.passed('enabled-set change dismisses stale radial selection')
 center=r.open_menu();r.point(0,128,center);image=pathlib.Path(r.env['TH_HANDS_DIR'])/'custom-s013.png';original=image.read_bytes()
 try:
  image.unlink();time.sleep(1.3);r.state(False);r.flags(0);assert 'custom-s013' not in r.state()['enabledPointers'];r.passed('custom availability refresh dismisses stale radial session')
 finally:image.write_bytes(original)
 time.sleep(1.2)
 # A captured annotation drag must remain captured, with its release drained.
 r.ctl('tool',tool='pen');before=r.counters();r.move(700,600,0);r.events({'type':1,'x':700,'y':600});r.flags(r.ALT);r.state(False);r.events({'type':6,'x':760,'y':640,'flags':r.ALT},{'type':2,'x':760,'y':640,'flags':r.ALT});r.flags(0);r.zero_input(before);assert not r.state()['input']['capturedButtons'];r.passed('existing annotation drag stays captured and drains release')
 # Pointer selection in Draw preserves activation, Interact and existing ink.
 before=r.counters();annotations=r.state()['annotations'];center=r.open_menu();r.point(0,128,center);r.point(4,216,center);r.close_release();s=r.state();assert s['style']=='robot' and s['active'] and not s['interact'] and s['annotations']==annotations;r.zero_input(before);r.passed('pointer selection preserves Draw, activation and existing annotations')
 # History dispatches the existing undo/redo actions.
 center=r.open_menu();r.point(4,128,center);assert r.state(True)['radial']['items'][0]['enabled'];r.point(0,216,center);r.close_release();assert r.state()['annotations']==annotations-1
 center=r.open_menu();r.point(4,128,center);r.point(1,216,center);r.close_release();assert r.state()['annotations']==annotations;r.passed('History shares undo and redo with actual annotation counts')
 # Two buttons in one captured gesture must both remain owned after closure.
 r.ctl('interact',enabled=True);before=r.counters();center=r.open_menu();x,y=center[0],r.native('state')['bounds'][3]-center[1]
 r.events({'type':1,'x':x,'y':y,'flags':r.ALT},{'type':3,'button':1,'x':x,'y':y,'flags':r.ALT},{'type':2,'x':x,'y':y,'flags':r.ALT},{'type':4,'button':1,'x':x,'y':y,'flags':r.ALT});r.flags(0);r.zero_input(before);assert not r.state()['input']['radial']['buttons'];r.passed('overlapping native left/right presses and releases remain paired')
 # Right and other clicks and trigger clearing still drain exactly paired releases.
 for down,up,button in [(3,4,1),(25,26,2)]:
  r.ctl('interact',enabled=True);before=r.counters();center=r.open_menu();r.events({'type':down,'button':button,'x':center[0],'y':r.native('state')['bounds'][3]-center[1],'flags':r.ALT});r.state(False)
  r.ctl('configure',settings={'radialTrigger':''});r.events({'type':up,'button':button,'x':center[0],'y':r.native('state')['bounds'][3]-center[1],'flags':r.ALT});r.flags(0);r.zero_input(before);assert not r.state()['input']['radial']['buttons'];r.ctl('configure',settings={'radialTrigger':'option'})
 r.passed('right/other cancellation releases drain after trigger clearing')
 # AX reads actual native names/state, and actions traverse hierarchy and select.
 center=r.open_menu();ax=r.native('ax');(r.out/'radial-root-ax.json').write_text(json.dumps(ax,indent=2));assert any(x['description']=='Pointer' or x['title']=='Pointer' for x in ax),ax
 pressed=r.native('press','Pointer');assert any(x.get('pressResult')==0 for x in pressed);assert r.state(True)['radial']['group']=='pointer'
 ax=r.native('ax');assert any(x['value']=='Selected' for x in ax),ax
 (r.out/'radial-pointer-ax.json').write_text(json.dumps(ax,indent=2));pressed=r.native('press','Cursor glove');assert any(x.get('pressResult')==0 for x in pressed);r.state(False);r.flags(0);assert r.state()['style']=='glove';r.passed('native Accessibility names, selected state, category and selection actions')
 # Every offered bare modifier opens only on a fresh press, then cancels safely.
 for trigger,flag,key in [('option',1<<19,58),('control',1<<18,59),('shift',1<<17,56),('command',1<<20,55)]:
  r.ctl('configure',settings={'radialTrigger':trigger});r.move(900,500,0);before=r.counters()
  r.events({'type':12,'key':key,'flags':flag});r.state(True);r.events({'type':12,'key':key,'flags':0});r.state(False);r.zero_input(before)
 r.ctl('configure',settings={'radialTrigger':'option'});r.passed('all four configured modifiers open and release without mouse input')
 r.ctl('off');r.flags(r.ALT);r.ctl('on');r.state(False);r.flags(r.ALT);r.state(False);r.flags(0);r.flags(r.ALT);r.state(True);r.flags(0);r.passed('activation with modifier already held requires release and fresh press')
 # An explicit app shortcut sharing the trigger modifier keeps working.
 reply=r.control('test-shortcuts',request={'command':'sound','shortcut':{'keyCode':40,'modifiers':2048,'display':'⌥K'}});assert reply['shortcuts']['accepted']
 before=r.state()['settings']['handSound'];r.open_menu();r.events({'type':10,'key':40,'flags':r.ALT},{'type':11,'key':40,'flags':r.ALT});r.state(False);r.flags(0);assert r.state()['settings']['handSound']!=before
 assert r.state()['shortcuts']['sound']['keyCode']==40;r.control('test-shortcuts',request={'command':'sound','shortcut':None});r.passed('explicit Option shortcut still runs while radial trigger is assigned')
 # Opening the app's own Settings disables the gesture even with pointer active.
 r.ctl('settings',section='shortcuts');time.sleep(.3)
 # Settings itself activates its own window.
 # Use actual app state and direct eligibility readback, without posting fixture-guarded input into Settings.
 s=r.state(False);assert not s['input']['radial']['eligible'];r.passed('Settings key window disables modifier gesture and interception')
 # Return public fixture frontmost; close the Settings window via native application command.
 r.native('own-key','close-settings')
 r.native('activate-fixture');time.sleep(.4)
 # Capture closes menu before hiding controls; held modifier cannot reopen it.
 center=r.open_menu();pending=r.ctl('capture');assert pending['capturing'] and not pending['input']['radial']['eligible'];r.state(False)
 for _ in range(50):
  s=r.state()
  if not s['capturing']:break
  time.sleep(.1)
 assert s['lastCapture'] and not s['lastCaptureError'];r.move(920,520);r.state(False);r.flags(0);r.passed('capture cancels radial, saves PNG and prevents held-trigger reopen',pending=pending)
 # Native annotation text entry takes key focus and disables radial input.
 r.ctl('tool',tool='text');r.events({'type':1,'x':800,'y':700},{'type':2,'x':800,'y':700});time.sleep(.2);s=r.state(False);assert not s['input']['radial']['eligible'];r.passed('annotation text entry disables radial ownership')
 r.native('own-key','cancel-text')
 r.native('activate-fixture');time.sleep(.3)
 r.ctl('interact',enabled=True);r.ctl('off');r.flags(0)

def run_denied():
 from types import SimpleNamespace
 r=SimpleNamespace(**globals())
 s=r.state();assert not s['accessibility'] and s['screenRecording']
 r.ctl('off');r.ctl('interact',enabled=True);r.ctl('configure',settings={'radialTrigger':'option','showToolbar':False});r.ctl('on');r.move(900,600,0);before=r.counters();r.flags(r.ALT);r.state(False)
 s=r.state();assert not s['input']['enabled'] and not s['input']['radial']['eligible'];r.passed('denied Accessibility leaves radial tap disabled with assigned trigger')
 r.events({'type':1,'x':900,'y':600,'flags':r.ALT},{'type':2,'x':900,'y':600,'flags':r.ALT});r.flags(0);after=r.counters();assert after['1']==before['1']+1 and after['2']==before['2']+1;r.passed('denied radial preserves native modified click pair',before=before,after=after)
 p=subprocess.run([str(r.binary),'--ctl',json.dumps({'version':1,'operation':'tool','tool':'rectangle'})],capture_output=True,text=True);v=json.loads(p.stdout);assert p.returncode==1 and v['error']['code']=='accessibility' and v['state']['interact'];r.passed('tool permission failure rejects before mutation')
 before=r.state()['settings'];p=subprocess.run([str(r.binary),'--ctl',json.dumps({'version':1,'operation':'configure','settings':{'radialTrigger':'fn','lineWidth':19}})],capture_output=True,text=True);v=json.loads(p.stdout);assert p.returncode==1 and v['state']['settings']==before;r.passed('invalid trigger rejects entire settings batch')
 r.ctl('off');r.ctl('configure',settings={'radialTrigger':''})

def run_reopen_stress(count=10):
 """Bounded same-PID reopen checks; every gesture must pass on its first try."""
 assert 1<=count<=50
 def received_keys():
  received=json.loads(pathlib.Path(env['TINYHAND_FIXTURE_STATE']).read_text())['events']
  return {k:received.get(k,0) for k in ['10','11']}
 def expect_callbacks(before,expected):
  after=state()['input']['types']
  assert all(after.get(k,0)-before.get(k,0)==count for k,count in expected.items()),(before,after,expected)
 assert control('test-shortcuts',request={})['shortcuts']['defaultsSuite']==env['TINYHAND_DEFAULTS_SUITE']
 ctl('off');control('test-shortcuts',request={'command':'reset'})
 ctl('configure',settings={'radialTrigger':'option','showToolbar':False,'handSound':False,'laserSound':False,'fade':0})
 ctl('interact',enabled=True);ctl('on');pid=native('state')['appPID']
 for iteration in range(count):
  before=counters();annotations=state()['annotations'];center=open_menu()
  x,y=center[0],native('state')['bounds'][3]-center[1]
  callbacks=state()['input']['types']
  # Exact sequence immediately preceding the retained failure.
  events({'type':1,'x':x,'y':y,'flags':ALT},{'type':3,'button':1,'x':x,'y':y,'flags':ALT},
         {'type':2,'x':x,'y':y,'flags':ALT},{'type':4,'button':1,'x':x,'y':y,'flags':ALT})
  flags(0);zero_input(before);assert not state(False)['input']['radial']['buttons']
  expect_callbacks(callbacks,{'1':1,'2':1,'3':1,'4':1,'12':1})
  for down,up,button in [(3,4,1),(25,26,2)]:
   center=open_menu();x,y=center[0],native('state')['bounds'][3]-center[1]
   callbacks=state()['input']['types']
   events({'type':down,'button':button,'x':x,'y':y,'flags':ALT});s=state(False)
   assert s['input']['radial']['buttons']==[button]
   ctl('configure',settings={'radialTrigger':''});s=state(False)
   assert s['input']['enabled'] and s['input']['radial']['buttons']==[button]
   events({'type':up,'button':button,'x':x,'y':y,'flags':ALT});flags(0);s=state(False)
   assert not s['input']['radial']['buttons'] and not s['input']['enabled'];zero_input(before)
   expect_callbacks(callbacks,{str(down):1,str(up):1})
   ctl('configure',settings={'radialTrigger':'option'})
  open_menu();close_release();zero_input(before)
  open_menu();keys=received_keys();callbacks=state()['input']['types']
  events({'type':10,'key':53,'flags':ALT},{'type':11,'key':53,'flags':ALT});state(False);flags(0);zero_input(before)
  assert received_keys()==keys;expect_callbacks(callbacks,{'10':1,'11':1,'12':1})
  open_menu();callbacks=state()['input']['types'];move(1400,800)
  events({'type':1,'x':1400,'y':800,'flags':ALT},{'type':2,'x':1400,'y':800,'flags':ALT});state(False);flags(0);zero_input(before)
  expect_callbacks(callbacks,{'1':1,'2':1,'12':1})
  for interact in [False,True]:
   ctl('interact',enabled=interact);open_menu();close_release();zero_input(before)
  assert state()['annotations']==annotations
  open_menu();ctl('off');state(False);flags(0);ctl('on');open_menu();close_release();zero_input(before)
  s=state(False);n=native('state')
  assert n['appPID']==pid and not n['combinedInput']['buttons'] and not n['hidInput']['buttons']
  assert not s['input']['capturedButtons'] and not s['input']['radial']['buttons'] and not s['input']['radial']['keys']
  assert not s['toolbarVisible'] and not s['settings']['showToolbar']
  assert not any(w.get('kCGWindowAlpha',0)>.01 and w.get('kCGWindowBounds',{}).get('Width')==s['toolbarFrame'][2] and w.get('kCGWindowBounds',{}).get('Height')==s['toolbarFrame'][3] for w in n['appWindows'])
  passed('same-process reopen cycle '+str(iteration+1),appPID=pid,openings=len(openings))
 ctl('off');ctl('configure',settings={'radialTrigger':''})

def run_reduce_motion():
 ctl('configure',settings={'radialTrigger':'option','showToolbar':False,'theme':'dark','size':.2})
 ctl('interact',enabled=True);ctl('on');before=counters();center=open_menu()
 assert state(True)['radial']['reduceMotion'], 'Enable the actual macOS Reduce Motion setting first'
 point(0,128,center);point(1,216,center)
 native('shot',out/'radial-reduce-motion-large.png')
 control('test-radial',request={'snapshot':str(out/'radial-reduce-motion.png')})
 close_release();zero_input(before);passed('actual macOS Reduce Motion: fixed geometry, no open/close animation or input leak')
 ctl('off');ctl('configure',settings={'radialTrigger':''})

if __name__ == '__main__':
 import sys
 name='denial-smoke' if '--denied' in sys.argv else 'reduce-motion' if '--reduce-motion' in sys.argv else 'escape-ownership' if '--escape-ownership' in sys.argv else 'reopen-stress' if '--reopen-stress' in sys.argv else 'radial-smoke'
 try:
  if '--denied' in sys.argv:run_denied()
  elif '--reduce-motion' in sys.argv:run_reduce_motion()
  elif '--escape-ownership' in sys.argv:run_escape_ownership()
  elif '--reopen-stress' in sys.argv:run_reopen_stress(int(sys.argv[sys.argv.index('--reopen-stress')+1]) if sys.argv[-1]!='--reopen-stress' else 10)
  else:run_escape_ownership();run();run_extended()
 except BaseException as error:
  failure={'error':str(error),'completedChecks':len(rows),'openingAttempts':len(openings)}
  for key,read in [('state',lambda:ctl('status')),('native',lambda:native('state'))]:
   try:failure[key]=read()
   except Exception as capture_error:failure[key+'Error']=str(capture_error)
  (out/f'{name}-failure-{time.monotonic_ns()}.json').write_text(json.dumps(failure,indent=2))
  raise
 finally:
  try:flags(0)
  except Exception:pass
  (out/(name+'.json')).write_text(json.dumps({'checks':rows,'openings':openings},indent=2))
