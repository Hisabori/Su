// Mock backend + real browser WebAuthn/PRF. Never sends credentials to the live API.
const {chromium} = require('playwright');
const assert = require('node:assert/strict');
(async () => {
  const browser = await chromium.launch({executablePath: process.env.CHROMIUM_PATH || '/usr/bin/chromium', headless: true, args: ['--no-sandbox', '--disable-dev-shm-usage']});
  try {
    const context = await browser.newContext({viewport: {width: 430, height: 932}});
    let expired = false, logins = 0, validations = 0;
    await context.route('https://suho-angel.vercel.app/api/community',route=>route.fulfill({status:503,headers:{'access-control-allow-origin':'*'},body:'unavailable in this fixture'}));
 await context.route('https://api-suho1004.innaim.com/**', async route => {
      const request = route.request(), endpoint = new URL(request.url()).pathname;
      if (request.method() === 'OPTIONS') return route.fulfill({status: 204, headers: {'access-control-allow-origin': '*', 'access-control-allow-methods': 'PUT', 'access-control-allow-headers': 'authorization,content-type'}});
      let result;
      if (endpoint.endsWith('/login')) { logins++; result = {ret: 1, user_id: 42, access_token: 'passkey-flow-fake-token'}; }
      else if (endpoint.endsWith('/validate_token')) { validations++; result = {ret: expired ? 0 : 1}; }
      else if (endpoint.endsWith('/work_info')) result = {ret: 1, work: {work_id: 8, work_name: '검증 업무'}, process: {current_version_id: 1}, steps: [{step_id: 1, step_name: '첫 단계', start_ment: '확인', work_seconds: 0}]};
      else throw new Error(`Unexpected API: ${endpoint}`);
      return route.fulfill({status: 200, headers: {'content-type': 'application/json; charset=utf-8', 'access-control-allow-origin': '*'}, body: JSON.stringify(result)});
    });
    const page = await context.newPage(), errors = [];
    page.on('pageerror', error => errors.push(error.message));
    const cdp = await context.newCDPSession(page);
    await cdp.send('WebAuthn.enable');
    await cdp.send('WebAuthn.addVirtualAuthenticator', {options: {protocol: 'ctap2', ctap2Version: 'ctap2_1', transport: 'internal', hasResidentKey: true, hasUserVerification: true, isUserVerified: true, automaticPresenceSimulation: true, hasPrf: true}});
    async function ready() {
      await page.locator('flutter-view').waitFor({timeout: 60000});
      await page.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
    }
    async function passwordLogin() {
      await page.locator('input').nth(0).click(); await page.keyboard.type('demo');
      await page.locator('input').nth(1).click(); await page.keyboard.type('not-a-real-password');
      await page.getByRole('button', {name: '로그인', exact: true}).click();
      await page.getByRole('button', {name: '패스키 로그인 설정', exact: true}).waitFor();
    }
    await page.goto(process.env.PWA_TEST_URL || 'http://localhost:8765/'); await ready();
    await passwordLogin();
    await page.getByRole('button', {name: '패스키 로그인 설정', exact: true}).click();
    await page.getByRole('button', {name: '이 기기에 패스키 설정', exact: true}).click();
    await page.getByText('패스키 로그인을 설정했습니다.', {exact: true}).last().waitFor();
    assert.equal(await page.evaluate(() => suhoPasskeys.isEnrolled()), true);
    const legacyKeys = await page.evaluate(() => Object.keys(localStorage).filter(key => /\.(jwt_access_token|jwt_refresh_token|auth_user_id|auth_device)$/.test(key)));
    assert.deepEqual(legacyKeys, []);
    console.log('PASS UI enrollment removes legacy token copies');
    await page.getByRole('button', {name: 'Back', exact: true}).click();
    await page.getByRole('button', {name: '앱 잠그기', exact: true}).click();
    await page.getByRole('button', {name: '이 기기 패스키로 로그인', exact: true}).waitFor();
    assert.equal(await page.evaluate(() => suhoPasskeys.read('jwt_access_token')), null);
    await page.getByRole('button', {name: '이 기기 패스키로 로그인', exact: true}).click();
    await page.getByRole('button', {name: '작업 시작', exact: true}).waitFor();
    assert.equal(logins, 1); assert.ok(validations >= 1);
    console.log('PASS app lock and passkey login validate the existing server session');
    await page.reload(); await ready();
    await page.getByRole('button', {name: '이 기기 패스키로 로그인', exact: true}).waitFor();
    assert.equal(await page.evaluate(() => suhoPasskeys.read('jwt_access_token')), null);
    expired = true;
    await page.getByRole('button', {name: '이 기기 패스키로 로그인', exact: true}).click();
    await page.getByText('저장된 로그인 세션을 서버에서 확인하지 못했습니다. 연결을 확인하거나 비밀번호로 다시 로그인해 주세요.', {exact: true}).last().waitFor();
    assert.equal(await page.evaluate(() => suhoPasskeys.read('jwt_access_token')), null);
    console.log('PASS reload requires passkey; expired sessions stay on password login');
    expired = false;
    await passwordLogin();
    await page.getByRole('button', {name: '패스키 로그인 설정', exact: true}).click();
    await page.getByRole('button', {name: '로그인 정보 갱신', exact: true}).click();
    await page.getByText('패스키의 로그인 정보를 갱신했습니다.', {exact: true}).last().waitFor();
    await page.getByRole('button', {name: '이 기기의 패스키 로그인 해제', exact: true}).click();
    await page.getByRole('button', {name: '해제', exact: true}).click();
    await page.getByText('이 기기의 패스키 로그인을 해제했습니다.', {exact: true}).last().waitFor();
    assert.equal(await page.evaluate(() => suhoPasskeys.isEnrolled()), false);
    assert.equal(errors.length, 0, errors.join('\n'));
    console.log('PASS explicit session refresh and disable preserve normal password sign-in');
  } catch (error) {
    const pages = browser.contexts().flatMap(c => c.pages());
    if (pages[0]) await pages[0].screenshot({path: '/tmp/suho-passkey-flow-failure.png'});
    throw error;
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exit(1); });
