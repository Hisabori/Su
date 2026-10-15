/* Device-local session vault. This is not server-side WebAuthn account authentication.
 * A WebAuthn PRF output derives the non-exportable AES key. No password is stored.
 */
(() => {
  'use strict';
  const KEY = 'suho.passkey.session.v1';
  const enc = new TextEncoder();
  const dec = new TextDecoder();
  const fields = ['jwt_access_token', 'jwt_refresh_token', 'auth_user_id', 'auth_device'];
  let session = Object.create(null);
  let pending = false;
  const fail = code => { const error = new Error(code); error.code = code; throw error; };
  const random = n => crypto.getRandomValues(new Uint8Array(n));
  const bytes = value => new Uint8Array(value);
  const b64 = value => btoa(String.fromCharCode(...bytes(value))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
  function unb64(value) {
    if (typeof value !== 'string' || !/^[A-Za-z0-9_-]+$/.test(value)) fail('invalid_vault');
    const text = value.replace(/-/g, '+').replace(/_/g, '/');
    return Uint8Array.from(atob(text + '='.repeat((4 - text.length % 4) % 4)), c => c.charCodeAt(0));
  }
  const supported = () => !!(window.isSecureContext && window.PublicKeyCredential && navigator.credentials && crypto.subtle);
  const enrolled = () => localStorage.getItem(KEY) !== null;
  function vault() {
    let v;
    try { v = JSON.parse(localStorage.getItem(KEY)); } catch (_) { fail('invalid_vault'); }
    if (!v || v.version !== 1 || v.origin !== location.origin || typeof v.user !== 'string' ||
        !/^\d+$/.test(v.user) || !v.credential || !v.salt || !v.iv || !v.cipher) fail('invalid_vault');
    if (unb64(v.salt).length !== 32 || unb64(v.iv).length !== 12) fail('invalid_vault');
    return v;
  }
  function parseSession(json) {
    let data;
    try { data = JSON.parse(json); } catch (_) { fail('invalid_session'); }
    if (!data || typeof data.jwt_access_token !== 'string' || !data.jwt_access_token ||
        typeof data.auth_user_id !== 'string' || !/^[1-9]\d*$/.test(data.auth_user_id)) fail('invalid_session');
    const filtered = Object.create(null);
    for (const key of fields) {
      if (data[key] != null && typeof data[key] !== 'string') fail('invalid_session');
      if (data[key] != null) filtered[key] = data[key];
    }
    return filtered;
  }
  async function aes(prf, salt) {
    if (!prf || bytes(prf).length !== 32) fail('prf_unsupported');
    const input = await crypto.subtle.importKey('raw', prf, 'HKDF', false, ['deriveKey']);
    return crypto.subtle.deriveKey({name: 'HKDF', hash: 'SHA-256', salt,
      info: enc.encode(`suho.session.v1:${location.origin}`)}, input,
      {name: 'AES-GCM', length: 256}, false, ['encrypt', 'decrypt']);
  }
  const aad = v => enc.encode(JSON.stringify([v.version, v.origin, v.credential, v.salt, v.user]));
  async function seal(data, credential, salt, prf) {
    const v = {version: 1, origin: location.origin, credential, salt: b64(salt), user: data.auth_user_id, iv: b64(random(12))};
    const key = await aes(prf, salt);
    v.cipher = b64(await crypto.subtle.encrypt({name: 'AES-GCM', iv: unb64(v.iv), additionalData: aad(v)}, key, enc.encode(JSON.stringify(data))));
    localStorage.setItem(KEY, JSON.stringify(v));
    session = data;
  }
  async function assertion(v) {
    const credential = await navigator.credentials.get({publicKey: {
      challenge: random(32), rpId: location.hostname,
      allowCredentials: [{id: unb64(v.credential), type: 'public-key'}],
      userVerification: 'required', timeout: 60000,
      extensions: {prf: {eval: {first: unb64(v.salt)}}},
    }});
    if (!credential || b64(credential.rawId) !== v.credential) fail('credential_mismatch');
    const prf = credential.getClientExtensionResults().prf?.results?.first;
    if (!prf) fail('prf_unsupported');
    return prf;
  }
  async function run(operation) {
    if (pending) return JSON.stringify({ok: false, code: 'busy'});
    pending = true;
    try { return JSON.stringify({ok: true, ...await operation()}); }
    catch (error) { return JSON.stringify({ok: false, code: error.code || error.name || 'failed'}); }
    finally { pending = false; }
  }
  window.suhoPasskeys = Object.freeze({
    isEnrolled: enrolled,
    read: key => fields.includes(key) ? session[key] ?? null : null,
    write: (key, value) => { if (fields.includes(key)) session[key] = value; },
    remove: key => { if (fields.includes(key)) delete session[key]; },
    lock: () => { session = Object.create(null); },
    status: () => run(async () => ({supported: supported(), enrolled: enrolled(), unlocked: !!session.jwt_access_token})),
    enroll: (json, label) => run(async () => {
      if (!supported()) fail('unsupported');
      if (enrolled()) fail('already_enrolled');
      const data = parseSession(json);
      const salt = random(32);
      const credential = await navigator.credentials.create({publicKey: {
        challenge: random(32), rp: {id: location.hostname, name: '수호천사 기기 로그인'},
        user: {id: random(32), name: label || `수호천사 ${data.auth_user_id}`, displayName: '수호천사 로그인 세션'},
        pubKeyCredParams: [{type: 'public-key', alg: -7}, {type: 'public-key', alg: -257}],
        authenticatorSelection: {residentKey: 'required', userVerification: 'required'},
        attestation: 'none', timeout: 60000, extensions: {prf: {eval: {first: salt}}},
      }});
      if (!credential) fail('NotAllowedError');
      const extension = credential.getClientExtensionResults().prf;
      if (!extension?.enabled) fail('prf_unsupported');
      const id = b64(credential.rawId);
      const prf = extension.results?.first || await assertion({credential: id, salt: b64(salt)});
      await seal(data, id, salt, prf);
      return {};
    }),
    unlock: () => run(async () => {
      session = Object.create(null);
      if (!supported()) fail('unsupported');
      const v = vault();
      const prf = await assertion(v);
      const key = await aes(prf, unb64(v.salt));
      let plain;
      try { plain = await crypto.subtle.decrypt({name: 'AES-GCM', iv: unb64(v.iv), additionalData: aad(v)}, key, unb64(v.cipher)); }
      catch (_) { fail('invalid_vault'); }
      const data = parseSession(dec.decode(plain));
      if (data.auth_user_id !== v.user) fail('invalid_vault');
      session = data;
      return {};
    }),
    refresh: json => run(async () => {
      if (!supported()) fail('unsupported');
      const data = parseSession(json), v = vault();
      if (data.auth_user_id !== v.user) fail('different_account');
      const prf = await assertion(v);
      await seal(data, v.credential, unb64(v.salt), prf);
      return {};
    }),
    forget: () => run(async () => { localStorage.removeItem(KEY); session = Object.create(null); return {}; }),
  });
})();
