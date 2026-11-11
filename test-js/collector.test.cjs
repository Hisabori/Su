const {test}=require('node:test');
const assert=require('node:assert/strict');
const {createHash}=require('node:crypto');
const {createCommunity}=require('../server/community.cjs');
function setup(){
 let time=Date.now(),down=false,storageDown=false,calls=0;
 const objects=new Map();
 const blob={get:async key=>objects.has(key)?{statusCode:200,stream:new Response(JSON.stringify(objects.get(key))).body}:null,
  put:async(key,value)=>{if(storageDown&&key.startsWith('collectors/'))throw Error('full');if(objects.has(key))throw Error('exists');objects.set(key,JSON.parse(value));},
  list:async({prefix,limit,cursor})=>{const keys=[...objects.keys()].filter(k=>k.startsWith(prefix)).sort(),start=Number(cursor||0),selected=keys.slice(start,start+limit);return {blobs:selected.map(pathname=>({pathname})),hasMore:start+limit<keys.length,cursor:String(start+limit)};},
  del:async key=>objects.delete(key)};
 const handle=createCommunity({blob,now:()=>time,fetcher:async(url,options)=>{
  const body=JSON.parse(options.body);
  if(url.endsWith('/login'))return Response.json({ret:1,user_id:body.username==='b'?42:31,name:'서버 사용자',access_token:'token-'+body.username,company_device_name:body.username==='other'?'elsewhere':'partner',kiosk_id:body.username==='unassigned'?null:7});
  if(url.endsWith('/validate_token'))return Response.json({ret:1});
  assert.ok(url.endsWith('/kiosk_info'));assert.equal(body.packetid,undefined);assert.equal(body.partnerId,'partner');calls++;
  if(down)throw Error('offline');
  return Response.json({kiosks:[{kioskId:7,name:'수거기 7',currentCapacity:250,maxCapacity:1000,isAvailable:true}]});
 }});
 const connect=async name=>{const reply=await handle({action:'login',username:name,password:'a'.repeat(64)});return {reply,headers:{authorization:'Bearer token-'+name,'x-community-session':reply.data.community_session}};};
 return {handle,objects,connect,get calls(){return calls;},get time(){return time;},tick:()=>{time+=600000;},down:()=>{down=true;},storageDown:()=>{storageDown=true;}};
}
test('different authenticated clients share server observations for their assigned collector',async()=>{
 const s=setup(),a=await s.connect('a'),b=await s.connect('b'),other=await s.connect('other');
 assert.equal(a.reply.data.device_history_enabled,true);
 await s.handle({action:'device_sample'},a.headers);
 await s.handle({action:'device_sample'},b.headers);
 assert.equal(s.calls,1);
 const rows=(await s.handle({action:'device_history'},b.headers)).data.records;
 assert.equal(rows.length,1);assert.equal(rows[0].current,250);assert.equal(rows[0].error_code,null);
 assert.equal(JSON.stringify(rows).includes('token-'),false);assert.equal(rows[0].user_id,undefined);
 assert.equal((await s.handle({action:'device_history'},other.headers)).data.records.length,0);
 await assert.rejects(s.handle({action:'device_sample',current:9999},a.headers),e=>e.errorCode==='DVC-003');
 await assert.rejects(s.handle({action:'device_history',kiosk:'other'},a.headers),e=>e.errorCode==='DVC-003');
 await assert.rejects(s.handle({action:'device_history'}),e=>e.errorCode==='DVC-001');
});
test('server errors have stable codes; failed observations remain unknown',async()=>{
 const s=setup(),a=await s.connect('a'),missing=await s.connect('unassigned');
 await assert.rejects(s.handle({action:'device_history'},missing.headers),e=>e.errorCode==='DVC-002');
 s.down();const reading=(await s.handle({action:'device_sample'},a.headers)).data.reading;
 assert.equal(reading.error_code,'DVC-101');assert.equal(reading.current,null);
 s.tick();s.storageDown();
 await assert.rejects(s.handle({action:'device_sample'},a.headers),e=>e.errorCode==='DVC-202');
});
test('history is paginated and excludes samples older than seven days',async()=>{
 const s=setup(),a=await s.connect('a');
 const hash=createHash('sha256').update(JSON.stringify(['partner','7'])).digest('hex');
 for(let i=0;i<102;i++){
  const at=s.time-i*600000;
  s.objects.set(`collectors/v1/${hash}/${String(9999999999999-at).padStart(13,'0')}.json`,{partner:'partner',kiosk:'7',at:new Date(at).toISOString(),current:i,capacity:1000});
 }
 const first=(await s.handle({action:'device_history'},a.headers)).data;
 assert.equal(first.records.length,100);assert.ok(first.cursor);
 const second=(await s.handle({action:'device_history',cursor:first.cursor},a.headers)).data;
 assert.equal(second.records.length,2);assert.equal(second.cursor,null);
 const old=s.time-8*86400000;
 s.objects.set(`collectors/v1/${hash}/${String(9999999999999-old).padStart(13,'0')}.json`,{partner:'partner',kiosk:'7',at:new Date(old).toISOString()});
 const last=(await s.handle({action:'device_history',cursor:first.cursor},a.headers)).data;
 assert.equal(last.records.length,2);assert.equal(last.cursor,null);
});
