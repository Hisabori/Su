// Run after serving build/web; requires playwright and a Chromium executable.
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH || '/usr/bin/chromium',headless:true,args:['--no-sandbox','--disable-dev-shm-usage']});
 const context=await browser.newContext({viewport:{width:390,height:844}});
 const errors=[], calls=[];let saves=0;
 await context.route('https://api-suho1004.innaim.com/**',async route=>{
  const req=route.request();const path=new URL(req.url()).pathname;
  if(req.method()==='OPTIONS') return route.fulfill({status:204,headers:{'access-control-allow-origin':'*','access-control-allow-methods':'PUT','access-control-allow-headers':'content-type,authorization'}});
  const body=req.postDataJSON();calls.push({path,method:req.method(),body});
  let reply;
  if(path.endsWith('/login')) reply={ret:1,user_id:42,access_token:'browser-test-only'};
  else if(path.endsWith('/validate_token')) reply={ret:1};
  else if(path.endsWith('/work_info')) reply={ret:1,work:{work_id:8,work_name:'검증 업무'},process:{current_version_id:1},steps:[{step_id:1,step_name:'첫 단계',start_ment:'첫 번째 확인',work_seconds:0,display_order:1},{step_id:2,step_name:'두 번째 단계',start_ment:'두 번째 확인',work_seconds:0,display_order:2}]};
  else if(path.endsWith('/work_result')) {saves++;reply={ret:1,result_id:99};}
  else if(path.endsWith('/logout')) reply={ret:1};
  else throw Error(`Unexpected API: ${path}`);
  await route.fulfill({status:200,headers:{'content-type':'application/json; charset=utf-8','access-control-allow-origin':'*'},body:JSON.stringify(reply)});
 });
 const page=await context.newPage();page.on('pageerror',e=>errors.push(e.message));
 async function ready(){await page.locator('flutter-view').waitFor({timeout:60000});await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());}
 await page.goto(process.env.PWA_TEST_URL || 'http://127.0.0.1:8765/');await ready();
 await page.locator('input').nth(0).click();await page.keyboard.type('demo');
 await page.locator('input').nth(1).click();await page.keyboard.type('fake-password');
 await page.getByRole('button',{name:'로그인',exact:true}).click();

 await page.getByRole('button',{name:'작업 시작',exact:true}).click();
 await page.getByRole('button',{name:'네',exact:true}).click();
 await page.getByText('두 번째 확인',{exact:true}).waitFor();
 await page.reload();await ready();
 await page.getByText('두 번째 확인',{exact:true}).waitFor({timeout:30000});
 console.log('PASS refresh restores step 2 with previous answer');
 await page.getByRole('button',{name:'네',exact:true}).click();
 await page.getByText('서버에 작업 결과를 저장했습니다.',{exact:true}).waitFor();
 assert.equal(saves,1);
 const result=calls.find(c=>c.path.endsWith('/work_result'));
 assert.equal(result.method,'PUT');assert.equal(JSON.parse(result.body.result_json).length,2);
 assert.equal(JSON.parse(result.body.result_json)[0]['비고'],1);
 await page.getByRole('button',{name:'작업 기록 보기',exact:true}).click();
 await page.getByText('서버 저장 완료',{exact:false}).waitFor();
 assert.equal(await page.getByRole('button',{name:'결과 재전송'}).count(),0);
 console.log('PASS result acknowledged once; history has no retry');

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
})().catch(e=>{console.error(e);process.exit(1)});
