// Replaces Flutter's old service worker: removes itself and its saved files
// so every phone switches to the newest uploaded version.
self.addEventListener('install', function () { self.skipWaiting(); });
self.addEventListener('activate', function (event) {
  event.waitUntil((async function () {
    const keys = await caches.keys();
    await Promise.all(keys.map(function (k) { return caches.delete(k); }));
    await self.registration.unregister();
    const tabs = await self.clients.matchAll({ type: 'window' });
    tabs.forEach(function (c) { c.navigate(c.url); });
  })());
});
