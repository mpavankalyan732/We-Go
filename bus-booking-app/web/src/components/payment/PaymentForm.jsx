import { useState } from 'react';
import { useBooking } from '../../context/BookingContext.jsx';
import { formatCurrency } from '../../utils/formatters.js';
import Loader from '../common/Loader.jsx';
import ErrorBanner from '../common/ErrorBanner.jsx';

// Payment is simulated for the demo: no real gateway is called. When a real
// payment gateway is integrated later, its client SDK would run here first
// (tokenize the card, confirm the charge) and only then call confirmBooking(),
// which is what actually creates the booking against the external Bus API.
export default function PaymentForm() {
  const { state, confirmBooking, goBack } = useBooking();
  const { selectedTrip, selectedSeats, seatMap, loading, error } = state;
  const [card, setCard] = useState({ number: '', expiry: '', cvv: '' });
  const [formError, setFormError] = useState(null);

  const seatByNumber = new Map(seatMap.map((s) => [s.number, s]));
  const totalFare = selectedSeats.reduce(
    (sum, num) => sum + selectedTrip.fare + (seatByNumber.get(num)?.priceModifier ?? 0),
    0
  );

  function handlePay(e) {
    e.preventDefault();
    const digitsOnly = card.number.replace(/\s/g, '');
    if (digitsOnly.length !== 16 || !/^\d{16}$/.test(digitsOnly)) {
      setFormError('Enter a valid 16-digit card number.');
      return;
    }
    if (!/^\d{2}\/\d{2}$/.test(card.expiry)) {
      setFormError('Enter expiry as MM/YY.');
      return;
    }
    if (!/^\d{3}$/.test(card.cvv)) {
      setFormError('Enter a valid 3-digit CVV.');
      return;
    }
    setFormError(null);
    confirmBooking();
  }

  return (
    <section className="card payment-section">
      <button className="btn btn--link" onClick={goBack} disabled={loading}>
        ← Back to Passenger Details
      </button>
      <h2>Payment</h2>
      <p className="payment-section__demo-note">Demo mode — no real charge will be made.</p>

      <div className="payment-section__body">
        <form className="payment-form" onSubmit={handlePay}>
          <div className="search-form__field">
            <label>Card Number</label>
            <input
              placeholder="4111 1111 1111 1111"
              maxLength={19}
              value={card.number}
              onChange={(e) => setCard((c) => ({ ...c, number: e.target.value }))}
              disabled={loading}
            />
          </div>
          <div className="passenger-fieldset__grid">
            <div className="search-form__field search-form__field--narrow">
              <label>Expiry (MM/YY)</label>
              <input
                placeholder="08/28"
                maxLength={5}
                value={card.expiry}
                onChange={(e) => setCard((c) => ({ ...c, expiry: e.target.value }))}
                disabled={loading}
              />
            </div>
            <div className="search-form__field search-form__field--narrow">
              <label>CVV</label>
              <input
                placeholder="123"
                maxLength={3}
                value={card.cvv}
                onChange={(e) => setCard((c) => ({ ...c, cvv: e.target.value }))}
                disabled={loading}
              />
            </div>
          </div>

          {formError && <p className="field-error">{formError}</p>}
          <ErrorBanner message={error} />

          <button type="submit" className="btn btn--primary btn--full" disabled={loading}>
            {loading ? 'Processing…' : `Pay ${formatCurrency(totalFare)} & Confirm Booking`}
          </button>
          {loading && <Loader label="Confirming your booking with the bus operator…" />}
        </form>

        <aside className="card fare-summary">
          <h3>Fare Summary</h3>
          <div className="fare-summary__row">
            <span>
              {selectedSeats.length} seat{selectedSeats.length > 1 ? 's' : ''} × {selectedTrip.operator}
            </span>
          </div>
          <ul className="fare-summary__seats">
            {selectedSeats.map((num) => (
              <li key={num}>
                <span>Seat {num}</span>
                <span>{formatCurrency(selectedTrip.fare + (seatByNumber.get(num)?.priceModifier ?? 0))}</span>
              </li>
            ))}
          </ul>
          <div className="fare-summary__total">
            <span>Total Amount</span>
            <strong>{formatCurrency(totalFare)}</strong>
          </div>
        </aside>
      </div>
    </section>
  );
}
