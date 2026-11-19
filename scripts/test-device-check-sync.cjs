// Entirely mocked original APIs. Never creates or edits an operational record.
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
let debugPage;
const headers={'content-type':'application/json; charset=utf-8','access-control-allow-origin':'*','access-control-allow-methods':'PUT,POST,OPTIONS','access-control-allow-headers':'content-type,authorization'};
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',args:['--no-sandbox','--disable-dev-shm-usage']});
 async function fixture(){
  const context=await browser.newContext({viewport:{width:390,height:844},timezoneId:'Asia/Seoul'});
  await require('./access-fixture.cjs')(context);
  await context.addInitScript(()=>{
   window.SpeechSynthesisUtterance=class {constructor(text){this.text=text;}};
   Object.defineProperty(window,'speechSynthesis',{configurable:true,value:{getVoices:()=>[{name:'Korean fixture',lang:'ko-KR'}],addEventListener:()=>{},cancel:()=>{},speak:u=>setTimeout(()=>{u.onstart?.();setTimeout(()=>u.onend?.(),10);},0)}});
  });
  const state={current:12,offline:false,saves:[],delay:null,started:null};
  await context.route('https://suho-angel.vercel.app/api/community',route=>route.fulfill({status:503,headers,body:'fixture fallback'}));
  await context.route('https://api-suho1004.innaim.com/**',async route=>{
   const request=route.request(),path=new URL(request.url()).pathname;
   if(request.method()==='OPTIONS')return route.fulfill({status:204,headers});
   const body=request.postDataJSON();let reply;
   if(path.endsWith('/login'))reply={ret:1,user_id:69,name:'호환 검증용',access_token:'device-check-fixture',company_device_name:'fixture-partner',kiosk_id:'fixture-kiosk'};
   else if(path.endsWith('/validate_token'))reply={ret:1};
   else if(path.endsWith('/work_info'))reply={ret:1,work:{work_id:2,work_name:'가상 호환 검증'},process:{current_version_id:25},steps:[{step_id:74,step_name:'확인',start_ment:'확인해 주세요.',work_seconds:0,display_order:1}]};
   else if(path.endsWith('/kiosk_info')){
    if(state.delay){state.started?.();await state.delay;}
    if(state.offline)return route.fulfill({status:503,headers,body:JSON.stringify({message:'fixture offline'})});
    reply={ret:1,kiosks:[{kioskID:'fixture-kiosk',name:'검증 수거기',currentCapacity:state.current,maxCapacity:1000,isAvailable:true}]};
   } else if(path.endsWith('/work_result')){
    assert.equal(request.method(),'PUT');assert.equal(body.user_id,69);
    state.saves.push(body);reply={ret:1,result_id:900001};
   } else if(path.endsWith('/list_work_result')){
    assert.equal(body.user_id,69);assert.equal(body.packetid,'list_work_result');
    reply={ret:1,results:state.saves.map(saved=>({...saved,result_id:900001}))};
   } else throw Error(`Unmocked original API ${path}`);
   return route.fulfill({status:200,headers,body:JSON.stringify(reply)});
  });
  const page=await context.newPage();debugPage=page;
  await page.clock.setFixedTime(new Date('2026-11-19T00:00:00Z'));
  async function ready(){await page.locator('flutter-view').waitFor({timeout:60000});await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());}
  await page.goto(process.env.PWA_TEST_URL||'http://127.0.0.1:8765/');await ready();
  for(const [i,value]of ['fixture-worker','fixture-password'].entries()){
   await page.locator('input').nth(i).click();await page.keyboard.type(value,{delay:20});await page.keyboard.press('Tab');
  }
  await page.getByRole('button',{name:'로그인',exact:true}).click();
  await page.getByRole('button',{name:'작업 시작',exact:true}).click();
  await page.getByText('질문 1 / 1',{exact:true}).waitFor();
  return {context,page,state,ready};
 }
 try {
  const {context,page,state,ready}=await fixture();
  await page.clock.setFixedTime(new Date('2026-11-19T00:01:35Z'));
  await page.getByRole('button',{name:'기기 상태',exact:true}).click();
  await page.getByText('수거기 적재율 기록',{exact:true}).waitFor();
  assert.equal(state.saves.length,0,'a manual check must not create a work result');
  state.current=25;
  await page.clock.setFixedTime(new Date('2026-11-19T00:02:35Z'));
  await page.getByRole('button',{name:/지금 기기 조회/}).click();
  await page.getByRole('button',{name:/지금 기기 조회/}).waitFor({state:'visible'});
  await page.waitForTimeout(500);
  state.offline=true;
  await page.clock.setFixedTime(new Date('2026-11-19T00:03:35Z'));
  await page.getByRole('button',{name:/지금 기기 조회/}).click();
  await page.waitForTimeout(500);
  state.offline=false;state.current=37;
  await page.clock.setFixedTime(new Date('2026-11-19T00:04:35Z'));
  await page.getByRole('button',{name:/지금 기기 조회/}).click();
  await page.waitForTimeout(700);
  assert.equal(state.saves.length,0,'retrying a reading must remain local until finish');
  await page.reload();await ready();
  await page.getByText('질문 1 / 1',{exact:true}).waitFor();
  // Replayed same reading after restore must not duplicate the journal entry.
  await page.getByRole('button',{name:'기기 상태',exact:true}).click();
  await page.getByText('수거기 적재율 기록',{exact:true}).waitFor();
  await page.getByRole('button',{name:'Back',exact:true}).click();
  await page.getByRole('button',{name:'예',exact:true}).click();
  await page.getByText('서버에 작업 결과를 저장했습니다.',{exact:true}).last().waitFor();
  assert.equal(state.saves.length,1);
  const checks=JSON.parse(state.saves[0].result_json).filter(row=>row.type==='device_check');
  assert.deepEqual(checks.map(row=>row['기기상태체크']),['1.2%','2.5%','3.7%']);
  for(const row of checks){assert.equal(row.device_name,'검증 수거기');assert.equal(row.isAvailable,true);assert.equal(row['업무내용'],'기기체크');}
  await page.clock.setFixedTime(new Date('2026-11-19T00:05:35Z'));
  state.current=50;
  await page.getByRole('button',{name:'기기 상태',exact:true}).click();
  await page.getByText('수거기 적재율 기록',{exact:true}).waitFor();
  await page.getByRole('button',{name:/지금 기기 조회/}).click();await page.waitForTimeout(500);
  assert.equal(state.saves.length,1,'completed work must not be resubmitted by a reading');
  const admin=await page.evaluate(async()=>{
   const response=await fetch('https://api-suho1004.innaim.com/api/admin/list_work_result',{method:'PUT',headers:{'Content-Type':'application/json','Authorization':'Bearer fixture-admin'},body:JSON.stringify({packetid:'list_work_result',user_id:69,start_date:'2026-11-19',end_date:'2026-11-19'})});return response.json();
  });
  assert.deepEqual(JSON.parse(admin.results[0].result_json).filter(row=>row.type==='device_check'),checks);
  console.log('PASS mocked manual reads, refresh, network retry, journal restore, one work submission, post-completion read-only and admin JSON comparison');
  await context.close();
  const race=await fixture();let release,entered;
  race.state.delay=new Promise(resolve=>release=resolve);
  const queryStarted=new Promise(resolve=>entered=resolve);race.state.started=entered;
  await race.page.clock.setFixedTime(new Date('2026-11-19T00:01:35Z'));
  await race.page.getByRole('button',{name:'기기 상태',exact:true}).click();
  await queryStarted;
  await race.page.clock.setFixedTime(new Date('2026-11-19T03:00:00Z'));
  await race.page.waitForTimeout(1500);
  assert.equal(race.state.saves.length,0,'finish must wait for a manual reading already in flight');
  race.state.delay=null;release();
  for(let i=0;i<40&&race.state.saves.length===0;i++)await race.page.waitForTimeout(100);
  assert.equal(race.state.saves.length,1);
  assert.equal(JSON.parse(race.state.saves[0].result_json).filter(row=>row.type==='device_check').length,1);
  console.log('PASS automatic finish drains the pre-existing manual read before freezing the single result payload');
  await race.context.close();
 } catch(error) {console.error(await debugPage.locator('[role]').evaluateAll(nodes=>nodes.map(n=>({role:n.getAttribute('role'),label:n.getAttribute('aria-label'),text:n.innerText?.slice(0,120)})).slice(-55)));throw error;} finally {await browser.close();}
})().catch(async error=>{if(debugPage&&!debugPage.isClosed())console.error(await debugPage.locator('[role]').evaluateAll(nodes=>nodes.map(n=>({role:n.getAttribute('role'),label:n.getAttribute('aria-label'),text:n.innerText?.slice(0,120)})).slice(-55)));console.error(error);process.exit(1)});
