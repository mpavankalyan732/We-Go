import SearchForm from './SearchForm.jsx';

export default function Hero() {
  return (
    <>
      <section className="hero">
        <div className="hero__content">
          <span className="hero__eyebrow">🚌 India's Trusted Bus Booking Platform</span>
          <h1 className="hero__title">Book Bus Tickets Online</h1>
          <p className="hero__subtitle">Real-time seats, instant confirmation, zero hassle.</p>
        </div>
      </section>
      <div className="hero__search card">
        <SearchForm />
      </div>
    </>
  );
}
