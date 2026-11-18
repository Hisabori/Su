// Required shell updates; server results and user storage are never cleared.
if ('serviceWorker' in navigator && window.isSecureContext) {
  let refreshing = false;
  async function prepareRefresh() {
    let banner = document.getElementById('pwa-update');
    if (!banner) {
      banner = document.createElement('aside');
      banner.id = 'pwa-update';
      banner.setAttribute('role', 'alert');
      banner.textContent = '필수 업데이트를 준비하고 있어요. 진행 중인 작업을 저장합니다.';
      document.body.append(banner);
    }
    document.querySelector('flutter-view')?.setAttribute('inert', '');
    if (typeof window.suhoBeforeUpdate === 'function') await window.suhoBeforeUpdate();
    banner.textContent = '최신 버전으로 새로고침합니다.';
  }
  navigator.serviceWorker.addEventListener('message', async event => {
    if (event.data?.type !== 'PREPARE_REFRESH' || refreshing) return;
    refreshing = true;
    try {
      await prepareRefresh();
      event.ports[0]?.postMessage({ready:true});
    } catch (_) {
      event.ports[0]?.postMessage({ready:false});
      const banner = document.getElementById('pwa-update');
      banner.textContent = '작업 임시저장을 확인하지 못했습니다. 저장 공간을 확인하고 다시 시도해 주세요.';
      const retry = document.createElement('button');
      retry.textContent = '저장 후 새로고침';
      retry.onclick = async () => { try { await prepareRefresh(); window.location.reload(); } catch (_) { banner.textContent = '임시저장을 확인하지 못했습니다. 저장 공간을 확인해 주세요.'; banner.append(retry); retry.disabled = false; } };
      banner.append(retry);
      refreshing = false;
    }
  });
  window.addEventListener('load', async () => {
    try {
      const registration = await navigator.serviceWorker.register('service-worker.js', {updateViaCache:'none'});
      // Migrate a worker installed by an older app as well.
      registration.waiting?.postMessage({type:'ACTIVATE_UPDATE'});
      await registration.update();
      window.setInterval(() => { if (!document.hidden) registration.update().catch(() => {}); }, 60000);
      document.addEventListener('visibilitychange', () => { if (!document.hidden) registration.update().catch(() => {}); });
    } catch (_) { /* An offline launch retains the last complete shell. */ }
  });
}
window.setTimeout(() => {
  const text = document.getElementById('loading-text');
  if (text) text.textContent = '연결이 느립니다. 잠시 기다리거나 다시 불러와 주세요.';
  const reload = document.getElementById('reload');
  if (reload) reload.style.display = 'inline-block';
}, 25000);
