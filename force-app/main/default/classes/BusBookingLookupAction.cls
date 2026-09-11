/**
 * Agentforce action: look up a bus booking by reference ID + PNR.
 * Reads live from the Bus API (source of truth), not Salesforce's synced
 * copy, so it reflects any cancellation/reschedule made directly through the
 * website too. The PNR must match the reference ID - this is the only
 * identity check protecting a booking lookup, so both are required.
 */
public with sharing class BusBookingLookupAction {
    public class LookupRequest {
        @InvocableVariable(label='Booking Reference Id' description='e.g. BK-UU9WPA' required=true)
        public String bookingReferenceId;

        @InvocableVariable(label='PNR' description='10-digit PNR printed on the booking confirmation' required=true)
        public String pnr;
    }

    public class PassengerInfo {
        @InvocableVariable public String seatNumber;
        @InvocableVariable public String name;
        @InvocableVariable public Integer age;
        @InvocableVariable public String gender;
    }

    public class LookupResult {
        @InvocableVariable public Boolean found = false;
        @InvocableVariable public String message;

        @InvocableVariable public String bookingReferenceId;
        @InvocableVariable public String status;
        @InvocableVariable public String operatorName;
        @InvocableVariable public String busType;
        @InvocableVariable public String originCity;
        @InvocableVariable public String destinationCity;
        @InvocableVariable public String travelDate;
        @InvocableVariable public String departureTime;
        @InvocableVariable public String arrivalTime;
        @InvocableVariable public String boardingPoint;
        @InvocableVariable public String droppingPoint;
        @InvocableVariable public List<PassengerInfo> passengers;
        @InvocableVariable public Decimal totalAmount;
        @InvocableVariable public String contactEmail;
        @InvocableVariable public String contactPhone;
        @InvocableVariable public String cancelledAt;
        @InvocableVariable public String cancellationReason;
        @InvocableVariable public Decimal refundAmount;
    }

    @InvocableMethod(label='Look Up Bus Booking' description='Finds a bus booking by reference ID and PNR and returns its trip, seat, and passenger details.')
    public static List<LookupResult> lookUp(List<LookupRequest> requests) {
        List<LookupResult> results = new List<LookupResult>();
        for (LookupRequest r : requests) {
            results.add(lookupOne(r));
        }
        return results;
    }

    private static LookupResult lookupOne(LookupRequest r) {
        LookupResult out = new LookupResult();

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
        out.found = true;
        out.message = 'Booking found.';
        out.bookingReferenceId = booking.bookingReferenceId;
        out.status = booking.status;
        out.totalAmount = booking.totalAmount;
        out.contactEmail = booking.contactEmail;
        out.contactPhone = booking.contactPhone;
        out.cancelledAt = booking.cancelledAt;
        out.cancellationReason = booking.cancellationReason;
        out.refundAmount = booking.refundAmount;

        if (booking.trip != null) {
            out.operatorName = booking.trip.operator;
            out.busType = booking.trip.busType;
            out.originCity = booking.trip.fromCity;
            out.destinationCity = booking.trip.toCity;
            out.travelDate = booking.trip.travelDate;
            out.departureTime = booking.trip.departureTime;
            out.arrivalTime = booking.trip.arrivalTime;
            out.boardingPoint = booking.trip.boardingPoint;
            out.droppingPoint = booking.trip.droppingPoint;
        }

        out.passengers = new List<PassengerInfo>();
        if (booking.passengers != null) {
            for (BusApiClient.PassengerDto p : booking.passengers) {
                PassengerInfo info = new PassengerInfo();
                info.seatNumber = p.seatNumber;
                info.name = p.name;
                info.age = p.age;
                info.gender = p.gender;
                out.passengers.add(info);
            }
        }

        return out;
    }
}
