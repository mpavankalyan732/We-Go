import { useState } from 'react';
import { useBooking } from '../../context/BookingContext.jsx';
import { POPULAR_CITIES } from '../../utils/cities.js';
import { todayIsoDate } from '../../utils/formatters.js';

export default function SearchForm() {
  const { search, state } = useBooking();
  const [form, setForm] = useState({
    fromCity: state.search.fromCity || '',
    toCity: state.search.toCity || '',
    travelDate: state.search.travelDate || todayIsoDate(),
    passengers: state.search.passengers || 1
  });
  const [formError, setFormError] = useState(null);

  function handleChange(field, value) {
    setForm((prev) => ({ ...prev, [field]: value }));
  }

  function handleSwap() {
    setForm((prev) => ({ ...prev, fromCity: prev.toCity, toCity: prev.fromCity }));
  }

  function handleSubmit(e) {
    e.preventDefault();
    if (!form.fromCity.trim() || !form.toCity.trim() || !form.travelDate) {
      setFormError('Please fill in from city, to city and travel date.');
      return;
    }
    if (form.fromCity.trim().toLowerCase() === form.toCity.trim().toLowerCase()) {
      setFormError('From city and to city must be different.');
      return;
    }
    setFormError(null);
    search({ ...form, passengers: Number(form.passengers) });
  }

  return (
    <form className="search-form" onSubmit={handleSubmit}>
      <div className="search-form__field">
        <label htmlFor="fromCity">📍 From City</label>
        <input
          id="fromCity"
          list="city-options"
          placeholder="e.g. Chennai"
          value={form.fromCity}
          onChange={(e) => handleChange('fromCity', e.target.value)}
          autoComplete="off"
        />
      </div>

      <button type="button" className="search-form__swap" onClick={handleSwap} aria-label="Swap from and to cities">
        ⇄
      </button>

      <div className="search-form__field">
        <label htmlFor="toCity">🎯 To City</label>
        <input
          id="toCity"
          list="city-options"
          placeholder="e.g. Tirupati"
          value={form.toCity}
          onChange={(e) => handleChange('toCity', e.target.value)}
          autoComplete="off"
        />
      </div>

      <datalist id="city-options">
        {POPULAR_CITIES.map((city) => (
          <option key={city} value={city} />
        ))}
      </datalist>

      <div className="search-form__field">
        <label htmlFor="travelDate">📅 Travel Date</label>
        <input
          id="travelDate"
          type="date"
          min={todayIsoDate()}
          value={form.travelDate}
          onChange={(e) => handleChange('travelDate', e.target.value)}
        />
      </div>

      <div className="search-form__field search-form__field--narrow">
        <label htmlFor="passengers">👥 Passengers</label>
        <select id="passengers" value={form.passengers} onChange={(e) => handleChange('passengers', e.target.value)}>
          {[1, 2, 3, 4, 5, 6].map((n) => (
            <option key={n} value={n}>
              {n}
            </option>
          ))}
        </select>
      </div>

      <button type="submit" className="btn btn--primary search-form__submit">
        Search Buses
      </button>

      {formError && <p className="field-error search-form__error">{formError}</p>}
    </form>
  );
}
