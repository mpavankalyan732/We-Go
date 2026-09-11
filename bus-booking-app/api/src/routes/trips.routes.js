import { Router } from 'express';
import { getTripById } from '../services/tripService.js';
import { getSeatMap } from '../services/seatService.js';

export const tripsRouter = Router();

// GET /api/trips/:tripId
tripsRouter.get('/:tripId', (req, res, next) => {
  try {
    res.json(getTripById(req.params.tripId));
  } catch (err) {
    next(err);
  }
});

// GET /api/trips/:tripId/seats
tripsRouter.get('/:tripId/seats', (req, res, next) => {
  try {
    res.json(getSeatMap(req.params.tripId));
  } catch (err) {
    next(err);
  }
});
