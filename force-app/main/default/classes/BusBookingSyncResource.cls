/**
 * POST /services/apexrest/roadlink/bookingSync
 * Called by the external Bus API right after a booking is created, to save
 * the booking (and trip/bus/seats/passengers/payment) into Salesforce.
 */
@RestResource(urlMapping='/roadlink/bookingSync/*')
global with sharing class BusBookingSyncResource {
    @HttpPost
    global static void syncBooking() {
        RestRequest req = RestContext.request;
        RestResponse res = RestContext.response;
        res.addHeader('Content-Type', 'application/json');

        try {
            String jsonBody = req.requestBody.toString();
            Id bookingId = BusBookingSyncService.syncBooking(jsonBody);
            res.statusCode = 200;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'success' => true,
                'bookingId' => bookingId
            }));
        } catch (Exception e) {
            res.statusCode = 400;
            res.responseBody = Blob.valueOf(JSON.serialize(new Map<String, Object>{
                'success' => false,
                'error' => e.getMessage()
            }));
        }
    }
}
