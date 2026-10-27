const {chromium}=require('playwright');
const assert=require('node:assert/strict');
let debugPage;const requests=[];
(async()=>{
 const browser=await chromium.launch({executablePath:process.env.CHROMIUM_PATH||'/usr/bin/chromium',headless:true,args:['--no-sandbox','--disable-dev-shm-usage']});
 const context=await browser.newContext({viewport:{width:390,height:844}});
 let posts=[],comments=[],liked=false,pinned=false,hidden=false,reports=[],creates=0,deletes=0;const errors=[];
 await context.route('https://suho-angel.vercel.app/api/community',async route=>{
  const req=route.request();const headers={'access-control-allow-origin':'*','access-control-allow-methods':'POST','access-control-allow-headers':'content-type,authorization,x-community-session','content-type':'application/json; charset=utf-8'};
  if(req.method()==='OPTIONS')return route.fulfill({status:204,headers});
  const body=req.postDataJSON();requests.push({action:body.action});let reply;
  if(body.action==='login')reply={ret:1,user_id:31,name:'정훈',access_token:'community-test-only',community_session:'a'.repeat(64)};
  else {
   assert.equal(req.headers().authorization,'Bearer community-test-only');assert.equal(req.headers()['x-community-session'],'a'.repeat(64));
   if(body.action==='list')reply={posts:posts.map(({image,...p})=>({...p,hasImage:!!image,pinned})),me:{name:'정훈',isAdmin:true},cursor:null};
   else if(body.action==='create'){assert.equal(body.title,'오늘의 이야기');assert.equal(body.body,'함께 나눌 내용입니다.');creates++;assert.equal(body.author,undefined);assert.equal(body.user_id,undefined);assert.equal(body.image.mime,'image/jpeg');assert.ok(body.image.data.length<699052);posts=[{id:body.id,title:body.title,body:body.body,author:'정훈',mine:true,createdAt:Date.now(),image:body.image}];reply={post:posts[0]};}
   else if(body.action==='detail')reply={post:{...posts[0],pinned,hidden},comments,cursor:null,liked,likes:liked?1:0,isAdmin:true};
   else if(body.action==='edit'){assert.equal(body.author,undefined);posts[0]={...posts[0],title:body.title,body:body.body,updatedAt:Date.now()};reply={saved:true};}
   else if(body.action==='comment_edit'){comments[0]={...comments[0],body:body.body,updatedAt:Date.now()};reply={saved:true};}
   else if(body.action==='comment_create'){assert.equal(body.body,'응원합니다.');assert.equal(body.author,undefined);comments=[{id:body.commentId,body:body.body,author:'정훈',createdAt:Date.now(),mine:true}];reply={saved:true};}
   else if(body.action==='comment_delete'){comments=[];reply={deleted:true};}
   else if(body.action==='like'){liked=body.liked;reply={liked,likes:liked?1:0};}
   else if(body.action==='pin'){pinned=body.enabled;reply={saved:true};}
   else if(body.action==='hide'){hidden=body.enabled;reply={saved:true};}
   else if(body.action==='report'){reports=[{key:'a'.repeat(64)+'-31.json',postId:posts[0].id,reporter:'정훈',reason:body.reason,createdAt:Date.now()}];reply={reported:true};}
   else if(body.action==='reports')reply={reports,cursor:null};
   else if(body.action==='report_resolve'){reports=[];reply={resolved:true};}
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
 const page=await context.newPage();debugPage=page;page.on('pageerror',e=>errors.push(e.message));
 async function ready(){await page.locator('flutter-view').waitFor({timeout:60000});await page.evaluate(()=>document.querySelector('flt-semantics-placeholder')?.click());}
 await page.goto(process.env.PWA_TEST_URL||'http://127.0.0.1:8765/');await ready();
 await page.getByRole('button',{name:'레거시 모드 켜기',exact:true}).waitFor();
 if(process.env.PWA_SCREENSHOT_DIR)await page.screenshot({path:require('node:path').join(process.env.PWA_SCREENSHOT_DIR,'glass-login.png')});
 await page.locator('input').nth(0).click();await page.waitForTimeout(200);await page.keyboard.type('cesco999',{delay:40});await page.keyboard.press('Tab');await page.waitForTimeout(150);assert.equal(await page.locator('input').nth(0).inputValue(),'cesco999');
 await page.locator('input').nth(1).click();await page.waitForTimeout(200);await page.keyboard.type('fake',{delay:40});await page.keyboard.press('Tab');await page.waitForTimeout(150);assert.equal(await page.locator('input').nth(1).inputValue(),'fake');
 await page.getByRole('button',{name:'로그인',exact:true}).click();
 await page.getByText('안녕하세요!',{exact:true}).waitFor();
 await page.getByRole('button',{name:'동료 이야기',exact:true}).click();
 await page.getByText('정훈 님, 오늘의 이야기를 들려주세요.',{exact:true}).waitFor();
 await page.getByText('아직 이야기가 없어요.',{exact:false}).waitFor();
 await page.getByRole('button',{name:'글쓰기',exact:true}).click();
 await page.getByText('작성자 · 정훈',{exact:true}).waitFor();await page.waitForTimeout(400);
 await page.locator('input').click();await page.waitForTimeout(250);await page.keyboard.insertText('오늘의 이야기');await page.keyboard.press('Tab');await page.waitForTimeout(200);assert.equal(await page.locator('input').inputValue(),'오늘의 이야기');
 await page.locator('textarea').click();await page.waitForTimeout(250);await page.keyboard.insertText('함께 나눌 내용입니다.');await page.keyboard.press('Tab');await page.waitForTimeout(200);assert.equal(await page.locator('textarea').inputValue(),'함께 나눌 내용입니다.');
 await page.getByRole('button',{name:'제목·내용 임시저장',exact:true}).click();
 await page.getByText('제목·내용 임시저장됨 · 사진은 제외',{exact:true}).waitFor();
 await page.getByRole('button',{name:'Back',exact:true}).click();
 await page.getByRole('button',{name:'글쓰기',exact:true}).click();
 await page.getByText('임시저장한 글을 불러왔습니다.',{exact:true}).waitFor();await page.waitForTimeout(400);
 await page.locator('input').click();await page.waitForTimeout(200);
 assert.equal(await page.locator('input').inputValue(),'오늘의 이야기');
 await page.locator('textarea').click();await page.waitForTimeout(200);
 assert.equal(await page.locator('textarea').inputValue(),'함께 나눌 내용입니다.');await page.keyboard.press('Tab');
 const chooserPromise=page.waitForEvent('filechooser');
 await page.getByRole('button',{name:'사진 첨부',exact:true}).click();
 const chooser=await chooserPromise;
 await chooser.setFiles({name:'pixel.png',mimeType:'image/png',buffer:Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a9WQAAAAASUVORK5CYII=','base64')});
 await page.getByText('사진 1장 · 최대 512KB · 위치 정보 없이 전송',{exact:true}).waitFor();
 await page.getByRole('button',{name:'글 등록',exact:true}).click();
 await page.getByText('오늘의 이야기',{exact:true}).or(page.getByRole('group',{name:/오늘의 이야기/})).or(page.getByLabel(/오늘의 이야기/)).last().waitFor();
 assert.equal(creates,1);
 if(process.env.PWA_SCREENSHOT_DIR)await page.screenshot({path:require('node:path').join(process.env.PWA_SCREENSHOT_DIR,'community-glass.png')});
 await page.reload();await ready();
 await page.getByRole('button',{name:'커뮤니티',exact:true}).click();
 await page.getByText('오늘의 이야기',{exact:true}).or(page.getByRole('group',{name:/오늘의 이야기/})).or(page.getByLabel(/오늘의 이야기/)).last().waitFor();
 // Search is deliberately scoped to the posts already loaded.
 await page.locator('input').click();await page.waitForTimeout(200);await page.keyboard.insertText('없는 검색어');
 await page.getByText('검색 조건에 맞는 글이 없어요. 이전 글도 불러와 보세요.',{exact:true}).waitFor();
 await page.getByRole('button',{name:'검색 지우기',exact:true}).click();
 await page.locator('input').click();await page.waitForTimeout(200);
 assert.equal(await page.locator('input').inputValue(),'');
 await page.getByRole('button',{name:'댓글 · 좋아요',exact:true}).click();
 await page.getByRole('img',{name:'첨부 사진',exact:true}).waitFor();
 await page.getByRole('button',{name:'내 글 수정',exact:true}).click();
 await page.getByText('이야기 수정',{exact:true}).waitFor();await page.waitForTimeout(400);
 await page.locator('input').click();await page.waitForTimeout(200);await page.keyboard.press('ControlOrMeta+A');await page.keyboard.insertText('수정한 이야기');await page.keyboard.press('Tab');
 await page.getByRole('button',{name:'수정 저장',exact:true}).click();
 await page.getByText('수정한 이야기',{exact:true}).waitFor();
 await page.getByRole('button',{name:'좋아요 0',exact:true}).click();
 await page.getByRole('button',{name:'좋아요 취소 1',exact:true}).waitFor();
 await page.locator('textarea').click();await page.waitForTimeout(200);await page.keyboard.insertText('응원합니다.');
 await page.getByRole('button',{name:'댓글 등록',exact:true}).click();
 await page.getByText('응원합니다.',{exact:true}).waitFor();
 await page.getByRole('button',{name:'댓글 수정',exact:true}).click();
 await page.locator('textarea').last().click();await page.waitForTimeout(200);await page.keyboard.press('ControlOrMeta+A');await page.keyboard.insertText('수정 응원합니다.');await page.keyboard.press('Tab');
 await page.getByRole('button',{name:'댓글 수정 저장',exact:true}).click();
 await page.getByText('수정 응원합니다.',{exact:true}).waitFor();
 await page.getByRole('button',{name:'공지로 등록',exact:true}).click();
 await page.getByRole('button',{name:'공지 해제',exact:true}).waitFor();
 await page.getByRole('button',{name:'글 숨기기',exact:true}).click();
 await page.getByRole('button',{name:'글 다시 공개',exact:true}).waitFor();
 await page.getByRole('button',{name:'글 다시 공개',exact:true}).click();
 await page.getByRole('button',{name:'글 숨기기',exact:true}).waitFor();
 await page.getByRole('button',{name:'신고하기',exact:true}).click();
 await page.locator('textarea').last().click();await page.waitForTimeout(200);await page.keyboard.insertText('확인 부탁드립니다.');await page.keyboard.press('Tab');await page.waitForTimeout(150);assert.equal(await page.locator('textarea').last().inputValue(),'확인 부탁드립니다.');
 await page.getByRole('button',{name:'신고 접수',exact:true}).click();
 await page.getByText('신고를 접수했습니다.',{exact:true}).last().waitFor();
 await page.getByRole('button',{name:'댓글 삭제',exact:true}).click();
 await page.getByText('첫 댓글을 남겨보세요.',{exact:true}).waitFor();
 if(process.env.PWA_SCREENSHOT_DIR)await page.screenshot({path:require('node:path').join(process.env.PWA_SCREENSHOT_DIR,'community-detail.png')});
 await page.getByRole('button',{name:'Back',exact:true}).click();
 await page.getByRole('button',{name:'신고 관리',exact:true}).click();
 await page.getByText('확인 부탁드립니다.',{exact:true}).waitFor();
 await page.getByRole('button',{name:'처리 완료',exact:true}).click();
 await page.getByText('접수된 신고가 없습니다.',{exact:true}).waitFor();
 await page.getByRole('button',{name:'Back',exact:true}).click();
 await page.getByRole('button',{name:'내 글 삭제',exact:true}).click();
 await page.getByRole('button',{name:'삭제',exact:true}).click();
 await page.getByText('아직 이야기가 없어요.',{exact:false}).waitFor();
 assert.equal(deletes,1);assert.deepEqual(errors,[]);
 console.log('PASS community author follows authenticated numeric identity, not username suffix; draft/create/photo/search/edit/comments/edit-comment/likes/moderation/reload/delete');
 await browser.close();
})().catch(async e=>{
 console.error('COMMUNITY REQUESTS',requests);
 if(debugPage)console.error('ACCESSIBLE NODES',await debugPage.locator('[role]').evaluateAll(nodes=>nodes.map(n=>({role:n.getAttribute('role'),label:n.getAttribute('aria-label'),text:n.innerText?.slice(0,250)})).slice(-50)));
 console.error(e);process.exit(1);
});
