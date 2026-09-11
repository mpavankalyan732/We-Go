import { useBooking } from '../../context/BookingContext.jsx';
import BookingSummaryCard from './BookingSummaryCard.jsx';

export default function ConfirmationCard() {
  const { state, restart } = useBooking();
  const { booking } = state;
  if (!booking) return null;

  return (
    <section className="card confirmation-card">
      <div className="confirmation-card__badge">✓</div>
      <h2>Booking Confirmed!</h2>
      <p className="confirmation-card__subtitle">A confirmation has been sent to {booking.contactEmail}</p>

      <BookingSummaryCard booking={booking} />

      <p className="confirmation-card__note">
        Keep your Booking Reference ID handy — it's what you'll use to ask our support assistant for
        rescheduling or cancellation later.
      </p>

      <button className="btn btn--primary" onClick={restart}>
        Book Another Trip
      </button>
    </section>
  );
}
