// Points the website at the real external Bus API (bus-booking-app/api).
// Local dev: run `npm run dev` from bus-booking-app/ — the API listens on
// :4000. In production (Render), set VITE_API_BASE_URL at build time to the
// deployed API's public URL (see api/README.md "Deploying to Render").
export const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:4000';

// Only needed if the deployed Bus API has API_KEY set (auth enabled). Once
// bundled into the built site this is visible to anyone via devtools/network
// tab — it's not a real secret at that point, just a gate against casual
// anonymous scraping. Leave VITE_API_KEY unset to match a Bus API running
// with auth disabled (API_KEY unset there too).
export const API_KEY = import.meta.env.VITE_API_KEY || '';
