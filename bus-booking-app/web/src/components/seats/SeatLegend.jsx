const ITEMS = [
  { status: 'available', label: 'Available' },
  { status: 'selected', label: 'Selected' },
  { status: 'booked', label: 'Booked' },
  { status: 'blocked', label: 'Blocked' }
];

export default function SeatLegend() {
  return (
    <ul className="seat-legend">
      {ITEMS.map((item) => (
        <li key={item.status} className="seat-legend__item">
          <span className={`seat-swatch seat-swatch--${item.status}`} />
          {item.label}
        </li>
      ))}
    </ul>
  );
}
