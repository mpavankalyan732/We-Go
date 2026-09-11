// Points the website at the real external Bus API (bus-booking-app/api).
// Local dev: run `npm run dev` from bus-booking-app/ — the API listens on
// :4000. In production (Render), set VITE_API_BASE_URL at build time to the
// deployed API's public URL (see api/README.md "Deploying to Render").
export const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 'http://localhost:4000';
