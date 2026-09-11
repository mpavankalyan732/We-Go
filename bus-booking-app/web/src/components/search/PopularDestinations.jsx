import { useBooking } from '../../context/BookingContext.jsx';
import { POPULAR_CITIES } from '../../utils/cities.js';

const DEFAULT_ORIGIN = 'Chennai';
const GRADIENTS = [
  'linear-gradient(135deg, #0d6b5f, #14b8a6)',
  'linear-gradient(135deg, #f59e0b, #d97e06)',
  'linear-gradient(135deg, #0369a1, #0d6b5f)',
  'linear-gradient(135deg, #7c3aed, #0d6b5f)',
  'linear-gradient(135deg, #d97e06, #0d6b5f)'
];

// Only cities with a generated photo go here; every other city falls back to
// the gradient tiles below so the grid never breaks waiting on more images.
const DESTINATION_IMAGES = {
  Vellore: '/images/destinations/vellore.png'
};

function tomorrowIsoDate() {
  return new Date(Date.now() + 86400000).toISOString().slice(0, 10);
}

function destinationCardStyle(city, index) {
  const image = DESTINATION_IMAGES[city];
  if (image) {
    return {
      backgroundImage: `linear-gradient(to top, rgba(9, 26, 23, 0.85), rgba(9, 26, 23, 0.15)), url('${image}')`
    };
  }
  return { background: GRADIENTS[index % GRADIENTS.length] };
}

export default function PopularDestinations() {
  const { search } = useBooking();
  const destinations = POPULAR_CITIES.filter((city) => city !== DEFAULT_ORIGIN);

  function quickSearch(city) {
    search({ fromCity: DEFAULT_ORIGIN, toCity: city, travelDate: tomorrowIsoDate(), passengers: 1 });
  }

  return (
    <section className="popular-destinations">
      <h2>Discover Your Next Journey</h2>
      <p className="popular-destinations__subtitle">Tap a city to see buses from {DEFAULT_ORIGIN}</p>
      <div className="popular-destinations__grid">
        {destinations.map((city, index) => (
          <button
            key={city}
            type="button"
            className="destination-card"
            style={destinationCardStyle(city, index)}
            onClick={() => quickSearch(city)}
          >
            {!DESTINATION_IMAGES[city] && <span className="destination-card__icon">🏙️</span>}
            <span className="destination-card__name">{city}</span>
            <span className="destination-card__cta">Explore buses →</span>
          </button>
        ))}
      </div>
    </section>
  );
}
