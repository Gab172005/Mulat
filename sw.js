/*
  GabayAI - Service Worker
  Provides complete offline capabilities using a Stale-While-Revalidate strategy.
*/

const CACHE_NAME = 'gabayai-cache-v1';

// Static assets and CDN dependencies to cache immediately on installation
const ASSETS_TO_CACHE = [
  '/',
  '/index.html',
  '/styles.css',
  '/app.js',
  '/manifest.json',
  'https://cdn.tailwindcss.com',
  'https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@300;400;500;600;700;800&display=swap',
  'https://unpkg.com/pdfjs-dist@4.3.136/build/pdf.min.mjs',
  'https://unpkg.com/pdfjs-dist@4.3.136/build/pdf.worker.min.mjs',
  'https://cdn.jsdelivr.net/npm/@huggingface/transformers@3.3.3'
];

// Install Event
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      console.log('[Service Worker] Pre-caching static assets');
      return cache.addAll(ASSETS_TO_CACHE);
    }).then(() => self.skipWaiting())
  );
});

// Activate Event (Cleanup old caches)
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cache) => {
          if (cache !== CACHE_NAME && cache.startsWith('gabayai-')) {
            console.log('[Service Worker] Clearing old cache:', cache);
            return caches.delete(cache);
          }
        })
      );
    }).then(() => self.clients.claim())
  );
});

// Fetch Event (Stale-While-Revalidate)
self.addEventListener('fetch', (event) => {
  const url = event.request.url;

  // 1. Bypass Service Worker cache for HuggingFace model weights.
  // Transformers.js handles its own model caching inside the page context using the Cache API.
  // Intercepting these large binary files (~1GB) in the Service Worker is memory-intensive
  // and can cause storage quota crashes.
  if (
    url.includes('huggingface.co') || 
    url.includes('onnx') || 
    url.endsWith('.onnx') || 
    url.endsWith('.bin')
  ) {
    // Return network response directly, ignoring cache.
    return;
  }

  // 2. Only cache GET requests
  if (event.request.method !== 'GET') {
    return;
  }

  // 3. Stale-While-Revalidate Strategy for site assets & static CDNs
  event.respondWith(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.match(event.request).then((cachedResponse) => {
        const fetchPromise = fetch(event.request)
          .then((networkResponse) => {
            // Update cache in the background with the new response
            if (networkResponse.status === 200) {
              cache.put(event.request, networkResponse.clone());
            }
            return networkResponse;
          })
          .catch((err) => {
            console.warn('[Service Worker] Fetch failed (probably offline):', err);
            // Return cached response if offline fetch failed
            if (cachedResponse) return cachedResponse;
            throw err;
          });

        // Return cached version immediately if we have it, else wait for network
        return cachedResponse || fetchPromise;
      });
    })
  );
});
