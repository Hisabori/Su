const {createHash, randomBytes}=require('node:crypto');
const {createFeatures,validateImage}=require('./community_features.cjs');
const UPSTREAM='https://api-suho1004.innaim.com';
const sha=value=>createHash('sha256').update(value).digest('hex');
class CommunityError extends Error {constructor(status,message){super(message);this.status=status;}}
const fail=(status,message)=>{throw new CommunityError(status,message);};
const authorFor=data=>{
 const userId=Number(data.user_id);
 if(!Number.isSafeInteger(userId)||userId<=0)fail(502,'로그인 사용자 정보를 확인하지 못했습니다.');
 // Only the authenticated server result determines the identity. Never use a username suffix.
 const name=typeof data.name==='string'?data.name.trim().slice(0,60):'';
 return {userId,name:name||`사용자 ${userId}`};
};
const publicPost=(post,userId)=>({id:post.id,title:post.title,body:post.body,author:post.author,
 hasImage:!!post.image,createdAt:post.createdAt,mine:post.ownerId===userId});
function createCommunity({blob,fetcher=fetch,now=Date.now,adminIds=[]}){
 async function read(path){
  const result=await blob.get(path,{access:'private',useCache:false});
  if(!result||result.statusCode!==200)return null;
  return JSON.parse(await new Response(result.stream).text());
 }
 async function write(path,data){return blob.put(path,JSON.stringify(data),{access:'private',contentType:'application/json',addRandomSuffix:false,allowOverwrite:false});}
 async function upstream(path,body,token){
  let response;
  try {response=await fetcher(UPSTREAM+path,{method:'PUT',headers:{'Content-Type':'application/json; charset=utf-8','Accept':'application/json',...(token?{Authorization:`Bearer ${token}`}:{})},body:JSON.stringify({packetid:`${path.split('/').pop()}_${now()}`, ...body}),signal:AbortSignal.timeout(20000)});}
  catch {fail(502,'로그인 서버에 연결하지 못했습니다. 다시 시도해 주세요.');}
  let data;
  try{data=await response.json();if(typeof data==='string')data=JSON.parse(data);}catch{fail(502,'로그인 서버 응답을 확인하지 못했습니다.');}
  if(!data||typeof data!=='object'||Array.isArray(data))fail(502,'로그인 서버 응답을 확인하지 못했습니다.');
  return {status:response.status,data};
 }
 async function login(body){
  if(typeof body.username!=='string'||body.username.length>100||!body.username.trim()||!/^([a-f0-9]{64})$/.test(body.password||''))fail(400,'로그인 정보를 확인해 주세요.');
  const result=await upstream('/api/user/login',{username:body.username.trim(),password:body.password});
  if(result.status<200||result.status>=300||Number(result.data.ret)!==1)return result;
  const {userId,name}=authorFor(result.data), token=result.data.access_token??result.data.jwt_access_token;
  if(typeof token!=='string'||!token)fail(502,'로그인 응답을 확인하지 못했습니다.');
  // Community provisioning cannot turn a successful work login into a failed login.
  try {
   const secret=randomBytes(32).toString('hex');
   await write(`community/sessions/${sha(secret)}.json`,{userId,name,tokenHash:sha(token),expiresAt:now()+12*60*60*1000});
   return {status:result.status,data:{...result.data,community_session:secret}};
  }catch{return {status:result.status,data:result.data};}
 }
 async function authenticate(headers){
  const match=/^Bearer (\S+)$/.exec(headers.authorization||'');
  const secret=headers['x-community-session'];
  if(!match||typeof secret!=='string'||!/^[a-f0-9]{64}$/.test(secret))fail(401,'커뮤니티를 이용하려면 다시 로그인해 주세요.');
  const path=`community/sessions/${sha(secret)}.json`,session=await read(path);
  if(!session||session.expiresAt<=now()||session.tokenHash!==sha(match[1]))fail(401,'커뮤니티 로그인이 만료되었습니다. 다시 로그인해 주세요.');
  const verified=await upstream('/api/user/validate_token',{token:match[1]},match[1]);
  if(verified.status!==200||Number(verified.data.ret)!==1)fail(401,'커뮤니티 로그인이 만료되었습니다. 다시 로그인해 주세요.');
  return {...session,path};
 }
 function postPath(id){
  if(typeof id!=='string'||!/^\d{13}-[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/.test(id))fail(400,'글 번호를 확인해 주세요.');
  return `community/posts/${String(9999999999999-Number(id.slice(0,13))).padStart(13,'0')}-${id.slice(14)}.json`;
 }
 const features=createFeatures({blob,read,write,postPath,publicPost,fail,now,adminIds});
 return async function handle(body,headers={}){
  if(!body||typeof body!=='object'||Array.isArray(body)||Buffer.byteLength(JSON.stringify(body))>(body.action==='create'?750000:16384))fail(400,'요청 내용을 확인해 주세요.');
  if(body.action==='login')return login(body);
  const session=await authenticate(headers);
  const feature=await features.handle(body,session);if(feature)return feature;
  if(body.action==='list'){
   if(body.cursor!=null&&(typeof body.cursor!=='string'||body.cursor.length>2048))fail(400,'목록 위치를 확인해 주세요.');
   const result=await blob.list({prefix:'community/posts/',limit:20,...(body.cursor?{cursor:body.cursor}:{})});
   const values=await Promise.all(result.blobs.map(item=>read(item.pathname)));
   const posts=values.filter(Boolean).sort((a,b)=>b.createdAt-a.createdAt);
   const decorated=(await Promise.all(posts.map(p=>features.decorate(p,session)))).filter(Boolean);
   const pinned=body.cursor?[]:await features.notices(session);
   const combined=[...pinned,...decorated.filter(p=>!pinned.some(n=>n.id===p.id))];
   return {status:200,data:{posts:combined,me:{name:session.name,isAdmin:features.admin(session)},cursor:result.hasMore?result.cursor:null}};
  }
  if(body.action==='create'){
   const path=postPath(body.id);
   const prior=await read(path);
   if(prior){if(prior.ownerId!==session.userId)fail(409,'글 번호가 중복되었습니다. 다시 시도해 주세요.');return {status:200,data:{post:publicPost(prior,session.userId)}};}
   if(Math.abs(now()-Number(body.id.slice(0,13)))>10*60*1000)fail(400,'기기 시간을 확인한 뒤 글쓰기를 다시 열어 주세요.');
   if(typeof body.title!=='string'||!body.title.trim()||body.title.trim().length>80||typeof body.body!=='string'||!body.body.trim()||body.body.trim().length>2000)fail(400,'제목은 80자, 내용은 2,000자 이내로 입력해 주세요.');
   const post={id:body.id,title:body.title.trim(),body:body.body.trim(),author:session.name,ownerId:session.userId,createdAt:now(),image:validateImage(body.image,fail)};
   try {await write(path,post);}catch(error){const existing=await read(path);if(!existing||existing.ownerId!==session.userId)throw error;return {status:200,data:{post:publicPost(existing,session.userId)}};}
   return {status:201,data:{post:publicPost(post,session.userId)}};
  }
  if(body.action==='delete'){
   const path=postPath(body.id),post=await read(path);
   if(!post)return {status:200,data:{deleted:true}};
   if(post.ownerId!==session.userId)fail(403,'내가 작성한 글만 삭제할 수 있습니다.');
   await blob.del(path);return {status:200,data:{deleted:true}};
  }
  if(body.action==='logout'){await blob.del(session.path);return {status:200,data:{loggedOut:true}};}
  fail(400,'지원하지 않는 요청입니다.');
 };
}
module.exports={createCommunity,CommunityError,authorFor};
