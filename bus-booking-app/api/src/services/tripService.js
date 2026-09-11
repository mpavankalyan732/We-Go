import { db, runInTransaction } from '../db/index.js';
import { ApiError } from '../utils/ApiError.js';
import { hashCode, mulberry32, addMinutes } from '../utils/random.js';
import { DEPARTURE_HOURS } from './operatorData.js';

function buildSeatLayout(busType, rand) {
  const seats = [];
  const isSleeper = busType.toLowerCase().includes('sleeper');

  if (isSleeper) {
    ['Lower', 'Upper'].forEach((deck) => {
      for (let row = 1; row <= 6; row++) {
        seats.push({ seat_number: `${deck[0]}${row}A`, deck, row_number: row, col_letter: 'A', category: 'single-berth' });
        seats.push({ seat_number: `${deck[0]}${row}B`, deck, row_number: row, col_letter: 'B', category: 'double-berth' });
        seats.push({ seat_number: `${deck[0]}${row}C`, deck, row_number: row, col_letter: 'C', category: 'double-berth' });
      }
    });
  } else {
    for (let row = 1; row <= 10; row++) {
      ['A', 'B', 'C', 'D'].forEach((col) => {
        seats.push({ seat_number: `${row}${col}`, deck: null, row_number: row, col_letter: col, category: 'seater' });
      });
    }
  }

  return seats.map((seat) => ({
    ...seat,
    status: pickStatus(rand()),
    price_modifier: seat.deck === 'Lower' ? 100 : 0
  }));
}

function pickStatus(rand) {
  if (rand < 0.58) return 'available';
  if (rand < 0.9) return 'booked';
  return 'blocked';
}

function computeTripId(fromCity, toCity, travelDate, operatorName, hour) {
  return `TRIP-${hashCode(`${fromCity}|${toCity}|${travelDate}|${operatorName}|${hour}`).toString(36)}`;
}

function insertTripAndSeats(tripId, operator, fromCity, toCity, travelDate, hour, index) {
  const rand = mulberry32(hashCode(tripId));
  const seats = buildSeatLayout(operator.bus_type, rand);
  const durationHours = 4 + Math.floor(rand() * 8);
  const baseFare = 450 + Math.floor(rand() * 950);

  runInTransaction(() => {
    db.prepare(
      `INSERT INTO trips
        (trip_id, operator_id, bus_name, from_city, to_city, travel_date, departure_time, arrival_time,
         boarding_point, dropping_point, base_fare, duration_label, total_seats)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
    ).run(
      tripId,
      operator.id,
      `${operator.name} ${100 + index}`,
      fromCity,
      toCity,
      travelDate,
      addMinutes(hour, 0),
      addMinutes(hour, durationHours * 60),
      `${fromCity} Central Bus Stand`,
      `${toCity} Main Bus Depot`,
      baseFare,
      `${durationHours}h ${rand() < 0.5 ? '00' : '30'}m`,
      seats.length
    );

    const insertSeat = db.prepare(
      `INSERT INTO seats (trip_id, seat_number, deck, row_number, col_letter, category, price_modifier, status)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`
    );
    for (const seat of seats) {
      insertSeat.run(tripId, seat.seat_number, seat.deck, seat.row_number, seat.col_letter, seat.category, seat.price_modifier, seat.status);
    }
  });
}

function ensureTripAndSeats(fromCity, toCity, travelDate, operator, hour, index) {
  const tripId = computeTripId(fromCity, toCity, travelDate, operator.name, hour);
  const existing = db.prepare('SELECT 1 FROM trips WHERE trip_id = ?').get(tripId);
  if (!existing) {
    insertTripAndSeats(tripId, operator, fromCity, toCity, travelDate, hour, index);
  }
  return tripId;
}

function toTripJson(row) {
  return {
    tripId: row.trip_id,
    operator: row.operator_name,
    busName: row.bus_name,
    busType: row.bus_type,
    rating: row.rating,
    fromCity: row.from_city,
    toCity: row.to_city,
    travelDate: row.travel_date,
    departureTime: row.departure_time,
    arrivalTime: row.arrival_time,
    durationLabel: row.duration_label,
    boardingPoint: row.boarding_point,
    droppingPoint: row.dropping_point,
    fare: row.base_fare,
    totalSeats: row.total_seats,
    availableSeats: row.available_seats
  };
}

const TRIP_WITH_AVAILABILITY_SQL = `
  SELECT
    t.*,
    o.name AS operator_name,
    o.bus_type AS bus_type,
    o.rating AS rating,
    (SELECT COUNT(*) FROM seats s WHERE s.trip_id = t.trip_id AND s.status = 'available') AS available_seats
  FROM trips t
  JOIN operators o ON o.id = t.operator_id
`;

export function searchTrips({ fromCity, toCity, travelDate }) {
  if (!fromCity || !toCity || !travelDate) {
    throw ApiError.badRequest('fromCity, toCity and travelDate are required');
  }
  if (fromCity.trim().toLowerCase() === toCity.trim().toLowerCase()) {
    throw ApiError.badRequest('fromCity and toCity must be different');
  }

  const from = fromCity.trim();
  const to = toCity.trim();
  const operators = db.prepare('SELECT * FROM operators ORDER BY id').all();

  operators.forEach((operator, index) => {
    const hour = DEPARTURE_HOURS[index % DEPARTURE_HOURS.length];
    ensureTripAndSeats(from, to, travelDate, operator, hour, index);
  });

  const rows = db
    .prepare(`${TRIP_WITH_AVAILABILITY_SQL} WHERE t.from_city = ? AND t.to_city = ? AND t.travel_date = ? ORDER BY t.departure_time`)
    .all(from, to, travelDate);

  return rows.map(toTripJson);
}

export function getTripById(tripId) {
  const row = db.prepare(`${TRIP_WITH_AVAILABILITY_SQL} WHERE t.trip_id = ?`).get(tripId);
  if (!row) throw ApiError.notFound(`Trip not found: ${tripId}`);
  return toTripJson(row);
}

export function assertTripExists(tripId) {
  const row = db.prepare('SELECT trip_id FROM trips WHERE trip_id = ?').get(tripId);
  if (!row) throw ApiError.notFound(`Trip not found: ${tripId}`);
}
