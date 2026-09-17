/**
 * Agentforce action: performs a reschedule. Tries the live Bus API first
 * (POST /bookings/:ref/reschedule) - the actual system of record, which does
 * the seat release/re-lock and validates eligibility itself - then mirrors
 * the result into Salesforce (Bus_Trip__c, seats, passenger seat
 * assignments, a Bus_Reschedule__c audit record). That mirror is
 * best-effort: a failure there doesn't undo the reschedule, which already
 * succeeded at the Bus API.
 *
 * If the live API doesn't have the booking or is unreachable (e.g. a Render
 * free-tier cold start / the ephemeral disk was reset), falls back to
 * performing the reschedule directly against Salesforce's own records - the
 * new trip must already exist in Salesforce (synced from some earlier
 * booking), and seat availability/fare are approximated (bus capacity minus
 * seats already recorded in Salesforce for that trip; flat per-seat fare,
 * since Salesforce has no seat-category pricing for a trip it hasn't
 * already sold seats on). This deliberately makes the Bus API's own
 * database fall out of sync with Salesforce for this booking - dataSource
 * on the result says which path was used, so the agent can tell the
 * customer their booking's live record may not reflect it.
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
        @InvocableVariable public String dataSource;
        @InvocableVariable public String bookingReferenceId;
        @InvocableVariable public String newTripId;
        @InvocableVariable public Decimal newTotalAmount;
        @InvocableVariable public Decimal fareDifference;
    }

    @InvocableMethod(label='Reschedule Bus Booking' description='Moves a confirmed bus booking to a different trip. Falls back to a Salesforce-only reschedule if the live booking system does not have this booking.')
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

        String referenceId = r.bookingReferenceId.trim();
        String pnr = r.pnr.trim();
        String newTripId = r.newTripId.trim();

        BusApiClient.BookingResult before;
        try {
            before = BusApiClient.getBooking(referenceId);
        } catch (Exception e) {
            before = null;
        }

        if (before != null && before.booking.pnr == pnr) {
            return rescheduleViaLiveApi(referenceId, before, newTripId, r.reason);
        }

        RescheduleResult fallback = rescheduleViaSalesforce(referenceId, pnr, newTripId, r.reason);
        if (fallback != null) {
            return fallback;
        }

        out.message = 'No booking found for that reference ID and PNR combination.';
        return out;
    }

    private static RescheduleResult rescheduleViaLiveApi(String referenceId, BusApiClient.BookingResult before, String newTripId, String reason) {
        RescheduleResult out = new RescheduleResult();
        out.bookingReferenceId = referenceId;

        if (before.booking.status != 'Confirmed') {
            out.message = 'This booking is ' + before.booking.status + ' and cannot be rescheduled.';
            return out;
        }

        Decimal oldAmount = before.booking.totalAmount != null ? before.booking.totalAmount : 0;

        BusApiClient.BookingResult after;
        try {
            after = BusApiClient.rescheduleBooking(referenceId, newTripId, reason);
        } catch (Exception e) {
            out.message = 'Reschedule failed: ' + e.getMessage();
            return out;
        }

        out.success = true;
        out.dataSource = 'Live';
        out.newTripId = after.booking.trip != null ? after.booking.trip.tripId : newTripId;
        out.newTotalAmount = after.booking.totalAmount;
        Decimal newAmount = after.booking.totalAmount != null ? after.booking.totalAmount : 0;
        out.fareDifference = newAmount - oldAmount;
        out.message = 'Booking rescheduled to trip ' + out.newTripId + '.';

        try {
            mirrorToSalesforce(referenceId, after, oldAmount, reason);
        } catch (Exception e) {
            System.debug('WARN: BusRescheduleAction Salesforce mirror update failed for ' + referenceId + ': ' + e.getMessage());
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

        replaceSeats(existing[0].Bus_Seats__r, newSeats, existing[0].Booking_Passengers__r, referenceId);

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

    // Salesforce-only path: the new trip must already exist in Salesforce
    // (synced from some earlier booking) - there's no live search to
    // discover brand-new trips here. Seat availability is approximated as
    // Bus__c.Total_Seat__c minus seats already recorded in Salesforce for
    // that trip, and fare is a flat Base_Fare__c per seat, since Salesforce
    // has no seat-category pricing for a trip it hasn't already sold seats
    // on. Returns null if the booking itself isn't in Salesforce either.
    private static RescheduleResult rescheduleViaSalesforce(String referenceId, String pnr, String newTripId, String reason) {
        List<Bus_Booking__c> bookings = [
            SELECT Id, Booking_Status__c, Bus_Trip__c, Total_Amount__c,
                   (SELECT Id, Deck__c, Seat_Category__c FROM Bus_Seats__r),
                   (SELECT Id, Bus_Seat__c FROM Booking_Passengers__r ORDER BY CreatedDate ASC)
            FROM Bus_Booking__c
            WHERE Booking_Reference_Id__c = :referenceId AND PNR__c = :pnr
            LIMIT 1
        ];
        if (bookings.isEmpty()) {
            return null;
        }

        Bus_Booking__c booking = bookings[0];
        RescheduleResult out = new RescheduleResult();
        out.bookingReferenceId = referenceId;
        out.dataSource = 'SalesforceRecord';

        if (booking.Booking_Status__c != 'Confirmed') {
            out.message = 'This booking is ' + booking.Booking_Status__c + ' and cannot be rescheduled.';
            return out;
        }

        List<Bus_Trip__c> newTrips = [
            SELECT Id, Bus__r.Total_Seat__c, Base_Fare__c
            FROM Bus_Trip__c
            WHERE External_Trip_Id__c = :newTripId
            LIMIT 1
        ];
        if (newTrips.isEmpty()) {
            out.message = 'That trip is not on file in Salesforce, and the live booking system is currently unreachable - please try again shortly.';
            return out;
        }
        Bus_Trip__c newTrip = newTrips[0];

        Integer seatsNeeded = booking.Bus_Seats__r.size();
        Integer alreadyBooked = 0;
        for (AggregateResult ar : [SELECT COUNT(Id) bookedCount FROM Bus_Seat__c WHERE Bus_Trip__c = :newTrip.Id]) {
            alreadyBooked = (Integer) ar.get('bookedCount');
        }
        Integer totalSeats = newTrip.Bus__r != null && newTrip.Bus__r.Total_Seat__c != null ? Integer.valueOf(newTrip.Bus__r.Total_Seat__c) : 0;
        if (totalSeats - alreadyBooked < seatsNeeded) {
            out.message = 'Not enough seats are available on that trip according to Salesforce records (' + (totalSeats - alreadyBooked) + ' open, ' + seatsNeeded + ' needed).';
            return out;
        }

        Decimal oldAmount = booking.Total_Amount__c != null ? booking.Total_Amount__c : 0;
        Decimal newAmount = (newTrip.Base_Fare__c != null ? newTrip.Base_Fare__c : 0) * seatsNeeded;

        Id oldTripId = booking.Bus_Trip__c;
        booking.Bus_Trip__c = newTrip.Id;
        booking.Total_Amount__c = newAmount;
        booking.Booking_Status__c = 'Rescheduled';
        update booking;

        List<Bus_Seat__c> newSeats = new List<Bus_Seat__c>();
        for (Bus_Seat__c oldSeat : booking.Bus_Seats__r) {
            newSeats.add(new Bus_Seat__c(
                Bus_Booking__c = booking.Id,
                Bus_Trip__c = newTrip.Id,
                Deck__c = oldSeat.Deck__c,
                Seat_Category__c = oldSeat.Seat_Category__c,
                Fare__c = newTrip.Base_Fare__c
            ));
        }
        replaceSeats(booking.Bus_Seats__r, newSeats, booking.Booking_Passengers__r, referenceId);

        insert new Bus_Reschedule__c(
            Bus_Booking__c = booking.Id,
            Old_Trip__c = oldTripId,
            New_Trip__c = newTrip.Id,
            Fare_Difference__c = newAmount - oldAmount,
            Reschedule_Date__c = System.now(),
            Requested_Via__c = 'Agentforce',
            Status__c = 'Completed',
            Reschedule_Reason__c = reason
        );

        out.success = true;
        out.newTripId = newTripId;
        out.newTotalAmount = newAmount;
        out.fareDifference = newAmount - oldAmount;
        out.message = 'Booking rescheduled to trip ' + newTripId + ' using Salesforce records - the live booking system does not have this booking right now, so this change will not appear if the customer checks the website directly.';
        return out;
    }

    // Booking_Passenger__c.Bus_Seat__c is required and Restrict-on-delete, so
    // the old seats can't be deleted while any passenger still points at
    // them - new seats must be inserted and passengers repointed FIRST, old
    // seats deleted last. Shared by both the live-API mirror and the
    // Salesforce-only path.
    private static void replaceSeats(List<Bus_Seat__c> oldSeats, List<Bus_Seat__c> newSeats, List<Booking_Passenger__c> existingPassengers, String referenceId) {
        if (!newSeats.isEmpty()) {
            insert newSeats;
        }

        // The Bus API reassigns passengers to new seats positionally (same
        // order as the original passengers/seats arrays) rather than by
        // name - see bookingService.js#rescheduleBooking. Existing
        // Booking_Passenger__c records queried in creation order line up
        // with the new seat records in the same way; the Salesforce-only
        // path builds newSeats directly from oldSeats in the same order, so
        // the same positional pairing holds there too.
        if (existingPassengers.size() == newSeats.size()) {
            List<Booking_Passenger__c> toUpdate = new List<Booking_Passenger__c>();
            for (Integer i = 0; i < existingPassengers.size(); i++) {
                toUpdate.add(new Booking_Passenger__c(Id = existingPassengers[i].Id, Bus_Seat__c = newSeats[i].Id));
            }
            update toUpdate;
        } else {
            System.debug('BusRescheduleAction: passenger count (' + existingPassengers.size() + ') did not match new seat count (' + newSeats.size() + ') for ' + referenceId + ' - leaving old seat assignments in place.');
        }

        if (!oldSeats.isEmpty()) {
            delete oldSeats;
        }
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
