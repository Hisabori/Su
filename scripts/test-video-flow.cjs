// Real HTML5 playback with a local, generated fixture and mocked production APIs.
const {chromium}=require('playwright');
const assert=require('node:assert/strict');
const fs=require('node:fs');
let debugPage;
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',headless:true,args:['--no-sandbox','--disable-dev-shm-usage']});
 const context=await browser.newContext({viewport:{width:390,height:844}});
 await context.addInitScript(()=>{
  window.SpeechSynthesisUtterance=class {constructor(text){this.text=text;}};
  let active;
  Object.defineProperty(window,'speechSynthesis',{configurable:true,value:{getVoices:()=>[{name:'Korean test',lang:'ko-KR'}],addEventListener:()=>{},cancel:()=>{active=null;},speak:u=>{active=u;setTimeout(()=>{if(active!==u)return;u.onstart?.();setTimeout(()=>{if(active===u)u.onend?.();},40);},0);}}});
 });
 let failVideo=true,saves=0;const errors=[];
 await context.route('https://api-suho1004.innaim.com/**',async route=>{
  const req=route.request(),path=new URL(req.url()).pathname;
  const headers={'access-control-allow-origin':'*','access-control-allow-methods':'PUT,GET,OPTIONS','access-control-allow-headers':'content-type,authorization,range'};
  if(req.method()==='OPTIONS')return route.fulfill({status:204,headers});
  if(path.endsWith('/test-video.mp4'))return route.fulfill({status:failVideo?404:200,headers:{...headers,'content-type':'video/mp4'},body:failVideo?'missing':fs.readFileSync('browser-tests/fixtures/work-video.mp4')});
  let reply;
  if(path.endsWith('/login'))reply={ret:1,user_id:42,name:'영상 검증',access_token:'test-only',company_device_name:'partner',kiosk_id:'kiosk'};
  else if(path.endsWith('/validate_token'))reply={ret:1};
  else if(path.endsWith('/work_info'))reply={ret:1,work:{work_id:8,work_name:'영상 검증'},process:{current_version_id:1},steps:[{step_id:1,step_name:'영상',start_ment:'영상을 시청해 주세요.',video_path:'/test-video.mp4',work_seconds:0,display_order:1},{step_id:2,step_name:'확인',start_ment:'영상 확인 완료',work_seconds:0,display_order:2}]};
  else if(path.endsWith('/kiosk_info'))reply={ret:1,kiosks:[{kioskId:'kiosk',name:'검증 기기',currentCapacity:0,maxCapacity:1000,isAvailable:true}]};
  else if(path.endsWith('/work_result')){saves++;reply={ret:1,result_id:99};}
  else throw Error(`Unexpected API: ${path}`);
  return route.fulfill({status:200,headers:{...headers,'content-type':'application/json; charset=utf-8'},body:JSON.stringify(reply)});
 });
 const page=await context.newPage();debugPage=page;page.on('pageerror',e=>errors.push(e.message));
 await page.goto(process.env.PWA_TEST_URL||'http://127.0.0.1:8765/');
 await page.locator('flutter-view').waitFor({timeout:60000});await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());
 await page.locator('input').nth(0).fill('demo');await page.locator('input').nth(1).fill('fake');
 await page.getByRole('button',{name:'로그인',exact:true}).click();
 await page.getByRole('button',{name:'작업 시작',exact:true}).click();
 await page.getByRole('button',{name:'영상 다시 불러오기',exact:true}).waitFor({timeout:30000});
 await page.waitForTimeout(1500);
 assert.equal(await page.getByText('질문 1 / 2',{exact:true}).count(),1);assert.equal(saves,0);
 failVideo=false;
 await page.getByRole('button',{name:'영상 다시 불러오기',exact:true}).click();
 await page.waitForFunction(()=>document.querySelector('video')?.readyState>=2);
 await page.getByRole('button',{name:'재생 / 일시정지',exact:true}).click();
 await page.waitForFunction(()=>!document.querySelector('video').paused);
 await page.getByRole('button',{name:'기기 상태',exact:true}).click();
 await page.getByText('키오스크 현황',{exact:true}).waitFor();
 await page.waitForFunction(()=>document.querySelector('video').paused);
 await page.getByRole('button',{name:'닫기',exact:true}).click();
 assert.equal(await page.evaluate(()=>document.querySelector('video').paused),true);
 await page.getByRole('button',{name:'재생 / 일시정지',exact:true}).click();
 await page.getByText('질문 2 / 2',{exact:true}).waitFor({timeout:15000});
 assert.equal(saves,0);
 await page.getByRole('button',{name:'예',exact:true}).click();
 await page.getByText('서버에 작업 결과를 저장했습니다.',{exact:true}).last().waitFor();
 assert.equal(saves,1);assert.deepEqual(errors,[]);
 console.log('PASS failed video does not skip; retry plays real clip; modal pauses; completion saves once');
 await browser.close();
})().catch(async e=>{
 if(debugPage && process.env.PWA_SCREENSHOT_DIR){
  const base=require('node:path').join(process.env.PWA_SCREENSHOT_DIR,'video-failure');
  await debugPage.screenshot({path:base+'.png'}).catch(()=>{});
  require('node:fs').writeFileSync(base+'.html',await debugPage.content());
 }
 console.error(e);process.exit(1);
});
