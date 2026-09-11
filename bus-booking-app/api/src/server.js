import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { healthRouter } from './routes/health.routes.js';
import { busesRouter } from './routes/buses.routes.js';
import { tripsRouter } from './routes/trips.routes.js';
import { bookingsRouter } from './routes/bookings.routes.js';
import { notificationsRouter } from './routes/notifications.routes.js';
import { apiKeyAuth } from './middleware/auth.js';
import { errorHandler, notFoundHandler } from './middleware/errorHandler.js';

const app = express();

app.use(cors());
app.use(express.json());

app.use(healthRouter);

app.use('/api/buses', apiKeyAuth, busesRouter);
app.use('/api/trips', apiKeyAuth, tripsRouter);
app.use('/api/bookings', apiKeyAuth, bookingsRouter);
app.use('/api/notifications', apiKeyAuth, notificationsRouter);

app.use(notFoundHandler);
app.use(errorHandler);

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => {
  console.log(`RoadLink Bus API listening on port ${PORT}`);
});
