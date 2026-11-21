Object.assign(S,{toolPane:'drawing',radialOpen:false,presetMenu:false});

function scopedSection(id,name,scope,body,note=''){
 return `<section id="${id}"><div class="section-heading"><h3>${name}</h3><span class="section-scope">${scope}</span></div>${group(body)}${note?`<p class="subnote">${note}</p>`:''}</section>`;
}
function general(){
 return title('General','Set up access, startup and app appearance.')+
 section('permissions','Permissions',permission('Accessibility',S.accessibility,'Drawing, tool keys and Quick controls.')+permission('Screen Recording',S.recordingPermission,'Screenshots and magnification.'))+
 section('startup','Startup and updates',row('Open at login',switcher('Open at login','login',S.login))+(S.updates?
 row('Check automatically',button('Check Now','check-updates')+switcher('Check for updates automatically','autoUpdates',S.autoUpdates),`Last checked ${S.lastCheck.toLowerCase()}.`):
 row('Updates','<span class="status">Unavailable</span>','Updates are not set up in this build.','disabled-row')))+
 section('appearance','Appearance',row('Theme',radios('App theme','themePreference',['System','Light','Dark'],S.themePreference)))+
 `<div class="page-footer"><span>New to Look Here Please?</span>${link('Practice the Controls…','practice')}</div>`;
}
function defaultPreview(){
 const count=customCount(S.current);
 return `<div class="compact-preview"><div class="preview-controls"><strong>Default sample</strong>${menu('Sample background','previewBackground',['Light','Dark','Patterned'],S.previewBackground||'Light')}</div><div class="preview-sample" id="defaults-sample">${art('lavender')}<div class="sample-actions">${button('Preview Tap','preview-tap')}${button('Preview Motion','preview-motion')}</div></div>${count?`<div class="scope-note"><span>${esc(entry(S.current).name)} has ${count} custom values.</span>${link('Review…','customize-current')}</div>`:'<p class="subnote">This sample uses the shared values below.</p>'}</div>`;
}
function defaults(){
 return title('Pointer defaults','Set the starting look and sound for your pointers.')+defaultPreview()+
 scopedSection('default-look','Look','Can be customized per pointer',
 row('Size',slider('Default size','defaults.size',S.defaults.size,4,20,1,'%'),'Percent of display height.')+
 row('Shadow',menu('Default shadow','defaultShadow',['Off','Original','Contact'],S.defaults.shadow?S.defaults.shadowStyle:'Off')))+
 scopedSection('default-sound','Tap sound','Can be customized per pointer',
 row('Play on tap',switcher('Default tap sound','defaults.soundEnabled',S.defaults.soundEnabled))+
 row('Sound',menu('Default tap sound choice','defaults.sound',SOUND,S.defaults.sound)+button('Preview','preview-sound',S.output.muted||S.output.volume===0?'disabled title="App sound is muted or at zero volume"':'')))+
 scopedSection('app-output','App sound','Applies to all pointers',
 row('Volume',button(S.output.muted?'Unmute':'Mute','toggle-mute',`aria-pressed="${S.output.muted}" aria-label="${S.output.muted?'Unmute all app sounds':'Mute all app sounds'}"`)+slider('App volume','output.volume',S.output.volume,0,100,1,'%')),
 S.output.muted?'All app sounds and previews are muted.':S.output.volume===0?'Volume is zero. Sound previews are silent.':'')+
 scopedSection('motion','Motion','Applies across the app',
 row('Follow',radios('Follow behavior','motion.follow',['Original','Responsive'],S.motion.follow),S.motion.follow==='Original'?'A looser grip swing.':'Tracks small moves and catches quick flicks.')+
 row('Tap swing',slider('Tap swing','motion.swing',S.motion.swing,0,2,.1,'×'))+
 row('Keep hand visible during clicks and drags',switcher('Keep hand visible while interacting','motion.keepVisible',S.motion.keepVisible)),
 'Reduce Motion turns tap swing off. Size also sets Spotlight aperture and presentation rod thickness.');
}
function toolbarFavorites(){
 return `<div class="favorite-row"><div class="favorite-label"><strong>Toolbar</strong><span>${S.pins.length} of 8</span></div><div class="slots toolbar-slots">${S.pins.map((id,i)=>`<button type="button" class="slot ${S.selectedPin===i?'selected':''}" draggable="true" data-pin-index="${i}" aria-label="Toolbar ${i+1}: ${esc(entry(id).name)}. ${entry(id).enabled?'Enabled':'Off'}. Open reorder actions." title="${esc(entry(id).name)} · Move or unpin">${entry(id).available?art(id):'<span class="fine">⚠</span>'}<span class="slot-label">${i+1}</span></button>`).join('')}${S.pins.length<8?`<button class="slot add-favorite" data-action="add-toolbar" aria-label="Add a toolbar favorite"><span>+</span></button>`:''}</div></div>`;
}
function radialFavorites(){
 const directions=['N','NE','E','SE','SW','W'];
 return `<div class="favorite-row quick-row"><div class="favorite-label"><strong>Quick controls</strong><span>Six fixed directions</span></div><div class="quick-strip" aria-label="Quick controls favorites, separate from toolbar">${S.quick.map((id,i)=>`<button class="quick-chip" data-quick-index="${i}" aria-label="${directions[i]}: ${esc(entry(id).name)}. ${entry(id).enabled?'Enabled':'Off'}. Choose a favorite." title="${directions[i]}: ${esc(entry(id).name)}">${entry(id).available?art(id):'<span class="fine">⚠</span>'}<span>${directions[i]}</span></button>`).join('')}</div><button class="direction-map-button" data-ui-action="toggle-direction-map" aria-expanded="${S.radialOpen}" aria-label="Show Quick controls direction map" title="See the radial arrangement">${S.radialOpen?'Hide map':'Map'}</button></div>${S.radialOpen?directionMap():''}`;
}
function directionMap(){
 const pos=[['N',1,0],['NE',2,0],['E',2,1],['SE',2,2],['SW',0,2],['W',0,1]];
 return `<div class="direction-map"><p class="fine">Each direction keeps its saved slot. Choosing an existing favorite swaps the slots.</p><div class="radial-favorites">${pos.map(([d,x,y],i)=>`<button class="radial-slot" style="grid-column:${x+1};grid-row:${y+1}" data-quick-index="${i}" aria-label="Edit ${d}: ${esc(entry(S.quick[i]).name)}">${art(S.quick[i])}<span>${d}</span></button>`).join('')}<span class="radial-center" style="grid-column:2;grid-row:2">Pointer</span><span class="radial-static" style="grid-column:1;grid-row:1">All</span><span class="radial-static" style="grid-column:2;grid-row:3">Back</span></div></div>`;
}
function pointers(){
 const p=entry(S.current),items=filteredCatalog(),hidden=!items.some(e=>e.id===p.id);
 return title('Pointers','Choose a pointer and keep your favorites close.')+
 `<div class="current-strip">${art(S.current)}<div class="current-copy"><div class="fine">Current pointer</div><div class="current-name">${esc(p.name)}</div><span class="selection-scope">${customCount(S.current)?customCount(S.current)+' custom values':'Uses Pointer Defaults'}</span></div>${button('Customize…','customize-current')}</div>`+
 `<div class="favorites-group group">${toolbarFavorites()}${radialFavorites()}</div>`+
 `<div class="library-tools sticky-library"><input type="search" id="pointer-search" placeholder="Search ${CATALOG.filter(e=>!e.removed).length} pointers" aria-label="Search all pointers" value="${esc(S.query)}">${button(S.filters.size?'Filters · '+S.filters.size:'All pointers','show-filters',`aria-haspopup="menu" aria-expanded="${S.filterOpen}"`)}${button('New Hand…','new-hand')}</div>`+
 (S.filterOpen?`<div class="filter-menu" role="menu" aria-label="Filter pointers" style="position:fixed;left:${S.filterX||240}px;top:${S.filterY||440}px"><div class="fine">Combine filters</div>${['Enabled','Pinned','Custom'].map(f=>`<button role="menuitemcheckbox" aria-checked="${S.filters.has(f)}" data-filter-item="${f}">${S.filters.has(f)?'✓ ':''}${f}</button>`).join('')}${link('Show All','show-all')}</div>`:'')+
 (S.filters.size||S.query?`<div class="filter-summary">${items.length} matches${S.filters.size?' · '+[...S.filters].join(' + '):''}${link('Show All','show-all')}</div>`:'')+
 (hidden?`<div class="inline-message">${esc(p.name)} is hidden by filters. ${link('Show All','show-all')}</div>`:'')+
 (S.libraryRecovery?`<div class="transaction">Removed ${esc(S.libraryRecovery.name)}.${button('Undo','undo-remove-hand')}</div>`:'')+pointerMenu()+
 `<div class="gallery">${items.map(p=>`<div class="tile ${p.id===S.current?'selected':''} ${p.enabled?'':'disabled'}"><button class="select-pointer" data-pointer="${p.id}" ${!p.enabled||!p.available?'disabled':''} aria-pressed="${p.id===S.current}" aria-label="${esc(p.name)}, ${p.id===S.current?'selected, ':''}${p.enabled?'enabled':'off'}, ${S.pins.includes(p.id)?'pinned':'not pinned'}${p.custom?', custom':''}${p.available?'':', image unavailable'}">${p.available?art(p.id):'<span class="native-art unavailable">⚠</span>'}<span class="tile-name">${esc(p.name)}</span><span class="tile-state">${[p.id===S.current?'✓ Selected':'',S.pins.includes(p.id)?'Pinned':'',!p.enabled?'Off':'',p.custom?'Custom':'',!p.available?'Image unavailable':''].filter(Boolean).join(' · ')}</span></button><button class="more" data-menu="${p.id}" aria-label="Actions for ${esc(p.name)}" aria-haspopup="menu">···</button></div>`).join('')||`<div class="empty-state" style="grid-column:1/-1"><strong>No matching pointers</strong><p>Try a different name or show the full library.</p>${button('Show All','show-all')}</div>`}</div>`;
}
function toolPaneNavigation(){
 return `<div class="tool-pane-nav" role="group" aria-label="Tool settings">${[['drawing','Drawing'],['magnification','Magnification'],['screenshots','Screenshots']].map(([id,label])=>`<button data-tool-pane="${id}" aria-pressed="${S.toolPane===id}" class="${S.toolPane===id?'active':''}">${label}</button>`).join('')}</div>`;
}
function tools(){
 let body=title('Tools','Set up drawing, magnification and capture.')+toolPaneNavigation();
 if(S.toolPane==='magnification')return body+`<div class="magnifier-example" role="img" aria-label="Illustrative magnification sample at ${S.magnifier.zoom} times"><div class="sample-document"><span>Project notes</span><i></i><i></i><i></i></div><div class="sample-lens"><strong>${S.magnifier.zoom}×</strong><span>Click point</span><b>+</b></div></div>`+
 section('magnification','Magnification',row('Zoom',slider('Magnification zoom','magnifier.zoom',S.magnifier.zoom,1.5,6,.5,'×'))+row('Lens size',slider('Lens size','magnifier.diameter',S.magnifier.diameter,160,480,16,' pt')),'The lens stays on the current display and marks the exact click point.')+
 `<p class="subnote">Turn magnification on from the toolbar, menu or an assigned shortcut.</p>`+(S.recordingPermission==='Allowed'?`<div class="access-summary"><span class="status good">Screen Recording allowed</span></div>`:`<div class="inline-message error-message">Screen Recording is ${S.recordingPermission.toLowerCase()}. ${link('Review Access…','go-permissions')}</div>`);
 if(S.toolPane==='screenshots')return body+`<div class="capture-example"><span class="capture-symbol" aria-hidden="true">▣</span><div><strong>Capture what you are showing</strong><p>Includes the display, pointer and annotations.</p></div></div>`+
 section('screenshots','After capturing',row('Destination',menu('Screenshot destination','capture',['Save and copy','Save to folder','Copy to clipboard'],S.capture))+(S.capture==='Copy to clipboard'?'':row('Save folder',button('Choose…','choose-folder'),esc(S.folder))))+
 `<p class="subnote">Capture the full display or choose a region from the toolbar, menu or a shortcut.</p>`+(S.recordingPermission==='Allowed'?`<div class="access-summary"><span class="status good">Screen Recording allowed</span></div>`:`<div class="inline-message error-message">Screen Recording is ${S.recordingPermission.toLowerCase()}. ${link('Review Access…','go-permissions')}</div>`);
 return body+practiceMarkup()+
 section('drawing-ink','Ink',row('Color',`<div class="swatches refined-swatches">${INK.map(([id,name,color])=>`<button class="ink-hit ${S.ink===id?'active':''}" data-ink="${id}" aria-label="${name}" aria-pressed="${S.ink===id}" style="--swatch:${color}"><span class="ink-dot ${id==='match'?'match':''}"></span></button>`).join('')}</div>`)+row('Line width',slider('Line width','width',S.width,2,20,1,' pt'))+row('Opacity',slider('Ink opacity','opacity',S.opacity,10,100,5,'%')))+
 section('fading','Fading',row('Behavior',radios('Fading behavior','fade',['Keep','Fade','Trail'],S.fade))+(S.fade==='Keep'?'':row(S.fade==='Trail'?'Other marks fade after':'Fade after',fadeDelayPicker())))+
 group(details('timing','Smoothing and trail timing',S.smoothing+(S.fade==='Trail'?` · ${S.trailDelay}s · ${S.trailSpeed}pt/s`:''),row('Smoothing',menu('Smoothing','smoothing',['Off','Very light','Light','Medium'],S.smoothing))+(S.fade==='Trail'?row('Trail delay',slider('Trail delay','trailDelay',S.trailDelay,.2,3,.2,' s'))+row('Trail speed',slider('Trail speed','trailSpeed',S.trailSpeed,40,600,20,' pt/s')):'')));
}
function keyRows(commands){
 const conflicts=conflictKeys();
 return commands.filter(c=>c.toLowerCase().includes(S.keyQuery.toLowerCase())&&(S.keyFilter!=='Assigned'||S.keys[c])&&(!S.conflictView||conflicts.includes(c))).map(c=>{
  const scope=keyScope(c),needsCaption=c.includes('Gesture')||c==='Tap Sound On/Off';
  const global=['Pointer On/Off','Clear Drawing'].includes(c);
  return row(`${esc(c)}${global?'<span class="global-key-label">Global</span>':''}${needsCaption?'<span class="scope-label">'+esc(scope)+'</span>':''}`,
  `<button class="mbtn keyfield ${S.keys[c]?'assigned':''}" data-key="${esc(c)}" aria-label="Record ${esc(c)} shortcut. ${esc(scope)}">${S.recordingKey===c?'Press keys…':esc(S.keys[c]||'Record')}</button>`+
  (S.keys[c]?link('Clear','clear-key',`data-command="${esc(c)}" aria-label="Clear ${esc(c)} shortcut"`):''),'','key-row')+
  (conflicts.includes(c)?`<div class="row-error">⚠ Also assigned to ${esc(conflicts.find(k=>k!==c&&S.keys[k]===S.keys[c])||'another command')}. Record another key or Clear.</div>`:'')+
  (S.keyError[c]?`<div class="row-error">${esc(S.keyError[c])}</div>`:'');
 }).join('');
}
function shortcuts(){
 const conflicts=conflictKeys(),total=Object.keys(S.keys).length;
 const matching=[...Object.values(COMMANDS).flat(),...TOOLS].filter(c=>c.toLowerCase().includes(S.keyQuery.toLowerCase())&&(S.keyFilter!=='Assigned'||S.keys[c])&&(!S.conflictView||conflicts.includes(c)));
 return title('Shortcuts','Find a command and choose its keys.')+
 (conflicts.length?`<div class="inline-message error-message"><span>⚠ ${conflicts.length} commands use the same shortcut.</span>${button(S.conflictView?'Show All':'Show Conflicts','show-conflicts')}</div>`:'')+
 `<div class="command-search-header"><div class="command-filter"><input type="search" id="key-search" placeholder="Find a command" aria-label="Find a command" value="${esc(S.keyQuery)}">${menu('Command filter','keyFilter',['All commands','Assigned'],S.keyFilter)}</div><div class="search-help"><span>${total?total+' assigned':'Starts unassigned'}</span><span>Click to record. Escape cancels.</span></div></div>`+
 `<div class="section-jump secondary-jumps"><a href="#keyboard">Keyboard</a><a href="#toolbar">Toolbar</a><a href="#quick-controls">Quick controls</a><a href="#stream-deck">Stream Deck</a></div>`+
 `<section id="keyboard">${!matching.length?'<div class="empty-state"><strong>No matching commands</strong><p>Change the search or choose All commands.</p></div>':''}${commandGroup('Pointer',COMMANDS.Pointer)}${commandGroup('Presenting',COMMANDS.Presenting)}${commandGroup('Drawing',COMMANDS.Drawing,false)}${group(`<details data-disclosure="tool-keys" ${S.open['tool-keys']||TOOLS.some(c=>S.keys[c])||S.keyQuery||TOOLS.some(c=>conflicts.includes(c))?'open':''}><summary>Tool keys · Interact off<span class="summary-value">${TOOLS.filter(c=>S.keys[c]).length} of 7 set</span></summary><p class="subnote" style="padding:0 12px 8px">Single keys work here. They pause while you type.</p>${keyRows(TOOLS)}</details>`)}<p class="subnote">Global keys work with the pointer off. Other commands require Pointer On. Standard editing keys keep working in text fields.</p></section>`+
 section('toolbar','Toolbar',row('Show toolbar',switcher('Show toolbar','showToolbar',S.showToolbar),'Reveals at startup and when the cursor is nearby.')+row('Position',button('Reset Position','reset-position')))+
 section('quick-controls','Quick controls',row('Hold to open',menu('Hold-to-open modifier','modifier',['Unassigned','Option','Control','Shift','Command'],S.modifier)+(S.modifier!=='Unassigned'?link('Clear','clear-modifier'):''))+row('Open Quick controls',`<button class="mbtn keyfield" data-key="Open Quick controls">${S.recordingKey==='Open Quick controls'?'Press keys…':esc(S.keys['Open Quick controls']||'Record')}</button>`+(S.keys['Open Quick controls']?link('Clear','clear-key','data-command="Open Quick controls"'):'')),'Hold, move to a choice, release. Desktop use needs Accessibility and Pointer On.')+
 `<div class="preview-controls">${link('Practice…','practice-quick')}${link('Edit favorites in Pointers…','go-favorites')}</div>`+
 section('stream-deck','Stream Deck',row('Bundled plugin 1.1.0.0',button(S.deckBusy?'Opening…':'Install Plugin…','install-deck',S.deckBusy?'disabled':''),'Requires Stream Deck 6.5 or later.')+(!S.deckHost?row('Stream Deck app',link('Download Stream Deck…','download-deck'),'Install the app before adding the plugin.'):'')+(S.deckMessage?row('Status','<span class="fine">'+esc(S.deckMessage)+'</span>'):''),'Finish installation in Stream Deck, then add actions to your keys.');
}
function presets(){
 const p=S.presets[S.selectedPreset];
 return title('Presets & Backup','Keep a few setups ready to use.')+recoveryBanner()+
 `<div class="section-heading preset-heading"><h3>Saved presets</h3>${button('Save Current Setup…','save-preset')}</div>`+
 group(S.presets.length?S.presets.map((p,i)=>`<div class="preset-row ${i===S.selectedPreset?'selected':''}"><button class="preset-choice" data-preset="${i}" aria-pressed="${i===S.selectedPreset}">${art(p.pointer)}<span><strong>${esc(p.name)}</strong><span class="detail">${esc(entry(p.pointer).name)} · ${p.pins} toolbar favorites · ${p.off} pointers off</span></span></button>${i===S.selectedPreset?button('Apply','apply-preset'):''}</div>`).join(''):'<div class="empty-state"><strong>No saved presets</strong><p>Save the current setup to use it again.</p></div>')+
 (p?`<div class="preset-inline-actions"><span>Selected: ${esc(p.name)}</span><div>${link('Update from Current Setup','update-preset')}${link('Remove…','remove-preset')}</div></div>`:'')+
 `<p class="subnote">Applying preserves activation, Interact, shortcuts and startup. Missing pointer settings stay saved.</p>`+
 section('backup','Backup',row('Settings and artwork',button('Export…','export-backup')+button('Import…','import-backup')),'Includes presets and custom artwork. Shortcuts, startup, capture folders and display positions stay on this Mac.')+
 group(details('backup-included','What is included','',`<div class="row"><div class="left">Supported settings, pointer defaults, independent pointer overrides, presets, custom hands and gesture artwork. Imports keep existing files and stop on conflicts.</div></div>`)+details('recovery-folder','Recovery copies','',row('Local recovery folder',button('Show in Finder','show-recovery'))))+
 `<div class="reset-footer"><span>Return app preferences to their defaults.</span>${button('Reset All Settings…','reset-all','style="color:var(--danger-ink,#b54f4a)"')}</div>`;
}
function about(){
 return `<div class="about-header"><img src="${parent.REVIEW_ICON}" alt="Look Here Please app icon"><div><h2>Look Here Please</h2><p class="version">Version 1.2.0</p><p>Point it out. Draw it on screen.</p><p>By Austin Presley</p></div></div><div class="links-list"><a class="plain-link" target="_blank" rel="noopener" href="https://github.com/austinpresley/please-look-here">Source and project status <span aria-hidden="true">↗</span></a><a class="plain-link" target="_blank" rel="noopener" href="https://github.com/nilbuild/tinyhand">Based on TinyHand <small>Kamran Ahmed</small></a><a class="plain-link" target="_blank" rel="noopener" href="https://github.com/austinpresley/please-look-here/blob/main/LICENSE">MIT license <span aria-hidden="true">↗</span></a>${link('Show Open-source Notices','show-notices')}</div><p class="build-number">Build 20261116015628</p>`;
}
function fieldReset(id,field){
 if(S.overrides[id]?.[field]===undefined)return '';
 const label=({size:sizeLabel(id).toLowerCase(),shadow:'shadow',shadowStyle:'shadow style',soundEnabled:'tap sound',sound:'sound choice'})[field];
 const value=S.defaults[field],formatted=typeof value==='boolean'?(value?'On':'Off'):field==='size'?value+'%':value;
 return `<button class="reset-value reset-default" data-reset-field="${field}" aria-label="Use default ${label}, ${esc(formatted)}, for ${esc(entry(id).name)}" title="Shared default: ${esc(formatted)}">Use Default</button>`;
}
document.addEventListener('click',e=>{
 const pane=e.target.closest('[data-tool-pane]');
 if(pane){S.toolPane=pane.dataset.toolPane;render();parent.postMessage({type:'tool-request',pane:S.toolPane},'*');return}
 const a=e.target.closest('[data-ui-action]')?.dataset.uiAction;
 if(a==='toggle-direction-map'){S.radialOpen=!S.radialOpen;render(true)}
});
window.addEventListener('message',e=>{
 if(e.source!==parent||e.data?.type!=='review-state')return;
 if(e.data.toolPane&&e.data.toolPane!==S.toolPane){S.toolPane=e.data.toolPane;if(S.page==='drawing')render()}
});

function openPinMenu(b){
 const index=S.selectedPin,r=b.getBoundingClientRect();S.menu=null;
 const host=document.createElement('div');host.className='pin-menu pointer-actions';host.setAttribute('role','menu');
 host.style.cssText=`position:fixed;left:${Math.max(8,Math.min(innerWidth-210,r.left))}px;top:${Math.min(innerHeight-135,r.bottom+4)}px`;
 host.innerHTML=`<div class="fine">${esc(entry(S.pins[index]).name)}</div>${button('Move Left','move-pin-left',index===0?'disabled':'')}${button('Move Right','move-pin-right',index===S.pins.length-1?'disabled':'')}${button('Unpin from Toolbar','unpin-selected',S.pins.length===1?'disabled':'')}`;
 document.querySelector('.pin-menu')?.remove();$('app').append(host);host.querySelector('button:not(:disabled)')?.focus();
}

function fadeDelayPicker(){return `<select aria-label="Fade delay" data-setting="fadeDelay">${[3,6,10].map(n=>`<option value="${n}" ${S.fadeDelay===n?'selected':''}>${n} seconds</option>`).join('')}</select>`}
