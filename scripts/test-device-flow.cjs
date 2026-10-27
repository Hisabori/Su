const {chromium}=require('playwright');
const assert=require('node:assert/strict');
let debugPage;
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',headless:true,args:['--no-sandbox','--disable-dev-shm-usage']});
 const context=await browser.newContext({viewport:{width:390,height:844}});
 let current=250,calls=0;const errors=[];
 await context.route('https://suho-angel.vercel.app/api/community',route=>route.fulfill({status:503,headers:{'access-control-allow-origin':'*'},body:'fixture offline'}));
 await context.route('https://api-suho1004.innaim.com/**',async route=>{
  const req=route.request(),path=new URL(req.url()).pathname;
  const headers={'access-control-allow-origin':'*','access-control-allow-methods':'PUT','access-control-allow-headers':'content-type,authorization','content-type':'application/json; charset=utf-8'};
  if(req.method()==='OPTIONS')return route.fulfill({status:204,headers});
  let reply;
  if(path.endsWith('/login'))reply={ret:1,user_id:31,name:'정훈',access_token:'device-test-only',company_device_name:'partner',kiosk_id:'pet'};
  else if(path.endsWith('/validate_token'))reply={ret:1};
  else if(path.endsWith('/work_info'))reply={ret:1,work:{work_id:8,work_name:'적재율 검증'},process:{current_version_id:1},steps:[{step_id:1,step_name:'확인',start_ment:'확인',work_seconds:0}]};
  else if(path.endsWith('/kiosk_info')){calls++;reply={ret:1,kiosks:[{kioskId:'pet',name:'수호천사05',currentCapacity:current,maxCapacity:1000,isAvailable:true}]};}
  else throw Error('Unexpected API '+path);
  return route.fulfill({status:200,headers,body:JSON.stringify(reply)});
 });
 const page=await context.newPage();debugPage=page;page.on('pageerror',e=>errors.push(e.message));
 await page.goto(process.env.PWA_TEST_URL||'http://127.0.0.1:8765/');
 await page.locator('flutter-view').waitFor({timeout:60000});await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());
 await page.locator('input').nth(0).click();await page.waitForTimeout(200);await page.keyboard.type('demo',{delay:40});await page.keyboard.press('Tab');await page.waitForTimeout(150);assert.equal(await page.locator('input').nth(0).inputValue(),'demo');
 await page.locator('input').nth(1).click();await page.waitForTimeout(200);await page.keyboard.type('fake',{delay:40});await page.keyboard.press('Tab');await page.waitForTimeout(150);assert.equal(await page.locator('input').nth(1).inputValue(),'fake');
 await page.getByRole('button',{name:'로그인',exact:true}).click();
 await page.getByText('안녕하세요!',{exact:true}).waitFor();
 // Allow the first foreground baseline to finish before opening the history.
 await page.waitForTimeout(1800);assert.equal(calls,1);
 await page.getByRole('button',{name:'기기 상태',exact:true}).click();
 await page.getByText('수거기 적재율 기록',{exact:true}).waitFor();
 await page.getByText('25.0%',{exact:true}).last().waitFor();
 const graph=page.getByRole('img',{name:/페트병 수거기 적재율 추이 그래프/});await graph.waitFor();
 assert.ok((await graph.boundingBox()).y<400);
 await page.getByRole('checkbox',{name:'7일',exact:true}).click();
 const baseline=calls,baseTime=await page.evaluate(()=>Date.now());
 current=500;await page.clock.setFixedTime(new Date(baseTime+10*60*1000));
 await page.getByText('50.0%',{exact:true}).last().waitFor();assert.equal(calls,baseline+1);
 current=750;await page.clock.setFixedTime(new Date(baseTime+40*60*1000));
 await page.getByText('75.0%',{exact:true}).last().waitFor();assert.equal(calls,baseline+2);
 await page.getByText('조회 기록 3회',{exact:true}).waitFor();
 assert.deepEqual(errors,[]);
 if(process.env.PWA_SCREENSHOT_DIR)await page.screenshot({path:require('node:path').join(process.env.PWA_SCREENSHOT_DIR,'pet-capacity-history.png')});
 console.log('PASS PET capacity baseline, ten-minute polling, chronological history and no invented gap samples');
 await browser.close();
})().catch(async e=>{if(debugPage)console.error('ACCESSIBLE NODES',await debugPage.locator('[role]').evaluateAll(nodes=>nodes.map(n=>({role:n.getAttribute('role'),label:n.getAttribute('aria-label'),text:n.innerText?.slice(0,250)})).slice(-50)));console.error(e);process.exit(1)});
