import { useState } from 'react';
import * as busApi from '../../api/busApiService.js';
import Loader from '../common/Loader.jsx';
import ErrorBanner from '../common/ErrorBanner.jsx';
import BookingSummaryCard from '../confirmation/BookingSummaryCard.jsx';

export default function TrackBooking() {
  const [referenceId, setReferenceId] = useState('');
  const [booking, setBooking] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  async function handleSubmit(e) {
    e.preventDefault();
    if (!referenceId.trim()) return;
    setLoading(true);
    setError(null);
    setBooking(null);
    try {
      const result = await busApi.getBooking(referenceId.trim().toUpperCase());
      setBooking(result);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  }

  return (
    <section className="card track-booking">
      <h2>Track Your Booking</h2>
      <p className="search-card__subtitle">Enter the booking reference ID you received at checkout</p>

      <form className="track-booking__form" onSubmit={handleSubmit}>
        <input
          placeholder="e.g. BK-7F3K2Q"
          value={referenceId}
          onChange={(e) => setReferenceId(e.target.value)}
        />
        <button type="submit" className="btn btn--primary" disabled={loading}>
          {loading ? 'Searching…' : 'Find Booking'}
        </button>
      </form>

      {loading && <Loader label="Looking up your booking…" />}
      <ErrorBanner message={error} />
      {booking && (
        <div className="track-booking__result">
          <BookingSummaryCard booking={booking} />
        </div>
      )}
    </section>
  );
}
