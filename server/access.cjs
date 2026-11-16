const {createHash,randomUUID}=require('node:crypto');
const UPSTREAM='https://api-suho1004.innaim.com';
const hash=s=>createHash('sha256').update(s).digest('hex');
const uuid=/^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/;
class AccessError extends Error {constructor(status,message,code){super(message);this.status=status;this.code=code;}}
const fail=(status,message,code)=>{throw new AccessError(status,message,code);};
const client=v=>['web','ios','android','desktop'].includes(v)?v:'unknown';
function agentDetails(value,platform){
 const ua=typeof value==='string'?value.slice(0,512):'';
 const os=/iPhone|iPad|iPod/i.test(ua)?'ios':/Android/i.test(ua)?'android':/Windows/i.test(ua)?'windows':/Macintosh|Mac OS/i.test(ua)?'macos':/Linux/i.test(ua)?'linux':['ios','android'].includes(platform)?platform:'unknown';
 const browser=/Edg\//i.test(ua)?'edge':/Chrome|CriOS/i.test(ua)?'chrome':/Firefox|FxiOS/i.test(ua)?'firefox':/Safari/i.test(ua)?'safari':'other';
 return {os,browser};
}
// Call only after the original server accepted this exact token. No local
// signature guess, username suffix, client ID, root `id` or ambiguous `sub`.
function verifiedTokenIdentity(token){
 try {
  if(token.length>8192||! /^[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(token))return null;
  const [head,payload]=token.split('.');
  const header=JSON.parse(Buffer.from(head,'base64url').toString('utf8'));
  if(!['HS256','HS384','HS512','RS256','RS384','RS512','ES256','ES384','ES512','EdDSA'].includes(header.alg))return null;
  const claims=JSON.parse(Buffer.from(payload,'base64url').toString('utf8'));
  const value=claims.user_id??claims.userId;
  const userId=Number(value);
  if(!Number.isSafeInteger(userId)||userId<=0)return null;
  if(claims.user_id!=null&&claims.userId!=null&&Number(claims.user_id)!==Number(claims.userId))return null;
  return {userId,name:typeof claims.name==='string'&&claims.name.trim()?claims.name.trim().slice(0,60):`사용자 ${userId}`,source:'validated_token_claim'};
 }catch {return null;}
}
function createAccess({blob,fetcher=fetch,now=Date.now,adminIds=[]}) {
 async function read(path){const r=await blob.get(path,{access:'private',useCache:false});return !r||r.statusCode!==200?null:JSON.parse(await new Response(r.stream).text());}
 async function record(identity,{kind,eventId=randomUUID(),platform='unknown',trace=null,agent=''}){
  const at=now(),bucket=Math.floor(at/60000)*60000;
  const path=`access/v1/${String(9999999999999-bucket).padStart(13,'0')}-${identity.userId}-${eventId}.json`;
  const entry={event_id:eventId,user_id:identity.userId,name:identity.name,at:new Date(at).toISOString(),kind,client:client(platform),source:kind==='password_login'?'verified_login':identity.source||'verified_session',trace:/^[a-f0-9]{32}$/.test(trace||'')?trace:null,...agentDetails(agent,platform)};
  let stored=true;
  try {
   const existing=await read(path);
   if(!existing)await blob.put(path,JSON.stringify(entry),{access:'private',contentType:'application/json',addRandomSuffix:false,allowOverwrite:false});
  }catch {
   try {stored=!!await read(path);}catch {stored=false;}
  }
  try {console.info(JSON.stringify({event:'access_record',user_id:identity.userId,kind,at:entry.at,stored,error_id:stored?'ACC-000':'ACC-202',trace}));}catch {}
  return {access_recorded:stored,error_code:stored?null:'ACC-202',event_id:eventId};
 }
 async function authenticate(headers,{listing=false}={}){
  const token=/^Bearer (\S+)$/.exec(headers.authorization||'')?.[1];
  if(!token)fail(401,'접속 기록 인증이 필요합니다.','ACC-001');
  const secret=headers['x-community-session'];
  let session=null;
  try {if(typeof secret==='string'&&/^[a-f0-9]{64}$/.test(secret))session=await read(`community/sessions/${hash(secret)}.json`);}catch {fail(503,'접속 기록 세션을 읽지 못했습니다.','ACC-101');}
  if(session&&session.tokenHash!==hash(token))session=null;
  let response,data;
  try {
   response=await fetcher(UPSTREAM+'/api/user/validate_token',{method:'PUT',headers:{'Content-Type':'application/json; charset=utf-8',Authorization:`Bearer ${token}`},body:JSON.stringify({packetid:`validate_token_${now()}`,token}),signal:AbortSignal.timeout(20000)});
   data=await response.json();if(typeof data==='string')data=JSON.parse(data);
  }catch {fail(502,'기존 서버에서 접속 상태를 확인하지 못했습니다.','ACC-101');}
  if(response.status!==200||Number(data?.ret)!==1)fail(401,'로그인 상태를 다시 확인해 주세요.','ACC-001');
  // For a write-only access event an old community ticket still binds this
  // server-issued ID to a currently valid original-server token. It grants no
  // expired community, device-history or administrator read permissions.
  if(session&&Number.isSafeInteger(Number(session.userId))&&Number(session.userId)>0){
   if(listing&&(!Number.isFinite(Number(session.expiresAt))||Number(session.expiresAt)<=now()))fail(401,'접속 기록 조회를 위해 다시 로그인해 주세요.','ACC-001');
   return {...session,userId:Number(session.userId),name:typeof session.name==='string'&&session.name.trim()?session.name:`사용자 ${Number(session.userId)}`};
  }
  if(listing)fail(401,'접속 기록 조회를 위해 다시 로그인해 주세요.','ACC-001');
  // Some upstream versions provide verified identity with token validation.
  // Never use a client-supplied ID or an unverified decoded JWT claim.
  const userId=Number(data.user_id);
  if(!Number.isSafeInteger(userId)||userId<=0){
   const verified=verifiedTokenIdentity(token);
   if(verified)return verified;
   fail(409,'접속 기록을 연결하려면 근무를 마친 뒤 다시 로그인해 주세요.','ACC-002');
  }
  return {userId,name:typeof data.name==='string'&&data.name.trim()?data.name.trim().slice(0,60):`사용자 ${userId}`};
 }
 async function handle(body,headers={}){
  if(!body||typeof body!=='object'||Array.isArray(body)||Buffer.byteLength(JSON.stringify(body))>4096)fail(400,'접속 기록 요청을 확인해 주세요.','ACC-003');
  if(body.action==='open'){
   if(Object.keys(body).some(k=>!['action','event_id','client','trace'].includes(k))||!uuid.test(body.event_id||''))fail(400,'접속 기록 요청을 확인해 주세요.','ACC-003');
   const identity=await authenticate(headers);
   return {status:200,data:await record(identity,{kind:'session_open',eventId:body.event_id,platform:body.client,agent:headers['user-agent'],trace:/^[a-f0-9]{32}$/.test(body.trace||'')?body.trace:null})};
  }
  if(body.action==='list'){
   const identity=await authenticate(headers,{listing:true});
   if(!adminIds.includes(identity.userId))fail(403,'관리자만 접속 기록을 조회할 수 있습니다.','ACC-403');
   if(body.cursor!=null&&(typeof body.cursor!=='string'||body.cursor.length>2048))fail(400,'접속 기록 위치를 확인해 주세요.','ACC-003');
   try {
    const page=await blob.list({prefix:'access/v1/',limit:100,...(body.cursor?{cursor:body.cursor}:{})});
    const rows=[];
    for(let i=0;i<page.blobs.length;i+=10)rows.push(...await Promise.all(page.blobs.slice(i,i+10).map(x=>read(x.pathname))));
    rows.sort((a,b)=>Date.parse(b?.at)-Date.parse(a?.at));
    const seen=new Set();
    const records=rows.filter(Boolean).filter(row=>{
     const key=`${row.user_id}/${row.event_id}`;
     if(seen.has(key))return false;seen.add(key);return true;
    });
    return {status:200,data:{records,cursor:page.hasMore?page.cursor:null}};
   }catch {fail(503,'접속 기록 목록을 읽지 못했습니다.','ACC-201');}
  }
  fail(400,'지원하지 않는 접속 기록 요청입니다.','ACC-003');
 }
 return {recordLogin:(identity,options={})=>record(identity,{...options,kind:'password_login'}),handle};
}
module.exports={createAccess,AccessError,agentDetails};
