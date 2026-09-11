const OFFERS = [
  {
    icon: '🎉',
    title: '20% OFF on Your First Booking',
    subtitle: 'New to RoadLink? Get a flat 20% off your first ride.',
    code: 'FIRST20',
    image: '/images/offers/first-booking.png'
  },
  {
    icon: '🤝',
    title: 'Refer & Earn ₹50 Cashback',
    subtitle: 'Invite friends — you both get rewarded after their first trip.',
    code: 'REFER50',
    image: '/images/offers/referral.png'
  },
  {
    icon: '👥',
    title: 'Save More on Group Bookings',
    subtitle: 'Booking 4+ seats together? Unlock extra savings.',
    code: 'GROUP100',
    image: '/images/offers/group-booking.png'
  }
];

export default function OffersSection() {
  return (
    <section className="offers">
      <h2>Offers &amp; Discounts</h2>
      <p className="offers__subtitle">Demo promotions — shown for illustration, not applied at checkout yet</p>
      <div className="offers__grid">
        {OFFERS.map((offer) => (
          <div
            key={offer.code}
            className="offer-card"
            style={{
              backgroundImage: `linear-gradient(to top, rgba(9, 26, 23, 0.85), rgba(9, 26, 23, 0.25)), url('${offer.image}')`
            }}
          >
            <span className="offer-card__icon">{offer.icon}</span>
            <h3>{offer.title}</h3>
            <p>{offer.subtitle}</p>
            <span className="offer-card__code">USE CODE {offer.code}</span>
          </div>
        ))}
      </div>
    </section>
  );
}
