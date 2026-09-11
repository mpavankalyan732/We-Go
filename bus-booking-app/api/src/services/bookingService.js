import { db, runInTransaction } from '../db/index.js';
import { ApiError } from '../utils/ApiError.js';
import { isValidEmail, isValidPhone } from '../utils/validators.js';
import { generateUniqueReferenceId, generateUniquePnr } from '../utils/ids.js';
import { getTripById, assertTripExists } from './tripService.js';
import { lockSeats, releaseSeatsByNumber, pickAvailableSeats } from './seatService.js';
import { syncBookingToSalesforce } from './salesforceSync.js';

const GENDERS = new Set(['Male', 'Female', 'Other']);

function toIso(sqliteDatetime) {
  return sqliteDatetime ? `${sqliteDatetime.replace(' ', 'T')}Z` : null;
}

function validateCreatePayload({ tripId, seatNumbers, passengers, contactEmail, contactPhone }) {
  if (!tripId) throw ApiError.badRequest('tripId is required');
  if (!Array.isArray(seatNumbers) || seatNumbers.length === 0) {
    throw ApiError.badRequest('At least one seat must be selected');
  }
  if (!Array.isArray(passengers) || passengers.length !== seatNumbers.length) {
    throw ApiError.badRequest('passengers must have exactly one entry per selected seat');
  }
  if (!isValidEmail(contactEmail)) throw ApiError.badRequest('A valid contactEmail is required');
  if (!isValidPhone(contactPhone)) throw ApiError.badRequest('A valid 10-digit contactPhone is required');

  for (const p of passengers) {
    if (!p.seatNumber || !seatNumbers.includes(p.seatNumber)) {
      throw ApiError.badRequest('Each passenger must reference one of the selected seatNumbers');
    }
    if (!p.name || !String(p.name).trim()) throw ApiError.badRequest(`Missing name for seat ${p.seatNumber}`);
    const age = Number(p.age);
    if (!Number.isInteger(age) || age < 1 || age > 120) {
      throw ApiError.badRequest(`Invalid age for seat ${p.seatNumber} (must be 1-120)`);
    }
    if (!GENDERS.has(p.gender)) throw ApiError.badRequest(`Invalid gender for seat ${p.seatNumber}`);
  }
}

function getBookingRow(referenceId) {
  const row = db.prepare('SELECT * FROM bookings WHERE booking_reference_id = ?').get(referenceId);
  if (!row) throw ApiError.notFound(`No booking found for reference ID: ${referenceId}`);
  return row;
}

function getActiveBookingSeats(bookingId) {
  return db
    .prepare('SELECT * FROM booking_seats WHERE booking_id = ? AND released_at IS NULL ORDER BY id')
    .all(bookingId);
}

function getActiveBookingSeatsWithDetail(bookingId) {
  return db
    .prepare(
      `SELECT bs.seat_number, bs.fare, s.deck, s.category
       FROM booking_seats bs
       JOIN seats s ON s.id = bs.seat_id
       WHERE bs.booking_id = ? AND bs.released_at IS NULL
       ORDER BY bs.id`
    )
    .all(bookingId);
}

function composeBookingJson(bookingRow) {
  const trip = getTripById(bookingRow.trip_id);
  const activeSeats = getActiveBookingSeats(bookingRow.id);
  const passengers = db
    .prepare('SELECT seat_number, name, age, gender, email, phone FROM passengers WHERE booking_id = ? ORDER BY id')
    .all(bookingRow.id);

  return {
    bookingReferenceId: bookingRow.booking_reference_id,
    pnr: bookingRow.pnr,
    status: bookingRow.status,
    createdAt: toIso(bookingRow.created_at),
    trip,
    seatNumbers: activeSeats.map((s) => s.seat_number),
    seats: getActiveBookingSeatsWithDetail(bookingRow.id).map((s) => ({
      number: s.seat_number,
      deck: s.deck,
      category: s.category,
      fare: s.fare
    })),
    passengers: passengers.map((p) => ({
      seatNumber: p.seat_number,
      name: p.name,
      age: p.age,
      gender: p.gender,
      email: p.email,
      phone: p.phone
    })),
    contactEmail: bookingRow.contact_email,
    contactPhone: bookingRow.contact_phone,
    totalAmount: bookingRow.total_amount,
    cancelledAt: toIso(bookingRow.cancelled_at),
    cancellationReason: bookingRow.cancellation_reason,
    refundAmount: bookingRow.refund_amount
  };
}

