import { formatCurrency } from '../../utils/formatters.js';

export default function BusCard({ trip, onSelect }) {
  const seatsLow = trip.availableSeats <= 5;

  return (
    <article className="bus-card">
      <div className="bus-card__main">
        <div className="bus-card__operator">
          <h3>{trip.operator}</h3>
          <span className="bus-card__type">{trip.busType}</span>
        </div>

        <div className="bus-card__timing">
          <div className="bus-card__time">
            <strong>{trip.departureTime}</strong>
            <span>{trip.boardingPoint}</span>
          </div>
          <div className="bus-card__duration">
            <span>{trip.durationLabel}</span>
            <div className="bus-card__line" aria-hidden="true" />
          </div>
          <div className="bus-card__time">
            <strong>{trip.arrivalTime}</strong>
            <span>{trip.droppingPoint}</span>
          </div>
        </div>

        <div className="bus-card__meta">
          <span className="badge badge--rating">★ {trip.rating}</span>
          <span className={`badge ${seatsLow ? 'badge--warning' : 'badge--success'}`}>
            {trip.availableSeats} seats left
          </span>
        </div>
      </div>

      <div className="bus-card__action">
        <span className="bus-card__fare">{formatCurrency(trip.fare)}</span>
        <button className="btn btn--primary" onClick={() => onSelect(trip)}>
          Select Seats
        </button>
      </div>
    </article>
  );
}
