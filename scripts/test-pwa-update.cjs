// Required updates invalidate open tabs after their checkpoint finishes.
const {chromium} = require('playwright');
const http = require('node:http');
const fs = require('node:fs');
const assert = require('node:assert/strict');
(async () => {
  let revision = 1;
  const worker = fs.readFileSync('build/web/service-worker.js', 'utf8');
  const updater = fs.readFileSync('web/pwa.js', 'utf8');
  const server = http.createServer((req, res) => {
    res.setHeader('Cache-Control', 'no-store');
    if (req.url === '/service-worker.js') {
      res.setHeader('Content-Type', 'text/javascript; charset=utf-8');
      res.end(worker.replace(/const CACHE = .*?;/, `const CACHE = 'suho-shell-test-${revision}';`)
        .replace(/const ASSETS = .*?;/, "const ASSETS = ['index.html', 'pwa.js'];"));
    } else if (req.url.startsWith('/pwa.js')) {
      res.setHeader('Content-Type', 'text/javascript; charset=utf-8'); res.end(updater);
    } else {
      res.setHeader('Content-Type', 'text/html; charset=utf-8');
      res.end('<!doctype html><html><body><p>앱</p><script src="pwa.js?update=2"></script></body></html>');
    }
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const browser = await chromium.launch({executablePath: process.env.CHROMIUM_PATH || '/usr/bin/chromium', args: ['--no-sandbox']});
  try {
    const page = await browser.newPage();
    await page.goto(`http://127.0.0.1:${server.address().port}/`);
    await page.evaluate(() => navigator.serviceWorker.ready);
    await page.waitForFunction(() => navigator.serviceWorker.controller !== null);
    assert.equal(await page.locator('#pwa-update').count(), 0);
    let navigations = 0;
    page.on('framenavigated', frame => { if (frame === page.mainFrame()) navigations++; });
    // Let the initial registration/update request finish before changing the fixture.
    await page.waitForTimeout(1000);
    await page.evaluate(() => {
      window.suhoBeforeUpdate = () => new Promise(resolve => {
        window.checkpointStarted = true;
        window.releaseCheckpoint = resolve;
      });
    });
    revision = 2;
    await page.evaluate(async () => (await navigator.serviceWorker.ready).update());
    await page.waitForFunction(() => window.checkpointStarted === true);
    assert.equal(navigations, 0);
    await Promise.all([page.waitForEvent('load'), page.evaluate(() => window.releaseCheckpoint())]);
    assert.equal(navigations, 1);
    assert.equal(await page.locator('#pwa-update').count(), 0);
    assert.equal(await page.evaluate(async () => !!(await navigator.serviceWorker.ready).waiting), false);
    await page.evaluate(() => { window.suhoBeforeUpdate = async () => { throw Error('storage unavailable'); }; });
    revision = 3;
    await page.evaluate(async () => (await navigator.serviceWorker.ready).update());
    await page.getByRole('button', {name:'저장 후 새로고침'}).waitFor();
    assert.equal(navigations, 1);
    await page.evaluate(() => { window.suhoBeforeUpdate = async () => {}; });
    await Promise.all([page.waitForEvent('load'), page.getByRole('button', {name:'저장 후 새로고침'}).click()]);
    assert.equal(navigations, 2);
    console.log('PASS mandatory PWA update checkpoints before reload; failed storage blocks reload and permits retry');
  } finally {
    await browser.close();
    server.closeAllConnections();
    await new Promise(resolve => server.close(resolve));
  }
})().catch(error => { console.error(error); process.exit(1); });
