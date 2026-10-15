"""Generate a versioned cache of public build files, never user/API data."""
from pathlib import Path
import hashlib
import json
root = Path('build/web')
files = sorted(p for p in root.rglob('*') if p.is_file() and p.name not in {'service-worker.js', '.DS_Store'} and not p.name.endswith('.map'))
revision = hashlib.sha256()
for path in files:
    revision.update(path.relative_to(root).as_posix().encode())
    revision.update(hashlib.sha256(path.read_bytes()).digest())
version = revision.hexdigest()[:16]
assets = [p.relative_to(root).as_posix() for p in files]
worker = '''const CACHE = 'suho-shell-VERSION';
const ASSETS = ASSET_LIST;
const urls = ASSETS.map(path => new URL(path, self.registration.scope).href);
self.addEventListener('install', event => {
  event.waitUntil(caches.open(CACHE).then(cache => cache.addAll(urls)));
});
self.addEventListener('activate', event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(
    keys.filter(key => key.startsWith('suho-shell-') && key !== CACHE).map(key => caches.delete(key))
  )).then(() => self.clients.claim()));
});
self.addEventListener('fetch', event => {
  const request = event.request;
  const url = new URL(request.url);
  if (request.method !== 'GET' || url.origin !== self.location.origin) return;
  if (request.mode === 'navigate') {
    if (!url.href.startsWith(self.registration.scope)) return;
    event.respondWith(fetch(request).catch(() => caches.match(new URL('index.html', self.registration.scope).href)));
  } else if (urls.includes(url.href)) {
    event.respondWith(caches.open(CACHE).then(async cache => (await cache.match(request)) || fetch(request)));
  }
});
'''.replace('VERSION', version).replace('ASSET_LIST', json.dumps(assets))
(root / 'service-worker.js').write_text(worker)
(root / '.nojekyll').touch()
print(f'PWA cache {version}: {len(files)} public files')
