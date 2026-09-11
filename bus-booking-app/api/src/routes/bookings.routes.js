import { Router } from 'express';
import { createBooking, getBookingByReference, cancelBooking, rescheduleBooking } from '../services/bookingService.js';

export const bookingsRouter = Router();

// POST /api/bookings
bookingsRouter.post('/', async (req, res, next) => {
  try {
    const booking = await createBooking(req.body);
    res.status(201).json(booking);
  } catch (err) {
    next(err);
  }
});

// GET /api/bookings/:bookingReferenceId
bookingsRouter.get('/:bookingReferenceId', (req, res, next) => {
  try {
    res.json(getBookingByReference(req.params.bookingReferenceId));
  } catch (err) {
    next(err);
  }
});

// POST /api/bookings/:bookingReferenceId/cancel
bookingsRouter.post('/:bookingReferenceId/cancel', (req, res, next) => {
  try {
    const booking = cancelBooking(req.params.bookingReferenceId, req.body?.reason);
    res.json(booking);
  } catch (err) {
    next(err);
  }
});

// POST /api/bookings/:bookingReferenceId/reschedule
bookingsRouter.post('/:bookingReferenceId/reschedule', (req, res, next) => {
  try {
    const booking = rescheduleBooking(req.params.bookingReferenceId, req.body?.newTripId, req.body?.reason);
    res.json(booking);
  } catch (err) {
    next(err);
  }
});
