/**
 * Agentforce action: checks whether a booking can be rescheduled and, if so,
 * fetches alternative trips on the same route. Tries the live Bus API first
 * (source of truth for real-time seat availability). If the live API doesn't
 * have the booking or is unreachable (e.g. Render free-tier cold start / the
 * ephemeral disk was reset), falls back to Salesforce's own records: other
 * Bus_Trip__c rows already synced for the same route, with availability
 * approximated as Bus__c.Total_Seat__c minus seats already recorded in
 * Salesforce for that trip. dataSource on the result says which one answered.
 *
 * This is read-only - it never performs the reschedule itself (see
 * BusRescheduleAction for that, which has the matching live/Salesforce
 * fallback pair).
 *
 * Eligibility mirrors the Bus API's own rule (see
 * bookingService.js#rescheduleBooking): a booking can be rescheduled only
 * while its status is "Confirmed". There is no departure-time cutoff.
 */
public without sharing class BusRescheduleEligibilityAction {
    public class EligibilityRequest {
        @InvocableVariable(label='Booking Reference Id' required=true)
        public String bookingReferenceId;

        @InvocableVariable(label='PNR' required=true)
        public String pnr;

        @InvocableVariable(label='New Travel Date' description='yyyy-MM-dd. Defaults to the current travel date on the booking if left blank.')
        public String newTravelDate;
    }

    public class AlternativeTrip {
        @InvocableVariable public String tripId;
        @InvocableVariable public String operatorName;
        @InvocableVariable public String busType;
        @InvocableVariable public String departureTime;
        @InvocableVariable public String arrivalTime;
        @InvocableVariable public String durationLabel;
        @InvocableVariable public Decimal fare;
        @InvocableVariable public Integer availableSeats;
    }

    public class EligibilityResult {
        @InvocableVariable public Boolean eligible = false;
        @InvocableVariable public String message;
        @InvocableVariable public String dataSource;
        @InvocableVariable public String currentTripId;
        @InvocableVariable public String originCity;
        @InvocableVariable public String destinationCity;
        @InvocableVariable public String currentTravelDate;
        @InvocableVariable public List<AlternativeTrip> alternatives;
    }

    @InvocableMethod(label='Check Reschedule Eligibility' description='Checks whether a bus booking can be rescheduled and lists alternative trips on the same route. Falls back to the saved Salesforce trips if the live booking system does not have this booking.')
    public static List<EligibilityResult> check(List<EligibilityRequest> requests) {
        List<EligibilityResult> results = new List<EligibilityResult>();
        for (EligibilityRequest r : requests) {
            results.add(checkOne(r));
        }
        return results;
    }

    private static EligibilityResult checkOne(EligibilityRequest r) {
        if (String.isBlank(r.bookingReferenceId) || String.isBlank(r.pnr)) {
            EligibilityResult blank = new EligibilityResult();
            blank.alternatives = new List<AlternativeTrip>();
            blank.message = 'Both a booking reference ID and PNR are required.';
            return blank;
        }

        String referenceId = r.bookingReferenceId.trim();
        String pnr = r.pnr.trim();

        BusApiClient.BookingResult liveResult;
        try {
            liveResult = BusApiClient.getBooking(referenceId);
        } catch (Exception e) {
            liveResult = null;
        }

        if (liveResult != null && liveResult.booking.pnr == pnr) {
            return checkFromLive(liveResult.booking, r.newTravelDate);
        }

        EligibilityResult fallback = checkFromSalesforce(referenceId, pnr, r.newTravelDate);
        if (fallback != null) {
            return fallback;
        }

        EligibilityResult notFound = new EligibilityResult();
        notFound.alternatives = new List<AlternativeTrip>();
        notFound.message = 'No booking found for that reference ID and PNR combination.';
        return notFound;
    }

    private static EligibilityResult checkFromLive(BusApiClient.BookingDto booking, String requestedTravelDate) {
        EligibilityResult out = new EligibilityResult();
        out.dataSource = 'Live';
        out.alternatives = new List<AlternativeTrip>();
        out.currentTripId = booking.trip != null ? booking.trip.tripId : null;
        out.originCity = booking.trip != null ? booking.trip.fromCity : null;
        out.destinationCity = booking.trip != null ? booking.trip.toCity : null;
        out.currentTravelDate = booking.trip != null ? booking.trip.travelDate : null;

        if (booking.status != 'Confirmed') {
            out.message = 'This booking is ' + booking.status + ' and cannot be rescheduled.';
            return out;
        }
        if (booking.trip == null) {
            out.message = 'This booking has no trip on file - it cannot be rescheduled.';
            return out;
        }

        String searchDate = String.isNotBlank(requestedTravelDate) ? requestedTravelDate.trim() : booking.trip.travelDate;

        List<BusApiClient.TripDto> trips;
        try {
            trips = BusApiClient.searchTrips(booking.trip.fromCity, booking.trip.toCity, searchDate);
        } catch (Exception e) {
            out.message = 'Booking is eligible for reschedule, but alternative trips could not be fetched: ' + e.getMessage();
            return out;
        }

        for (BusApiClient.TripDto trip : trips) {
            if (trip.tripId == booking.trip.tripId) {
                continue;
            }
            AlternativeTrip alt = new AlternativeTrip();
            alt.tripId = trip.tripId;
            alt.operatorName = trip.operator;
            alt.busType = trip.busType;
            alt.departureTime = trip.departureTime;
            alt.arrivalTime = trip.arrivalTime;
            alt.durationLabel = trip.durationLabel;
            alt.fare = trip.fare;
            alt.availableSeats = trip.availableSeats;
            out.alternatives.add(alt);
        }

        out.eligible = true;
        out.message = out.alternatives.isEmpty()
            ? 'Booking is eligible for reschedule, but no alternative trips were found for ' + searchDate + '.'
            : 'Booking is eligible for reschedule. ' + out.alternatives.size() + ' alternative trip(s) found for ' + searchDate + '.';
        return out;
    }

    // Read-only fallback - only looks at trips Salesforce already knows about
    // (synced from a previous booking), and approximates availability as
    // Bus__c.Total_Seat__c minus seats already recorded against that trip in
    // Salesforce. Can't discover brand-new trips the way the live API's
    // search can.
    private static EligibilityResult checkFromSalesforce(String referenceId, String pnr, String requestedTravelDate) {
        List<Bus_Booking__c> bookings = [
            SELECT Id, Booking_Status__c, Bus_Trip__c,
                   Bus_Trip__r.External_Trip_Id__c, Bus_Trip__r.Origin_City__c, Bus_Trip__r.Destination_City__c,
                   Bus_Trip__r.Travel_Date__c,
                   (SELECT Id FROM Bus_Seats__r)
            FROM Bus_Booking__c
            WHERE Booking_Reference_Id__c = :referenceId AND PNR__c = :pnr
            LIMIT 1
        ];
        if (bookings.isEmpty()) {
            return null;
        }

        Bus_Booking__c b = bookings[0];
        EligibilityResult out = new EligibilityResult();
        out.dataSource = 'SalesforceRecord';
        out.alternatives = new List<AlternativeTrip>();

        if (b.Bus_Trip__c == null) {
            out.message = 'This booking has no trip on file - it cannot be rescheduled.';
            return out;
        }

        out.currentTripId = b.Bus_Trip__r.External_Trip_Id__c;
        out.originCity = b.Bus_Trip__r.Origin_City__c;
        out.destinationCity = b.Bus_Trip__r.Destination_City__c;
        out.currentTravelDate = formatDate(b.Bus_Trip__r.Travel_Date__c);

        if (b.Booking_Status__c != 'Confirmed') {
            out.message = 'This booking is ' + b.Booking_Status__c + ' and cannot be rescheduled.';
            return out;
        }

        Date searchDate = String.isNotBlank(requestedTravelDate) ? Date.valueOf(requestedTravelDate.trim()) : b.Bus_Trip__r.Travel_Date__c;

        List<Bus_Trip__c> candidates = [
            SELECT Id, External_Trip_Id__c, Base_Fare__c, Departure_Time__c, Arrival_Time__c, Duration_Label__c,
                   Bus__r.Operator_Name__c, Bus__r.Bus_Type__c, Bus__r.Total_Seat__c
            FROM Bus_Trip__c
            WHERE Origin_City__c = :b.Bus_Trip__r.Origin_City__c
              AND Destination_City__c = :b.Bus_Trip__r.Destination_City__c
              AND Travel_Date__c = :searchDate
              AND Id != :b.Bus_Trip__c
        ];

        Map<Id, Integer> bookedCountByTrip = new Map<Id, Integer>();
        if (!candidates.isEmpty()) {
            Set<Id> candidateIds = new Map<Id, Bus_Trip__c>(candidates).keySet();
            for (AggregateResult ar : [
                SELECT Bus_Trip__c tripId, COUNT(Id) bookedCount
                FROM Bus_Seat__c
                WHERE Bus_Trip__c IN :candidateIds
                GROUP BY Bus_Trip__c
            ]) {
                bookedCountByTrip.put((Id) ar.get('tripId'), (Integer) ar.get('bookedCount'));
            }
        }

        for (Bus_Trip__c trip : candidates) {
            Integer booked = bookedCountByTrip.containsKey(trip.Id) ? bookedCountByTrip.get(trip.Id) : 0;
            Integer totalSeats = trip.Bus__r != null && trip.Bus__r.Total_Seat__c != null ? Integer.valueOf(trip.Bus__r.Total_Seat__c) : 0;

            AlternativeTrip alt = new AlternativeTrip();
            alt.tripId = trip.External_Trip_Id__c;
            alt.operatorName = trip.Bus__r != null ? trip.Bus__r.Operator_Name__c : null;
            alt.busType = trip.Bus__r != null ? trip.Bus__r.Bus_Type__c : null;
            alt.departureTime = formatTime(trip.Departure_Time__c);
            alt.arrivalTime = formatTime(trip.Arrival_Time__c);
            alt.durationLabel = trip.Duration_Label__c;
            alt.fare = trip.Base_Fare__c;
            alt.availableSeats = totalSeats - booked;
            out.alternatives.add(alt);
        }

        out.eligible = true;
        out.message = 'Showing alternatives from the saved Salesforce trips - the live booking system does not have this booking right now, so newly-added trips may not be included. '
            + (out.alternatives.isEmpty() ? 'No saved alternative trips were found for ' + formatDate(searchDate) + '.'
                                           : out.alternatives.size() + ' alternative trip(s) found for ' + formatDate(searchDate) + '.');
        return out;
    }

    private static String formatDate(Date d) {
        if (d == null) {
            return null;
        }
        return String.valueOf(d.year()) + '-' + String.valueOf(d.month()).leftPad(2, '0') + '-' + String.valueOf(d.day()).leftPad(2, '0');
    }

    private static String formatTime(Time t) {
        if (t == null) {
            return null;
        }
        return String.valueOf(t.hour()).leftPad(2, '0') + ':' + String.valueOf(t.minute()).leftPad(2, '0');
    }
}
