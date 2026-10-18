const {chromium}=require('playwright');
const assert=require('node:assert/strict');
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',headless:true,args:['--no-sandbox','--disable-dev-shm-usage']});
 const context=await browser.newContext({viewport:{width:390,height:844}});
 let posts=[],creates=0,deletes=0;const errors=[];
 await context.route('https://suho-angel.vercel.app/api/community',async route=>{
  const req=route.request();const headers={'access-control-allow-origin':'*','access-control-allow-methods':'POST','access-control-allow-headers':'content-type,authorization,x-community-session','content-type':'application/json; charset=utf-8'};
  if(req.method()==='OPTIONS')return route.fulfill({status:204,headers});
  const body=req.postDataJSON();let reply;
  if(body.action==='login')reply={ret:1,user_id:31,name:'정훈',access_token:'community-test-only',community_session:'a'.repeat(64)};
  else {
   assert.equal(req.headers().authorization,'Bearer community-test-only');assert.equal(req.headers()['x-community-session'],'a'.repeat(64));
   if(body.action==='list')reply={posts,me:{name:'정훈'},cursor:null};
   else if(body.action==='create'){creates++;assert.equal(body.author,undefined);assert.equal(body.user_id,undefined);posts=[{id:body.id,title:body.title,body:body.body,author:'정훈',mine:true,createdAt:Date.now()}];reply={post:posts[0]};}
   else if(body.action==='delete'){deletes++;posts=[];reply={deleted:true};}
   else throw Error('Unexpected action '+body.action);
  }
  return route.fulfill({status:200,headers,body:JSON.stringify(reply)});
 });
 await context.route('https://api-suho1004.innaim.com/**',async route=>{
  const headers={'access-control-allow-origin':'*','access-control-allow-methods':'PUT','access-control-allow-headers':'content-type,authorization','content-type':'application/json'};
  if(route.request().method()==='OPTIONS')return route.fulfill({status:204,headers});
  const path=new URL(route.request().url()).pathname;
  let reply;
  if(path.endsWith('/validate_token'))reply={ret:1};
  else if(path.endsWith('/work_info'))reply={ret:1,work:{work_id:8,work_name:'커뮤니티 검증'},process:{current_version_id:1},steps:[{step_id:1,step_name:'확인',start_ment:'첫 확인',work_seconds:0}]};
  else throw Error('Unexpected work API '+path);
  return route.fulfill({status:200,headers,body:JSON.stringify(reply)});
 });
 const page=await context.newPage();page.on('pageerror',e=>errors.push(e.message));
 async function ready(){await page.locator('flutter-view').waitFor({timeout:60000});await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());}
 await page.goto(process.env.PWA_TEST_URL||'http://127.0.0.1:8765/');await ready();
 await page.locator('input').nth(0).fill('cesco999');await page.locator('input').nth(1).fill('fake');
 await page.getByRole('button',{name:'로그인',exact:true}).click();
 await page.getByRole('button',{name:'커뮤니티',exact:true}).click();
 await page.getByText('정훈 님, 오늘의 이야기를 들려주세요.',{exact:true}).waitFor();
 await page.getByText('아직 이야기가 없어요.',{exact:true}).waitFor();
 await page.getByRole('button',{name:'글쓰기',exact:true}).click();
 await page.getByText('작성자 · 정훈',{exact:true}).waitFor();
 await page.locator('input').fill('오늘의 이야기');await page.locator('textarea').fill('함께 나눌 내용입니다.');
 await page.getByRole('button',{name:'글 등록',exact:true}).click();
 await page.getByText('오늘의 이야기',{exact:true}).or(page.getByRole('group',{name:/오늘의 이야기/})).last().waitFor();
 assert.equal(creates,1);
 if(process.env.PWA_SCREENSHOT_DIR)await page.screenshot({path:require('node:path').join(process.env.PWA_SCREENSHOT_DIR,'community-classic.png')});
 await page.reload();await ready();
 await page.getByRole('button',{name:'커뮤니티',exact:true}).click();
 await page.getByText('오늘의 이야기',{exact:true}).or(page.getByRole('group',{name:/오늘의 이야기/})).last().waitFor();
 await page.getByRole('button',{name:'내 글 삭제',exact:true}).click();
 await page.getByRole('button',{name:'삭제',exact:true}).click();
 await page.getByText('아직 이야기가 없어요.',{exact:true}).waitFor();
 assert.equal(deletes,1);assert.deepEqual(errors,[]);
 console.log('PASS community author follows authenticated numeric identity, not username suffix; create/reload/delete');
 await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
