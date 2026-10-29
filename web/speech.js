// Device/browser speech only; no application audio service or API key.
(() => {
  'use strict';
  const synth = window.speechSynthesis;
  const available = !!synth && typeof window.SpeechSynthesisUtterance === 'function';
  let generation = 0, active = null, lastState = null, stateCallback = null;
  let voices = available ? synth.getVoices() : [];
  if (available) synth.addEventListener('voiceschanged', () => { voices = synth.getVoices(); });
  function voiceScore(voice) {
    const name = voice.name.toLowerCase();
    return (/premium|프리미엄/.test(name) ? 100 : 0) +
      (/enhanced|고품질|natural|neural|자연/.test(name) ? 70 : 0) +
      (/google|microsoft/.test(name) ? 20 : 0) + (voice.localService ? 5 : 0);
  }
  function selectVoice() {
    voices = synth.getVoices();
    return voices.filter(v => /^ko(?:[-_]|$)/i.test(v.lang))
      .sort((a, b) => voiceScore(b) - voiceScore(a))[0];
  }
  function notify(callback, value) {
    if (lastState === value) return;
    lastState = value;
    if (typeof callback === 'function') callback(value);
  }
  function stop() {
    generation++;
    if (stateCallback) notify(stateCallback, false);
    stateCallback = null;
    if (active) active.cancel();
    active = null;
    if (available) synth.cancel();
    lastState = false;
  }
  function chunks(text) {
    // Keep decimals, URLs and the content intact; blank paragraphs mark a pause.
    const pieces = text.replace(/\r\n?/g, '\n').split(/([!?。！？]\s+|\.\s+|\n\s*\n)/u);
    const result = [];
    for (let i = 0; i < pieces.length; i += 2) {
      const part = (pieces[i] + (pieces[i + 1] || '').trim()).replace(/\s+/g, ' ').trim();
      if (part) result.push(part);
    }
    return result;
  }
  async function speak(text, callback, speed = 1) {
    stop();
    const id = generation;
    stateCallback = callback;
    if (!available) return JSON.stringify({ok: false, code: 'unsupported'});
    const parts = chunks(text);
    if (!parts.length) return JSON.stringify({ok: true});
    try {
      for (let i = 0; i < parts.length; i++) {
        if (id !== generation) return JSON.stringify({ok: true, cancelled: true});
        if (i) await new Promise(resolve => setTimeout(resolve, 180));
        if (id !== generation) return JSON.stringify({ok: true, cancelled: true});
        await new Promise((resolve, reject) => {
          const utterance = new SpeechSynthesisUtterance(parts[i]);
          utterance.lang = 'ko-KR';
          utterance.rate = 0.95 * (Number.isFinite(speed) ? Math.min(1.1, Math.max(.85, speed)) : 1);
          utterance.pitch = 1;
          utterance.volume = 1;
          const voice = selectVoice();
          if (voice) utterance.voice = voice;
          let done = false;
          const finish = error => {
            if (done) return;
            done = true;
            clearTimeout(timer);
            utterance.onstart = utterance.onend = utterance.onerror = null;
            if (active?.utterance === utterance) active = null;
            error ? reject(error) : resolve();
          };
          const timer = setTimeout(() => {
            finish('timeout');
            if (id === generation) synth.cancel();
          }, 60000);
          active = {utterance, cancel: () => { notify(callback, false); finish(); }};
          utterance.onstart = () => { if (id === generation) notify(callback, true); };
          utterance.onend = () => finish();
          utterance.onerror = event => finish(event.error || 'speech-error');
          try { synth.speak(utterance); } catch (_) { finish('speech-error'); }
        });
      }
      return JSON.stringify(id === generation ? {ok: true} : {ok: true, cancelled: true});
    } catch (code) {
      return JSON.stringify({ok: false, code: String(code)});
    } finally {
      if (id === generation) { notify(callback, false); stateCallback = null; }
    }
  }
  window.suhoSpeech = Object.freeze({speak, stop, available});
})();
