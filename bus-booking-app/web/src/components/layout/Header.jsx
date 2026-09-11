export default function Header({ view, onNavigate }) {
  return (
    <header className="site-header">
      <div className="site-header__inner">
        <button className="brand" onClick={() => onNavigate('flow')} aria-label="RoadLink home">
          <img className="brand__mark" src="/images/brand/bus-logo.png" alt="" />
          <span className="brand__name">RoadLink</span>
        </button>
        <nav className="site-header__nav">
          <button
            className={`nav-link ${view === 'track' ? 'nav-link--active' : ''}`}
            onClick={() => onNavigate('track')}
          >
            Track Booking
          </button>
        </nav>
      </div>
    </header>
  );
}
