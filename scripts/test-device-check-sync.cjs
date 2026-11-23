// Entirely mocked original APIs. Never creates or edits an operational record.
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
let debugPage;
const headers={'content-type':'application/json; charset=utf-8','access-control-allow-origin':'*','access-control-allow-methods':'PUT,POST,OPTIONS','access-control-allow-headers':'content-type,authorization'};
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',args:['--no-sandbox','--disable-dev-shm-usage']});
 async function fixture({rejectPartnerId=false,assignment={partner:'fixture-partner',kiosk:'fixture-kiosk'},kiosks=null,startWork=true}={}){
  const context=await browser.newContext({viewport:{width:390,height:844},timezoneId:'Asia/Seoul'});
  await require('./access-fixture.cjs')(context);
  await context.addInitScript(()=>{
   window.SpeechSynthesisUtterance=class {constructor(text){this.text=text;}};
   Object.defineProperty(window,'speechSynthesis',{configurable:true,value:{getVoices:()=>[{name:'Korean fixture',lang:'ko-KR'}],addEventListener:()=>{},cancel:()=>{},speak:u=>setTimeout(()=>{u.onstart?.();setTimeout(()=>u.onend?.(),10);},0)}});
  });
  const state={current:12,offline:false,saves:[],delay:null,started:null,kioskRequests:[]};
  await context.route('https://suho-angel.vercel.app/api/community',route=>route.fulfill({status:503,headers,body:'fixture fallback'}));
  await context.route('https://api-suho1004.innaim.com/**',async route=>{
   const request=route.request(),path=new URL(request.url()).pathname;
   if(request.method()==='OPTIONS')return route.fulfill({status:204,headers});
   const body=request.postDataJSON();let reply;
   if(path.endsWith('/login'))reply={ret:1,user_id:69,name:'호환 검증용',access_token:'device-check-fixture',company_device_name:assignment.partner,kiosk_id:assignment.kiosk};
   else if(path.endsWith('/validate_token'))reply={ret:1};
   else if(path.endsWith('/work_info'))reply={ret:1,work:{work_id:2,work_name:'가상 호환 검증'},process:{current_version_id:25},steps:[{step_id:74,step_name:'확인',start_ment:'확인해 주세요.',work_seconds:0,display_order:1}]};
   else if(path.endsWith('/kiosk_info')){
    state.kioskRequests.push(body);
    if(rejectPartnerId && Object.hasOwn(body,'partnerId'))return route.fulfill({status:422,headers,body:JSON.stringify({message:'fixture requires partnerIds'})});
    if(state.delay){state.started?.();await state.delay;}
    if(state.offline)return route.fulfill({status:503,headers,body:JSON.stringify({message:'fixture offline'})});
    reply={ret:1,kiosks:kiosks||[{kioskID:'fixture-kiosk',name:'검증 수거기',currentCapacity:state.current,maxCapacity:1000,isAvailable:true}]};
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
  if(startWork){
   await page.getByRole('button',{name:'작업 시작',exact:true}).click();
   await page.getByText('질문 1 / 1',{exact:true}).waitFor();
  }else await page.getByRole('button',{name:'작업 시작',exact:true}).waitFor();
  return {context,page,state,ready};
 }
 async function preparationRace(){
  const flow=await fixture();
  await flow.page.getByRole('button',{name:'설정',exact:true}).click();
  await flow.page.getByText('기기 기록 · 그래프',{exact:true}).waitFor();
  // Pause real browser secure-storage reads before kiosk HTTP starts, not the HTTP itself.
  await flow.page.evaluate(()=>{
   const original=SubtleCrypto.prototype.decrypt;
   window.__storageWaiters=[];window.__holdStorage=true;
   SubtleCrypto.prototype.decrypt=function(...args){
    const run=()=>original.apply(this,args);
    return window.__holdStorage?new Promise((resolve,reject)=>window.__storageWaiters.push(()=>run().then(resolve,reject))):run();
   };
  });
  await flow.page.getByText('기기 기록 · 그래프',{exact:true}).click();
  await flow.page.waitForFunction(()=>window.__storageWaiters.length>0);
  await flow.page.clock.setFixedTime(new Date('2026-11-19T03:00:00Z'));
  await flow.page.waitForTimeout(1500);
  await flow.page.evaluate(()=>{
   window.__holdStorage=false;
   window.__storageWaiters.splice(0).forEach(run=>run());
  });
  for(let i=0;i<100&&flow.state.saves.length===0;i++)await flow.page.waitForTimeout(100);
  assert.equal(flow.state.saves.length,1);
  const checks=JSON.parse(flow.state.saves[0].result_json).filter(row=>row.type==='device_check');
  assert.equal(checks.length,1,'a query clicked during work must survive slow preparation and automatic finish');
  assert.equal(checks[0]['기기상태체크'],'1.2%');
  console.log('PASS manual query intent survives delayed secure-storage preparation and automatic finish (one result, one check)');
  await flow.context.close();
 }
 try {
  await preparationRace();
  if(process.env.PWA_DEVICE_TEST_CASE==='prepare-race')return;
  const {context,page,state,ready}=await fixture();
  await page.clock.setFixedTime(new Date('2026-11-19T00:01:35Z'));
  await page.getByRole('button',{name:'기기 상태',exact:true}).click();
  await page.getByText('수거기 적재율 기록',{exact:true}).waitFor();
  await page.getByText(/근무 결과에 포함할 점검 1건/).waitFor();
  if(process.env.PWA_AUDIT_SCREENSHOTS)await page.screenshot({path:'build/collector-status-active.png',fullPage:true});
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
  await page.getByText(/이번 조회는 상태·용량·배정 정보를 확인하지 못해/).waitFor();
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
  const compatibility=await fixture({rejectPartnerId:true});
  await compatibility.page.getByRole('button',{name:'기기 상태',exact:true}).click();
  await compatibility.page.getByText('수거기 적재율 기록',{exact:true}).waitFor();
  assert(compatibility.state.kioskRequests.some(body=>body.partnerId==='fixture-partner'));
  assert(compatibility.state.kioskRequests.some(body=>Array.isArray(body.partnerIds)&&body.partnerIds[0]==='fixture-partner'));
  await compatibility.page.getByRole('button',{name:'Back',exact:true}).click();
  await compatibility.page.getByRole('button',{name:'예',exact:true}).click();
  await compatibility.page.getByText('서버에 작업 결과를 저장했습니다.',{exact:true}).last().waitFor();
  assert.equal(compatibility.state.saves.length,1);
  const recovered=JSON.parse(compatibility.state.saves[0].result_json).filter(row=>row.type==='device_check');
  assert.equal(recovered.length,1);
  assert.equal(recovered[0]['기기상태체크'],'1.2%');
  console.log('PASS HTTP 422 partnerId fallback preserves the manual percentage in one work result');
  await compatibility.context.close();
  // Replay the observed field shapes with fake authentication and intercepted APIs.
  // A mixed-type maximum and a decoy kiosk must not erase/select the wrong reading.
  const observed=await fixture({
   assignment:{partner:'greenhug',kiosk:'VixVL4sPtmkwPaGHBWoR'},
   kiosks:[
    {kioskId:'AepXb0agjlZ6JhI0bxw9',name:'여주아울렛04',currentCapacity:12,maxCapacity:1000,isAvailable:true},
    {kioskId:' ',kioskID:' VixVL4sPtmkwPaGHBWoR ',name:'여주아울렛06',currentCapacity:'14',maxCapacity:'1000',isAvailable:1}
   ]
  });
  await observed.page.getByRole('button',{name:'기기 상태',exact:true}).click();
  await observed.page.getByText('수거기 적재율 기록',{exact:true}).waitFor();
  await observed.page.getByRole('button',{name:'Back',exact:true}).click();
  await observed.page.reload();await observed.ready();
  await observed.page.getByText('질문 1 / 1',{exact:true}).waitFor();
  await observed.page.getByRole('button',{name:'예',exact:true}).click();
  await observed.page.getByText('서버에 작업 결과를 저장했습니다.',{exact:true}).last().waitFor();
  assert.equal(observed.state.saves.length,1);
  assert(observed.state.kioskRequests.every(body=>body.partnerId==='greenhug'||body.partnerIds?.[0]==='greenhug'));
  const observedChecks=JSON.parse(observed.state.saves[0].result_json).filter(row=>row.type==='device_check');
  assert.equal(observedChecks.length,1);
  assert.equal(observedChecks[0].device_name,'여주아울렛06');
  assert.equal(observedChecks[0]['기기상태체크'],'1.4%');
  assert.equal(observedChecks[0].isAvailable,true);
  assert.equal(observedChecks[0]['업무내용'],'기기체크');
  console.log('PASS assigned kiosk alias/whitespace and mixed numeric values survive reload and produce one 1.4% work check (mock API only)');
  await observed.context.close();
  const beforeWork=await fixture({startWork:false});
  await beforeWork.page.getByRole('button',{name:'기기 상태',exact:true}).click();
  await beforeWork.page.getByText('수거기 적재율 기록',{exact:true}).waitFor();
  await beforeWork.page.getByText(/작업 시작 전 조회입니다/).waitFor();
  if(process.env.PWA_AUDIT_SCREENSHOTS)await beforeWork.page.screenshot({path:'build/collector-status-before-work.png',fullPage:true});
  assert.equal(beforeWork.state.saves.length,0);
  await beforeWork.page.getByRole('button',{name:'Back',exact:true}).click();
  await beforeWork.page.getByRole('button',{name:'작업 시작',exact:true}).click();
  await beforeWork.page.getByText('질문 1 / 1',{exact:true}).waitFor();
  await beforeWork.page.getByRole('button',{name:'예',exact:true}).click();
  await beforeWork.page.getByText('서버에 작업 결과를 저장했습니다.',{exact:true}).last().waitFor();
  assert.equal(beforeWork.state.saves.length,1);
  assert.equal(JSON.parse(beforeWork.state.saves[0].result_json).filter(row=>row.type==='device_check').length,0);
  console.log('PASS a pre-work graph query is read-only for the work journal and is not silently converted into an in-work check');
  await beforeWork.context.close();
 } catch(error) {console.error(await debugPage.locator('[role]').evaluateAll(nodes=>nodes.map(n=>({role:n.getAttribute('role'),label:n.getAttribute('aria-label'),text:n.innerText?.slice(0,120)})).slice(-55)));throw error;} finally {await browser.close();}
})().catch(async error=>{if(debugPage&&!debugPage.isClosed())console.error(await debugPage.locator('[role]').evaluateAll(nodes=>nodes.map(n=>({role:n.getAttribute('role'),label:n.getAttribute('aria-label'),text:n.innerText?.slice(0,120)})).slice(-55)));console.error(error);process.exit(1)});
