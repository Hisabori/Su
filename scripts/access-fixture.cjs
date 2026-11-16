// All browser flows intercept access events: test credentials never hit production.
module.exports=async(context,{records=[]}={})=>{
 const events=[];
 await context.route('https://suho-angel.vercel.app/api/access',async route=>{
  const headers={'access-control-allow-origin':'*','access-control-allow-methods':'POST, OPTIONS','access-control-allow-headers':'content-type,authorization,x-community-session','content-type':'application/json; charset=utf-8'};
  if(route.request().method()==='OPTIONS')return route.fulfill({status:204,headers});
  const body=route.request().postDataJSON();
  if(body.action==='open'){
   events.push(body);
   return route.fulfill({status:200,headers,body:JSON.stringify({access_recorded:true,event_id:body.event_id})});
  }
  return route.fulfill({status:200,headers,body:JSON.stringify({records,cursor:null})});
 });
 return events;
};
