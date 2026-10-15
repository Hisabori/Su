// Cache only public app files. Login and API responses never enter the cache.
if ('serviceWorker' in navigator && window.isSecureContext) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('service-worker.js', {updateViaCache: 'none'})
      .catch(() => {}); // The app remains usable when storage is unavailable.
  });
}
window.setTimeout(() => {
  const text = document.getElementById('loading-text');
  if (text) text.textContent = '연결이 느립니다. 잠시 기다리거나 다시 불러와 주세요.';
  const reload = document.getElementById('reload');
  if (reload) reload.style.display = 'inline-block';
}, 25000);
