const {test}=require('node:test');
const assert=require('node:assert/strict');
const {randomUUID}=require('node:crypto');
const {createCommunity,authorFor}=require('../server/community.cjs');
function setup(){
 const objects=new Map(),fixed=1792367038734;
 let loginReply={ret:1,user_id:31,name:'정훈',access_token:'verified-token'},valid=true;
 const blob={
  get:async key=>objects.has(key)?{statusCode:200,stream:new Response(JSON.stringify(objects.get(key))).body}:null,
  put:async(key,value)=>{if(objects.has(key))throw Error('exists');objects.set(key,JSON.parse(value));},
  list:async()=>({blobs:[...objects.keys()].filter(k=>k.startsWith('community/posts/')).sort().map(pathname=>({pathname})),hasMore:false}),
  del:async key=>objects.delete(key),
 };
 const handle=createCommunity({blob,now:()=>fixed,fetcher:async(url,options)=>{
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
 assert.deepEqual(authorFor({user_id:31}),{userId:31,name:'정훈'});
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
