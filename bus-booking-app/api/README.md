# RoadLink Bus API (Phase 2)

The external Bus API — source of truth for schedules, fares, seat availability/locking, and booking/cancel/reschedule eligibility, per the project architecture. Salesforce (Phase 4+) will own passenger/transaction records and always call back through this API for anything live.

## Stack & why

- **Node.js + Express** — matches the spec's suggested stack, minimal ceremony for a demo-scale REST API.
- **Database: `node:sqlite`** (Node's built-in SQLite, stable-enough as of Node 22.5+, confirmed working here on Node 25.9). Chosen over `better-sqlite3` specifically to avoid any native-module compile step — zero extra dependencies, works identically in dev and on Render. Chosen over Postgres for this phase because a demo doesn't need a separately provisioned/paid managed database; the schema is portable to Postgres later with minimal changes if this needs to scale beyond a demo.
- **No ORM** — hand-written parameterized SQL (`db.prepare(...).run/get/all`) over 8 tables. The dataset and query set are small enough that an ORM would add indirection without paying for itself.

**Known limitation (be aware of this, not a bug):** Render's free web-service tier has an ephemeral disk — the SQLite file resets on every redeploy/restart. Fine for a demo (mirrors Phase 1's mock data resetting on page reload); if you need bookings to survive redeploys, either attach a Render persistent disk and point `DB_PATH` at it, or migrate to Render's managed Postgres (schema in `src/db/schema.sql` translates directly — see "Scaling to Postgres" below).

## Run it

```bash
npm install
cp .env.example .env   # optional — leave API_KEY blank to run with auth disabled locally
npm run dev
```

Server starts on `http://localhost:4000` (or `PORT` from `.env`). `GET /health` needs no auth key.

## Salesforce sync

Right after `POST /api/bookings` commits, `src/services/salesforceSync.js` pushes the booking (trip/bus/seats/passengers/payment) into Salesforce via an Apex REST endpoint — `POST {instanceUrl}/services/apexrest/roadlink/bookingSync`, implemented by `BusBookingSyncService.cls` + `BusBookingSyncResource.cls` in `force-app/main/default/classes/`.

**This is best-effort and non-blocking**: the Bus API's own database is already the source of truth for the booking transaction once it commits, so a Salesforce hiccup is logged (`[salesforceSync] ...`) and never fails the customer's booking.

**Auth: OAuth 2.0 Client Credentials Flow** via a dedicated External Client App (`RoadLink_Bus_Integration`, in `force-app/main/default/externalClientApps/` + its related `extlClntAppOauthSettings`/`extlClntAppOauthPolicies` metadata) — server-to-server, no user interaction. `src/services/salesforceAuth.js` exchanges `SF_CLIENT_ID`/`SF_CLIENT_SECRET` for an access token on demand, caching it for ~10 minutes at a time.

Setup, if rebuilding this from scratch:
1. Deploy the three metadata pieces together (they reference each other, so a partial deploy rolls back entirely):
   ```bash
   sf project deploy start --target-org FAgent \
     --source-dir force-app/main/default/externalClientApps/RoadLink_Bus_Integration.eca-meta.xml \
     --source-dir force-app/main/default/extlClntAppOauthSettings/RoadLink_Bus_Integration_oauth.ecaOauth-meta.xml \
     --source-dir force-app/main/default/extlClntAppOauthPolicies/RoadLink_Bus_Integration_oauthPlcy.ecaOauthPlcy-meta.xml
   ```
   The policy file sets `isClientCredentialsFlowEnabled=true`, `permittedUsersPolicyType=AdminApprovedPreAuthorized`, and `clientCredentialsFlowUser` (the username the flow runs as — must be set to a real active user).
