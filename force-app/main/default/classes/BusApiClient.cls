/**
 * Thin callout wrapper around the external Bus API (bus-booking-app/api),
 * used by the BusAgent invocable actions (lookup/reschedule/cancel). The Bus
 * API is always the source of truth for a booking's live status/seats/trip -
 * these calls never read Salesforce's synced copy for anything that can
 * change after creation, since only booking *creation* pushes into Salesforce
 * today (see BusBookingSyncService) - a cancel/reschedule made directly
 * through the website would otherwise leave Salesforce stale.
 *
 * Requires the 'Bus_API' Named Credential to point at a publicly reachable
 * instance of the Bus API (Salesforce cannot call http://localhost) and the
 * Bus_Api_Config__mdt "Default" record's Api_Key__c to match the Bus API's
 * configured API_KEY (blank/blank if the Bus API is running with auth off).
 */
public without sharing class BusApiClient {
    public class BusApiException extends Exception {}

    // ===================== JSON SHAPES ===================== //
    // Mirrors BusBookingSyncService's payload classes. "seats" is deliberately
    // NOT a typed field here - its JSON key "number" is a reserved identifier
    // in Apex - it's parsed separately via JSON.deserializeUntyped() instead.

    public class TripDto {
        public String tripId;
        public String operator;
        public String busName;
        public String busType;
        public Decimal rating;
        public String fromCity;
        public String toCity;
        public String travelDate;
        public String departureTime;
        public String arrivalTime;
        public String durationLabel;
        public String boardingPoint;
        public String droppingPoint;
        public Decimal fare;
        public Integer totalSeats;
        public Integer availableSeats;
    }

    public class PassengerDto {
        public String seatNumber;
        public String name;
        public Integer age;
        public String gender;
        public String email;
        public String phone;
    }

    public class BookingDto {
        public String bookingReferenceId;
        public String pnr;
        public String status;
        public String createdAt;
        public TripDto trip;
        public List<String> seatNumbers;
        public List<PassengerDto> passengers;
        public String contactEmail;
        public String contactPhone;
        public Decimal totalAmount;
        public String cancelledAt;
        public String cancellationReason;
        public Decimal refundAmount;
    }

    // A BookingDto plus the raw "seats" array (deck/category/fare/number),
    // needed by BusRescheduleAction to rebuild Bus_Seat__c records.
    public class BookingResult {
        public BookingDto booking;
        public List<Object> rawSeats;
    }

    // ===================== PUBLIC API ===================== //

    public static List<TripDto> searchTrips(String fromCity, String toCity, String travelDate) {
        HttpResponse res = send('GET', '/buses/search?from=' + enc(fromCity) + '&to=' + enc(toCity) + '&date=' + enc(travelDate), null);
        assertOk(res);
        return (List<TripDto>) JSON.deserialize(res.getBody(), List<TripDto>.class);
    }

    // Returns null if no booking exists for that reference ID.
    public static BookingResult getBooking(String referenceId) {
        HttpResponse res = send('GET', '/bookings/' + enc(referenceId), null);
        if (res.getStatusCode() == 404) {
            return null;
        }
        assertOk(res);
        return toBookingResult(res.getBody());
    }

    public static BookingResult cancelBooking(String referenceId, String reason) {
        Map<String, Object> body = new Map<String, Object>();
        if (String.isNotBlank(reason)) {
            body.put('reason', reason);
        }
        HttpResponse res = send('POST', '/bookings/' + enc(referenceId) + '/cancel', JSON.serialize(body));
        assertOk(res);
        return toBookingResult(res.getBody());
    }

    public static BookingResult rescheduleBooking(String referenceId, String newTripId, String reason) {
        Map<String, Object> body = new Map<String, Object>{ 'newTripId' => newTripId };
        if (String.isNotBlank(reason)) {
            body.put('reason', reason);
        }
        HttpResponse res = send('POST', '/bookings/' + enc(referenceId) + '/reschedule', JSON.serialize(body));
        assertOk(res);
        return toBookingResult(res.getBody());
    }

    // ===================== INTERNAL ===================== //

    private static BookingResult toBookingResult(String responseBody) {
        BookingResult result = new BookingResult();
        result.booking = (BookingDto) JSON.deserialize(responseBody, BookingDto.class);
        Map<String, Object> raw = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
        result.rawSeats = (List<Object>) raw.get('seats');
        return result;
    }

    private static void assertOk(HttpResponse res) {
        Integer status = res.getStatusCode();
        if (status < 200 || status >= 300) {
            String message = extractErrorMessage(res.getBody());
            throw new BusApiException(String.isNotBlank(message) ? message : ('Bus API request failed (HTTP ' + status + ')'));
        }
    }

    private static String extractErrorMessage(String body) {
        try {
            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(body);
            Map<String, Object> error = (Map<String, Object>) parsed.get('error');
            return error != null ? (String) error.get('message') : null;
        } catch (Exception e) {
            return null;
        }
    }

    private static HttpResponse send(String method, String path, String body) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Bus_API/api' + path);
        req.setMethod(method);
        req.setTimeout(20000);

        String apiKey = Bus_Api_Config__mdt.getInstance('Default') != null
            ? Bus_Api_Config__mdt.getInstance('Default').Api_Key__c
            : null;
        if (String.isNotBlank(apiKey)) {
            req.setHeader('x-api-key', apiKey);
        }
        if (body != null) {
            req.setHeader('Content-Type', 'application/json');
            req.setBody(body);
        }

        return new Http().send(req);
    }

    private static String enc(String value) {
        return EncodingUtil.urlEncode(value == null ? '' : value, 'UTF-8');
    }
}
