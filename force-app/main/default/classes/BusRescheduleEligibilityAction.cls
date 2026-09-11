/**
 * Agentforce action: checks whether a booking can be rescheduled and, if so,
 * fetches alternative trips on the same route from the live Bus API. This is
 * read-only - it never calls the Bus API's reschedule endpoint itself (see
 * BusRescheduleAction for that).
 *
 * Eligibility mirrors the Bus API's own rule exactly (see
 * bookingService.js#rescheduleBooking): a booking can be rescheduled only
 * while its live status is "Confirmed". There is no departure-time cutoff on
 * the Bus API side, so none is enforced here either - the Bus API is the
 * single source of truth for this rule.
 */
public with sharing class BusRescheduleEligibilityAction {
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
        @InvocableVariable public String currentTripId;
        @InvocableVariable public String originCity;
        @InvocableVariable public String destinationCity;
        @InvocableVariable public String currentTravelDate;
        @InvocableVariable public List<AlternativeTrip> alternatives;
    }

    @InvocableMethod(label='Check Reschedule Eligibility' description='Checks whether a bus booking can be rescheduled and lists alternative trips on the same route from the live Bus API.')
    public static List<EligibilityResult> check(List<EligibilityRequest> requests) {
        List<EligibilityResult> results = new List<EligibilityResult>();
        for (EligibilityRequest r : requests) {
            results.add(checkOne(r));
        }
        return results;
    }

    private static EligibilityResult checkOne(EligibilityRequest r) {
        EligibilityResult out = new EligibilityResult();
        out.alternatives = new List<AlternativeTrip>();

        if (String.isBlank(r.bookingReferenceId) || String.isBlank(r.pnr)) {
            out.message = 'Both a booking reference ID and PNR are required.';
            return out;
        }

        BusApiClient.BookingResult result;
        try {
            result = BusApiClient.getBooking(r.bookingReferenceId.trim());
        } catch (Exception e) {
            out.message = 'Could not reach the booking system: ' + e.getMessage();
            return out;
        }

        if (result == null || result.booking.pnr != r.pnr.trim()) {
            out.message = 'No booking found for that reference ID and PNR combination.';
            return out;
        }

        BusApiClient.BookingDto booking = result.booking;
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

        String searchDate = String.isNotBlank(r.newTravelDate) ? r.newTravelDate.trim() : booking.trip.travelDate;

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
}
