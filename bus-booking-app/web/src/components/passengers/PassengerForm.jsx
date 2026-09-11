import { useState } from 'react';
import { useBooking } from '../../context/BookingContext.jsx';
import { isValidEmail, isValidPhone } from '../../utils/validators.js';

export default function PassengerForm() {
  const { state, updatePassenger, goToPayment, goBack } = useBooking();
  const { passengers } = state;
  const [formError, setFormError] = useState(null);

  function handleSubmit(e) {
    e.preventDefault();
    for (let i = 0; i < passengers.length; i++) {
      const p = passengers[i];
      if (!p.name.trim() || !p.age || !p.gender) {
        setFormError(`Please complete name, age and gender for passenger ${i + 1} (seat ${p.seatNumber}).`);
        return;
      }
      if (Number(p.age) < 1 || Number(p.age) > 120) {
        setFormError(`Please enter a valid age for passenger ${i + 1} (seat ${p.seatNumber}).`);
        return;
      }
    }
    const primary = passengers[0];
    if (!isValidEmail(primary.email)) {
      setFormError('Please enter a valid email address for the primary passenger (used for booking confirmation).');
      return;
    }
    if (!isValidPhone(primary.phone)) {
      setFormError('Please enter a valid 10-digit phone number for the primary passenger.');
      return;
    }
    setFormError(null);
    goToPayment();
  }

  return (
    <section className="card passenger-form-section">
      <button className="btn btn--link" onClick={goBack}>
        ← Back to Seats
      </button>
      <h2>Passenger Details</h2>

      <form onSubmit={handleSubmit}>
        {passengers.map((p, index) => (
          <fieldset key={p.seatNumber} className="passenger-fieldset">
            <legend>
              Passenger {index + 1} · Seat {p.seatNumber}
              {index === 0 && <span className="badge badge--rating">Primary Contact</span>}
            </legend>

            <div className="passenger-fieldset__grid">
              <div className="search-form__field">
                <label>Full Name</label>
                <input
                  value={p.name}
                  onChange={(e) => updatePassenger(index, 'name', e.target.value)}
                  placeholder="As per ID proof"
                />
              </div>
              <div className="search-form__field search-form__field--narrow">
                <label>Age</label>
                <input
                  type="number"
                  min="1"
                  max="120"
                  value={p.age}
                  onChange={(e) => updatePassenger(index, 'age', e.target.value)}
                />
              </div>
              <div className="search-form__field search-form__field--narrow">
                <label>Gender</label>
                <select value={p.gender} onChange={(e) => updatePassenger(index, 'gender', e.target.value)}>
                  <option>Male</option>
                  <option>Female</option>
                  <option>Other</option>
                </select>
              </div>

              {index === 0 && (
                <>
                  <div className="search-form__field">
                    <label>Email</label>
                    <input
                      type="email"
                      value={p.email}
                      onChange={(e) => updatePassenger(index, 'email', e.target.value)}
                      placeholder="you@example.com"
                    />
                  </div>
                  <div className="search-form__field">
                    <label>Phone Number</label>
                    <input
                      type="tel"
                      value={p.phone}
                      onChange={(e) => updatePassenger(index, 'phone', e.target.value)}
                      placeholder="10-digit mobile number"
                    />
                  </div>
                </>
              )}
            </div>
          </fieldset>
        ))}

        {formError && <p className="field-error">{formError}</p>}

        <button type="submit" className="btn btn--primary btn--full">
          Continue to Payment
        </button>
      </form>
    </section>
  );
}
