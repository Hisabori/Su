// Read-only deployment check: no credentials, posts, or upstream login calls.
const assert=require('node:assert/strict');
(async()=>{
 const base='https://suho-angel.vercel.app';
 let last;
 for(let attempt=0;attempt<12;attempt++){
  try{
   const response=await fetch(base+'/api/community',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({action:'list'}),signal:AbortSignal.timeout(15000)});
   assert.equal(response.status,401);
   assert.match(response.headers.get('cache-control'),/no-store/);
   assert.equal((await response.json()).message,'커뮤니티를 이용하려면 다시 로그인해 주세요.');
   const shell=await fetch(base+'/',{signal:AbortSignal.timeout(15000)});
   assert.equal(shell.status,200);assert.match(await shell.text(),/수호천사/);
   console.log('PASS live app shell and community endpoint; unauthenticated access is rejected and not cached');return;
  }catch(error){last=error;}
  if(attempt<11)await new Promise(resolve=>setTimeout(resolve,15000));
 }
 throw last;
})().catch(error=>{console.error(error);process.exit(1)});
