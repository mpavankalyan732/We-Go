/**
 * Agentforce action: checks whether a booking can be cancelled and previews
 * the refund it would receive. Read-only - never calls the Bus API's cancel
 * endpoint (see BusCancellationAction for that).
 *
 * The refund preview mirrors the Bus API's own tiered policy exactly (see
 * bookingService.js#computeRefund): full refund more than 24h before
 * departure, 50% within 24h, 0% once departure has passed. There is no
 * "preview" endpoint on the Bus API, so this logic is duplicated here - if
 * that policy ever changes, update both places.
 */
public with sharing class BusCancellationEligibilityAction {
    public class EligibilityRequest {
        @InvocableVariable(label='Booking Reference Id' required=true)
        public String bookingReferenceId;

        @InvocableVariable(label='PNR' required=true)
        public String pnr;
    }

    public class EligibilityResult {
        @InvocableVariable public Boolean eligible = false;
        @InvocableVariable public String message;
        @InvocableVariable public Decimal totalAmount;
        @InvocableVariable public Decimal estimatedRefundAmount;
        @InvocableVariable public Integer refundPercent;
    }

    @InvocableMethod(label='Check Cancellation Eligibility' description='Checks whether a bus booking can be cancelled and estimates the refund based on the live Bus API booking status and departure time.')
    public static List<EligibilityResult> check(List<EligibilityRequest> requests) {
        List<EligibilityResult> results = new List<EligibilityResult>();
        for (EligibilityRequest r : requests) {
            results.add(checkOne(r));
        }
        return results;
    }

    private static EligibilityResult checkOne(EligibilityRequest r) {
        EligibilityResult out = new EligibilityResult();

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
        out.totalAmount = booking.totalAmount;

        if (booking.status != 'Confirmed') {
            out.message = 'This booking is ' + booking.status + ' and cannot be cancelled.';
            return out;
        }
        if (booking.trip == null) {
            out.message = 'This booking has no trip on file - it cannot be cancelled.';
            return out;
        }

        Integer refundPercent = estimateRefundPercent(booking.trip.travelDate, booking.trip.departureTime);
        out.refundPercent = refundPercent;
        out.estimatedRefundAmount = ((booking.totalAmount != null ? booking.totalAmount : 0) * refundPercent / 100).setScale(2);
        out.eligible = true;
        out.message = 'Booking is eligible for cancellation. Estimated refund: ' + refundPercent + '% of the total amount.';
        return out;
    }

    private static Integer estimateRefundPercent(String travelDate, String departureTime) {
        if (String.isBlank(travelDate) || String.isBlank(departureTime)) {
            return 0;
        }
        List<String> hm = departureTime.split(':');
        Datetime departure = Datetime.newInstanceGmt(
            Date.valueOf(travelDate),
            Time.newInstance(Integer.valueOf(hm[0]), Integer.valueOf(hm[1]), 0, 0)
        );
        Decimal hoursUntilDeparture = (departure.getTime() - Datetime.now().getTime()) / (1000.0 * 60 * 60);
        if (hoursUntilDeparture <= 0) return 0;
        if (hoursUntilDeparture <= 24) return 50;
        return 100;
    }
}
