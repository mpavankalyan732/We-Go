import { useState } from 'react';
import Header from './components/layout/Header.jsx';
import { BookingProvider } from './context/BookingContext.jsx';
import BookingFlow from './BookingFlow.jsx';
import TrackBooking from './components/track/TrackBooking.jsx';

export default function App() {
  const [view, setView] = useState('flow');

  return (
    <BookingProvider>
      <Header view={view} onNavigate={setView} />
      <main className="app-main">{view === 'track' ? <TrackBooking /> : <BookingFlow />}</main>
      <footer className="site-footer">
        <p>RoadLink Bus Booking — demo build. Payments are simulated; bus data is served by the RoadLink Bus API.</p>
      </footer>
    </BookingProvider>
  );
}
