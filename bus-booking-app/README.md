# RoadLink Bus Booking App

One folder, two workspaces:

```
bus-booking-app/
  web/   — the customer-facing website (React + Vite)
  api/   — the external Bus API (Node/Express + built-in SQLite)
```

## Which database? SQLite — already built in, nothing to install

`api/` uses Node's **built-in `node:sqlite` module**. There is no separate database server to install, configure, or start — the SQLite file lives inside `api/data/` and the API process manages it directly. Running the API *is* running the database. (For comparison: MySQL/SQL Server or PostgreSQL would both require installing and starting a separate server process — unnecessary overhead for this project right now.)

## Step-by-step: run everything

1. **Install once, from this folder** (installs both `web` and `api` via npm workspaces):
   ```bash
   cd bus-booking-app
   npm install
   ```
2. **Start both servers together:**
   ```bash
   npm run dev
   ```
   This runs the API on `http://localhost:4000` and the website on `http://localhost:5173` side by side (labeled `API`/`WEB` in the terminal output).
3. **Open the website**: `http://localhost:5173` — this still uses Phase 1's mock data internally (see below), so it works immediately with no further setup.
4. **Try the API directly**, if you want to see Phase 2 on its own:
   ```bash
   curl "http://localhost:4000/api/buses/search?from=Chennai&to=Tirupati&date=2026-09-20"
   ```
5. **Stop everything**: `Ctrl+C` in the terminal running `npm run dev` (stops both).

Only need one at a time? `npm run dev:api` or `npm run dev:web`.

## Where things stand

- **Website (`web/`)** currently talks to an in-memory mock (`web/src/api/mockProvider.js`), not the real API — that's still correct for now. The website and the API were built to the exact same data contract on purpose.
- **API (`api/`)** is complete and independently tested (search, seats, booking, cancel, reschedule, notifications) — see `api/README.md` for full endpoint docs, request/response shapes, and Render deployment steps.
- **Phase 3** (pointing the website at the real API instead of the mock) is a two-line change in `web/src/api/config.js` (`API_BASE_URL` + `USE_MOCK_API = false`) whenever you're ready for it — no component code changes needed.
- **Salesforce** — all 8 custom objects (`Bus__c`, `Bus_Trip__c`, `Bus_Seat__c`, `Bus_Booking__c`, `Booking_Passenger__c`, `Booking_Transaction__c`, `Booking_Notification__c`, `Bus_Reschedule__c`) have been created in the org with fields confirmed. That work lives in `force-app/` at the repo root, separate from this app.
