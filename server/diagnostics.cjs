const areas=new Set(['session','work_history','device_history']);
const codes=new Set(['read_failed','save_failed','backup_failed','rows_recovered','restore_failed','login_ok','restore_ok','login_rejected']);
function details(area,code){
 const prefix={session:'AUTH',work_history:'WORK',device_history:'DEVICE'}[area];
 const number={read_failed:'101',save_failed:'102',backup_failed:'103',restore_failed:'104',login_rejected:'105',rows_recovered:'010',login_ok:'000',restore_ok:'001'}[code];
 const stage={read_failed:'history_read',save_failed:'storage_write',backup_failed:'recovery_backup',restore_failed:'session_restore',login_rejected:'login',rows_recovered:'recovery',login_ok:'login',restore_ok:'session_restore'}[code];
 return {error_id:`${prefix}-${number}`,stage,severity:code.endsWith('failed')?'error':code==='login_rejected'?'warning':'info'};
}
function createDiagnostics({log=entry=>console.info(JSON.stringify(entry)),now=Date.now}={}) {
 const recent=new Map();
 return (req,res)=>{
  res.setHeader('Cache-Control','private, no-store');
  res.setHeader('X-Content-Type-Options','nosniff');
  if(req.method!=='POST'){res.setHeader('Allow','POST');return res.status(405).end();}
  if(req.headers.origin!=='https://suho-angel.vercel.app')return res.status(403).end();
  if(Number(req.headers['content-length']||0)>1024)return res.status(413).end();
  let body;
  try {body=typeof req.body==='string'?JSON.parse(req.body):req.body;}catch{return res.status(400).end();}
  if(!body||Array.isArray(body)||Object.keys(body).some(k=>!['trace','area','code','error_id'].includes(k))||
     (typeof body.trace!=='string'||!/^[a-f0-9]{32}$/.test(body.trace))||!areas.has(body.area)||!codes.has(body.code))return res.status(400).end();
  if(body.error_id!=null&&body.error_id!==details(body.area,body.code).error_id)return res.status(400).end();
  const time=now(),key=`${body.trace}/${body.area}/${body.code}`;
  for(const [key,at] of recent)if(time-at>=60000)recent.delete(key);
  if(recent.has(key))return res.status(204).end();
  if(recent.size>=1000)return res.status(429).end();
  recent.set(key,time);
  // Client-reported diagnostics, not proof of an authenticated account action.
  log({event:'suho_diagnostic',source:'client',at:new Date(time).toISOString(),
    trace:body.trace,area:body.area,code:body.code,...details(body.area,body.code)});
  return res.status(204).end();
 };
}
module.exports={createDiagnostics,details};
