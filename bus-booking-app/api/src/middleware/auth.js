import { ApiError } from '../utils/ApiError.js';

// Simple API-key auth via header, matching the pattern a Salesforce Named
// Credential's "Custom Header" auth would send — good enough for a demo API,
// and this is exactly what the existing Bus_API Named Credential in the org
// will eventually be configured to send once Salesforce integration begins.
export function apiKeyAuth(req, res, next) {
  const expectedKey = process.env.API_KEY;
  if (!expectedKey) return next(); // no key configured — auth disabled (local dev convenience)

  const providedKey = req.get('x-api-key');
  if (providedKey !== expectedKey) {
    return next(ApiError.unauthorized());
  }
  next();
}
