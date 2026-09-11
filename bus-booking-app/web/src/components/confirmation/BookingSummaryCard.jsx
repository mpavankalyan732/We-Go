import { formatCurrency, formatDisplayDate } from '../../utils/formatters.js';

export default function BookingSummaryCard({ booking }) {
  return (
    <>
      <div className="confirmation-card__ids">
        <div>
          <span>Booking Reference ID</span>
          <strong>{booking.bookingReferenceId}</strong>
        </div>
        <div>
          <span>PNR</span>
          <strong>{booking.pnr}</strong>
        </div>
        <div>
          <span>Status</span>
          <strong className={`badge ${booking.status === 'Confirmed' ? 'badge--success' : 'badge--warning'}`}>
            {booking.status}
          </strong>
        </div>
      </div>

      <div className="confirmation-card__grid">
        <div>
          <h4>Trip Details</h4>
          <p>
            {booking.trip.operator} · {booking.trip.busType}
          </p>
          <p>
            {booking.trip.fromCity} → {booking.trip.toCity}
          </p>
          <p>{formatDisplayDate(booking.trip.travelDate)}</p>
          <p>
            Departure {booking.trip.departureTime} · Arrival {booking.trip.arrivalTime}
          </p>
          <p>Boarding: {booking.trip.boardingPoint}</p>
        </div>

        <div>
          <h4>Seats</h4>
          <div className="seat-selection__chips">
            {booking.seatNumbers.map((num) => (
              <span key={num} className="chip">
                {num}
              </span>
            ))}
          </div>
          <h4 className="confirmation-card__amount-label">Total Amount</h4>
          <strong className="confirmation-card__amount">{formatCurrency(booking.totalAmount)}</strong>
        </div>
      </div>

      <div>
        <h4>Passengers</h4>
        <table className="confirmation-card__table">
          <thead>
            <tr>
              <th>Name</th>
              <th>Age</th>
              <th>Gender</th>
              <th>Seat</th>
            </tr>
          </thead>
          <tbody>
            {booking.passengers.map((p) => (
              <tr key={p.seatNumber}>
                <td>{p.name}</td>
                <td>{p.age}</td>
                <td>{p.gender}</td>
                <td>{p.seatNumber}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </>
  );
}
