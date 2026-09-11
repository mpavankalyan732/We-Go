// Best-effort push to Salesforce right after a booking is created. This is
// deliberately non-blocking: a Salesforce hiccup should never fail the
// customer's booking, since the Bus API's own database is already the
// source of truth for the transaction at that point. Failures are logged,
// not thrown.
import { getSalesforceAccessToken } from './salesforceAuth.js';

export async function syncBookingToSalesforce(booking) {
  let auth;
  try {
    auth = await getSalesforceAccessToken();
  } catch (err) {
    console.error(`[salesforceSync] Auth failed, skipping sync for ${booking.bookingReferenceId}:`, err.message);
    return { synced: false, reason: err.message };
  }

  if (!auth) {
    console.log('[salesforceSync] Salesforce JWT auth not configured — skipping Salesforce sync.');
    return { synced: false, reason: 'not_configured' };
  }

  try {
    const res = await fetch(`${auth.instanceUrl}/services/apexrest/roadlink/bookingSync`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${auth.accessToken}`
      },
      body: JSON.stringify(booking)
    });

    const body = await res.json().catch(() => null);

    if (!res.ok || !body?.success) {
      console.error(`[salesforceSync] Failed to sync booking ${booking.bookingReferenceId}:`, body?.error || res.status);
      return { synced: false, reason: body?.error || `HTTP ${res.status}` };
    }

    console.log(`[salesforceSync] Synced booking ${booking.bookingReferenceId} -> Salesforce Id ${body.bookingId}`);
    return { synced: true, salesforceId: body.bookingId };
  } catch (err) {
    console.error(`[salesforceSync] Error syncing booking ${booking.bookingReferenceId}:`, err.message);
    return { synced: false, reason: err.message };
  }
}
