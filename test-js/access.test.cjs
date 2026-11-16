const {test}=require('node:test');
const assert=require('node:assert/strict');
const {createHash,randomUUID}=require('node:crypto');
const {createCommunity}=require('../server/community.cjs');
const {createAccess,agentDetails}=require('../server/access.cjs');
function setup(){
 let reply,clock=Date.now(),accessDown=false,withIdentity=false;
 const objects=new Map();
 const blob={get:async key=>objects.has(key)?{statusCode:200,stream:new Response(JSON.stringify(objects.get(key))).body}:null,
  put:async(key,value)=>{if(accessDown&&key.startsWith('access/'))throw Error('disk full');if(objects.has(key))throw Error('exists');objects.set(key,JSON.parse(value));},
  list:async({prefix,limit,cursor})=>{const keys=[...objects.keys()].filter(k=>k.startsWith(prefix)).sort(),start=Number(cursor||0);return {blobs:keys.slice(start,start+limit).map(pathname=>({pathname})),hasMore:start+limit<keys.length,cursor:String(start+limit)};},del:async key=>objects.delete(key)};
 const fetcher=async(url,options)=>url.endsWith('/login')?Response.json(reply):Response.json({ret:/^t-\d+$/.test(JSON.parse(options.body).token)?1:0,...(withIdentity?{user_id:Number(JSON.parse(options.body).token.slice(2)),name:'검증 서버 이름'}:{})});
 const access=createAccess({blob,fetcher,now:()=>clock,adminIds:[31]});
 const community=createCommunity({blob,fetcher,now:()=>clock,adminIds:[31]});
 const connect=async(id,name=`이름 ${id}`)=>{
  reply={ret:1,user_id:id,name,access_token:`t-${id}`};
  const result=await community({action:'login',username:'not-the-user-id-999',password:'a'.repeat(64),client:'web'});
  return {result,headers:{authorization:`Bearer t-${id}`,'x-community-session':result.data.community_session}};
 };
 return {objects,access,community,connect,get clock(){return clock;},failWrites:()=>{accessDown=true;},verifyIdentity:()=>{withIdentity=true;}};
}
test('all server IDs are collected within the same minute; admin filtering only limits viewing',async()=>{
 const s=setup(),clients=[];
 for(const id of [31,42,73,310,999])clients.push(await s.connect(id));
 const records=[...s.objects.entries()].filter(([key])=>key.startsWith('access/')).map(([,r])=>r);
 assert.deepEqual(records.map(r=>r.user_id),[31,42,73,310,999]);
 assert.ok(records.every(r=>r.kind==='password_login'&&!JSON.stringify(r).includes('t-')));
 assert.equal(clients[1].result.data.access_recorded,true);
 await assert.rejects(s.access.handle({action:'list'},clients[1].headers),e=>e.code==='ACC-403');
 const list=(await s.access.handle({action:'list'},clients[0].headers)).data.records;
 assert.equal(list.length,5);assert.ok(list.some(r=>r.user_id===73));
});
test('session opens are isolated by verified ID, retry-safe and cannot spoof an author',async()=>{
 const s=setup(),a=await s.connect(31),b=await s.connect(42),event_id=randomUUID();
 for(const headers of [a.headers,a.headers,b.headers])assert.equal((await s.access.handle({action:'open',event_id,client:'ios'},headers)).data.access_recorded,true);
 const opened=[...s.objects.values()].filter(r=>r.kind==='session_open');
 assert.deepEqual(opened.map(r=>r.user_id),[31,42]);
 const viewed=(await s.access.handle({action:'list'},a.headers)).data.records.filter(r=>r.kind==='session_open');
 assert.deepEqual(viewed.map(r=>r.user_id).sort((a,b)=>a-b),[31,42]);
 await assert.rejects(s.access.handle({action:'open',event_id,user_id:999},a.headers),e=>e.code==='ACC-003');
 await assert.rejects(s.access.handle({action:'open',event_id},{...a.headers,authorization:'Bearer changed'}),e=>e.code==='ACC-001');
});
test('old community tickets log a valid session without restoring expired read privileges',async()=>{
 const s=setup(),a=await s.connect(31),secret=a.headers['x-community-session'];
 s.objects.get(`community/sessions/${createHash('sha256').update(secret).digest('hex')}.json`).expiresAt=s.clock-1;
 assert.equal((await s.access.handle({action:'open',event_id:randomUUID()},a.headers)).data.access_recorded,true);
 await assert.rejects(s.access.handle({action:'list'},a.headers),e=>e.code==='ACC-001');
 await assert.rejects(s.community({action:'list'},a.headers),e=>e.status===401);
});
test('fallback identity must come from the validation server, never a decoded or claimed ID',async()=>{
 const s=setup(),headers={authorization:'Bearer t-73'};
 await assert.rejects(s.access.handle({action:'open',event_id:randomUUID()},headers),e=>e.code==='ACC-002');
 s.verifyIdentity();
 assert.equal((await s.access.handle({action:'open',event_id:randomUUID()},headers)).data.access_recorded,true);
 assert.equal([...s.objects.values()].find(r=>r.kind==='session_open').user_id,73);
});
test('audit storage failure is explicit and does not erase a valid work login',async()=>{
 const s=setup();s.failWrites();const a=await s.connect(42);
 assert.equal(a.result.data.ret,1);assert.equal(a.result.data.access_recorded,false);assert.equal(a.result.data.access_error_code,'ACC-202');
 const failed=(await s.access.handle({action:'open',event_id:randomUUID()},a.headers)).data;
 assert.equal(failed.access_recorded,false);assert.equal(failed.error_code,'ACC-202');
});

test('device categories are bounded and raw user-agent strings are not stored',()=>{
 assert.deepEqual(agentDetails('Mozilla/5.0 (iPhone) AppleWebKit Safari/605.1','web'),{os:'ios',browser:'safari'});
 assert.deepEqual(agentDetails('Mozilla/5.0 Windows Chrome/120 Edg/120','web'),{os:'windows',browser:'edge'});
});

test('direct-login tokens need original-server validation and explicit signed user claims',async()=>{
 const objects=new Map();let valid=true;
 const blob={get:async key=>objects.has(key)?{statusCode:200,stream:new Response(JSON.stringify(objects.get(key))).body}:null,put:async(key,value)=>objects.set(key,JSON.parse(value))};
 const access=createAccess({blob,fetcher:async()=>Response.json({ret:valid?1:0})});
 const token=claims=>[Buffer.from(JSON.stringify({alg:'HS256'})).toString('base64url'),Buffer.from(JSON.stringify(claims)).toString('base64url'),'servervalidatedsignature'].join('.');
 const jwt=token({user_id:73,name:'검증 토큰 이름'});
 const request={action:'open',event_id:randomUUID()};
 valid=false;
 await assert.rejects(access.handle(request,{authorization:`Bearer ${jwt}`}),e=>e.code==='ACC-001');
 assert.equal(objects.size,0);
 valid=true;
 assert.equal((await access.handle(request,{authorization:`Bearer ${jwt}`})).data.access_recorded,true);
 assert.equal([...objects.values()][0].user_id,73);
 assert.equal([...objects.values()][0].source,'validated_token_claim');
 await assert.rejects(access.handle({...request,event_id:randomUUID()},{authorization:`Bearer ${token({sub:999,id:999})}`}),e=>e.code==='ACC-002');
});
