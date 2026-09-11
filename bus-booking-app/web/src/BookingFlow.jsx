import { useBooking } from './context/BookingContext.jsx';
import StepProgress from './components/layout/StepProgress.jsx';
import Loader from './components/common/Loader.jsx';
import ErrorBanner from './components/common/ErrorBanner.jsx';
import SearchSection from './components/search/SearchSection.jsx';
import ResultsList from './components/results/ResultsList.jsx';
import SeatSelection from './components/seats/SeatSelection.jsx';
import PassengerForm from './components/passengers/PassengerForm.jsx';
import PaymentForm from './components/payment/PaymentForm.jsx';
import ConfirmationCard from './components/confirmation/ConfirmationCard.jsx';

export default function BookingFlow() {
  const { state } = useBooking();
  const { step, loading, error } = state;

  return (
    <div className="booking-flow">
      {step !== 'search' && <StepProgress currentStep={step} />}

      {/* search/seat-map loading & errors surface here; payment has its own inline UI */}
      {step !== 'payment' && loading && (
        <div className="app-main__loading">
          <Loader label={step === 'results' ? 'Loading seat map…' : 'Searching buses…'} />
        </div>
      )}
      {step !== 'payment' && <ErrorBanner message={error} />}

      {step === 'search' && <SearchSection />}
      {step === 'results' && !loading && <ResultsList />}
      {step === 'seats' && <SeatSelection />}
      {step === 'passengers' && <PassengerForm />}
      {step === 'payment' && <PaymentForm />}
      {step === 'confirmation' && <ConfirmationCard />}
    </div>
  );
}
