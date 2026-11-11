const test=require('node:test');
const assert=require('node:assert/strict');
const {createDiagnostics}=require('../server/diagnostics.cjs');
function call(handler,body,headers={origin:'https://suho-angel.vercel.app'},method='POST') {
 const response={statusCode:200,headers:{},setHeader(k,v){this.headers[k]=v;},status(n){this.statusCode=n;return this;},end(){return this;}};
 handler({method,headers,body},response);return response;
}
const event={trace:'a'.repeat(32),area:'session',code:'save_failed'};
test('only fixed diagnostics are logged; no extra content can enter logs',()=>{
 const logs=[],handler=createDiagnostics({log:e=>logs.push(e),now:()=>100000});
 assert.equal(call(handler,event).statusCode,204);
 assert.deepEqual(logs,[{event:'suho_diagnostic',source:'client',at:new Date(100000).toISOString(),...event,error_id:'AUTH-102',stage:'storage_write',severity:'error'}]);
 for(const body of [{...event,password:'secret'},{...event,code:'secret'}, {...event,trace:'username'},null,'broken']) {
  assert.equal(call(handler,body).statusCode,400);
 }
 assert.equal(logs.length,1);
});
test('duplicate diagnostics are suppressed for one minute and never cached',()=>{
 let time=100000;const logs=[],handler=createDiagnostics({log:e=>logs.push(e),now:()=>time});
 assert.equal(call(handler,event).headers['Cache-Control'],'private, no-store');
 call(handler,event);assert.equal(logs.length,1);
 time+=60000;call(handler,event);assert.equal(logs.length,2);
});
test('untrusted origins and unsupported methods never reach logging',()=>{
 const handler=createDiagnostics({log:()=>assert.fail('unexpected log')});
 assert.equal(call(handler,event,{}).statusCode,403);
 assert.equal(call(handler,event,{origin:'https://example.com'}).statusCode,403);
 assert.equal(call(handler,event,{},'GET').statusCode,405);
 assert.equal(call(handler,event,{origin:'https://suho-angel.vercel.app','content-length':'2000'}).statusCode,413);
});
