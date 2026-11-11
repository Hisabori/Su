const {createHash}=require('node:crypto');
const INTERVAL=600000,RETENTION=7*86400000;
const id=v=>v==null?'':String(v).trim();
const number=v=>!['number','string'].includes(typeof v)||(typeof v==='string'&&!v.trim())?null:Number.isFinite(Number(v))?Number(v):null;
function createCollector({blob,read,write,upstream,fail,now}) {
 function assignment(s) {
  if(!s.partner||!s.kiosk)fail(409,'서버 기록을 연결하려면 근무를 마친 뒤 다시 로그인해 주세요.','DVC-002');
  return {partner:s.partner,kiosk:s.kiosk};
 }
 return async(b,s,token)=>{
  if(!['device_history','device_sample'].includes(b.action))return null;
  if(Object.keys(b).some(k=>!['action','cursor'].includes(k)))fail(400,'기기 조회 요청을 확인해 주세요.','DVC-003');
  const device=assignment(s);
  const hash=createHash('sha256').update(JSON.stringify([device.partner,device.kiosk])).digest('hex');
  const prefix=`collectors/v1/${hash}/`;
  if(b.action==='device_history') {
   if(b.cursor!=null&&(typeof b.cursor!=='string'||b.cursor.length>2048))fail(400,'기록 위치를 확인해 주세요.','DVC-003');
   try {
    const page=await blob.list({prefix,limit:100,...(b.cursor?{cursor:b.cursor}:{})});
    const rows=[];
    // Bound parallel Blob reads instead of opening 100 requests at once.
    for(let i=0;i<page.blobs.length;i+=10)rows.push(...await Promise.all(page.blobs.slice(i,i+10).map(x=>read(x.pathname))));
    const records=rows.filter(r=>r&&r.partner===device.partner&&r.kiosk===device.kiosk&&
      Number.isFinite(Date.parse(r.at))&&Date.parse(r.at)>=now()-RETENTION&&Date.parse(r.at)<=now());
    const reachedOld=rows.some(r=>r&&Date.parse(r.at)<now()-RETENTION);
    records.sort((a,b)=>Date.parse(a.at)-Date.parse(b.at));
    console.info(JSON.stringify({event:'collector_history',source:'server',trace:s.trace,device_ref:hash.slice(0,16),error_id:'DVC-000',stage:'history_read',count:records.length}));
    return {status:200,data:{device,records,cursor:page.hasMore&&!reachedOld?page.cursor:null,interval_minutes:10,window_days:7}};
   }catch {fail(503,'서버 수거기 기록을 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.','DVC-201');}
  }
  const at=now(),bucket=Math.floor(at/INTERVAL)*INTERVAL;
  const path=prefix+String(9999999999999-bucket).padStart(13,'0')+'.json';
  let prior;
  try {prior=await read(path);}catch {fail(503,'서버 기록 저장소를 확인하지 못했습니다.','DVC-202');}
  if(prior)return {status:200,data:{reading:prior,cached:true}};
  let reading={...device,at:new Date(at).toISOString(),name:device.partner,current:null,capacity:null,available:null,error:null,error_code:null};
  try {
   const reply=await upstream('/api/admin/kiosk_info',{partnerId:device.partner},token,false);
   if(reply.status!==200||!Array.isArray(reply.data.kiosks))throw Error('upstream');
   const row=reply.data.kiosks.find(r=>id(r.kioskId)===device.kiosk);
   if(!row){reading.error='배정된 수거기를 찾을 수 없습니다.';reading.error_code='DVC-102';}
   else {
    reading.name=typeof row.name==='string'?row.name.slice(0,100):device.partner;
    reading.current=number(row.currentCapacity);reading.capacity=number(row.maxCapacity);
    reading.available=row.isAvailable===true||row.isAvailable===1?true:row.isAvailable===false||row.isAvailable===0?false:null;
    if(reading.current==null||reading.current<0||reading.capacity==null||reading.capacity<=0){reading.error='기기 용량을 확인하지 못했습니다.';reading.error_code='DVC-103';}
   }
  }catch {reading.error='수거기 서버에 연결하지 못했습니다.';reading.error_code='DVC-101';}
  try {await write(path,reading);}catch {
   // Concurrent clients share one immutable ten-minute observation.
   let existing;try {existing=await read(path);}catch {}
   if(!existing)fail(503,'수거기 조회 결과를 서버에 저장하지 못했습니다.','DVC-202');
   reading=existing;
  }
  console.info(JSON.stringify({event:'collector_sample',source:'server',trace:s.trace,duration_ms:Math.max(0,now()-at),device_ref:hash.slice(0,16),at:reading.at,error_id:reading.error_code||'DVC-000',stage:reading.error_code?'upstream_read':'stored'}));
  return {status:200,data:{reading,cached:false}};
 };
}
module.exports={createCollector};
