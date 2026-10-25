const {test}=require('node:test');
const assert=require('node:assert/strict');
const {randomUUID}=require('node:crypto');
const {createCommunity,authorFor}=require('../server/community.cjs');
function setup(adminIds=[]){
 const objects=new Map(),fixed=1792367038734;
 let loginReply={ret:1,user_id:31,name:'정훈',access_token:'verified-token'},valid=true;
 const blob={
  get:async key=>objects.has(key)?{statusCode:200,stream:new Response(JSON.stringify(objects.get(key))).body}:null,
  put:async(key,value)=>{if(objects.has(key))throw Error('exists');objects.set(key,JSON.parse(value));},
  list:async({prefix='community/posts/'})=>({blobs:[...objects.keys()].filter(k=>k.startsWith(prefix)).sort().map(pathname=>({pathname})),hasMore:false}),
  del:async key=>objects.delete(key),
 };
 const handle=createCommunity({blob,adminIds,now:()=>fixed,fetcher:async(url,options)=>{
  const body=JSON.parse(options.body);
  assert.equal(options.method,'PUT');
  assert.equal(body.packetid,`${url.split('/').pop()}_${fixed}`);
  assert.equal(options.headers.Accept,'application/json');
  if(url.endsWith('/login')){assert.match(body.password,/^[a-f0-9]{64}$/);return Response.json(loginReply);}
  assert.equal(url,'https://api-suho1004.innaim.com/api/user/validate_token');
  assert.equal(body.token,'verified-token');return Response.json({ret:valid?1:0});
 }});
 return {handle,objects,id:()=>`${fixed}-${randomUUID()}`,setLogin:data=>{loginReply=data;},expire:()=>{valid=false;}};
}
const credentials={action:'login',username:'cesco999',password:'a'.repeat(64)};
async function connect(s){const r=await s.handle(credentials);return {authorization:'Bearer verified-token','x-community-session':r.data.community_session};}
test('author uses authenticated numeric user id and server name, never username suffix',async()=>{
 const s=setup(),headers=await connect(s);
 assert.deepEqual(authorFor({user_id:31}),{userId:31,name:'사용자 31'});
 const r=await s.handle({action:'create',id:s.id(),title:'인사',body:'안녕하세요',author:'사칭',user_id:999},headers);
 assert.equal(r.data.post.author,'정훈');assert.equal(r.data.post.mine,true);
 assert.equal((await s.handle({action:'list'},headers)).data.me.name,'정훈');
 assert.equal((await s.handle({action:'list'},headers)).data.posts.length,1);
 assert.ok(!JSON.stringify(r.data.post).includes('verified-token'));
});
test('missing sessions, altered bearer and rejected server sessions cannot read or post',async()=>{
 const s=setup(),headers=await connect(s);
 for(const h of [{},{...headers,authorization:'Bearer changed'}])await assert.rejects(s.handle({action:'list'},h),e=>e.status===401);
 s.expire();await assert.rejects(s.handle({action:'create',id:s.id(),title:'제목',body:'내용'},headers),e=>e.status===401);
});
test('idempotency keeps one post; only its authenticated owner may delete',async()=>{
 const s=setup(),owner=await connect(s),id=s.id();
 const body={action:'create',id,title:'제목',body:'내용'};
 await Promise.all([s.handle(body,owner),s.handle(body,owner)]);
 assert.equal((await s.handle({action:'list'},owner)).data.posts.length,1);
 s.setLogin({ret:1,user_id:42,name:'다른 사용자',access_token:'verified-token'});
 const other=await connect(s);
 await assert.rejects(s.handle({action:'delete',id},other),e=>e.status===403);
 await s.handle({action:'delete',id},owner);
 assert.equal((await s.handle({action:'list'},owner)).data.posts.length,0);
});
test('denied login creates no session, and storage failure never blocks successful work login',async()=>{
 const s=setup();s.setLogin({ret:4});assert.deepEqual((await s.handle(credentials)).data,{ret:4});assert.equal(s.objects.size,0);
 const handle=createCommunity({blob:{put:async()=>{throw Error('storage unavailable');}},fetcher:async()=>Response.json({ret:1,user_id:31,name:'정훈',access_token:'verified-token'})});
 const result=await handle(credentials);assert.equal(result.data.ret,1);assert.equal(result.data.community_session,undefined);
});
test('invalid post size, path injection and stale new post ids are rejected',async()=>{
 const s=setup(),headers=await connect(s);
 await assert.rejects(s.handle({action:'delete',id:'../../sessions/key'},headers),e=>e.status===400);
 await assert.rejects(s.handle({action:'create',id:s.id(),title:'제목',body:'x'.repeat(2001)},headers),e=>e.status===400);
 await assert.rejects(s.handle({action:'create',id:`1000000000000-${randomUUID()}`,title:'제목',body:'내용'},headers),e=>e.status===400);
});
test('comments and likes are isolated by server identity, retry-safe and ownership checked',async()=>{
 const s=setup(),owner=await connect(s),id=s.id(),commentId=s.id();
 await s.handle({action:'create',id,title:'대화',body:'본문'},owner);
 const comment={action:'comment_create',id,commentId,body:'댓글',author:'사칭'};
 await Promise.all([s.handle(comment,owner),s.handle(comment,owner)]);
 await Promise.all([s.handle({action:'like',id,liked:true},owner),s.handle({action:'like',id,liked:true},owner)]);
 let detail=(await s.handle({action:'detail',id},owner)).data;
 assert.equal(detail.comments.length,1);assert.equal(detail.comments[0].author,'정훈');assert.equal(detail.likes,1);assert.equal(detail.liked,true);
 s.setLogin({ret:1,user_id:42,name:'동료',access_token:'verified-token'});const other=await connect(s);
 await assert.rejects(s.handle({action:'comment_delete',id,commentId},other),e=>e.status===403);
 await s.handle({action:'like',id,liked:true},other);
 assert.equal((await s.handle({action:'detail',id},other)).data.likes,2);
 await s.handle({action:'like',id,liked:false},owner);
 await s.handle({action:'comment_delete',id,commentId},owner);
 detail=(await s.handle({action:'detail',id},owner)).data;assert.equal(detail.likes,1);assert.equal(detail.comments.length,0);
});
test('only configured server user ids moderate; reports stay private and hidden posts are inaccessible',async()=>{
 const s=setup([31]),admin=await connect(s),id=s.id();
 await s.handle({action:'create',id,title:'공지 테스트',body:'내용'},admin);
 s.setLogin({ret:1,user_id:42,name:'동료',access_token:'verified-token'});const other=await connect(s);
 for(const action of ['reports','pin','hide','report_resolve'])await assert.rejects(s.handle({action,id,enabled:true,isAdmin:true,user_id:31},other),e=>e.status===403);
 await s.handle({action:'report',id,reason:'확인이 필요합니다.'},other);
 await s.handle({action:'report',id,reason:'중복 재시도'},other);
 const reports=(await s.handle({action:'reports'},admin)).data.reports;assert.equal(reports.length,1);assert.equal(reports[0].reporter,'동료');
 await s.handle({action:'pin',id,enabled:true},admin);
 assert.equal((await s.handle({action:'list'},other)).data.posts[0].pinned,true);
 await s.handle({action:'hide',id,enabled:true},admin);
 assert.equal((await s.handle({action:'list'},other)).data.posts.length,0);
 await assert.rejects(s.handle({action:'detail',id},other),e=>e.status===404);
 await assert.rejects(s.handle({action:'comment_create',id,commentId:s.id(),body:'내용'},other),e=>e.status===404);
 await s.handle({action:'hide',id,enabled:false},admin);
 await s.handle({action:'report_resolve',key:reports[0].key},admin);
 assert.equal((await s.handle({action:'reports'},admin)).data.reports.length,0);
});
test('photos are validated and delivered only through authenticated detail, not list rows',async()=>{
 const s=setup(),owner=await connect(s),id=s.id();
 // Minimal PNG signature fixture: content is never executed or exposed publicly.
 const image={mime:'image/png',data:Buffer.from([137,80,78,71,13,10,26,10,0,0,0,0]).toString('base64')};
 await s.handle({action:'create',id,title:'사진',body:'설명',image},owner);
 const list=(await s.handle({action:'list'},owner)).data;assert.equal(list.posts[0].hasImage,true);assert.equal(list.posts[0].image,undefined);
 assert.deepEqual((await s.handle({action:'detail',id},owner)).data.post.image,image);
 await assert.rejects(s.handle({action:'detail',id}),e=>e.status===401);
 for(const bad of [{mime:'image/svg+xml',data:'PHN2Zz4='},{mime:'image/jpeg',data:'bad'},{mime:'image/png',data:'a'.repeat(699056)}])
  await assert.rejects(s.handle({action:'create',id:s.id(),title:'사진',body:'내용',image:bad},owner),e=>e.status===400);
});
test('only owners edit text, original image and identity remain intact, retries stay idempotent',async()=>{
 const s=setup([31]),owner=await connect(s),id=s.id();
 await s.handle({action:'create',id,title:'원본',body:'내용'},owner);
 const mutationId=s.id();
 await s.handle({action:'edit',id,mutationId,title:'수정 제목',body:'수정 내용',author:'사칭'},owner);
 await s.handle({action:'edit',id,mutationId,title:'재전송',body:'변경 무시'},owner);
 let p=(await s.handle({action:'detail',id},owner)).data.post;
 assert.equal(p.title,'수정 제목');assert.equal(p.body,'수정 내용');assert.equal(p.author,'정훈');assert.ok(p.updatedAt);
 assert.equal((await s.handle({action:'list'},owner)).data.posts[0].title,'수정 제목');
 const commentId=s.id();await s.handle({action:'comment_create',id,commentId,body:'원 댓글'},owner);
 await s.handle({action:'comment_edit',id,commentId,mutationId:s.id(),body:'수정 댓글'},owner);
 assert.equal((await s.handle({action:'detail',id},owner)).data.comments[0].body,'수정 댓글');
 s.setLogin({ret:1,user_id:42,name:'다른 사용자',access_token:'verified-token'});const other=await connect(s);
 await assert.rejects(s.handle({action:'edit',id,mutationId:s.id(),title:'사칭',body:'내용'},other),e=>e.status===403);
 await assert.rejects(s.handle({action:'comment_edit',id,commentId,mutationId:s.id(),body:'사칭'},other),e=>e.status===403);
 const otherPost=s.id();await s.handle({action:'create',id:otherPost,title:'다른 글',body:'내용'},other);
 await s.handle({action:'comment_create',id:otherPost,commentId,body:'동일 댓글 ID'},other);
 await s.handle({action:'comment_edit',id:otherPost,commentId,mutationId:s.id(),body:'다른 글에서 수정'},other);
 assert.equal((await s.handle({action:'detail',id},owner)).data.comments[0].body,'수정 댓글');
});
