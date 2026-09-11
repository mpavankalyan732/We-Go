import { db } from '../db/index.js';
import { ApiError } from '../utils/ApiError.js';

const TYPES = new Set(['Booking Confirmation', 'Cancellation', 'Reschedule', 'Reminder']);
const CHANNELS = new Set(['Email', 'SMS', 'WhatsApp']);

// No real email/SMS/WhatsApp provider is wired up for the demo — this logs a
// notification record the same way payment is simulated. Swap in a real
// provider call here when one is available; callers don't need to change.
export function sendNotification({ bookingReferenceId, type, channel, recipient, messageBody }) {
  if (!TYPES.has(type)) throw ApiError.badRequest(`Invalid notification type: ${type}`);
  if (!CHANNELS.has(channel)) throw ApiError.badRequest(`Invalid channel: ${channel}`);
  if (!recipient) throw ApiError.badRequest('recipient is required');

  let bookingId = null;
  if (bookingReferenceId) {
    const booking = db.prepare('SELECT id FROM bookings WHERE booking_reference_id = ?').get(bookingReferenceId);
    if (!booking) throw ApiError.notFound(`No booking found for reference ID: ${bookingReferenceId}`);
    bookingId = booking.id;
  }

  const { lastInsertRowid: id } = db
    .prepare(
      `INSERT INTO notifications (booking_id, type, channel, recipient, status, message_body)
       VALUES (?, ?, ?, ?, 'Sent', ?)`
    )
    .run(bookingId, type, channel, recipient, messageBody || null);

  const row = db.prepare('SELECT * FROM notifications WHERE id = ?').get(id);
  return {
    notificationId: row.id,
    bookingReferenceId: bookingReferenceId || null,
    type: row.type,
    channel: row.channel,
    recipient: row.recipient,
    status: row.status,
    sentAt: `${row.created_at.replace(' ', 'T')}Z`
  };
}
