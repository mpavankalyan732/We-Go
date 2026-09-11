try {
    List<BusApiClient.TripDto> trips = BusApiClient.searchTrips('Chennai', 'Bangalore', '2026-12-15');
    System.debug('LIVE CALLOUT OK - trips found: ' + trips.size());
    if (!trips.isEmpty()) {
        System.debug('First trip: ' + JSON.serialize(trips[0]));
    }
} catch (Exception e) {
    System.debug('LIVE CALLOUT FAILED: ' + e.getMessage());
}
