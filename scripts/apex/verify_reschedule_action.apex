BusRescheduleAction.RescheduleRequest req = new BusRescheduleAction.RescheduleRequest();
req.bookingReferenceId = 'BK-PVXZ75';
req.pnr = '2157939413';
req.newTripId = 'TRIP-qors2f';
req.reason = 'Testing Salesforce-only reschedule fallback';

List<BusRescheduleAction.RescheduleResult> results =
    BusRescheduleAction.reschedule(new List<BusRescheduleAction.RescheduleRequest>{ req });

BusRescheduleAction.RescheduleResult result = results[0];

System.debug('=== RESCHEDULE RESULT ===');
System.debug('success: ' + result.success);
System.debug('dataSource: ' + result.dataSource);
System.debug('message: ' + result.message);
System.debug('newTripId: ' + result.newTripId);
System.debug('newTotalAmount: ' + result.newTotalAmount);
System.debug('fareDifference: ' + result.fareDifference);
