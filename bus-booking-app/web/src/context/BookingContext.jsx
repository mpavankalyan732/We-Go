import { createContext, useCallback, useContext, useMemo, useReducer } from 'react';
import * as busApi from '../api/busApiService.js';

export const STEPS = ['search', 'results', 'seats', 'passengers', 'payment', 'confirmation'];

const initialState = {
  step: 'search',
  search: { fromCity: '', toCity: '', travelDate: '', passengers: 1 },
  trips: [],
  selectedTrip: null,
  seatMap: [],
  selectedSeats: [],
  passengers: [],
  booking: null,
  loading: false,
  error: null
};

function reducer(state, action) {
  switch (action.type) {
    case 'LOADING':
      return { ...state, loading: true, error: null };
    case 'ERROR':
      return { ...state, loading: false, error: action.error };
    case 'SEARCH_SUCCESS':
      return { ...state, loading: false, search: action.search, trips: action.trips, step: 'results' };
    case 'SELECT_TRIP':
      return { ...state, selectedTrip: action.trip };
    case 'SEATMAP_SUCCESS':
      return { ...state, loading: false, seatMap: action.seatMap, selectedSeats: [], step: 'seats' };
    case 'TOGGLE_SEAT': {
      const already = state.selectedSeats.includes(action.seatNumber);
      if (already) {
        return { ...state, selectedSeats: state.selectedSeats.filter((n) => n !== action.seatNumber) };
      }
      if (state.selectedSeats.length >= state.search.passengers) {
        return state;
      }
      return { ...state, selectedSeats: [...state.selectedSeats, action.seatNumber] };
    }
    case 'GO_TO_PASSENGERS':
      return {
        ...state,
        step: 'passengers',
        passengers: state.selectedSeats.map(
          (seatNumber, i) =>
            state.passengers[i] && state.passengers[i].seatNumber === seatNumber
              ? state.passengers[i]
              : { seatNumber, name: '', age: '', gender: 'Male', email: '', phone: '' }
        )
      };
    case 'UPDATE_PASSENGER': {
      const passengers = [...state.passengers];
      passengers[action.index] = { ...passengers[action.index], [action.field]: action.value };
      return { ...state, passengers };
    }
    case 'GO_TO_PAYMENT':
      return { ...state, step: 'payment' };
    case 'BOOKING_SUCCESS':
      return { ...state, loading: false, booking: action.booking, step: 'confirmation' };
    case 'BACK': {
      const idx = STEPS.indexOf(state.step);
      return idx > 0 ? { ...state, step: STEPS[idx - 1], error: null } : state;
    }
    case 'RESTART':
      return { ...initialState };
    default:
      return state;
  }
}

const BookingContext = createContext(null);

export function BookingProvider({ children }) {
  const [state, dispatch] = useReducer(reducer, initialState);

  const search = useCallback(async (searchParams) => {
    dispatch({ type: 'LOADING' });
    try {
      const trips = await busApi.searchBuses(searchParams);
      dispatch({ type: 'SEARCH_SUCCESS', search: searchParams, trips });
    } catch (e) {
      dispatch({ type: 'ERROR', error: e.message });
    }
  }, []);

  const selectTrip = useCallback(async (trip) => {
    dispatch({ type: 'SELECT_TRIP', trip });
    dispatch({ type: 'LOADING' });
    try {
      const seatMap = await busApi.getSeatMap(trip.tripId);
      dispatch({ type: 'SEATMAP_SUCCESS', seatMap });
    } catch (e) {
      dispatch({ type: 'ERROR', error: e.message });
    }
  }, []);

  const toggleSeat = useCallback((seatNumber) => dispatch({ type: 'TOGGLE_SEAT', seatNumber }), []);
  const goToPassengers = useCallback(() => dispatch({ type: 'GO_TO_PASSENGERS' }), []);
  const updatePassenger = useCallback(
    (index, field, value) => dispatch({ type: 'UPDATE_PASSENGER', index, field, value }),
    []
  );
  const goToPayment = useCallback(() => dispatch({ type: 'GO_TO_PAYMENT' }), []);

  const confirmBooking = useCallback(async () => {
    dispatch({ type: 'LOADING' });
    try {
      const primary = state.passengers[0] ?? {};
      const booking = await busApi.createBooking({
        tripId: state.selectedTrip.tripId,
        seatNumbers: state.selectedSeats,
        passengers: state.passengers,
        contactEmail: primary.email,
        contactPhone: primary.phone
      });
      dispatch({ type: 'BOOKING_SUCCESS', booking });
    } catch (e) {
      dispatch({ type: 'ERROR', error: e.message });
    }
  }, [state.selectedTrip, state.selectedSeats, state.passengers]);

  const goBack = useCallback(() => dispatch({ type: 'BACK' }), []);
  const restart = useCallback(() => dispatch({ type: 'RESTART' }), []);

  const value = useMemo(
    () => ({
      state,
      search,
      selectTrip,
      toggleSeat,
      goToPassengers,
      updatePassenger,
      goToPayment,
      confirmBooking,
      goBack,
      restart
    }),
    [state, search, selectTrip, toggleSeat, goToPassengers, updatePassenger, goToPayment, confirmBooking, goBack, restart]
  );

  return <BookingContext.Provider value={value}>{children}</BookingContext.Provider>;
}

export function useBooking() {
  const ctx = useContext(BookingContext);
  if (!ctx) throw new Error('useBooking must be used within a BookingProvider');
  return ctx;
}
