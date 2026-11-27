const cacheName = 'nova-pwa-shell-1';
const shell = [
  './', './index.html', './style.css', './app.js', './catalog.js',
  './manifest.webmanifest', './icons/icon-180.png', './icons/icon-192.png',
  './icons/icon-512.png',
];
const shellUrls = new Set(shell.map(path => new URL(path, self.registration.scope).href));

self.addEventListener('install', event => {
  event.waitUntil(caches.open(cacheName).then(cache => cache.addAll(shell)));
});
self.addEventListener('activate', event => {
  event.waitUntil(caches.keys().then(keys => Promise.all(
    keys.filter(key => key.startsWith('nova-pwa-shell-') && key !== cacheName)
      .map(key => caches.delete(key)),
  )));
});
self.addEventListener('fetch', event => {
  // Cache the public app shell only. No playlists, provider requests or video.
  if (event.request.method !== 'GET' || !shellUrls.has(event.request.url)) return;
  event.respondWith(fetch(event.request).catch(() => caches.match(event.request)));
});
