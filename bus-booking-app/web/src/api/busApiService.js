// The only module the UI talks to for bus/booking data — every request goes
// to the real external Bus API (bus-booking-app/api). Every function returns
// a Promise and throws an Error with a user-safe .message on failure.
import { API_BASE_URL, API_KEY } from './config.js';

async function request(path, options = {}) {
  const res = await fetch(`${API_BASE_URL}${path}`, {
    headers: {
      'Content-Type': 'application/json',
      ...(API_KEY ? { 'x-api-key': API_KEY } : {})
    },
    ...options
  });
  const body = await res.json().catch(() => null);
  if (!res.ok) {
    throw new Error(body?.error?.message || `Request failed (${res.status})`);
  }
  return body;
}

export async function searchBuses(params) {
  const query = new URLSearchParams({
    from: params.fromCity,
    to: params.toCity,
    date: params.travelDate,
    passengers: String(params.passengers ?? 1)
  });
  return request(`/api/buses/search?${query}`);
}

export async function getTrip(tripId) {
  return request(`/api/trips/${encodeURIComponent(tripId)}`);
}

export async function getSeatMap(tripId) {
  return request(`/api/trips/${encodeURIComponent(tripId)}/seats`);
}

export async function createBooking(payload) {
  return request('/api/bookings', { method: 'POST', body: JSON.stringify(payload) });
}

export async function getBooking(bookingReferenceId) {
  return request(`/api/bookings/${encodeURIComponent(bookingReferenceId)}`);
}
