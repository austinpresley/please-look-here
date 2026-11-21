const {chromium}=require('/private/tmp/lhp-usability-tools/node_modules/playwright-core');
const fs=require('fs');
const path=require('path');
const root=__dirname;
(async()=>{
 const browser=await chromium.launch({executablePath:'/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',headless:true});
 const page=await browser.newPage({viewport:{width:1440,height:1000},deviceScaleFactor:2});
 const errors=[],checks=[];
 page.on('pageerror',e=>errors.push(e.message));
 async function check(ok,label){checks.push({passed:!!ok,label});if(!ok)throw Error(label);}
 const visible=s=>page.locator('#story-'+s);
 await page.goto('http://127.0.0.1:8768/look-here-please-before-and-after.html');
 await check(await page.locator('[role=tab]').count()===4,'Four comparison views');
 await visible('controls').locator('[data-mode=use]').first().click();
 await check(await visible('controls').locator('.draw-tools').count()===0,'Use apps hides irrelevant drawing tools');
 await visible('controls').locator('[data-mode=draw]').first().click();
 await check(await visible('controls').locator('.draw-tools button').count()===7,'Draw reveals all seven tools');
 await visible('controls').locator('[data-action=power]').click();
 await check(await visible('controls').locator('[data-mode=draw]').first().isDisabled(),'Pointer off disables click behavior without losing the mode');
 await visible('controls').locator('[data-action=power]').click();
 await visible('controls').locator('[data-action=mute]').click();
 await check(await visible('controls').locator('[data-action=mute]').getAttribute('aria-pressed')==='true','Mute has an explicit pressed state');
 await visible('controls').locator('[data-action=mute]').click();
 await page.getByRole('tab',{name:'Choose a pointer'}).click();
 await visible('library').getByRole('searchbox').fill('robot');
 await check(await visible('library').locator('.pointer-tile').count()===1,'Pointer search filters the library');
 await visible('library').locator('.pointer-tile .pick').click();
 await check((await visible('library').locator('.inspector-head').textContent()).includes('Robot'),'Selection updates the adjacent inspector');
 await visible('library').getByRole('searchbox').fill('nothing matches');
 await check(await visible('library').getByText('No matching pointers.').count()===1,'No-results state has a way back');
 await visible('library').getByRole('button',{name:'Show all',exact:true}).click();
 await check(await visible('library').locator('.pointer-tile').count()===9,'Show all restores the concept sample');
 await visible('library').locator('[data-favorite=lemon]').click();
 await check(await visible('library').locator('.library-favorites [data-pick=lemon]').count()===1,'Star adds a shared favorite without selecting it');
 await check((await visible('library').locator('.inspector-head').textContent()).includes('Robot'),'Starring does not change the selected pointer');
 await visible('library').locator('[data-action=adjust]').click();
 await visible('adjust').locator('[data-size]').fill('18');
 await visible('adjust').locator('[data-size]').dispatchEvent('change');
 await check(await visible('adjust').locator('[data-action=reset-size]').count()===1,'A pointer override gets a Use default action');
 await visible('adjust').locator('[data-scope]').selectOption('defaults');
 await check(await visible('adjust').locator('[data-size]').inputValue()==='13','Shared defaults remain separate from a pointer override');
 await visible('adjust').locator('[data-size]').fill('11');
 await visible('adjust').locator('[data-size]').dispatchEvent('change');
 await visible('adjust').locator('[data-scope]').selectOption('pointer');
 await check(await visible('adjust').locator('[data-size]').inputValue()==='18','Pointer override survives editing the defaults');
 await visible('adjust').locator('[data-action=reset-size]').click();
 await check(await visible('adjust').locator('[data-size]').inputValue()==='11','Use default inherits the current shared value');
 await visible('adjust').locator('summary').click();
 await check(await visible('adjust').locator('.gesture-row').first().isVisible(),'Hand gestures remain discoverable');
 await page.getByRole('tab',{name:'First use'}).click();
 await visible('practice').locator('[data-lesson=use]').click();
 await visible('practice').locator('[data-action=demo-click]').click();
 await check((await visible('practice').locator('[data-action=demo-click]').textContent()).includes('Clicked'),'Practice click gives immediate feedback');
 await visible('practice').locator('[data-lesson=draw]').click();
 const canvas=visible('practice').locator('[data-practice-canvas]');
 const rect=await canvas.boundingBox();
 await page.mouse.move(rect.x+50,rect.y+100);await page.mouse.down();await page.mouse.move(rect.x+200,rect.y+60,{steps:8});await page.mouse.up();
 await check((await visible('practice').locator('.drawn-path').getAttribute('d')).includes('L'),'Practice drawing creates visible local ink');
 await visible('practice').locator('[data-action=start-drawing]').click();
 await check(await visible('practice').getByText('Allow Accessibility to draw.').count()===1,'Desktop drawing explains permission only when requested');
 await page.keyboard.press('Escape');
 await check(await visible('practice').getByText('Allow Accessibility to draw.').count()===0,'Escape dismisses first-use permission explanation');
 for(const width of [360,728,1440]){
  await page.setViewportSize({width,height:1000});
  for(const id of ['controls','library','adjust','practice']){
   await page.locator('[data-view='+id+']').click();
   await check(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),'No page overflow at '+width+' on '+id);
   await check(await visible(id).locator('.after-stage').evaluate(el=>el.scrollWidth<=el.clientWidth+1),'No proposed UI overflow at '+width+' on '+id);
  }
 }
 await page.goto('http://127.0.0.1:8768/look-here-please-before-and-after.html');
 await page.setViewportSize({width:1440,height:1000});
 for(const theme of ['light','dark']){
  await page.locator('[data-theme='+theme+']').click();
  for(const id of ['controls','library','adjust','practice']){
   await page.locator('[data-view='+id+']').click();
   await page.locator('#story-'+id).screenshot({path:path.join(root,id+'-'+theme+'.png')});
  }
 }
 await page.goto('http://127.0.0.1:8768/look-here-please-before-and-after.html?board');
 await page.setViewportSize({width:1600,height:1200});
 await page.screenshot({path:path.join(root,'before-and-after-overview.png'),fullPage:true});
 await check(errors.length===0,'No browser JavaScript errors');
 fs.writeFileSync(path.join(root,'validation.json'),JSON.stringify({checks,errors,browser:'Local Chrome via Playwright',date:new Date().toISOString()},null,2));
 console.log(checks.length+' local checks passed. Eight comparison captures and one overview exported.');
 await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
