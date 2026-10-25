const {createHash}=require('node:crypto');
const hash=s=>createHash('sha256').update(s).digest('hex');
function validateImage(image,fail){
 if(image==null)return null;
 if(!image||!['image/jpeg','image/png'].includes(image.mime)||typeof image.data!=='string'||image.data.length>699052||! /^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=)?$/.test(image.data))fail(400,'사진은 512KB 이내의 JPG·PNG 파일을 사용해 주세요.');
 const bytes=Buffer.from(image.data,'base64');
 const valid=image.mime==='image/jpeg'?bytes[0]===255&&bytes[1]===216&&bytes[2]===255:bytes.subarray(0,8).equals(Buffer.from([137,80,78,71,13,10,26,10]));
 if(!valid||bytes.length<12||bytes.length>524288)fail(400,'사진 파일을 확인해 주세요.');
 return {mime:image.mime,data:bytes.toString('base64')};
}
function createFeatures({blob,read,write,postPath,publicPost,fail,now,adminIds=[]}){
 const admin=s=>adminIds.includes(s.userId);
 const prefix=id=>`community/activity/${hash(id)}/`;
 const marker=(kind,id)=>`community/${kind}/${hash(id)}.json`;
 const cursor=value=>{if(value!=null&&(typeof value!=='string'||value.length>2048))fail(400,'목록 위치를 확인해 주세요.');return value?{cursor:value}:{};};
 async function once(path,value){try{await write(path,value);}catch(e){if(!await read(path))throw e;}}
 async function revision(kind,id){const r=await blob.list({prefix:`community/revisions/${kind}/${hash(id)}/`,limit:1});return r.blobs.length?await read(r.blobs[0].pathname):null;}
 async function revised(kind,p,parent=''){return {...p,...await revision(kind,parent+p.id)};}
 async function visible(id,s){const raw=await read(postPath(id));const p=raw?await revised('posts',raw):null;if(!p||(!admin(s)&&await read(marker('hidden',id))))fail(404,'삭제되었거나 볼 수 없는 글입니다.');return p;}
 async function decorate(p,s){if(!admin(s)&&await read(marker('hidden',p.id)))return null;return {...publicPost(await revised('posts',p),s.userId),pinned:!!await read(marker('pins',p.id))};}
 async function notices(s){const r=await blob.list({prefix:'community/pins/',limit:10});const marks=await Promise.all(r.blobs.map(b=>read(b.pathname)));const values=await Promise.all(marks.filter(Boolean).map(m=>read(postPath(m.postId))));return (await Promise.all(values.filter(Boolean).map(p=>decorate(p,s)))).filter(Boolean);}
 async function reactions(id,s){const r=await blob.list({prefix:prefix(id)+'likes/',limit:1000});return {likes:r.blobs.length,likesMore:!!r.hasMore,liked:!!await read(prefix(id)+`likes/${s.userId}.json`)};}
 async function handle(b,s){
  if(b.action==='detail'||b.action==='comments'){
   const post=await visible(b.id,s);
   const r=await blob.list({prefix:prefix(b.id)+'comments/',limit:20,...cursor(b.cursor)});
   const rawComments=(await Promise.all(r.blobs.map(x=>read(x.pathname)))).filter(Boolean);
   const comments=(await Promise.all(rawComments.map(c=>revised('comments',c,b.id+'/')))).map(c=>({id:c.id,body:c.body,author:c.author,createdAt:c.createdAt,updatedAt:c.updatedAt??null,mine:c.ownerId===s.userId}));
   return {status:200,data:{post:{...await decorate(post,s),image:post.image??null,hidden:admin(s)&&!!await read(marker('hidden',b.id))},comments,cursor:r.hasMore?r.cursor:null,...await reactions(b.id,s),isAdmin:admin(s)}};
  }
  if(b.action==='edit'||b.action==='comment_edit'){
   const p=await visible(b.id,s);
   let original=p,kind='posts';
   if(b.action==='comment_edit'){
    original=await read(prefix(b.id)+'comments/'+postPath(b.commentId).split('/').pop());kind='comments';
    if(!original)fail(404,'삭제된 댓글입니다.');
   }
   if(original.ownerId!==s.userId)fail(403,'내가 작성한 내용만 수정할 수 있습니다.');
   const path=`community/revisions/${kind}/${hash((kind==='comments'?b.id+'/':'')+original.id)}/${postPath(b.mutationId).split('/').pop()}`;
   if(await read(path))return {status:200,data:{saved:true}};
   if(Math.abs(now()-Number(b.mutationId.slice(0,13)))>600000)fail(400,'기기 시간을 확인한 뒤 수정 화면을 다시 열어 주세요.');
   if(typeof b.body!=='string'||!b.body.trim()||b.body.trim().length>(kind==='posts'?2000:500))fail(400,'내용의 글자 수를 확인해 주세요.');
   if(kind==='posts'&&(typeof b.title!=='string'||!b.title.trim()||b.title.trim().length>80))fail(400,'제목은 80자 이내로 입력해 주세요.');
   await once(path,{body:b.body.trim(),...(kind==='posts'?{title:b.title.trim()}:{}),updatedAt:now()});
   return {status:200,data:{saved:true}};
  }
  if(b.action==='like'){
   await visible(b.id,s);if(typeof b.liked!=='boolean')fail(400,'좋아요 상태를 확인해 주세요.');
   const path=prefix(b.id)+`likes/${s.userId}.json`;
   if(b.liked)await once(path,{userId:s.userId});else await blob.del(path);
   return {status:200,data:await reactions(b.id,s)};
  }
  if(b.action==='comment_create'){
   await visible(b.id,s);const leaf=postPath(b.commentId).split('/').pop(),path=prefix(b.id)+'comments/'+leaf;
   const prior=await read(path);if(prior){if(prior.ownerId!==s.userId)fail(409,'댓글 번호가 중복되었습니다.');return {status:200,data:{saved:true}};}
   if(Math.abs(now()-Number(b.commentId.slice(0,13)))>600000||typeof b.body!=='string'||!b.body.trim()||b.body.trim().length>500)fail(400,'댓글은 500자 이내로 입력하고 기기 시간을 확인해 주세요.');
   await once(path,{id:b.commentId,body:b.body.trim(),ownerId:s.userId,author:s.name,createdAt:now()});
   const stored=await read(path);if(stored.ownerId!==s.userId)fail(409,'댓글 번호가 중복되었습니다.');
   return {status:201,data:{saved:true}};
  }
  if(b.action==='comment_delete'){
   await visible(b.id,s);const path=prefix(b.id)+'comments/'+postPath(b.commentId).split('/').pop(),c=await read(path);
   if(c&&c.ownerId!==s.userId&&!admin(s))fail(403,'내 댓글만 삭제할 수 있습니다.');
   await blob.del(path);return {status:200,data:{deleted:true}};
  }
  if(b.action==='report'){
   await visible(b.id,s);
   if(typeof b.reason!=='string'||!b.reason.trim()||b.reason.length>500)fail(400,'신고 사유를 500자 이내로 입력해 주세요.');
   await once(`community/reports/${hash(b.id)}-${s.userId}.json`,{postId:b.id,reporter:s.name,reason:b.reason.trim(),createdAt:now()});
   return {status:201,data:{reported:true}};
  }
  if(['pin','hide','reports','report_resolve'].includes(b.action)){
   if(!admin(s))fail(403,'관리자만 사용할 수 있습니다.');
   if(b.action==='reports'){
    const r=await blob.list({prefix:'community/reports/',limit:20,...cursor(b.cursor)});
    const reports=(await Promise.all(r.blobs.map(async x=>{const value=await read(x.pathname);if(!value)return null;return {...value,key:x.pathname.split('/').pop()};}))).filter(Boolean);
    return {status:200,data:{reports,cursor:r.hasMore?r.cursor:null}};
   }
   if(b.action==='report_resolve'){
    if(typeof b.key!=='string'||! /^[a-f0-9]{64}-[1-9]\d*\.json$/.test(b.key))fail(400,'신고 번호를 확인해 주세요.');
    await blob.del('community/reports/'+b.key);return {status:200,data:{resolved:true}};
   }
   await visible(b.id,s);if(typeof b.enabled!=='boolean')fail(400,'변경할 상태를 확인해 주세요.');
   const path=marker(b.action==='pin'?'pins':'hidden',b.id);
   if(b.enabled)await once(path,{postId:b.id,by:s.userId,at:now()});else await blob.del(path);
   return {status:200,data:{saved:true}};
  }
  return null;
 }
 return {handle,decorate,notices,admin};
}
module.exports={createFeatures,validateImage};
