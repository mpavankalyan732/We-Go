import { Router } from 'express';
import { searchTrips } from '../services/tripService.js';

export const busesRouter = Router();

// GET /api/buses/search?from=&to=&date=&passengers=
busesRouter.get('/search', (req, res, next) => {
  try {
    const { from, to, date } = req.query;
    const trips = searchTrips({ fromCity: from, toCity: to, travelDate: date });
    res.json(trips);
  } catch (err) {
    next(err);
  }
});
