import { STEPS } from '../../context/BookingContext.jsx';

const LABELS = {
  search: 'Search',
  results: 'Results',
  seats: 'Seats',
  passengers: 'Passengers',
  payment: 'Payment',
  confirmation: 'Confirmation'
};

export default function StepProgress({ currentStep }) {
  const currentIndex = STEPS.indexOf(currentStep);

  return (
    <ol className="step-progress">
      {STEPS.map((step, index) => {
        const status = index < currentIndex ? 'done' : index === currentIndex ? 'active' : 'upcoming';
        return (
          <li key={step} className={`step-progress__item step-progress__item--${status}`}>
            <span className="step-progress__dot">{index < currentIndex ? '✓' : index + 1}</span>
            <span className="step-progress__label">{LABELS[step]}</span>
          </li>
        );
      })}
    </ol>
  );
}
