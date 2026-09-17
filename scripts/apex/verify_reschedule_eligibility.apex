BusRescheduleEligibilityAction.EligibilityRequest req = new BusRescheduleEligibilityAction.EligibilityRequest();
req.bookingReferenceId = 'BK-PVXZ75';
req.pnr = '2157939413';
req.newTravelDate = '2026-09-11';

List<BusRescheduleEligibilityAction.EligibilityResult> results =
    BusRescheduleEligibilityAction.check(new List<BusRescheduleEligibilityAction.EligibilityRequest>{ req });

BusRescheduleEligibilityAction.EligibilityResult result = results[0];

System.debug('=== ELIGIBILITY RESULT ===');
System.debug('eligible: ' + result.eligible);
System.debug('dataSource: ' + result.dataSource);
System.debug('message: ' + result.message);
System.debug('alternatives: ' + JSON.serialize(result.alternatives));
