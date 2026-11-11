const {chromium}=require('playwright');
const assert=require('node:assert/strict');
let debugPage;
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',headless:true,args:['--no-sandbox','--disable-dev-shm-usage']});
 const now=Date.now(),errors=[];
 const row=(at,current)=>({partner:'partner',kiosk:'pet',name:'공유 수거기',at:new Date(at).toISOString(),current,capacity:1000,available:true,error:null,error_code:null});
 const older=row(now-1200000,100),previous=row(now-600000,200);
 let latest;
 async function open(user){
  const context=await browser.newContext({viewport:{width:430,height:932}});
  const headers={'access-control-allow-origin':'*','access-control-allow-methods':'POST, PUT, OPTIONS','access-control-allow-headers':'content-type,authorization,x-community-session,x-diagnostic-trace','content-type':'application/json; charset=utf-8'};
  await context.route('https://suho-angel.vercel.app/api/community',async route=>{
   if(route.request().method()==='OPTIONS')return route.fulfill({status:204,headers});
   const body=route.request().postDataJSON();let reply;
   if(body.action==='login')reply={ret:1,user_id:user,name:'서버 사용자',access_token:'fixture',community_session:'a'.repeat(64),company_device_name:'partner',kiosk_id:'pet',device_history_enabled:true};
   else if(body.action==='device_sample'){latest??=row(Date.now(),250);reply={reading:latest,cached:true};}
   else if(body.action==='device_history')reply=body.cursor?{records:[older],cursor:null}:{records:[previous,...(latest?[latest]:[])],cursor:'older'};
   else throw Error('Unexpected cloud action '+body.action);
   return route.fulfill({status:200,headers,body:JSON.stringify(reply)});
  });
  await context.route('https://api-suho1004.innaim.com/**',async route=>{
   if(route.request().method()==='OPTIONS')return route.fulfill({status:204,headers});
   const path=new URL(route.request().url()).pathname;let reply;
   if(path.endsWith('/validate_token'))reply={ret:1};
   else if(path.endsWith('/work_info'))reply={ret:1,work:{work_id:8,work_name:'서버 공유 검증'},process:{current_version_id:1},steps:[{step_id:1,step_name:'확인',start_ment:'확인',work_seconds:0}]};
   else if(path.endsWith('/kiosk_info'))reply={ret:1,kiosks:[{kioskId:'pet',name:'공유 수거기',currentCapacity:250,maxCapacity:1000,isAvailable:true}]};
   else throw Error('Unexpected cloud API '+path);
   return route.fulfill({status:200,headers,body:JSON.stringify(reply)});
  });
  const page=await context.newPage();debugPage=page;page.on('pageerror',e=>errors.push(e.message));
  await page.goto(process.env.PWA_TEST_URL||'http://127.0.0.1:8765/');
  await page.locator('flutter-view').waitFor({timeout:60000});await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());
  for(const [i,value] of [[0,'fixture'+user],[1,'fake']]){
   await page.locator('input').nth(i).click();await page.waitForTimeout(200);await page.keyboard.type(value,{delay:40});await page.keyboard.press('Tab');await page.waitForTimeout(150);
  }
  await page.getByRole('button',{name:'로그인',exact:true}).click();
  await page.getByText('안녕하세요!',{exact:true}).waitFor();await page.waitForTimeout(1600);
  await page.getByRole('button',{name:'기기 상태',exact:true}).click();
  await page.getByText(/^서버 공유 기록/).waitFor();
  await page.getByRole('img',{name:/유효한 측정 2회/}).waitFor();
  return {context,page};
 }
 const first=await open(31);await first.context.close();
 // A completely fresh browser/account has no local history from the first one.
 const second=await open(42),page=second.page;
 await page.mouse.move(200,700);await page.mouse.wheel(0,650);await page.waitForTimeout(500);
 await page.getByRole('button',{name:'이전 서버 기록 불러오기',exact:true}).click();
 await page.getByText('유효 측정 3회 · 미확인 0회',{exact:true}).waitFor();
 await page.getByText('18.3%',{exact:true}).waitFor();
 assert.deepEqual(errors,[]);
 if(process.env.PWA_SCREENSHOT_DIR)await page.screenshot({path:require('node:path').join(process.env.PWA_SCREENSHOT_DIR,'collector-shared-history.png')});
 console.log('PASS independent clients share server history, assigned identity and older-page summary');
 await browser.close();
})().catch(async error=>{if(debugPage)console.error('CLOUD NODES',await debugPage.locator('[role]').evaluateAll(nodes=>nodes.map(n=>({role:n.getAttribute('role'),label:n.getAttribute('aria-label')})).slice(-70)));console.error(error);process.exit(1)});