2. **The critical, easy-to-miss step**: with `permittedUsersPolicyType=AdminApprovedPreAuthorized`, the run-as user must be explicitly granted access to the app — and **this only works via a Permission Set, not a Profile**, even though the Policies UI page lets you add either. Adding the user's Profile (e.g. "System Administrator") to "Selected Profiles" *looks* like it works (it creates a real `SetupEntityAccess` record, confirmed via `SELECT ... FROM SetupEntityAccess WHERE SetupEntityId = '<app Id>'`) but the token endpoint still rejects it with `invalid_app_access - user is not admin approved to access this app`. The fix: create a Permission Set (`force-app/main/default/permissionsets/RoadLink_Bus_Integration_Access.permissionset-meta.xml`), assign it to the run-as user (`PermissionSetAssignment` — a data record, not metadata: `POST /services/data/vXX.X/sobjects/PermissionSetAssignment` with `AssigneeId`/`PermissionSetId`), then add `<commaSeparatedPermissionSet>RoadLink_Bus_Integration_Access</commaSeparatedPermissionSet>` to the policy file and redeploy. (This field is additive, not a full replace — redeploying it alongside an already-granted `commaSeparatedProfile` value throws "profile names are already taken"; only include the ones you're newly adding.)
3. **Use the org's own My Domain URL, not `login.salesforce.com`** — Client Credentials Flow specifically requires it (posting to the generic domain fails with `invalid_grant - request not supported on this domain`). Fill in `.env`: `SF_CLIENT_ID`, `SF_CLIENT_SECRET`, `SF_LOGIN_URL=https://<your-domain>.my.salesforce.com`.

(An earlier iteration of this used a classic Connected App + JWT Bearer Flow instead — `RoadLink_Bus_API` in `connectedApps/` + `certs/`. Left in place, unused; harmless either way — hit the exact same "not admin approved" wall for the exact same Profile-vs-Permission-Set reason before this was diagnosed.)

If `SF_CLIENT_ID`/`SF_CLIENT_SECRET` are blank, the sync is skipped entirely (logged, not thrown) — booking creation works fine either way.

## Endpoints

| Method & Path | Purpose |
|---|---|
| `GET /api/buses/search?from=&to=&date=&passengers=` | Search trips for a route+date. Generates trips/seats deterministically on first request for that combo, persists them, and reuses them on every later request. |
| `GET /api/trips/:tripId` | Trip detail. |
| `GET /api/trips/:tripId/seats` | Full seat map for a trip. |
| `POST /api/bookings` | Create a booking — locks the requested seats atomically. |
| `GET /api/bookings/:bookingReferenceId` | Booking detail (trip + seats + passengers). |
| `POST /api/bookings/:bookingReferenceId/cancel` | Cancel — releases seats, computes refund. |
| `POST /api/bookings/:bookingReferenceId/reschedule` | Move a booking to a different trip — releases old seats, locks new ones, logs history. |
| `POST /api/notifications` | Logs a notification record (email/SMS/WhatsApp simulated — no real provider wired up, same "simulated" pattern as payment in Phase 1). |

All `/api/*` routes require an `x-api-key` header matching `API_KEY` — **unless `API_KEY` is unset**, in which case auth is disabled (local-dev convenience). This is exactly the shape the existing `Bus_API` Named Credential in the Salesforce org should be configured to send once Salesforce integration begins (Custom Header auth, header name `x-api-key`).

## Request / response contracts

The JSON shapes below are **locked to match `bus-booking-web`'s `busApiService.js` exactly** — this is what makes Phase 3 (pointing the website at this API) a two-line config flip with zero component changes.

**`GET /api/buses/search`** → array of trips:
```json
[{
  "tripId": "TRIP-h7amyd", "operator": "Greenline Travels", "busName": "Greenline Travels 100",
  "busType": "AC Sleeper", "rating": 4.3, "fromCity": "Chennai", "toCity": "Tirupati",
  "travelDate": "2026-09-15", "departureTime": "06:00", "arrivalTime": "14:00",
  "durationLabel": "8h 30m", "boardingPoint": "Chennai Central Bus Stand",
  "droppingPoint": "Tirupati Main Bus Depot", "fare": 1272, "totalSeats": 36, "availableSeats": 20
}]
```

**`GET /api/trips/:tripId/seats`** → array of seats:
```json
[{ "number": "L1A", "deck": "Lower", "row": 1, "col": "A", "category": "single-berth", "status": "available", "priceModifier": 100 }]
```

**`POST /api/bookings`** request:
```json
{
  "tripId": "TRIP-h7amyd",
  "seatNumbers": ["L1C"],
  "passengers": [{ "seatNumber": "L1C", "name": "Jane Doe", "age": 30, "gender": "Male", "email": "jane@example.com", "phone": "9876543210" }],
  "contactEmail": "jane@example.com",
  "contactPhone": "9876543210"
}
```
→ response (also the shape of `GET /api/bookings/:ref`, and the cancel/reschedule responses):
```json
{
  "bookingReferenceId": "BK-UU9WPA", "pnr": "1659447893", "status": "Confirmed", "createdAt": "2026-09-09T12:35:47Z",
  "trip": { "...same shape as a search result item..." },
  "seatNumbers": ["L1C"],
  "passengers": [{ "seatNumber": "L1C", "name": "Jane Doe", "age": 30, "gender": "Male", "email": "jane@example.com", "phone": "9876543210" }],
  "contactEmail": "jane@example.com", "contactPhone": "9876543210", "totalAmount": 1372,
  "cancelledAt": null, "cancellationReason": null, "refundAmount": null
}
```

