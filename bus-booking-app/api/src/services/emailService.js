// Sends the booking confirmation email via SMTP (nodemailer). Best-effort and
// non-blocking, same pattern as salesforceSync.js: an email failure is only
// logged, never thrown — it should never fail the customer's booking. Skips
// entirely (logged, not thrown) if SMTP_* env vars aren't configured.
import nodemailer from 'nodemailer';

let cachedTransporter = null;

function getTransporter() {
  if (cachedTransporter) return cachedTransporter;

  const host = process.env.SMTP_HOST;
  const port = process.env.SMTP_PORT;
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;
  if (!host || !port || !user || !pass) return null;

  cachedTransporter = nodemailer.createTransport({
    host,
    port: Number(port),
    secure: Number(port) === 465,
    auth: { user, pass }
  });
  return cachedTransporter;
}

const REFUND_POLICY_TEXT =
  'Full refund if cancelled more than 24 hours before departure. ' +
  '50% refund if cancelled within 24 hours of departure. ' +
  'No refund once departure has passed.';

const RESCHEDULE_POLICY_TEXT =
  'You can reschedule to a different trip on the same route before departure, subject to seat availability. ' +
  'Any fare difference between your original and new trip is adjusted automatically.';

function formatPassengerLines(passengers) {
  return passengers.map((p) => `  • Seat ${p.seatNumber} — ${p.name} (${p.age}, ${p.gender})`).join('\n');
}

function formatPassengerRows(passengers) {
  return passengers
    .map(
      (p) => `<tr>
        <td style="padding:6px 12px;border:1px solid #e2e2e2;">${p.seatNumber}</td>
        <td style="padding:6px 12px;border:1px solid #e2e2e2;">${p.name}</td>
        <td style="padding:6px 12px;border:1px solid #e2e2e2;">${p.age}</td>
        <td style="padding:6px 12px;border:1px solid #e2e2e2;">${p.gender}</td>
      </tr>`
    )
    .join('');
}

function buildBookingConfirmationText(booking) {
  const { trip } = booking;
  return `Your RoadLink booking is confirmed!

Booking Reference: ${booking.bookingReferenceId}
PNR: ${booking.pnr}
Status: ${booking.status}

Trip Details
------------
Operator: ${trip.operator} (${trip.busType})
Route: ${trip.fromCity} -> ${trip.toCity}
Travel Date: ${trip.travelDate}
Departure: ${trip.departureTime} from ${trip.boardingPoint}
Arrival: ${trip.arrivalTime} at ${trip.droppingPoint}

Passengers
----------
${formatPassengerLines(booking.passengers)}

Total Amount: INR ${booking.totalAmount}

Cancellation & Refund Policy
-----------------------------
${REFUND_POLICY_TEXT}

Reschedule Policy
------------------
${RESCHEDULE_POLICY_TEXT}

Thank you for booking with RoadLink.
`;
}

function buildBookingConfirmationHtml(booking) {
  const { trip } = booking;
  return `
  <div style="font-family:Arial,sans-serif;color:#222;max-width:600px;margin:0 auto;">
    <h2 style="color:#1a73e8;">Your RoadLink booking is confirmed!</h2>
    <p><strong>Booking Reference:</strong> ${booking.bookingReferenceId}<br/>
       <strong>PNR:</strong> ${booking.pnr}<br/>
       <strong>Status:</strong> ${booking.status}</p>

    <h3>Trip Details</h3>
    <p>
      <strong>Operator:</strong> ${trip.operator} (${trip.busType})<br/>
      <strong>Route:</strong> ${trip.fromCity} &rarr; ${trip.toCity}<br/>
      <strong>Travel Date:</strong> ${trip.travelDate}<br/>
      <strong>Boarding Point:</strong> ${trip.boardingPoint} at ${trip.departureTime}<br/>
      <strong>Dropping Point:</strong> ${trip.droppingPoint} at ${trip.arrivalTime}
    </p>

    <h3>Passengers</h3>
    <table style="border-collapse:collapse;width:100%;">
      <thead>
        <tr>
          <th style="padding:6px 12px;border:1px solid #e2e2e2;text-align:left;">Seat</th>
          <th style="padding:6px 12px;border:1px solid #e2e2e2;text-align:left;">Name</th>
          <th style="padding:6px 12px;border:1px solid #e2e2e2;text-align:left;">Age</th>
          <th style="padding:6px 12px;border:1px solid #e2e2e2;text-align:left;">Gender</th>
        </tr>
      </thead>
      <tbody>${formatPassengerRows(booking.passengers)}</tbody>
    </table>

    <p><strong>Total Amount:</strong> INR ${booking.totalAmount}</p>

    <h3>Cancellation &amp; Refund Policy</h3>
    <p>${REFUND_POLICY_TEXT}</p>

    <h3>Reschedule Policy</h3>
    <p>${RESCHEDULE_POLICY_TEXT}</p>

    <p style="color:#666;font-size:13px;">Thank you for booking with RoadLink.</p>
  </div>`;
}

// booking is the JSON shape returned by composeBookingJson() in
// bookingService.js. Sends to booking.contactEmail (the primary contact
// captured at booking time) — individual passengers' own email/phone fields
// are optional and not all guaranteed to be filled in.
export async function sendBookingConfirmationEmail(booking) {
  const transporter = getTransporter();
  if (!transporter) {
    console.log('[emailService] SMTP not configured — skipping booking confirmation email.');
    return { sent: false, reason: 'not_configured' };
  }
  if (!booking.contactEmail) {
    console.log(`[emailService] No contactEmail on booking ${booking.bookingReferenceId} — skipping.`);
    return { sent: false, reason: 'no_recipient' };
  }

  try {
    await transporter.sendMail({
      from: process.env.SMTP_FROM || process.env.SMTP_USER,
      to: booking.contactEmail,
      subject: `Booking Confirmed - ${booking.bookingReferenceId}`,
      text: buildBookingConfirmationText(booking),
      html: buildBookingConfirmationHtml(booking)
    });
    console.log(`[emailService] Sent booking confirmation for ${booking.bookingReferenceId} to ${booking.contactEmail}`);
    return { sent: true };
  } catch (err) {
    console.error(`[emailService] Failed to send confirmation for ${booking.bookingReferenceId}:`, err.message);
    return { sent: false, reason: err.message };
  }
}
