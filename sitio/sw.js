/* PAM Baruta · Service worker
   - Guarda las páginas para que abran rápido y sin conexión.
   - Recibe notificaciones push enviadas por el servidor (Web Push / VAPID).
   Sistemas: el servidor debe guardar la suscripción de cada teléfono (PushManager.subscribe)
   y enviar un push cada vez que se cree un aviso, con el formato { titulo, mensaje, link }. */
const CACHE = 'pam-v2';
const ARCHIVOS = ['index.html', 'registro.html', 'eventos.html', 'tips.html', 'cobertura.html', 'assets/app.css', 'assets/core.js', 'img/familia.jpg', 'img/comunidad.jpg', 'img/icon-192.png', 'preguntas.html', 'nevera.html', 'assets/qrcode.js'];

self.addEventListener('install', e => { e.waitUntil(caches.open(CACHE).then(c => c.addAll(ARCHIVOS)).then(() => self.skipWaiting())); });
self.addEventListener('activate', e => { e.waitUntil(caches.keys().then(k => Promise.all(k.filter(x => x !== CACHE).map(x => caches.delete(x)))).then(() => self.clients.claim())); });
self.addEventListener('fetch', e => {
  if (e.request.method !== 'GET') return;
  e.respondWith(fetch(e.request).then(r => { const c = r.clone(); caches.open(CACHE).then(x => x.put(e.request, c)); return r; }).catch(() => caches.match(e.request)));
});
self.addEventListener('push', e => {
  let d = {}; try { d = e.data.json(); } catch (_) { d = { titulo: 'PAM Baruta', mensaje: e.data ? e.data.text() : '' }; }
  e.waitUntil(self.registration.showNotification(d.titulo || 'PAM Baruta', { body: d.mensaje || '', icon: 'img/icon-192.png', badge: 'img/icon-192.png', data: { link: d.link || 'index.html' }, lang: 'es', vibrate: [120, 60, 120] }));
});
self.addEventListener('notificationclick', e => {
  e.notification.close();
  const url = new URL(e.notification.data?.link || 'index.html', self.registration.scope).href;
  e.waitUntil(clients.matchAll({ type: 'window', includeUncontrolled: true }).then(ws => { const w = ws.find(x => x.url.startsWith(self.registration.scope)); return w ? (w.navigate(url), w.focus()) : clients.openWindow(url); }));
});
