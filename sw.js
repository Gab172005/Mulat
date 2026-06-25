/*
  MulatAI - Service Worker
  Provides complete offline capabilities using a Stale-While-Revalidate strategy.
*/

const CACHE_NAME = 'mulatai-cache-v1';

// Only cache LOCAL static assets on install.
// External CDN URLs (Tailwind, Google Fonts, HuggingFace) cannot be reliably
// pre-cached due to CORS / opaque-response restrictions — they cause the install
// event to throw and break the whole service worker registration.
const ASSETS_TO_CACHE = [
  '/',
  '/index.html',
  '/styles.css',
  '/app.js',
  '/ai-engine.js',
  '/manifest.json',
  '/sw.js'
];

// Install Event — cache local assets only
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      console.log('[Service Worker] Pre-caching static assets');
      // addAll throws if any request fails, so wrap each individually
      return Promise.allSettled(
        ASSETS_TO_CACHE.map((url) =>
          cache.add(url).catch((err) =>
            console.warn('[Service Worker] Failed to cache:', url, err)
          )
        )
      );
    }).then(() => self.skipWaiting())
  );
});

// Activate Event (Cleanup old caches)
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cache) => {
          if (cache !== CACHE_NAME && (cache.startsWith('gabayai-') || cache.startsWith('mulatai-'))) {
            console.log('[Service Worker] Clearing old cache:', cache);
            return caches.delete(cache);
          }
        })
      );
    }).then(() => self.clients.claim())
  );
});

// Fetch Event (Stale-While-Revalidate for local assets, network-first for CDN)
self.addEventListener('fetch', (event) => {
  const url = event.request.url;

  // 1. Bypass: HuggingFace model weights — Transformers.js handles its own caching.
  if (
    url.includes('huggingface.co') ||
    url.includes('onnx') ||
    url.endsWith('.onnx') ||
    url.endsWith('.bin')
  ) {
    return;
  }

  // 2. Bypass: External CDN requests — let them hit the network directly.
  //    Caching opaque cross-origin responses wastes quota and can cause failures.
  if (
    url.includes('cdn.tailwindcss.com') ||
    url.includes('cdn.jsdelivr.net') ||
    url.includes('fonts.googleapis.com') ||
    url.includes('fonts.gstatic.com') ||
    url.includes('unpkg.com')
  ) {
    return;
  }

  // 3. Only cache GET requests
  if (event.request.method !== 'GET') {
    return;
  }

  // 4. Stale-While-Revalidate for local site assets
  event.respondWith(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.match(event.request).then((cachedResponse) => {
        const fetchPromise = fetch(event.request)
          .then((networkResponse) => {
            if (networkResponse.status === 200) {
              cache.put(event.request, networkResponse.clone());
            }
            return networkResponse;
          })
          .catch((err) => {
            console.warn('[Service Worker] Fetch failed (probably offline):', err);
            if (cachedResponse) return cachedResponse;
            throw err;
          });

        return cachedResponse || fetchPromise;
      });
    })
  );
});
