// Only an explicit update action activates a waiting worker and reloads this tab.
if ('serviceWorker' in navigator && window.isSecureContext) {
  let updateRequested = false;
  let reloading = false;
  navigator.serviceWorker.addEventListener('controllerchange', () => {
    if (updateRequested && !reloading) {
      reloading = true;
      window.location.reload();
    }
  });
  window.addEventListener('load', async () => {
    try {
      const registration = await navigator.serviceWorker.register(
        'service-worker.js', {updateViaCache: 'none'});
      function offerUpdate() {
        if (!registration.waiting || !navigator.serviceWorker.controller ||
            document.getElementById('pwa-update')) return;
        const banner = document.createElement('aside');
        banner.id = 'pwa-update';
        banner.setAttribute('aria-label', '앱 업데이트');
        const message = document.createElement('span');
        message.textContent = '새 버전이 준비됐습니다. 작업을 마친 뒤 적용해 주세요.';
        const button = document.createElement('button');
        button.textContent = '새 버전 적용';
        button.onclick = () => {
          if (!window.confirm('열려 있는 다른 수호천사 창에도 새 버전이 적용됩니다. 진행 중인 작업을 마친 뒤 업데이트할까요?')) return;
          if (!registration.waiting) return;
          updateRequested = true;
          button.disabled = true;
          button.textContent = '업데이트 중…';
          registration.waiting.postMessage({type: 'ACTIVATE_UPDATE'});
        };
        banner.append(message, button);
        document.body.append(banner);
      }
      offerUpdate();
      registration.addEventListener('updatefound', () => {
        const worker = registration.installing;
        if (worker) worker.addEventListener('statechange', () => {
          if (worker.state === 'installed') offerUpdate();
        });
      });
      await registration.update();
    } catch (_) { /* Keep the app usable when offline or storage is unavailable. */ }
  });
}
window.setTimeout(() => {
  const text = document.getElementById('loading-text');
  if (text) text.textContent = '연결이 느립니다. 잠시 기다리거나 다시 불러와 주세요.';
  const reload = document.getElementById('reload');
  if (reload) reload.style.display = 'inline-block';
}, 25000);
