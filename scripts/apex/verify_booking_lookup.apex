BusBookingLookupAction.LookupRequest req = new BusBookingLookupAction.LookupRequest();
req.bookingReferenceId = 'BK-2HCTKJ';
req.pnr = '0390780185';

List<BusBookingLookupAction.LookupResult> results =
    BusBookingLookupAction.lookUp(new List<BusBookingLookupAction.LookupRequest>{ req });

BusBookingLookupAction.LookupResult result = results[0];

System.debug('=== LOOKUP RESULT ===');
System.debug('found: ' + result.found);
System.debug('dataSource: ' + result.dataSource);
System.debug('message: ' + result.message);
System.debug('status: ' + result.status);
System.debug('route: ' + result.originCity + ' -> ' + result.destinationCity);
System.debug('operator: ' + result.operatorName + ' (' + result.busType + ')');
System.debug('boardingPoint: ' + result.boardingPoint);
System.debug('droppingPoint: ' + result.droppingPoint);
System.debug('travelDate: ' + result.travelDate + ' departureTime: ' + result.departureTime + ' arrivalTime: ' + result.arrivalTime);
System.debug('totalAmount: ' + result.totalAmount);
System.debug('passengers: ' + JSON.serialize(result.passengers));
