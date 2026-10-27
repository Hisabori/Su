const {chromium}=require('playwright');
const assert=require('node:assert/strict');
let debugPage;
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',headless:true,args:['--no-sandbox','--disable-dev-shm-usage']});
 const context=await browser.newContext({viewport:{width:390,height:844}});
 let logins=0,validations=0,workLoads=0,expired=false,offline=false,logouts=0;
 const errors=[];
 await context.route('https://suho-angel.vercel.app/api/community',route=>route.fulfill({status:503,headers:{'access-control-allow-origin':'*'},body:'fixture unavailable'}));
 await context.route('https://api-suho1004.innaim.com/**',async route=>{
  const req=route.request(),path=new URL(req.url()).pathname;
  const headers={'access-control-allow-origin':'*','access-control-allow-methods':'PUT','access-control-allow-headers':'content-type,authorization','content-type':'application/json; charset=utf-8'};
  if(req.method()==='OPTIONS')return route.fulfill({status:204,headers});
  let reply;
  if(path.endsWith('/login')){logins++;reply={ret:1,user_id:31,name:'서버 이름',access_token:'auto-login-fixture'};}
  else if(path.endsWith('/validate_token')){
   validations++;assert.equal(req.headers().authorization,'Bearer auto-login-fixture');
   const data=req.postDataJSON();assert.equal(data.token,'auto-login-fixture');assert.equal(data.password,undefined);
   if(offline)return route.fulfill({status:503,headers,body:'{}'});
   reply={ret:expired?0:1};
  }
  else if(path.endsWith('/work_info')){workLoads++;reply={ret:1,work:{work_id:8,work_name:'자동 로그인 검증'},process:{current_version_id:1},steps:[{step_id:1,step_name:'확인',start_ment:'확인',work_seconds:0}]};}
  else if(path.endsWith('/logout')){logouts++;reply={ret:1};}
  else throw Error('Unexpected API '+path);
  return route.fulfill({status:200,headers,body:JSON.stringify(reply)});
 });
 const page=await context.newPage();debugPage=page;page.on('pageerror',e=>errors.push(e.message));
 async function ready(){await page.locator('flutter-view').waitFor({timeout:60000});await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());}
 async function reload(){await page.reload();await ready();}
 async function login(){
  for(const [i,value] of ['demo','fake'].entries()){
   const input=page.locator('input').nth(i);await input.click();await page.waitForTimeout(200);await page.keyboard.press('ControlOrMeta+A');await page.keyboard.type(value,{delay:40});await page.keyboard.press('Tab');await page.waitForTimeout(150);assert.equal(await input.inputValue(),value);
  }
  await page.getByRole('button',{name:'로그인',exact:true}).click();await page.getByText('안녕하세요!',{exact:true}).waitFor();
 }
 await page.goto(process.env.PWA_TEST_URL||'http://127.0.0.1:8765/');await ready();
 const checkbox=()=>page.getByRole('checkbox',{name:/자동 로그인/});
 await checkbox().waitFor();assert.equal(await checkbox().getAttribute('aria-checked'),'true');
 await login();assert.equal(logins,1);
 await reload();await page.getByText('안녕하세요!',{exact:true}).waitFor();assert.equal(logins,1);assert.equal(validations,1);
 offline=true;await reload();await page.getByRole('button',{name:'자동 로그인 다시 시도',exact:true}).waitFor();
 offline=false;await page.getByRole('button',{name:'자동 로그인 다시 시도',exact:true}).click();await page.getByText('안녕하세요!',{exact:true}).waitFor();assert.equal(logins,1);
 expired=true;await reload();await page.getByText('저장된 로그인이 만료되었습니다. 다시 로그인해 주세요.',{exact:true}).last().waitFor();
 expired=false;const afterExpired=validations;await reload();await checkbox().waitFor();assert.equal(validations,afterExpired);
 await checkbox().click();await page.waitForTimeout(250);assert.equal(await checkbox().getAttribute('aria-checked'),'false');
 await login();const offWork=workLoads,offValidations=validations;await reload();await checkbox().waitFor();assert.equal(await checkbox().getAttribute('aria-checked'),'false');assert.equal(workLoads,offWork);assert.equal(validations,offValidations);
 await checkbox().click();await page.waitForTimeout(250);await login();
 await page.getByRole('button',{name:'로그아웃',exact:true}).click();await page.getByRole('button',{name:'로그인',exact:true}).waitFor();
 const afterLogout=validations;await reload();await checkbox().waitFor();assert.equal(validations,afterLogout);assert.equal(logouts,1);assert.equal(logins,3);
 assert.deepEqual(errors,[]);
 console.log('PASS automatic login validates saved sessions without passwords, retries transient failures, clears expired sessions, honors opt-out and logout');
 await browser.close();
})().catch(async e=>{if(debugPage)console.error('ACCESSIBLE NODES',await debugPage.locator('[role]').evaluateAll(nodes=>nodes.map(n=>({role:n.getAttribute('role'),label:n.getAttribute('aria-label'),text:n.innerText?.slice(0,220)})).slice(-40)));console.error(e);process.exit(1);});
