const areas=new Set(['session','work_history','device_history']);
const codes=new Set(['read_failed','save_failed','backup_failed','rows_recovered','restore_failed','login_ok','restore_ok','login_rejected']);
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
  if(!body||Array.isArray(body)||Object.keys(body).some(k=>!['trace','area','code'].includes(k))||
     (typeof body.trace!=='string'||!/^[a-f0-9]{32}$/.test(body.trace))||!areas.has(body.area)||!codes.has(body.code))return res.status(400).end();
  const time=now(),key=`${body.trace}/${body.area}/${body.code}`;
  for(const [key,at] of recent)if(time-at>=60000)recent.delete(key);
  if(recent.has(key))return res.status(204).end();
  if(recent.size>=1000)return res.status(429).end();
  recent.set(key,time);
  // Client-reported diagnostics, not proof of an authenticated account action.
  log({event:'suho_diagnostic',source:'client',at:new Date(time).toISOString(),
    trace:body.trace,area:body.area,code:body.code});
  return res.status(204).end();
 };
}
module.exports={createDiagnostics};
