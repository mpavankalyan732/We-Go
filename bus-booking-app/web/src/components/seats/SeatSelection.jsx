import { useBooking } from '../../context/BookingContext.jsx';
import { formatCurrency, formatDisplayDate } from '../../utils/formatters.js';
import SeatMap from './SeatMap.jsx';
import SeatLegend from './SeatLegend.jsx';

export default function SeatSelection() {
  const { state, toggleSeat, goToPassengers, goBack } = useBooking();
  const { selectedTrip, seatMap, selectedSeats, search } = state;

  const seatByNumber = new Map(seatMap.map((s) => [s.number, s]));
  const totalFare = selectedSeats.reduce(
    (sum, num) => sum + selectedTrip.fare + (seatByNumber.get(num)?.priceModifier ?? 0),
    0
  );
  const canContinue = selectedSeats.length === search.passengers;

  return (
    <section className="seat-selection">
      <button className="btn btn--link" onClick={goBack}>
        ← Back to Results
      </button>

      <div className="trip-summary card">
        <div>
          <h2>{selectedTrip.operator}</h2>
          <p>
            {selectedTrip.busType} · {selectedTrip.fromCity} → {selectedTrip.toCity} ·{' '}
            {formatDisplayDate(search.travelDate)}
          </p>
        </div>
        <div className="trip-summary__timing">
          <strong>{selectedTrip.departureTime}</strong> → <strong>{selectedTrip.arrivalTime}</strong>
        </div>
      </div>

      <div className="seat-selection__body">
        <div className="card seat-selection__map">
          <SeatLegend />
          <SeatMap seatMap={seatMap} selectedSeats={selectedSeats} onToggle={toggleSeat} fare={selectedTrip.fare} />
        </div>

        <aside className="card seat-selection__sidebar">
          <h3>Your Selection</h3>
          <p className="seat-selection__hint">
            Select {search.passengers} seat{search.passengers > 1 ? 's' : ''} ({selectedSeats.length}/{search.passengers} chosen)
          </p>
          <div className="seat-selection__chips">
            {selectedSeats.length === 0 && <span className="empty-state">No seats selected yet</span>}
            {selectedSeats.map((num) => (
              <span key={num} className="chip">
                {num}
              </span>
            ))}
          </div>
          <div className="seat-selection__total">
            <span>Total Fare</span>
            <strong>{formatCurrency(totalFare)}</strong>
          </div>
          <button className="btn btn--primary btn--full" disabled={!canContinue} onClick={goToPassengers}>
            Continue to Passenger Details
          </button>
        </aside>
      </div>
    </section>
  );
}
