const blob=require('@vercel/blob');
const {createCommunity,CommunityError}=require('../server/community.cjs');
const handler=createCommunity({blob});
module.exports=async(req,res)=>{
 res.setHeader('Cache-Control','private, no-store');
 res.setHeader('X-Content-Type-Options','nosniff');
 const origin=req.headers.origin;
 const allowed=['https://suho-angel.vercel.app','http://127.0.0.1:8765'];
 if(origin&&!allowed.includes(origin))return res.status(403).json({message:'이 주소에서는 요청할 수 없습니다.'});
 if(origin){res.setHeader('Access-Control-Allow-Origin',origin);res.setHeader('Vary','Origin');}
 res.setHeader('Access-Control-Allow-Methods','POST, OPTIONS');
 res.setHeader('Access-Control-Allow-Headers','Content-Type, Authorization, X-Community-Session');
 if(req.method==='OPTIONS')return res.status(204).end();
 if(req.method!=='POST'){res.setHeader('Allow','POST, OPTIONS');return res.status(405).json({message:'지원하지 않는 요청입니다.'});}
 try {
  const body=typeof req.body==='string'?JSON.parse(req.body):req.body;
  const reply=await handler(body,req.headers);
  return res.status(reply.status).json(reply.data);
 }catch(error){
  const status=error instanceof CommunityError?error.status:error instanceof SyntaxError?400:503;
  return res.status(status).json({message:error instanceof CommunityError?error.message:status===400?'요청 내용을 확인해 주세요.':'커뮤니티에 연결하지 못했습니다. 잠시 후 다시 시도해 주세요.'});
 }
};
