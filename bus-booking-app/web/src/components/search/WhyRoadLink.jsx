const REASONS = [
  { icon: '🕒', title: 'On-Time Departures', description: 'Reliable schedules tracked live from every boarding point.' },
  { icon: '✅', title: 'Verified Operators', description: 'Every operator on RoadLink is vetted for safety and service quality.' },
  { icon: '💺', title: 'Live Seat Availability', description: 'See real seat maps and fares before you commit — no surprises.' },
  { icon: '🔒', title: 'Secure Payments', description: 'Your booking and payment details are encrypted end to end.' }
];

export default function WhyRoadLink() {
  return (
    <section className="why-us">
      <h2>Why RoadLink is the Smarter Way to Travel</h2>
      <div className="why-us__grid">
        {REASONS.map((reason) => (
          <div key={reason.title} className="why-us__item">
            <span className="why-us__icon">{reason.icon}</span>
            <h3>{reason.title}</h3>
            <p>{reason.description}</p>
          </div>
        ))}
      </div>
    </section>
  );
}
