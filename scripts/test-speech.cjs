const vm = require('node:vm');
const fs = require('node:fs');
const assert = require('node:assert/strict');
const source = fs.readFileSync('web/speech.js', 'utf8');
function fixture() {
  const spoken = [], pending = [], listeners = {};
  const voices = [
    {name:'Natural English',lang:'en-US',localService:true},
    {name:'Korean basic',lang:'ko-KR',localService:true},
    {name:'Korean Enhanced',lang:'ko-KR',localService:true},
  ];
  const synth = {getVoices:()=>voices,addEventListener:(e,f)=>{listeners[e]=f;},
    cancel:()=>{},speak:u=>{spoken.push(u);pending.push(u);u.onstart?.();}};
  const window = {speechSynthesis:synth,SpeechSynthesisUtterance:class {constructor(t){this.text=t;}}};
  vm.runInNewContext(source,{window,SpeechSynthesisUtterance:window.SpeechSynthesisUtterance,setTimeout,clearTimeout});
  return {api:window.suhoSpeech,spoken,pending,voices,listeners};
}
(async()=>{
  const f=fixture(), state=[];
  const result=f.api.speak('첫 질문인가요?  용량은 0.5%입니다.',v=>state.push(v));
  assert.equal(f.spoken[0].voice.name,'Korean Enhanced');
  assert.equal(f.spoken[0].lang,'ko-KR');assert.equal(f.spoken[0].rate,.95);
  f.pending.shift().onend();
  await new Promise(r=>setTimeout(r,210));
  assert.equal(f.spoken[1].text,'용량은 0.5%입니다.');
  f.pending.shift().onend();
  assert.equal(JSON.parse(await result).ok,true);assert.deepEqual(state,[true,false]);
  console.log('PASS Korean voice preference, natural rate, sentence pause and decimal preservation');
  const a=f.api.speak('오래된 질문입니다.',()=>{}),old=f.spoken.at(-1);
  const b=f.api.speak('새 질문입니다.',()=>{}),latest=f.spoken.at(-1);
  assert.equal(old.onend,null); latest.onend();
  assert.equal(JSON.parse(await a).cancelled,true);assert.equal(JSON.parse(await b).ok,true);
  const c=f.api.speak('중지합니다.',()=>{});f.api.stop();assert.equal(JSON.parse(await c).cancelled,true);
  console.log('PASS replacement and stop cancel old utterances without replaying them');
  const denied=f.api.speak('읽어주세요.',()=>{});f.spoken.at(-1).onerror({error:'not-allowed'});
  assert.equal(JSON.parse(await denied).code,'not-allowed');
  const fallback=fixture();fallback.voices.length=0;
  const missing=fallback.api.speak('한국어입니다.',()=>{});assert.equal(fallback.spoken[0].lang,'ko-KR');fallback.spoken[0].onend();await missing;
  console.log('PASS autoplay rejection and empty voice list settle without a stuck reading state');
})().catch(e=>{console.error(e);process.exit(1)});
