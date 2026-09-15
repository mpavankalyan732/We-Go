/**
 * Agentforce action: look up a bus booking by reference ID + PNR.
 * Tries the live Bus API first (source of truth - reflects any
 * cancellation/reschedule made directly through the website). If the live
 * API doesn't have the booking (404) or is unreachable (e.g. a Render
 * free-tier cold start / the ephemeral disk was reset by a redeploy), falls
 * back to Salesforce's own synced copy (Bus_Booking__c etc.) so older
 * bookings can still be looked up. dataSource on the result tells the caller
 * which one actually answered, so the agent can be honest about it.
 *
 * Reschedule/cancellation eligibility and the actions that perform them do
 * NOT have this fallback - they need the live API's real-time seat/status
 * state to act safely, so a stale Salesforce snapshot isn't good enough for
 * those. This fallback is lookup-only, read-only.
 *
 * The PNR must match the reference ID in whichever source answers - this is
 * the only identity check protecting a booking lookup, so both are required.
 */
public without sharing class BusBookingLookupAction {
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
        @InvocableVariable public String dataSource;

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

    @InvocableMethod(label='Look Up Bus Booking' description='Finds a bus booking by reference ID and PNR and returns its trip, seat, and passenger details. Falls back to the saved Salesforce copy if the live booking system does not have it.')
    public static List<LookupResult> lookUp(List<LookupRequest> requests) {
        List<LookupResult> results = new List<LookupResult>();
        for (LookupRequest r : requests) {
            results.add(lookupOne(r));
        }
        return results;
    }

    private static LookupResult lookupOne(LookupRequest r) {
        if (String.isBlank(r.bookingReferenceId) || String.isBlank(r.pnr)) {
            LookupResult blank = new LookupResult();
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
            return fromLiveResult(liveResult);
        }

        LookupResult fallback = lookupFromSalesforce(referenceId, pnr);
        if (fallback != null) {
            return fallback;
        }

        LookupResult notFound = new LookupResult();
        notFound.message = 'No booking found for that reference ID and PNR combination.';
        return notFound;
    }

    private static LookupResult fromLiveResult(BusApiClient.BookingResult result) {
        BusApiClient.BookingDto booking = result.booking;

        LookupResult out = new LookupResult();
        out.found = true;
        out.dataSource = 'Live';
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

    // Read-only fallback against Salesforce's own synced copy - used only
    // when the live Bus API doesn't have this booking or can't be reached.
    // Bus_Seat__c.Seat_Number__c is a broken formula (just an auto-number,
    // not the real seat position - see BusBookingSyncService), so seatNumber
    // here is a best-effort "Deck Category" descriptor instead.
    private static LookupResult lookupFromSalesforce(String referenceId, String pnr) {
        List<Bus_Booking__c> bookings = [
            SELECT Id, Booking_Reference_Id__c, PNR__c, Booking_Status__c, Total_Amount__c,
                   Primary_Contact_Email__c, Primary_Contact_Phone__c, Cancelled_Date__c,
                   Cancellation_Reason__c, Refund_Amount__c,
                   Bus_Trip__c, Bus_Trip__r.Origin_City__c, Bus_Trip__r.Destination_City__c,
                   Bus_Trip__r.Travel_Date__c, Bus_Trip__r.Departure_Time__c, Bus_Trip__r.Arrival_Time__c,
                   Bus_Trip__r.Boarding_Point__c, Bus_Trip__r.Dropping_Point__c,
                   Bus_Trip__r.Bus__r.Operator_Name__c, Bus_Trip__r.Bus__r.Bus_Type__c,
                   (SELECT Full_Name__c, Age__c, Gender__c, Bus_Seat__r.Deck__c, Bus_Seat__r.Seat_Category__c
                    FROM Booking_Passengers__r ORDER BY CreatedDate ASC)
            FROM Bus_Booking__c
            WHERE Booking_Reference_Id__c = :referenceId AND PNR__c = :pnr
            LIMIT 1
        ];
        if (bookings.isEmpty()) {
            return null;
        }

        Bus_Booking__c b = bookings[0];
        LookupResult out = new LookupResult();
        out.found = true;
        out.dataSource = 'SalesforceRecord';
        out.message = 'Showing the most recently saved details for this booking - the live booking system does not have it right now, so this may not reflect very recent changes.';
        out.bookingReferenceId = b.Booking_Reference_Id__c;
        out.status = b.Booking_Status__c;
        out.totalAmount = b.Total_Amount__c;
        out.contactEmail = b.Primary_Contact_Email__c;
        out.contactPhone = b.Primary_Contact_Phone__c;
        out.cancelledAt = b.Cancelled_Date__c != null ? b.Cancelled_Date__c.format() : null;
        out.cancellationReason = b.Cancellation_Reason__c;
        out.refundAmount = b.Refund_Amount__c;

        if (b.Bus_Trip__c != null) {
            out.originCity = b.Bus_Trip__r.Origin_City__c;
            out.destinationCity = b.Bus_Trip__r.Destination_City__c;
            out.travelDate = formatDate(b.Bus_Trip__r.Travel_Date__c);
            out.departureTime = formatTime(b.Bus_Trip__r.Departure_Time__c);
            out.arrivalTime = formatTime(b.Bus_Trip__r.Arrival_Time__c);
            out.boardingPoint = b.Bus_Trip__r.Boarding_Point__c;
            out.droppingPoint = b.Bus_Trip__r.Dropping_Point__c;
            if (b.Bus_Trip__r.Bus__r != null) {
                out.operatorName = b.Bus_Trip__r.Bus__r.Operator_Name__c;
                out.busType = b.Bus_Trip__r.Bus__r.Bus_Type__c;
            }
        }

        out.passengers = new List<PassengerInfo>();
        for (Booking_Passenger__c p : b.Booking_Passengers__r) {
            PassengerInfo info = new PassengerInfo();
            info.name = p.Full_Name__c;
            info.age = p.Age__c != null ? Integer.valueOf(p.Age__c) : null;
            info.gender = p.Gender__c;
            if (p.Bus_Seat__r != null) {
                List<String> parts = new List<String>();
                if (String.isNotBlank(p.Bus_Seat__r.Deck__c)) {
                    parts.add(p.Bus_Seat__r.Deck__c);
                }
                if (String.isNotBlank(p.Bus_Seat__r.Seat_Category__c)) {
                    parts.add(p.Bus_Seat__r.Seat_Category__c);
                }
                info.seatNumber = parts.isEmpty() ? null : String.join(parts, ' ');
            }
            out.passengers.add(info);
        }

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