export async function createBooking(payload) {
  validateCreatePayload(payload);
  const { tripId, seatNumbers, passengers, contactEmail, contactPhone } = payload;
  const trip = getTripById(tripId);

  const referenceId = runInTransaction(() => {
    const lockedSeats = lockSeats(tripId, seatNumbers);
    const seatByNumber = new Map(lockedSeats.map((s) => [s.seat_number, s]));
    const totalAmount = seatNumbers.reduce((sum, num) => sum + trip.fare + seatByNumber.get(num).price_modifier, 0);

    const referenceId = generateUniqueReferenceId();
    const pnr = generateUniquePnr();

    const { lastInsertRowid: bookingId } = db
      .prepare(
        `INSERT INTO bookings (booking_reference_id, pnr, trip_id, status, total_amount, contact_email, contact_phone)
         VALUES (?, ?, ?, 'Confirmed', ?, ?, ?)`
      )
      .run(referenceId, pnr, tripId, totalAmount, contactEmail, contactPhone);

    const insertBookingSeat = db.prepare(
      'INSERT INTO booking_seats (booking_id, seat_id, seat_number, fare) VALUES (?, ?, ?, ?)'
    );
    const insertPassenger = db.prepare(
      'INSERT INTO passengers (booking_id, seat_number, name, age, gender, email, phone) VALUES (?, ?, ?, ?, ?, ?, ?)'
    );

    for (const num of seatNumbers) {
      const seat = seatByNumber.get(num);
      insertBookingSeat.run(bookingId, seat.id, num, trip.fare + seat.price_modifier);
    }
    for (const p of passengers) {
      insertPassenger.run(bookingId, p.seatNumber, p.name.trim(), Number(p.age), p.gender, p.email || null, p.phone || null);
    }

    return referenceId;
  });

  const booking = composeBookingJson(getBookingRow(referenceId));
  await syncBookingToSalesforce(booking); // best-effort — never fails the booking itself
  return booking;
}

export function getBookingByReference(referenceId) {
  return composeBookingJson(getBookingRow(referenceId));
}

// Simple, transparent refund policy for the demo: full refund outside 24h of
// departure, half within 24h, none once departure has passed.
function computeRefund(totalAmount, trip) {
  const departure = new Date(`${trip.travelDate}T${trip.departureTime}:00Z`);
  const hoursUntilDeparture = (departure.getTime() - Date.now()) / (1000 * 60 * 60);
  if (hoursUntilDeparture <= 0) return 0;
  if (hoursUntilDeparture <= 24) return Math.round(totalAmount * 0.5);
  return totalAmount;
}

export function cancelBooking(referenceId, reason) {
  const bookingRow = getBookingRow(referenceId);
  if (bookingRow.status !== 'Confirmed') {
    throw ApiError.conflict(`Booking ${referenceId} is already ${bookingRow.status} and cannot be cancelled`);
  }

  const trip = getTripById(bookingRow.trip_id);
  const refundAmount = computeRefund(bookingRow.total_amount, trip);

  runInTransaction(() => {
    const activeSeats = getActiveBookingSeats(bookingRow.id);
    const seatNumbers = activeSeats.map((s) => s.seat_number);

    releaseSeatsByNumber(bookingRow.trip_id, seatNumbers);
    db.prepare("UPDATE booking_seats SET released_at = datetime('now') WHERE booking_id = ? AND released_at IS NULL").run(
      bookingRow.id
    );
    db.prepare(
      "UPDATE bookings SET status = 'Cancelled', cancelled_at = datetime('now'), cancellation_reason = ?, refund_amount = ? WHERE id = ?"
    ).run(reason || null, refundAmount, bookingRow.id);
  });

  return composeBookingJson(getBookingRow(referenceId));
}

export function rescheduleBooking(referenceId, newTripId, reason) {
  const bookingRow = getBookingRow(referenceId);
  if (bookingRow.status !== 'Confirmed') {
    throw ApiError.conflict(`Booking ${referenceId} is ${bookingRow.status} and cannot be rescheduled`);
  }
  if (!newTripId) throw ApiError.badRequest('newTripId is required');
  if (newTripId === bookingRow.trip_id) {
    throw ApiError.badRequest('newTripId must be different from the booking\'s current trip');
  }
  assertTripExists(newTripId);
  const newTrip = getTripById(newTripId);

  runInTransaction(() => {
    const activeSeats = getActiveBookingSeats(bookingRow.id);
    const oldSeatNumbers = activeSeats.map((s) => s.seat_number);
    const passengers = db
      .prepare('SELECT * FROM passengers WHERE booking_id = ? ORDER BY id')
      .all(bookingRow.id);

    releaseSeatsByNumber(bookingRow.trip_id, oldSeatNumbers);
    db.prepare("UPDATE booking_seats SET released_at = datetime('now') WHERE booking_id = ? AND released_at IS NULL").run(
      bookingRow.id
    );

    const newSeats = pickAvailableSeats(newTripId, oldSeatNumbers.length);
    const insertBookingSeat = db.prepare(
      'INSERT INTO booking_seats (booking_id, seat_id, seat_number, fare) VALUES (?, ?, ?, ?)'
    );
    const updatePassengerSeat = db.prepare('UPDATE passengers SET seat_number = ? WHERE id = ?');

    let newTotalAmount = 0;
    newSeats.forEach((seat, index) => {
      const fare = newTrip.fare + seat.price_modifier;
      newTotalAmount += fare;
      insertBookingSeat.run(bookingRow.id, seat.id, seat.seat_number, fare);
      const passenger = passengers[index];
      if (passenger) updatePassengerSeat.run(seat.seat_number, passenger.id);
    });

    const fareDifference = newTotalAmount - bookingRow.total_amount;

    db.prepare('UPDATE bookings SET trip_id = ?, total_amount = ? WHERE id = ?').run(newTripId, newTotalAmount, bookingRow.id);
    db.prepare(
      `INSERT INTO reschedule_history (booking_id, previous_trip_id, new_trip_id, fare_difference, reason)
       VALUES (?, ?, ?, ?, ?)`
    ).run(bookingRow.id, bookingRow.trip_id, newTripId, fareDifference, reason || null);
  });

  return composeBookingJson(getBookingRow(referenceId));
}
