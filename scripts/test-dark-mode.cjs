// Mocked API only. Checks persisted theme choice across login and graph navigation.
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',headless:true,args:['--no-sandbox','--disable-dev-shm-usage']});
 try {
  const context=await browser.newContext({viewport:{width:430,height:932},colorScheme:'dark'});
  await context.route('https://suho-angel.vercel.app/api/community',r=>r.fulfill({status:503,headers:{'access-control-allow-origin':'*'},body:'fixture offline'}));
  await context.route('https://api-suho1004.innaim.com/**',async route=>{
   const path=new URL(route.request().url()).pathname;
   const headers={'content-type':'application/json','access-control-allow-origin':'*','access-control-allow-methods':'PUT','access-control-allow-headers':'authorization,content-type'};
   if(route.request().method()==='OPTIONS')return route.fulfill({status:204,headers});
   let data;
   if(path.endsWith('/login'))data={ret:1,user_id:31,name:'테마 검증',access_token:'theme-fixture-only',company_device_name:'partner',kiosk_id:'pet'};
   else if(path.endsWith('/validate_token'))data={ret:1};
   else if(path.endsWith('/work_info'))data={ret:1,work:{work_id:8,work_name:'테마 확인'},process:{current_version_id:1},steps:[{step_id:1,step_name:'확인',work_seconds:0}]};
   else if(path.endsWith('/kiosk_info'))data={ret:1,kiosks:[{kioskId:'pet',name:'수거기',currentCapacity:250,maxCapacity:1000,isAvailable:true}]};
   else throw Error('Unexpected API '+path);
   await route.fulfill({status:200,headers,body:JSON.stringify(data)});
  });
  const page=await context.newPage(),errors=[];page.on('pageerror',e=>errors.push(e.message));
  async function ready(){await page.locator('flutter-view').waitFor({timeout:60000});await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());}
  await page.goto(process.env.PWA_TEST_URL||'http://127.0.0.1:8765/');await ready();
  await page.mouse.move(210,650);await page.mouse.wheel(0,700);await page.waitForTimeout(400);
  await page.getByText('시스템',{exact:true}).click();await page.getByText('다크',{exact:true}).last().click();await page.waitForTimeout(400);
  await page.reload();await ready();
  await page.mouse.move(210,650);await page.mouse.wheel(0,700);await page.waitForTimeout(400);
  await page.getByText('다크',{exact:true}).waitFor();
  await page.getByText('다크',{exact:true}).click();await page.getByText('라이트',{exact:true}).last().click();await page.waitForTimeout(400);
  await page.getByText('라이트',{exact:true}).click();await page.getByText('다크',{exact:true}).last().click();await page.waitForTimeout(400);
  await page.mouse.wheel(0,-900);await page.waitForTimeout(300);
  for(const [index,value] of ['demo','fake'].entries()){
   const input=page.locator('input').nth(index);await input.click();await page.waitForTimeout(200);await page.keyboard.type(value,{delay:40});await page.keyboard.press('Tab');await page.waitForTimeout(150);assert.equal(await input.inputValue(),value);
  }
  await page.getByRole('button',{name:'로그인',exact:true}).click();await page.getByText('안녕하세요!',{exact:true}).waitFor();
  await page.getByRole('button',{name:'기기 상태',exact:true}).click();await page.getByRole('img',{name:/페트병 수거기 적재율 추이 그래프/}).waitFor();
  if(process.env.PWA_SCREENSHOT_DIR)await page.screenshot({path:require('node:path').join(process.env.PWA_SCREENSHOT_DIR,'dark-collector.png')});
  await page.getByRole('button',{name:'Back',exact:true}).click();await page.getByText('안녕하세요!',{exact:true}).waitFor();
  assert.deepEqual(errors,[]);
  console.log('PASS dark mode selection persists across reload, light/dark switching and authenticated graph navigation');
 } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
