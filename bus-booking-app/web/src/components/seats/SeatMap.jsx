import { useMemo } from 'react';

function seatButton(seat, selectedSeats, onToggle, fare) {
  const isSelected = selectedSeats.includes(seat.number);
  const status = isSelected ? 'selected' : seat.status;
  const disabled = seat.status !== 'available' && !isSelected;
  const price = fare + seat.priceModifier;

  return (
    <button
      key={seat.number}
      type="button"
      className={`seat seat--${status}`}
      disabled={disabled}
      title={`Seat ${seat.number} · ₹${price}`}
      onClick={() => onToggle(seat.number)}
    >
      {seat.number}
    </button>
  );
}

export default function SeatMap({ seatMap, selectedSeats, onToggle, fare }) {
  const grouped = useMemo(() => {
    const isSleeper = seatMap.some((s) => s.deck);
    if (isSleeper) {
      const decks = {};
      seatMap.forEach((s) => {
        decks[s.deck] = decks[s.deck] || {};
        decks[s.deck][s.row] = decks[s.deck][s.row] || {};
        decks[s.deck][s.row][s.col] = s;
      });
      return { type: 'sleeper', decks };
    }
    const rows = {};
    seatMap.forEach((s) => {
      rows[s.row] = rows[s.row] || {};
      rows[s.row][s.col] = s;
    });
    return { type: 'seater', rows };
  }, [seatMap]);

  if (grouped.type === 'sleeper') {
    return (
      <div className="seat-map seat-map--sleeper">
        {Object.entries(grouped.decks).map(([deck, rows]) => (
          <div key={deck} className="seat-deck">
            <h4 className="seat-deck__title">{deck} Deck</h4>
            <div className="seat-deck__rows">
              {Object.keys(rows)
                .sort((a, b) => Number(a) - Number(b))
                .map((row) => {
                  const r = rows[row];
                  return (
                    <div key={row} className="seat-row seat-row--sleeper">
                      <div className="seat-row__single">{r.A && seatButton(r.A, selectedSeats, onToggle, fare)}</div>
                      <div className="seat-row__gap" aria-hidden="true" />
                      <div className="seat-row__double">
                        {r.B && seatButton(r.B, selectedSeats, onToggle, fare)}
                        {r.C && seatButton(r.C, selectedSeats, onToggle, fare)}
                      </div>
                    </div>
                  );
                })}
            </div>
          </div>
        ))}
      </div>
    );
  }

  return (
    <div className="seat-map seat-map--seater">
      {Object.keys(grouped.rows)
        .sort((a, b) => Number(a) - Number(b))
        .map((row) => {
          const r = grouped.rows[row];
          return (
            <div key={row} className="seat-row seat-row--seater">
              <div className="seat-row__double">
                {r.A && seatButton(r.A, selectedSeats, onToggle, fare)}
                {r.B && seatButton(r.B, selectedSeats, onToggle, fare)}
              </div>
              <div className="seat-row__gap" aria-hidden="true" />
              <div className="seat-row__double">
                {r.C && seatButton(r.C, selectedSeats, onToggle, fare)}
                {r.D && seatButton(r.D, selectedSeats, onToggle, fare)}
              </div>
            </div>
          );
        })}
    </div>
  );
}
