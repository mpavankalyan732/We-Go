BusRescheduleEligibilityAction.EligibilityRequest req = new BusRescheduleEligibilityAction.EligibilityRequest();
req.bookingReferenceId = 'BK-PVXZ75';
req.pnr = '2157939413';

List<BusRescheduleEligibilityAction.EligibilityResult> results =
    BusRescheduleEligibilityAction.check(new List<BusRescheduleEligibilityAction.EligibilityRequest>{ req });

BusRescheduleEligibilityAction.EligibilityResult result = results[0];

System.debug('=== ELIGIBILITY RESULT ===');
System.debug('eligible: ' + result.eligible);
System.debug('message: ' + result.message);
System.debug('currentTripId: ' + result.currentTripId);
System.debug('route: ' + result.originCity + ' -> ' + result.destinationCity);
System.debug('currentTravelDate: ' + result.currentTravelDate);
System.debug('alternatives: ' + (result.alternatives != null ? result.alternatives.size() : null));
