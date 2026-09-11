import { useState } from 'react';

const TABS = ['All', 'Seating', 'Amenities', 'Safety'];

const GALLERY_ITEMS = [
  { category: 'Seating', icon: '💺', title: 'Spacious Reclining Seats', background: 'linear-gradient(135deg, #0d6b5f, #14b8a6)' },
  { category: 'Seating', icon: '🛏️', title: 'AC Sleeper Berths', background: 'linear-gradient(135deg, #0369a1, #0d6b5f)' },
  { category: 'Amenities', icon: '🔌', title: 'Charging Points Onboard', background: 'linear-gradient(135deg, #f59e0b, #d97e06)' },
  { category: 'Amenities', icon: '📶', title: 'Free Onboard Wi-Fi', background: 'linear-gradient(135deg, #7c3aed, #4c1d95)' },
  { category: 'Safety', icon: '📷', title: 'CCTV Monitored Buses', background: 'linear-gradient(135deg, #b91c1c, #7f1d1d)' },
  { category: 'Safety', icon: '🧯', title: 'Emergency Safety Kit', background: 'linear-gradient(135deg, #0d6b5f, #4c1d95)' }
];

export default function PhotoGallery() {
  const [activeTab, setActiveTab] = useState('All');
  const items = activeTab === 'All' ? GALLERY_ITEMS : GALLERY_ITEMS.filter((item) => item.category === activeTab);

  return (
    <section className="gallery">
      <h2>Onboard the RoadLink Experience</h2>
      <div className="gallery__tabs">
        {TABS.map((tab) => (
          <button
            key={tab}
            type="button"
            className={`gallery__tab ${activeTab === tab ? 'gallery__tab--active' : ''}`}
            onClick={() => setActiveTab(tab)}
          >
            {tab}
          </button>
        ))}
      </div>
      <div className="gallery__grid">
        {items.map((item) => (
          <div key={item.title} className="gallery-tile" style={{ background: item.background }}>
            <span className="gallery-tile__icon">{item.icon}</span>
            <span className="gallery-tile__title">{item.title}</span>
          </div>
        ))}
      </div>
    </section>
  );
}