**Errors** (every error, any endpoint):
```json
{ "error": { "code": "VALIDATION_ERROR", "message": "tripId is required", "details": null } }
```
`code` is one of `VALIDATION_ERROR` (400), `UNAUTHORIZED` (401), `NOT_FOUND` (404), `CONFLICT` (409), `INTERNAL_ERROR` (500).

## Business logic notes

- **Booking reference ID**: `BK-` + 6 random chars from an unambiguous alphabet (no `0/O/1/I`), checked against the DB for uniqueness (retries up to 10 times — collision odds are astronomically low, but this is a real database now, so it's checked rather than assumed). PNR: 10 random digits, same uniqueness check.
- **Seat locking**: `POST /api/bookings` runs inside a SQLite transaction — every requested seat is re-checked as `available` and flipped to `booked` atomically; if any seat lost the race, the whole transaction rolls back and the caller gets `409 CONFLICT` naming the seat. Because `node:sqlite` is synchronous, there's no async window for two requests to interleave mid-lock.
- **Cancellation refund policy** (demo-simple, documented so it's easy to change): full refund if departure is more than 24h away, 50% within 24h, 0% once departure has passed.
- **Reschedule**: releases the booking's current seats back to `available` on the old trip, locks the same *number* of seats on the new trip (first available, by deck/row/col order — not necessarily the same seat numbers, since the new trip may have a different layout), reassigns each passenger to a new seat, recomputes `totalAmount`, and logs a `reschedule_history` row with the fare difference.
- Trips/seats are generated **deterministically** (seeded by route+date+operator+hour) the first time they're requested, then persisted — so results are stable across repeated searches, matching Phase 1's mock behavior exactly, but now backed by a real database instead of an in-memory Map that resets on restart.

## Database design

8 tables in `src/db/schema.sql`, intentionally mirroring the Salesforce object model we designed (`operators`≈`Bus__c`, `trips`≈`Bus_Trip__c`, `bookings`≈`Bus_Booking__c`, `passengers`≈`Booking_Passenger__c`, `reschedule_history`≈`Bus_Reschedule__c`, `notifications`≈`Booking_Notification__c`) — this API is the operational system, Salesforce will be the CRM/reporting snapshot, and the parallel shape keeps a future sync mapping straightforward:

- `operators` — seeded catalog (name, bus type, rating)
- `trips` — one row per generated route+date+operator instance
- `seats` — full seat map per trip (this table *is* the live availability — not a cache of it)
- `bookings` — one row per booking, keyed by `booking_reference_id`
- `booking_seats` — junction: which seats belong to which booking, with `released_at` marking seats freed by a cancel/reschedule (kept, not deleted, for history)
- `passengers` — one row per traveler per booking
- `reschedule_history` — audit trail of trip changes per booking
- `notifications` — simulated notification log

## Deploying to Render

1. Push this directory to GitHub (as its own repo, or a subdirectory of a monorepo with Render's "Root Directory" set to `bus-booking-api`).
2. Render → New → Web Service → connect the repo.
3. Build command: `npm install`. Start command: `npm start`.
4. Environment variables: `API_KEY` (pick a real secret), `NODE_VERSION` = `22` or higher (needed for `node:sqlite`).
5. Render sets `PORT` automatically — already handled (`process.env.PORT`).
6. Health check path: `/health`.
7. If you need bookings to survive redeploys: Render → Disks → add a persistent disk, mount it (e.g. `/data`), set `DB_PATH=/data/bus_booking.sqlite`. Otherwise the demo works fine as-is with data resetting per deploy.

## Scaling to Postgres later

If this ever needs real persistence without a Render disk, or concurrent write throughput beyond what SQLite comfortably handles: the schema in `schema.sql` is plain ANSI-ish SQL (only `AUTOINCREMENT` and `datetime('now')` are SQLite-specific — swap for `SERIAL`/`now()`), and the only file that talks to the DB directly is `src/db/index.js` (`db.prepare/run/get/all`) — swapping in `pg` behind the same three methods is the entire migration surface. Nothing in `services/` or `routes/` would need to change.
