// Run after serving build/web; requires playwright and a Chromium executable.
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
let debugPage;
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH || '/usr/bin/chromium',headless:true,args:['--no-sandbox','--disable-dev-shm-usage']});
 const context=await browser.newContext({viewport:{width:390,height:844}});
 // CI has no installed Korean voice/audio device. Exercise the real JS bridge
 // with a deterministic platform speech engine; voice selection is tested separately.
 await context.addInitScript(() => {
  let active;
  const voices=[{name:'Korean Enhanced (test)',lang:'ko-KR',localService:true}];
  window.__speechCalls=[];
  window.SpeechSynthesisUtterance=class {constructor(text){this.text=text;}};
  Object.defineProperty(window,'speechSynthesis',{configurable:true,value:{
   getVoices:()=>voices,addEventListener:()=>{},cancel:()=>{active=null;},
   speak:utterance=>{
    active=utterance;
    window.__speechCalls.push({text:utterance.text,rate:utterance.rate,lang:utterance.lang,voice:utterance.voice?.name});
    setTimeout(()=>{if(active!==utterance)return;utterance.onstart?.();
     setTimeout(()=>{if(active===utterance)utterance.onend?.();},40);},0);
   }
  }});
 });
 const errors=[], calls=[];let saves=0, checkedOut=false;
 await context.route('https://suho-angel.vercel.app/api/community',route=>route.fulfill({status:503,headers:{'access-control-allow-origin':'*'},body:'unavailable in this fixture'}));
 await context.route('https://api-suho1004.innaim.com/**',async route=>{
  const req=route.request();const path=new URL(req.url()).pathname;
  if(req.method()==='OPTIONS') return route.fulfill({status:204,headers:{'access-control-allow-origin':'*','access-control-allow-methods':'PUT','access-control-allow-headers':'content-type,authorization'}});
  const body=req.postDataJSON();calls.push({path,method:req.method(),body});
  let reply;
  if(path.endsWith('/login') && checkedOut) reply={ret:4};
  else if(path.endsWith('/login')) reply={ret:1,user_id:42,name:'테스트 사용자',access_token:'browser-test-only',company_device_name:'test-partner',kiosk_id:'test-kiosk'};
  else if(path.endsWith('/kiosk_info')) { assert.deepEqual(body,{partnerId:'test-partner'}); reply={ret:1,kiosks:[{kioskId:'test-kiosk',name:'수호천사05',currentCapacity:0,maxCapacity:1000,isAvailable:true}]}; }
  else if(path.endsWith('/validate_token')) reply={ret:1};
  else if(path.endsWith('/work_info')) reply={ret:1,work:{work_id:8,work_name:'검증 업무'},process:{current_version_id:1},steps:[{step_id:1,step_name:'첫 단계',start_ment:'첫 번째 확인',work_seconds:0,display_order:1},{step_id:2,step_name:'두 번째 단계',start_ment:'두 번째 확인',work_seconds:0,display_order:2}]};
  else if(path.endsWith('/work_result')) {saves++;reply={ret:1,result_id:99};}
  else if(path.endsWith('/logout')) {checkedOut=true;reply={ret:1};}
  else throw Error(`Unexpected API: ${path}`);
  await route.fulfill({status:200,headers:{'content-type':'application/json; charset=utf-8','access-control-allow-origin':'*'},body:JSON.stringify(reply)});
 });
 const page=await context.newPage();debugPage=page;page.on('pageerror',e=>errors.push(e.message));
 async function ready(){await page.locator('flutter-view').waitFor({timeout:60000});await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());}
 await page.goto(process.env.PWA_TEST_URL || 'http://127.0.0.1:8765/');await ready();
 assert.equal(await page.getByText('함께하는 근무, 더 편안한 하루',{exact:false}).count(),0);
 await page.getByRole('button',{name:'베타버전 켜기',exact:true}).click();
 await page.getByRole('button',{name:'베타버전 끄기',exact:true}).waitFor();
 await page.locator('input').nth(0).click();await page.keyboard.type('demo');
 await page.locator('input').nth(1).click();await page.keyboard.type('fake-password');
 await page.getByRole('button',{name:'로그인',exact:true}).click();

 await page.getByText('안녕하세요!',{exact:true}).waitFor();
 await page.getByRole('button',{name:'작업 시작',exact:true}).waitFor();
 if(process.env.PWA_SCREENSHOT_DIR) {
  await page.screenshot({path:require('node:path').join(process.env.PWA_SCREENSHOT_DIR,'work-waiting-portrait.png')});
  await page.setViewportSize({width:844,height:390});
  await page.waitForTimeout(500);
  await page.screenshot({path:require('node:path').join(process.env.PWA_SCREENSHOT_DIR,'work-waiting-landscape.png')});
  await page.setViewportSize({width:390,height:844});
 }
 await page.getByRole('button',{name:'작업 시작',exact:true}).click();
 await page.waitForFunction(()=>window.__speechCalls.length>0);
 const spoken=await page.evaluate(()=>window.__speechCalls[0]);
 assert.equal(spoken.text,'첫 번째 확인');assert.equal(spoken.rate,0.95);assert.equal(spoken.lang,'ko-KR');
 await page.getByRole('button',{name:'기기 상태',exact:true}).click();
 await page.getByText('키오스크 현황',{exact:true}).waitFor();
 await page.getByText('0.0%  (0/1000)',{exact:true}).waitFor();
 await page.getByText('비어있음',{exact:true}).waitFor();
 if(process.env.PWA_SCREENSHOT_DIR) { await page.waitForTimeout(500); await page.screenshot({path:require('node:path').join(process.env.PWA_SCREENSHOT_DIR,'kiosk-status.png')}); }
 await page.getByRole('button',{name:'닫기',exact:true}).click();
 await page.getByText('질문 1 / 2',{exact:true}).waitFor();
 console.log('PASS assigned kiosk popup uses API values and returns to the same question');
 if(process.env.PWA_SCREENSHOT_DIR) { await page.waitForTimeout(1200); await page.screenshot({path:require('node:path').join(process.env.PWA_SCREENSHOT_DIR,'question-panel.png')}); }
 await page.getByRole('button',{name:'설정',exact:true}).click();
 await page.getByRole('switch',{name:/질문 자동 읽기/}).click();
 await page.getByRole('switch',{name:/자동 읽기가 꺼져 있습니다/}).waitFor();
 await page.getByRole('button',{name:'설정 닫기',exact:true}).click();
 const speechCount=await page.evaluate(()=>window.__speechCalls.length);
 await page.getByRole('button',{name:'예',exact:true}).click();
 await page.getByText('두 번째 확인',{exact:true}).waitFor();
 assert.equal(await page.evaluate(()=>window.__speechCalls.length),speechCount);
 await page.reload();await ready();
 await page.getByText('두 번째 확인',{exact:true}).waitFor({timeout:30000});
 await page.getByRole('button',{name:'설정',exact:true}).click();
 await page.getByRole('switch',{name:/자동 읽기가 꺼져 있습니다/}).waitFor();
 await page.getByRole('button',{name:/베타버전 끄기/}).waitFor();
 await page.getByRole('button',{name:/베타버전 끄기/}).click();
 await page.getByRole('button',{name:/베타버전 켜기/}).waitFor();
 await page.getByRole('button',{name:/베타버전 켜기/}).click();
 await page.getByRole('button',{name:/베타버전 끄기/}).waitFor();
 await page.getByRole('button',{name:'설정 닫기',exact:true}).click();
 await page.getByText('질문 2 / 2',{exact:true}).waitFor();
 assert.equal(await page.evaluate(()=>window.__speechCalls.length),0);
 await page.getByRole('button',{name:'다시 듣기',exact:true}).click();
 await page.waitForFunction(()=>window.__speechCalls.length>0);
 console.log('PASS refresh restores draft, voice and beta choice; style toggle preserves step; replay works');
 await page.getByRole('button',{name:'예',exact:true}).click();
 await page.getByText('서버에 작업 결과를 저장했습니다.',{exact:true}).last().waitFor();
 await page.getByRole('button',{name:'퇴근하기',exact:true}).waitFor();
 await page.getByText('수고하셨습니다.',{exact:false}).waitFor();
 if(process.env.PWA_SCREENSHOT_DIR) {await page.waitForTimeout(1000);await page.screenshot({path:require('node:path').join(process.env.PWA_SCREENSHOT_DIR,'work-complete.png')});}
 assert.equal(saves,1);
 const result=calls.find(c=>c.path.endsWith('/work_result'));
 assert.equal(result.method,'PUT');assert.equal(JSON.parse(result.body.result_json).length,3);
 assert.equal(JSON.parse(result.body.result_json).filter(row=>row.type==='device_check').length,1);
 assert.equal(JSON.parse(result.body.result_json).find(row=>row.type==='device_check')['기기상태체크'],'비어있음');
 assert.equal(JSON.parse(result.body.result_json)[0]['비고'],1);
 await page.getByRole('button',{name:'근무기록 자세히 보기',exact:true}).click();
 await page.getByRole('group',{name:/서버 저장 완료/}).waitFor();
 assert.equal(await page.getByRole('button',{name:'결과 재전송'}).count(),0);
 await page.getByRole('button',{name:'답변 기록 보기',exact:true}).click();
 await page.getByText('일일 근무 성과',{exact:true}).waitFor();
 await page.getByRole('button',{name:'확인했어요',exact:true}).click();
 console.log('PASS result acknowledged once; detailed history has no retry');

 await page.reload();await ready();
 await page.getByText('서버에 작업 결과를 저장했습니다.',{exact:true}).last().waitFor();
 assert.equal(await page.getByRole('button',{name:'작업 시작',exact:true}).count(),0);
 assert.equal(saves,1);
 assert.equal(calls.filter(c=>c.path.endsWith('/logout')).length,0);
 console.log('PASS reload preserves confirmed completion without restart or automatic logout');
 await page.getByRole('button',{name:'퇴근하기',exact:true}).click();
 await page.getByRole('button',{name:'퇴근 완료',exact:true}).waitFor();
 assert.equal(await page.getByRole('button',{name:'로그인',exact:true}).count(),0);
 assert.equal(calls.filter(c=>c.path.endsWith('/logout')).length,1);
 await page.getByRole('button',{name:'근무기록 자세히 보기',exact:true}).click();
 await page.getByRole('group',{name:/서버 저장 완료/}).waitFor();
 assert.equal(await page.getByRole('button',{name:'결과 재전송'}).count(),0);
 console.log('PASS checkout stays on completion; read-only history remains available');
 await page.reload();await ready();
 await page.locator('input').nth(0).click();await page.keyboard.type('demo');
 await page.locator('input').nth(1).click();await page.keyboard.type('fake-password');
 await page.getByRole('button',{name:'로그인',exact:true}).click();
 await page.getByText('계정 상태는 관리자에게 확인해 주세요.',{exact:true}).last().waitFor();
 await page.getByRole('button',{name:'자세한 오류',exact:true}).click();
 await page.getByText('로그인 권한이 없습니다. (응답 코드: 4)',{exact:true}).last().waitFor();
 assert.equal(saves,1);
 console.log('PASS checkout respects server logout; subsequent denial reports original login reason');
 assert.equal(errors.length,0,errors.join('\n'));
 await page.evaluate(()=>navigator.serviceWorker.ready);
 await page.waitForFunction(()=>navigator.serviceWorker.controller!==null);
 const manifest=await page.evaluate(async()=>{const m=await fetch('manifest.json');return m.json()});
 assert.equal(manifest.display,'standalone');assert.equal(manifest.name,'수호천사');
 await context.setOffline(true);
 await page.reload({waitUntil:'domcontentloaded'});await ready();
 await page.waitForTimeout(1000);
 assert.equal(await page.locator('flutter-view').count(),1);
 console.log('PASS offline app shell; API still requires network');
 console.log(JSON.stringify({errors,calls:calls.map(c=>c.path),saves,manifest:manifest.name}));
 await browser.close();
})().catch(async e=>{
 if(debugPage && process.env.PWA_SCREENSHOT_DIR){
  const base=require('node:path').join(process.env.PWA_SCREENSHOT_DIR,'work-failure');
  await debugPage.screenshot({path:base+'.png'}).catch(()=>{});
  require('node:fs').writeFileSync(base+'.html',await debugPage.content());
 }
 if(debugPage) console.error('ACCESSIBLE NODES',await debugPage.locator('[role]').evaluateAll(nodes=>nodes.map(n=>({role:n.getAttribute('role'),label:n.getAttribute('aria-label'),text:n.innerText?.slice(0,180)})).slice(-60)));
 console.error(e);process.exit(1);
});
