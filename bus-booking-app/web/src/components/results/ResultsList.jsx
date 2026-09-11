import { useBooking } from '../../context/BookingContext.jsx';
import { formatDisplayDate } from '../../utils/formatters.js';
import BusCard from './BusCard.jsx';

export default function ResultsList() {
  const { state, selectTrip, goBack } = useBooking();
  const { trips, search } = state;

  return (
    <section className="results">
      <div className="results__header">
        <div>
          <button className="btn btn--link" onClick={goBack}>
            ← Modify Search
          </button>
          <h2>
            {search.fromCity} → {search.toCity}
          </h2>
          <p className="results__subtitle">
            {formatDisplayDate(search.travelDate)} · {search.passengers} passenger{search.passengers > 1 ? 's' : ''}
          </p>
        </div>
        <span className="results__count">{trips.length} buses found</span>
      </div>

      {trips.length === 0 ? (
        <p className="empty-state">No buses found for this route and date.</p>
      ) : (
        <div className="results__list">
          {trips.map((trip) => (
            <BusCard key={trip.tripId} trip={trip} onSelect={selectTrip} />
          ))}
        </div>
      )}
    </section>
  );
}
