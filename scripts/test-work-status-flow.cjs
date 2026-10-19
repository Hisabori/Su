const {chromium}=require('playwright');
const assert=require('node:assert/strict');
let debugPage;
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',headless:true,args:['--no-sandbox','--disable-dev-shm-usage']});
 const context=await browser.newContext({viewport:{width:390,height:844}});
 let calls=0,available=false,submissions=0;const errors=[];
 await context.route('https://suho-angel.vercel.app/api/community',route=>route.fulfill({status:503,headers:{'access-control-allow-origin':'*'},body:'fixture offline'}));
 await context.route('https://api-suho1004.innaim.com/**',async route=>{
  const req=route.request(),path=new URL(req.url()).pathname;
  const headers={'access-control-allow-origin':'*','access-control-allow-methods':'PUT','access-control-allow-headers':'content-type,authorization','content-type':'application/json; charset=utf-8'};
  if(req.method()==='OPTIONS')return route.fulfill({status:204,headers});
  let reply;
  if(path.endsWith('/login'))reply={ret:1,user_id:31,name:'정훈',access_token:'device-test-only',company_device_name:'partner',kiosk_id:'pet'};
  else if(path.endsWith('/validate_token'))reply={ret:1};
  else if(path.endsWith('/work_info'))reply=available ?{ret:1,work:{work_id:8,work_name:'적재율 검증'},process:{current_version_id:1},steps:[{step_id:1,step_name:'확인',start_ment:'확인',work_seconds:0}]} : {ret:7};
  else if(path.endsWith('/kiosk_info')){calls++;reply={ret:1,kiosks:[{kioskId:'pet',name:'수호천사05',currentCapacity:250,maxCapacity:1000,isAvailable:true}]};}
  else if(path.endsWith('/work_result')){submissions++;throw Error('Status must not submit work');}
  else throw Error('Unexpected API '+path);
  return route.fulfill({status:200,headers,body:JSON.stringify(reply)});
 });
 const page=await context.newPage();debugPage=page;page.on('pageerror',e=>errors.push(e.message));
 await page.goto(process.env.PWA_TEST_URL||'http://127.0.0.1:8765/');
 await page.locator('flutter-view').waitFor({timeout:60000});await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());
 await page.locator('input').nth(0).click();await page.keyboard.type('demo');
 await page.locator('input').nth(1).click();await page.keyboard.type('fake');
 await page.getByRole('button',{name:'로그인',exact:true}).click();
 await page.getByText('근무 상태 안내',{exact:true}).waitFor();
 await page.getByText('정훈 님',{exact:true}).waitFor();
 assert.equal(await page.getByText('서버에서 요청을 거절했습니다.',{exact:false}).count(),0);
 assert.equal(await page.getByRole('button',{name:'작업 시작',exact:true}).count(),0);
 await page.getByRole('button',{name:'근무기록 자세히 보기',exact:true}).click();
 await page.getByText('오늘의 근무 기록',{exact:true}).waitFor();
 await page.getByRole('button',{name:'Back',exact:true}).click();
 await page.getByText('근무 상태 안내',{exact:true}).waitFor();
 available=true;
 await page.getByRole('button',{name:'근무 상태 다시 확인',exact:true}).click();
 await page.getByText('안녕하세요!',{exact:true}).waitFor();
 assert.equal(submissions,0);
 assert.deepEqual(errors,[]);
 if(process.env.PWA_SCREENSHOT_DIR)await page.screenshot({path:require('node:path').join(process.env.PWA_SCREENSHOT_DIR,'work-status-7-recovery.png')});
 console.log('PASS work_info ret=7 status, accessible history, explicit retry recovery and no invented work result');
 await browser.close();
})().catch(async e=>{if(debugPage)console.error('ACCESSIBLE NODES',await debugPage.locator('[role]').evaluateAll(nodes=>nodes.map(n=>({role:n.getAttribute('role'),label:n.getAttribute('aria-label'),text:n.innerText?.slice(0,250)})).slice(-50)));console.error(e);process.exit(1)});
