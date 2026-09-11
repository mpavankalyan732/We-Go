CREATE TABLE IF NOT EXISTS operators (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  bus_type TEXT NOT NULL,
  rating REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS trips (
  trip_id TEXT PRIMARY KEY,
  operator_id INTEGER NOT NULL REFERENCES operators(id),
  bus_name TEXT NOT NULL,
  from_city TEXT NOT NULL,
  to_city TEXT NOT NULL,
  travel_date TEXT NOT NULL,
  departure_time TEXT NOT NULL,
  arrival_time TEXT NOT NULL,
  boarding_point TEXT NOT NULL,
  dropping_point TEXT NOT NULL,
  base_fare INTEGER NOT NULL,
  duration_label TEXT NOT NULL,
  total_seats INTEGER NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_trips_route_date ON trips(from_city, to_city, travel_date);

CREATE TABLE IF NOT EXISTS seats (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  trip_id TEXT NOT NULL REFERENCES trips(trip_id),
  seat_number TEXT NOT NULL,
  deck TEXT,
  row_number INTEGER NOT NULL,
  col_letter TEXT NOT NULL,
  category TEXT NOT NULL,
  price_modifier INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'available',
  UNIQUE(trip_id, seat_number)
);

CREATE INDEX IF NOT EXISTS idx_seats_trip ON seats(trip_id);

CREATE TABLE IF NOT EXISTS bookings (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  booking_reference_id TEXT NOT NULL UNIQUE,
  pnr TEXT NOT NULL UNIQUE,
  trip_id TEXT NOT NULL REFERENCES trips(trip_id),
  status TEXT NOT NULL DEFAULT 'Confirmed',
  total_amount INTEGER NOT NULL,
  contact_email TEXT NOT NULL,
  contact_phone TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  cancelled_at TEXT,
  cancellation_reason TEXT,
  refund_amount INTEGER
);

CREATE INDEX IF NOT EXISTS idx_bookings_reference ON bookings(booking_reference_id);

CREATE TABLE IF NOT EXISTS booking_seats (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  booking_id INTEGER NOT NULL REFERENCES bookings(id),
  seat_id INTEGER NOT NULL REFERENCES seats(id),
  seat_number TEXT NOT NULL,
  fare INTEGER NOT NULL,
  released_at TEXT
);

CREATE TABLE IF NOT EXISTS passengers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  booking_id INTEGER NOT NULL REFERENCES bookings(id),
  seat_number TEXT NOT NULL,
  name TEXT NOT NULL,
  age INTEGER NOT NULL,
  gender TEXT NOT NULL,
  email TEXT,
  phone TEXT
);

CREATE TABLE IF NOT EXISTS reschedule_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  booking_id INTEGER NOT NULL REFERENCES bookings(id),
  previous_trip_id TEXT NOT NULL,
  new_trip_id TEXT NOT NULL,
  fare_difference INTEGER NOT NULL,
  reason TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS notifications (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  booking_id INTEGER REFERENCES bookings(id),
  type TEXT NOT NULL,
  channel TEXT NOT NULL,
  recipient TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'Sent',
  message_body TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
