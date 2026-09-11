import { Router } from 'express';
import { sendNotification } from '../services/notificationService.js';

export const notificationsRouter = Router();

// POST /api/notifications
notificationsRouter.post('/', (req, res, next) => {
  try {
    const notification = sendNotification(req.body);
    res.status(201).json(notification);
  } catch (err) {
    next(err);
  }
});
