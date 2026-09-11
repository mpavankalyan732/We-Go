/**
 * Agentforce action: performs a cancellation. The Bus API
 * (POST /bookings/:ref/cancel) is the actual system of record - it releases
 * seats and computes the real refund amount. This class re-validates against
 * the live booking, calls the Bus API, then mirrors the result into
 * Salesforce (Booking_Status__c/Cancelled_Date__c/Cancellation_Reason__c/
 * Refund_Amount__c).
 *
 * The Salesforce mirror uses `upsert ... Booking_Reference_Id__c` (a true
 * External ID) rather than a query-then-update, so it still records the
 * cancellation even if the booking was never synced to Salesforce in the
 * first place. Either way, a Salesforce-side failure never undoes the
 * cancellation itself, which has already succeeded at the Bus API.
 */
public without sharing class BusCancellationAction {
    public class CancellationRequest {
        @InvocableVariable(label='Booking Reference Id' required=true)
        public String bookingReferenceId;

        @InvocableVariable(label='PNR' required=true)
        public String pnr;

        @InvocableVariable(label='Reason')
        public String reason;
    }

    public class CancellationResult {
        @InvocableVariable public Boolean success = false;
        @InvocableVariable public String message;
        @InvocableVariable public String bookingReferenceId;
        @InvocableVariable public Decimal refundAmount;
    }

    @InvocableMethod(label='Cancel Bus Booking' description='Cancels a confirmed bus booking via the live Bus API and records the refund.')
    public static List<CancellationResult> cancel(List<CancellationRequest> requests) {
        List<CancellationResult> results = new List<CancellationResult>();
        for (CancellationRequest r : requests) {
            results.add(cancelOne(r));
        }
        return results;
    }

    private static CancellationResult cancelOne(CancellationRequest r) {
        CancellationResult out = new CancellationResult();
        out.bookingReferenceId = r.bookingReferenceId;

        if (String.isBlank(r.bookingReferenceId) || String.isBlank(r.pnr)) {
            out.message = 'Both a booking reference ID and PNR are required.';
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
            out.message = 'This booking is ' + before.booking.status + ' and cannot be cancelled.';
            return out;
        }

        BusApiClient.BookingResult after;
        try {
            after = BusApiClient.cancelBooking(r.bookingReferenceId.trim(), r.reason);
        } catch (Exception e) {
            out.message = 'Cancellation failed: ' + e.getMessage();
            return out;
        }

        out.success = true;
        out.refundAmount = after.booking.refundAmount;
        out.message = 'Booking cancelled. Refund amount: ' + (after.booking.refundAmount != null ? after.booking.refundAmount : 0) + '.';

        try {
            upsert new Bus_Booking__c(
                Booking_Reference_Id__c = r.bookingReferenceId.trim(),
                Booking_Status__c = 'Cancelled',
                Cancelled_Date__c = System.now(),
                Cancellation_Reason__c = r.reason,
                Refund_Amount__c = after.booking.refundAmount
            ) Booking_Reference_Id__c;
        } catch (Exception e) {
            System.debug('WARN: BusCancellationAction Salesforce mirror update failed for ' + r.bookingReferenceId + ': ' + e.getMessage());
        }

        return out;
    }
}
