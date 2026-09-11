// Mints Salesforce access tokens on demand via the OAuth 2.0 Client
// Credentials Flow, using the RoadLink_Bus_Integration External Client App
// (force-app/main/default/externalClientApps). Server-to-server, no user
// interaction — just a Client ID + Client Secret exchanged for a token.
let cached = null; // { accessToken, instanceUrl, expiresAt }

export async function getSalesforceAccessToken() {
  if (cached && cached.expiresAt > Date.now() + 30_000) {
    return cached;
  }

  const clientId = process.env.SF_CLIENT_ID;
  const clientSecret = process.env.SF_CLIENT_SECRET;
  const loginUrl = process.env.SF_LOGIN_URL || 'https://login.salesforce.com';

  if (!clientId || !clientSecret) {
    return null; // Salesforce sync simply skips if Client Credentials auth isn't configured
  }

  const res = await fetch(`${loginUrl}/services/oauth2/token`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'client_credentials',
      client_id: clientId,
      client_secret: clientSecret
    })
  });

  const body = await res.json().catch(() => null);
  if (!res.ok) {
    throw new Error(`Salesforce Client Credentials auth failed: ${body?.error} - ${body?.error_description}`);
  }

  cached = {
    accessToken: body.access_token,
    instanceUrl: body.instance_url,
    expiresAt: Date.now() + 10 * 60 * 1000 // re-mint well before any org session-timeout could hit
  };
  return cached;
}
