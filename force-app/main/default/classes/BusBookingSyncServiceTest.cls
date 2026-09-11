@isTest
private class BusBookingSyncServiceTest {
    private static String samplePayload(String bookingRef, String tripId) {
        // PNR__c is unique — derive one from bookingRef so calls with different
        // booking references never collide on the same hardcoded PNR.
        String pnr = String.valueOf(Math.abs(System.hashCode(bookingRef))).rightPad(10, '0').left(10);
        return '{' +
            '"bookingReferenceId":"' + bookingRef + '",' +
            '"pnr":"' + pnr + '",' +
            '"status":"Confirmed",' +
            '"trip":{' +
                '"tripId":"' + tripId + '",' +
                '"operator":"Greenline Travels",' +
                '"busName":"Greenline Travels 100",' +
                '"busType":"AC Sleeper",' +
                '"rating":4.3,' +
                '"fromCity":"Chennai",' +
                '"toCity":"Tirupati",' +
                '"travelDate":"2026-09-20",' +
                '"departureTime":"06:00",' +
                '"arrivalTime":"14:00",' +
                '"durationLabel":"8h 00m",' +
                '"boardingPoint":"Chennai Central Bus Stand",' +
                '"droppingPoint":"Tirupati Main Bus Depot",' +
                '"fare":900,' +
                '"totalSeats":36' +
            '},' +
            '"seats":[' +
                '{"number":"L1A","deck":"Lower","category":"single-berth","fare":1000},' +
                '{"number":"L1C","deck":"Lower","category":"double-berth","fare":1000}' +
            '],' +
            '"passengers":[' +
                '{"seatNumber":"L1A","name":"Jane Doe","age":30,"gender":"Female","email":"jane@example.com","phone":"9876543210"},' +
                '{"seatNumber":"L1C","name":"John Doe","age":32,"gender":"Male","email":null,"phone":null}' +
            '],' +
            '"contactEmail":"jane@example.com",' +
            '"contactPhone":"9876543210",' +
            '"totalAmount":2000' +
        '}';
    }

    @isTest
    static void createsBusTripBookingSeatsPassengersAndTransaction() {
        Test.startTest();
        Id bookingId = BusBookingSyncService.syncBooking(samplePayload('BK-TEST01', 'TRIP-test01'));
        Test.stopTest();

        Bus_Booking__c booking = [
            SELECT Id, Booking_Reference_Id__c, Total_Amount__c, Bus_Trip__c, Source_Channel__c
            FROM Bus_Booking__c WHERE Id = :bookingId
        ];
        System.assertEquals('BK-TEST01', booking.Booking_Reference_Id__c);
        System.assertEquals(2000, booking.Total_Amount__c);
        System.assertEquals('Website', booking.Source_Channel__c);

        Bus_Trip__c trip = [SELECT External_Trip_Id__c, Bus__c FROM Bus_Trip__c WHERE Id = :booking.Bus_Trip__c];
        System.assertEquals('TRIP-test01', trip.External_Trip_Id__c);

        Bus__c bus = [SELECT External_Bus_Id__c, Operator_Name__c FROM Bus__c WHERE Id = :trip.Bus__c];
        System.assertEquals('Greenline Travels 100', bus.External_Bus_Id__c);
        System.assertEquals('Greenline Travels', bus.Operator_Name__c);

        List<Bus_Seat__c> seats = [SELECT Id, Fare__c FROM Bus_Seat__c WHERE Bus_Booking__c = :bookingId];
        System.assertEquals(2, seats.size());

        List<Booking_Passenger__c> passengers = [
            SELECT Full_Name__c, Is_Primary_Contact__c FROM Booking_Passenger__c
            WHERE Bus_Booking__c = :bookingId ORDER BY Full_Name__c
        ];
        System.assertEquals(2, passengers.size());

        List<Booking_Transaction__c> txns = [
            SELECT Amount__c, Transaction_Type__c FROM Booking_Transaction__c WHERE Bus_Booking__c = :bookingId
        ];
        System.assertEquals(1, txns.size());
        System.assertEquals('Payment', txns[0].Transaction_Type__c);
    }

    @isTest
    static void reusesExistingBusAndTripOnASecondBookingForTheSameTrip() {
        BusBookingSyncService.syncBooking(samplePayload('BK-TEST02', 'TRIP-shared'));
        Test.startTest();
        BusBookingSyncService.syncBooking(samplePayload('BK-TEST03', 'TRIP-shared'));
        Test.stopTest();

        System.assertEquals(1, [SELECT COUNT() FROM Bus__c WHERE External_Bus_Id__c = 'Greenline Travels 100']);
        System.assertEquals(1, [SELECT COUNT() FROM Bus_Trip__c WHERE External_Trip_Id__c = 'TRIP-shared']);
        System.assertEquals(2, [SELECT COUNT() FROM Bus_Booking__c WHERE Bus_Trip__r.External_Trip_Id__c = 'TRIP-shared']);
    }

    @isTest
    static void resyncingTheSameBookingDoesNotDuplicateChildren() {
        Id bookingId = BusBookingSyncService.syncBooking(samplePayload('BK-TEST04', 'TRIP-test04'));
        Test.startTest();
        BusBookingSyncService.syncBooking(samplePayload('BK-TEST04', 'TRIP-test04'));
        Test.stopTest();

        System.assertEquals(2, [SELECT COUNT() FROM Bus_Seat__c WHERE Bus_Booking__c = :bookingId]);
        System.assertEquals(2, [SELECT COUNT() FROM Booking_Passenger__c WHERE Bus_Booking__c = :bookingId]);
    }

    @isTest
    static void restResourceReturnsSuccessJson() {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/roadlink/bookingSync';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf(samplePayload('BK-TEST05', 'TRIP-test05'));
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        BusBookingSyncResource.syncBooking();
        Test.stopTest();

        System.assertEquals(200, RestContext.response.statusCode);
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        System.assertEquals(true, body.get('success'));
    }

    @isTest
    static void restResourceReturnsErrorJsonOnBadPayload() {
        RestRequest req = new RestRequest();
        req.requestUri = '/services/apexrest/roadlink/bookingSync';
        req.httpMethod = 'POST';
        req.requestBody = Blob.valueOf('{}');
        RestContext.request = req;
        RestContext.response = new RestResponse();

        Test.startTest();
        BusBookingSyncResource.syncBooking();
        Test.stopTest();

        System.assertEquals(400, RestContext.response.statusCode);
        Map<String, Object> body = (Map<String, Object>) JSON.deserializeUntyped(RestContext.response.responseBody.toString());
        System.assertEquals(false, body.get('success'));
    }
}
