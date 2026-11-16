const blob=require('@vercel/blob');
const {createAccess,AccessError}=require('../server/access.cjs');
const access=createAccess({blob,adminIds:(process.env.COMMUNITY_ADMIN_IDS||'').split(',').map(Number).filter(n=>Number.isSafeInteger(n)&&n>0)});
module.exports=async(req,res)=>{
 res.setHeader('Cache-Control','private, no-store');res.setHeader('X-Content-Type-Options','nosniff');
 const origin=req.headers.origin;
 if(origin&&!['https://suho-angel.vercel.app','http://127.0.0.1:8765'].includes(origin))return res.status(403).json({message:'허용되지 않은 주소입니다.',error_code:'ACC-403'});
 if(origin){res.setHeader('Access-Control-Allow-Origin',origin);res.setHeader('Vary','Origin');}
 res.setHeader('Access-Control-Allow-Headers','Content-Type, Authorization, X-Community-Session');res.setHeader('Access-Control-Allow-Methods','POST, OPTIONS');
 if(req.method==='OPTIONS')return res.status(204).end();
 if(req.method!=='POST')return res.status(405).end();
 try {const body=typeof req.body==='string'?JSON.parse(req.body):req.body;const result=await access.handle(body,req.headers);return res.status(result.status).json(result.data);}
 catch(error){const known=error instanceof AccessError;const code=known?error.code:error instanceof SyntaxError?'ACC-003':'ACC-202';console.warn(JSON.stringify({event:'access_error',error_id:code}));return res.status(known?error.status:error instanceof SyntaxError?400:503).json({message:known?error.message:'접속 기록을 처리하지 못했습니다.',error_code:code});}
};
