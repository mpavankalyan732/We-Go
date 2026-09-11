// Points the website at the real external Bus API (bus-booking-app/api).
// Defaults straight to the live Render deployment so a build "just works"
// with no env vars required - VITE_API_BASE_URL still overrides this if
// ever needed (e.g. a different environment). Local dev (`npm run dev` from
// bus-booking-app/, API on :4000) auto-falls back to localhost instead,
// since import.meta.env.PROD is false outside a `vite build`.
export const API_BASE_URL =
  import.meta.env.VITE_API_BASE_URL ||
  (import.meta.env.PROD ? 'https://roadlink-bus-api.onrender.com' : 'http://localhost:4000');

// Must match the deployed Bus API's API_KEY. Bundled into the built site's
// JS, so it's visible to anyone via devtools/network tab once deployed -
// not a real secret at that point, just a gate against casual anonymous
// scraping. VITE_API_KEY still overrides this if the key ever changes.
export const API_KEY = import.meta.env.VITE_API_KEY || 'c71b98855345c5d9e21da119a06886c75908a7b3af86fafe';
