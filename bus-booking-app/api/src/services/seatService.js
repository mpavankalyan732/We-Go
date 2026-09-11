import { db } from '../db/index.js';
import { ApiError } from '../utils/ApiError.js';
import { assertTripExists } from './tripService.js';

function toSeatJson(row) {
  return {
    number: row.seat_number,
    deck: row.deck,
    row: row.row_number,
    col: row.col_letter,
    category: row.category,
    status: row.status,
    priceModifier: row.price_modifier
  };
}

export function getSeatMap(tripId) {
  assertTripExists(tripId);
  const rows = db.prepare('SELECT * FROM seats WHERE trip_id = ? ORDER BY deck, row_number, col_letter').all(tripId);
  return rows.map(toSeatJson);
}

// Must run inside runInTransaction() from the caller — throws ApiError.conflict
// (rolls back) if any requested seat is no longer available.
export function lockSeats(tripId, seatNumbers) {
  const placeholders = seatNumbers.map(() => '?').join(',');
  const rows = db
    .prepare(`SELECT * FROM seats WHERE trip_id = ? AND seat_number IN (${placeholders})`)
    .all(tripId, ...seatNumbers);

  const byNumber = new Map(rows.map((r) => [r.seat_number, r]));
  for (const num of seatNumbers) {
    const seat = byNumber.get(num);
    if (!seat) throw ApiError.badRequest(`Seat ${num} does not exist on this trip`);
    if (seat.status !== 'available') throw ApiError.conflict(`Seat ${num} is no longer available`, { seatNumber: num });
  }

  const update = db.prepare("UPDATE seats SET status = 'booked' WHERE id = ?");
  for (const seat of rows) update.run(seat.id);

  return rows;
}

export function releaseSeatsByNumber(tripId, seatNumbers) {
  if (seatNumbers.length === 0) return;
  const placeholders = seatNumbers.map(() => '?').join(',');
  db.prepare(`UPDATE seats SET status = 'available' WHERE trip_id = ? AND seat_number IN (${placeholders})`).run(
    tripId,
    ...seatNumbers
  );
}

export function pickAvailableSeats(tripId, count) {
  const rows = db
    .prepare("SELECT * FROM seats WHERE trip_id = ? AND status = 'available' ORDER BY deck, row_number, col_letter LIMIT ?")
    .all(tripId, count);
  if (rows.length < count) {
    throw ApiError.conflict(`Only ${rows.length} seat(s) available on the new trip, need ${count}`);
  }
  const update = db.prepare("UPDATE seats SET status = 'booked' WHERE id = ?");
  for (const seat of rows) update.run(seat.id);
  return rows;
}
