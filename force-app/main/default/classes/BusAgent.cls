/**
 * Formerly held 4 @InvocableMethod actions (search/book/reschedule/cancel)
 * built against a placeholder Named Credential and the old flattened
 * Bus_Booking__c fields (Origin_City__c, Bus_Operator__c, etc.) - both are
 * gone now: the invocable actions were split one-per-class (platform limit:
 * max 1 @InvocableMethod per class) into BusBookingLookupAction,
 * BusRescheduleEligibilityAction, BusRescheduleAction,
 * BusCancellationEligibilityAction, and BusCancellationAction, all calling
 * the real Bus API via BusApiClient. The old flattened fields were deleted
 * from Bus_Booking__c when the current 8-object model was built.
 *
 * confirmBusBooking() is kept as a stub purely so the busResultsRenderer LWC
 * (@salesforce/apex/BusAgent.confirmBusBooking) still compiles - that LWC and
 * its Custom Lightning Types are stale and scheduled for rework separately
 * (reconnecting them to real booking-creation via the Bus API is out of
 * scope here, since new bookings are made through the website, not chat).
 */
public without sharing class BusAgent {
    @AuraEnabled
    public static BusActionResult confirmBusBooking(BusBookingDetails bookingDetails) {
        throw new AuraHandledException('Booking via this component is not yet reconnected to the current booking flow.');
    }

    public class BusBookingDetails {
        @InvocableVariable public String busId;
        @InvocableVariable public String busOperator;
        @InvocableVariable public String departureTime;
        @InvocableVariable public String originCity;
        @InvocableVariable public String destinationCity;
        @InvocableVariable public Date dateOfTravel;
        @InvocableVariable public String seatNumbers;
        @InvocableVariable public Long price;
        @InvocableVariable public String passengerName;
        @InvocableVariable public String passengerEmail;
        @InvocableVariable public String passengerPhone;
    }

    public class BusActionResult {
        @InvocableVariable @AuraEnabled public String referenceId;
        @InvocableVariable @AuraEnabled public String bookingId;
        @InvocableVariable @AuraEnabled public String status;
        @InvocableVariable @AuraEnabled public String message;
    }
}
