/**
 * Agentforce action: performs a reschedule. The Bus API
 * (POST /bookings/:ref/reschedule) is the actual system of record - it does
 * the seat release/re-lock and validates eligibility itself. This class:
 *   1. Re-validates against the live booking (defense in depth - a caller
 *      could invoke this without going through BusRescheduleEligibilityAction
 *      first).
 *   2. Calls the Bus API to perform the reschedule.
 *   3. Mirrors the result into Salesforce (Bus_Trip__c, seats, passenger seat
 *      assignments, a Bus_Reschedule__c audit record).
 *
 * Step 3 is best-effort: if the booking was never synced to Salesforce (or
 * the mirror update otherwise fails), the reschedule itself has already
 * succeeded at the Bus API - the customer's booking is not rolled back for a
 * Salesforce-side failure, matching the same "non-blocking" philosophy as
 * salesforceSync.js on the Bus API side.
 */
public without sharing class BusRescheduleAction {
    public class RescheduleRequest {
        @InvocableVariable(label='Booking Reference Id' required=true)
        public String bookingReferenceId;

        @InvocableVariable(label='PNR' required=true)
        public String pnr;

        @InvocableVariable(label='New Trip Id' description='tripId of the trip to move the booking to, from Check Reschedule Eligibility' required=true)
        public String newTripId;

        @InvocableVariable(label='Reason')
        public String reason;
    }

    public class RescheduleResult {
        @InvocableVariable public Boolean success = false;
        @InvocableVariable public String message;
        @InvocableVariable public String bookingReferenceId;
        @InvocableVariable public String newTripId;
        @InvocableVariable public Decimal newTotalAmount;
        @InvocableVariable public Decimal fareDifference;
    }

    @InvocableMethod(label='Reschedule Bus Booking' description='Moves a confirmed bus booking to a different trip via the live Bus API.')
    public static List<RescheduleResult> reschedule(List<RescheduleRequest> requests) {
        List<RescheduleResult> results = new List<RescheduleResult>();
        for (RescheduleRequest r : requests) {
            results.add(rescheduleOne(r));
        }
        return results;
    }

    private static RescheduleResult rescheduleOne(RescheduleRequest r) {
        RescheduleResult out = new RescheduleResult();
        out.bookingReferenceId = r.bookingReferenceId;

        if (String.isBlank(r.bookingReferenceId) || String.isBlank(r.pnr) || String.isBlank(r.newTripId)) {
            out.message = 'Booking reference ID, PNR, and new trip ID are all required.';
            return out;
        }

        BusApiClient.BookingResult before;
        try {
            before = BusApiClient.getBooking(r.bookingReferenceId.trim());
        } catch (Exception e) {
            out.message = 'Could not reach the booking system: ' + e.getMessage();
            return out;
        }
        if (before == null || before.booking.pnr != r.pnr.trim()) {
            out.message = 'No booking found for that reference ID and PNR combination.';
            return out;
        }
        if (before.booking.status != 'Confirmed') {
            out.message = 'This booking is ' + before.booking.status + ' and cannot be rescheduled.';
            return out;
        }

        Decimal oldTotalAmount = before.booking.totalAmount;

        BusApiClient.BookingResult after;
        try {
            after = BusApiClient.rescheduleBooking(r.bookingReferenceId.trim(), r.newTripId.trim(), r.reason);
        } catch (Exception e) {
            out.message = 'Reschedule failed: ' + e.getMessage();
            return out;
        }

        out.success = true;
        out.newTripId = after.booking.trip != null ? after.booking.trip.tripId : r.newTripId.trim();
        out.newTotalAmount = after.booking.totalAmount;
        Decimal newAmount = after.booking.totalAmount != null ? after.booking.totalAmount : 0;
        Decimal oldAmount = oldTotalAmount != null ? oldTotalAmount : 0;
        out.fareDifference = newAmount - oldAmount;
        out.message = 'Booking rescheduled to trip ' + out.newTripId + '.';

        try {
            mirrorToSalesforce(r.bookingReferenceId.trim(), after, oldAmount, r.reason);
        } catch (Exception e) {
            System.debug('WARN: BusRescheduleAction Salesforce mirror update failed for ' + r.bookingReferenceId + ': ' + e.getMessage());
        }

        return out;
    }

    private static void mirrorToSalesforce(String referenceId, BusApiClient.BookingResult after, Decimal oldTotalAmount, String reason) {
        List<Bus_Booking__c> existing = [
            SELECT Id, Bus_Trip__c, Total_Amount__c,
                   (SELECT Id FROM Bus_Seats__r),
                   (SELECT Id, Bus_Seat__c FROM Booking_Passengers__r ORDER BY CreatedDate ASC)
            FROM Bus_Booking__c
            WHERE Booking_Reference_Id__c = :referenceId
            LIMIT 1
        ];
        if (existing.isEmpty()) {
            System.debug('BusRescheduleAction: booking ' + referenceId + ' was never synced to Salesforce - skipping mirror update.');
            return;
        }
        Bus_Booking__c booking = existing[0];
        Id oldTripId = booking.Bus_Trip__c;

        BusBookingSyncService.TripPayload tripPayload = toTripPayload(after.booking.trip);
        Bus__c bus = BusBookingSyncService.upsertBus(tripPayload);
        Bus_Trip__c newTrip = BusBookingSyncService.upsertTrip(tripPayload, bus.Id);

        booking.Bus_Trip__c = newTrip.Id;
        booking.Total_Amount__c = after.booking.totalAmount;
        booking.Booking_Status__c = 'Rescheduled';
        update booking;

        // Booking_Passenger__c.Bus_Seat__c is required and Restrict-on-delete,
        // so the old seats can't be deleted while any passenger still points
        // at them - new seats must be inserted and passengers repointed
        // FIRST, old seats deleted last.
        List<Bus_Seat__c> newSeats = new List<Bus_Seat__c>();
        if (after.rawSeats != null) {
            for (Object rawSeat : after.rawSeats) {
                Map<String, Object> seat = (Map<String, Object>) rawSeat;
                newSeats.add(new Bus_Seat__c(
                    Bus_Booking__c = booking.Id,
                    Bus_Trip__c = newTrip.Id,
                    Deck__c = (String) seat.get('deck'),
                    Seat_Category__c = BusBookingSyncService.mapSeatCategory((String) seat.get('category')),
                    Fare__c = (Decimal) seat.get('fare')
                ));
            }
        }
        if (!newSeats.isEmpty()) {
            insert newSeats;
        }

        // The Bus API reassigns passengers to new seats positionally (same
        // order as the original passengers/seats arrays) rather than by
        // name - see bookingService.js#rescheduleBooking. Existing
        // Booking_Passenger__c records queried in creation order line up
        // with the new seat records in the same way.
        List<Booking_Passenger__c> existingPassengers = existing[0].Booking_Passengers__r;
        if (existingPassengers.size() == newSeats.size()) {
            List<Booking_Passenger__c> toUpdate = new List<Booking_Passenger__c>();
            for (Integer i = 0; i < existingPassengers.size(); i++) {
                toUpdate.add(new Booking_Passenger__c(Id = existingPassengers[i].Id, Bus_Seat__c = newSeats[i].Id));
            }
            update toUpdate;
        } else {
            System.debug('BusRescheduleAction: passenger count (' + existingPassengers.size() + ') did not match new seat count (' + newSeats.size() + ') for ' + referenceId + ' - leaving old seat assignments in place.');
        }

        List<Bus_Seat__c> oldSeats = existing[0].Bus_Seats__r;
        if (!oldSeats.isEmpty()) {
            delete oldSeats;
        }

        insert new Bus_Reschedule__c(
            Bus_Booking__c = booking.Id,
            Old_Trip__c = oldTripId,
            New_Trip__c = newTrip.Id,
            Fare_Difference__c = (after.booking.totalAmount != null ? after.booking.totalAmount : 0) - oldTotalAmount,
            Reschedule_Date__c = System.now(),
            Requested_Via__c = 'Agentforce',
            Status__c = 'Completed',
            Reschedule_Reason__c = reason
        );
    }

    // BusApiClient.TripDto and BusBookingSyncService.TripPayload are
    // field-for-field identical (both mirror the Bus API's trip JSON) but
    // are distinct Apex types, so BusBookingSyncService's upsert helpers
    // need this conversion rather than accepting a TripDto directly.
    private static BusBookingSyncService.TripPayload toTripPayload(BusApiClient.TripDto trip) {
        BusBookingSyncService.TripPayload payload = new BusBookingSyncService.TripPayload();
        payload.tripId = trip.tripId;
        payload.operator = trip.operator;
        payload.busName = trip.busName;
        payload.busType = trip.busType;
        payload.rating = trip.rating;
        payload.fromCity = trip.fromCity;
        payload.toCity = trip.toCity;
        payload.travelDate = trip.travelDate;
        payload.departureTime = trip.departureTime;
        payload.arrivalTime = trip.arrivalTime;
        payload.durationLabel = trip.durationLabel;
        payload.boardingPoint = trip.boardingPoint;
        payload.droppingPoint = trip.droppingPoint;
        payload.fare = trip.fare;
        payload.totalSeats = trip.totalSeats;
        return payload;
    }
}
