@IsTest
private class BusAgentActionsTest {
    private static final String REF = 'BK-TEST1';
    private static final String PNR = '1234567890';

    private static void seedSalesforceBooking() {
        Bus__c bus = new Bus__c(External_Bus_Id__c = 'Greenline Travels 100', Operator_Name__c = 'Greenline Travels', Bus_Type__c = 'AC Sleeper', Rating__c = 4.3, Total_Seat__c = 36);
        insert bus;

        Bus_Trip__c trip = new Bus_Trip__c(
            External_Trip_Id__c = 'TRIP-OLD',
            Bus__c = bus.Id,
            Origin_City__c = 'Chennai',
            Destination_City__c = 'Tirupati',
            Travel_Date__c = Date.newInstance(2099, 1, 1),
            Departure_Time__c = Time.newInstance(6, 0, 0, 0),
            Arrival_Time__c = Time.newInstance(14, 0, 0, 0),
            Boarding_Point__c = 'Chennai Central Bus Stand',
            Dropping_Point__c = 'Tirupati Main Bus Depot',
            Base_Fare__c = 1272,
            Duration_Label__c = '8h 30m'
        );
        insert trip;

        Bus_Booking__c booking = new Bus_Booking__c(
            Booking_Reference_Id__c = REF,
            PNR__c = PNR,
            Bus_Trip__c = trip.Id,
            Booking_Status__c = 'Confirmed',
            Total_Amount__c = 1372,
            Primary_Contact_Email__c = 'jane@example.com',
            Primary_Contact_Phone__c = '9876543210',
            Source_Channel__c = 'Website'
        );
        insert booking;

        Bus_Seat__c seat = new Bus_Seat__c(
            Bus_Booking__c = booking.Id,
            Bus_Trip__c = trip.Id,
            Deck__c = 'Lower',
            Seat_Category__c = 'Double Berth',
            Fare__c = 1372
        );
        insert seat;

        insert new Booking_Passenger__c(
            Name = 'Jane Doe',
            Bus_Booking__c = booking.Id,
            Bus_Seat__c = seat.Id,
            Full_Name__c = 'Jane Doe',
            Age__c = 30,
            Gender__c = 'Female',
            Email__c = 'jane@example.com',
            Phone__c = '9876543210',
            Is_Primary_Contact__c = true
        );
    }

    @IsTest
    static void testLookup_found() {
        Test.setMock(HttpCalloutMock.class, new BusApiMock());

        BusBookingLookupAction.LookupRequest req = new BusBookingLookupAction.LookupRequest();
        req.bookingReferenceId = REF;
        req.pnr = PNR;

        Test.startTest();
        List<BusBookingLookupAction.LookupResult> results = BusBookingLookupAction.lookUp(new List<BusBookingLookupAction.LookupRequest>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals(true, results[0].found);
        System.assertEquals('Confirmed', results[0].status);
        System.assertEquals('Chennai', results[0].originCity);
        System.assertEquals(1, results[0].passengers.size());
    }

    @IsTest
    static void testLookup_wrongPnrNotFound() {
        Test.setMock(HttpCalloutMock.class, new BusApiMock());

        BusBookingLookupAction.LookupRequest req = new BusBookingLookupAction.LookupRequest();
        req.bookingReferenceId = REF;
        req.pnr = '0000000000';

        Test.startTest();
        List<BusBookingLookupAction.LookupResult> results = BusBookingLookupAction.lookUp(new List<BusBookingLookupAction.LookupRequest>{ req });
        Test.stopTest();

        System.assertEquals(false, results[0].found);
    }

    @IsTest
    static void testRescheduleEligibility_returnsAlternativesExcludingCurrentTrip() {
        Test.setMock(HttpCalloutMock.class, new BusApiMock());

        BusRescheduleEligibilityAction.EligibilityRequest req = new BusRescheduleEligibilityAction.EligibilityRequest();
        req.bookingReferenceId = REF;
        req.pnr = PNR;

        Test.startTest();
        List<BusRescheduleEligibilityAction.EligibilityResult> results = BusRescheduleEligibilityAction.check(new List<BusRescheduleEligibilityAction.EligibilityRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].eligible);
        System.assertEquals(1, results[0].alternatives.size());
        System.assertEquals('TRIP-ALT', results[0].alternatives[0].tripId);
    }

    @IsTest
    static void testReschedule_success_mirrorsSeatsAndPassengerToSalesforce() {
        seedSalesforceBooking();
        Test.setMock(HttpCalloutMock.class, new BusApiMock());

        BusRescheduleAction.RescheduleRequest req = new BusRescheduleAction.RescheduleRequest();
        req.bookingReferenceId = REF;
        req.pnr = PNR;
        req.newTripId = 'TRIP-NEW';
        req.reason = 'Passenger requested a later bus';

        Test.startTest();
        List<BusRescheduleAction.RescheduleResult> results = BusRescheduleAction.reschedule(new List<BusRescheduleAction.RescheduleRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assertEquals('TRIP-NEW', results[0].newTripId);
        System.assertEquals(1450, results[0].newTotalAmount);
        System.assertEquals(78, results[0].fareDifference);

        Bus_Booking__c updated = [SELECT Booking_Status__c, Total_Amount__c, Bus_Trip__c FROM Bus_Booking__c WHERE Booking_Reference_Id__c = :REF];
        System.assertEquals('Rescheduled', updated.Booking_Status__c);
        System.assertEquals(1450, updated.Total_Amount__c);

        Bus_Trip__c newTrip = [SELECT External_Trip_Id__c FROM Bus_Trip__c WHERE Id = :updated.Bus_Trip__c];
        System.assertEquals('TRIP-NEW', newTrip.External_Trip_Id__c);

        List<Bus_Seat__c> seats = [SELECT Seat_Category__c FROM Bus_Seat__c WHERE Bus_Booking__c = :updated.Id];
        System.assertEquals(1, seats.size());
        System.assertEquals('Seater', seats[0].Seat_Category__c);

        Booking_Passenger__c passenger = [SELECT Bus_Seat__c FROM Booking_Passenger__c WHERE Bus_Booking__c = :updated.Id];
        System.assertEquals(seats[0].Id, passenger.Bus_Seat__c);

        List<Bus_Reschedule__c> history = [SELECT Fare_Difference__c, Requested_Via__c, Status__c FROM Bus_Reschedule__c WHERE Bus_Booking__c = :updated.Id];
        System.assertEquals(1, history.size());
        System.assertEquals('Agentforce', history[0].Requested_Via__c);
        System.assertEquals('Completed', history[0].Status__c);
    }

    @IsTest
    static void testCancellationEligibility_fullRefundFarFromDeparture() {
        Test.setMock(HttpCalloutMock.class, new BusApiMock());

        BusCancellationEligibilityAction.EligibilityRequest req = new BusCancellationEligibilityAction.EligibilityRequest();
        req.bookingReferenceId = REF;
        req.pnr = PNR;

        Test.startTest();
        List<BusCancellationEligibilityAction.EligibilityResult> results = BusCancellationEligibilityAction.check(new List<BusCancellationEligibilityAction.EligibilityRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].eligible);
        System.assertEquals(100, results[0].refundPercent);
        System.assertEquals(1372.00, results[0].estimatedRefundAmount);
    }

    @IsTest
    static void testCancellation_success_mirrorsToSalesforce() {
        seedSalesforceBooking();
        Test.setMock(HttpCalloutMock.class, new BusApiMock());

        BusCancellationAction.CancellationRequest req = new BusCancellationAction.CancellationRequest();
        req.bookingReferenceId = REF;
        req.pnr = PNR;
        req.reason = 'Change of plans';

        Test.startTest();
        List<BusCancellationAction.CancellationResult> results = BusCancellationAction.cancel(new List<BusCancellationAction.CancellationRequest>{ req });
        Test.stopTest();

        System.assertEquals(true, results[0].success);
        System.assertEquals(1372, results[0].refundAmount);

        Bus_Booking__c updated = [SELECT Booking_Status__c, Cancellation_Reason__c, Refund_Amount__c, Cancelled_Date__c FROM Bus_Booking__c WHERE Booking_Reference_Id__c = :REF];
        System.assertEquals('Cancelled', updated.Booking_Status__c);
        System.assertEquals('Change of plans', updated.Cancellation_Reason__c);
        System.assertEquals(1372, updated.Refund_Amount__c);
        System.assertNotEquals(null, updated.Cancelled_Date__c);
    }

    // ===================== HTTP MOCK ===================== //
    private class BusApiMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            String endpoint = req.getEndpoint();
            String method = req.getMethod();

            if (endpoint.contains('/api/bookings/BK-NOTFOUND')) {
                res.setStatusCode(404);
                res.setBody('{"error":{"code":"NOT_FOUND","message":"No booking found"}}');
                return res;
            }
            if (method == 'POST' && endpoint.contains('/reschedule')) {
                res.setStatusCode(200);
                res.setBody(rescheduledBookingJson());
                return res;
            }
            if (method == 'POST' && endpoint.contains('/cancel')) {
                res.setStatusCode(200);
                res.setBody(cancelledBookingJson());
                return res;
            }
            if (method == 'GET' && endpoint.contains('/api/buses/search')) {
                res.setStatusCode(200);
                res.setBody(searchResultsJson());
                return res;
            }
            if (method == 'GET' && endpoint.contains('/api/bookings/' + REF)) {
                res.setStatusCode(200);
                res.setBody(confirmedBookingJson());
                return res;
            }
            res.setStatusCode(404);
            res.setBody('{"error":{"code":"NOT_FOUND","message":"unmocked endpoint: ' + endpoint + '"}}');
            return res;
        }

        private String confirmedBookingJson() {
            return '{'
                + '"bookingReferenceId":"' + REF + '","pnr":"' + PNR + '","status":"Confirmed","createdAt":"2026-09-09T12:35:47Z",'
                + '"trip":{"tripId":"TRIP-OLD","operator":"Greenline Travels","busName":"Greenline Travels 100","busType":"AC Sleeper","rating":4.3,'
                + '"fromCity":"Chennai","toCity":"Tirupati","travelDate":"2099-01-01","departureTime":"06:00","arrivalTime":"14:00",'
                + '"durationLabel":"8h 30m","boardingPoint":"Chennai Central Bus Stand","droppingPoint":"Tirupati Main Bus Depot","fare":1272,"totalSeats":36,"availableSeats":20},'
                + '"seatNumbers":["L1C"],'
                + '"seats":[{"number":"L1C","deck":"Lower","category":"double-berth","fare":1372}],'
                + '"passengers":[{"seatNumber":"L1C","name":"Jane Doe","age":30,"gender":"Female","email":"jane@example.com","phone":"9876543210"}],'
                + '"contactEmail":"jane@example.com","contactPhone":"9876543210","totalAmount":1372,'
                + '"cancelledAt":null,"cancellationReason":null,"refundAmount":null'
                + '}';
        }

        private String rescheduledBookingJson() {
            return '{'
                + '"bookingReferenceId":"' + REF + '","pnr":"' + PNR + '","status":"Confirmed","createdAt":"2026-09-09T12:35:47Z",'
                + '"trip":{"tripId":"TRIP-NEW","operator":"Metro Express","busName":"Metro Express 200","busType":"AC Seater","rating":4.1,'
                + '"fromCity":"Chennai","toCity":"Tirupati","travelDate":"2099-01-01","departureTime":"09:00","arrivalTime":"17:00",'
                + '"durationLabel":"8h 00m","boardingPoint":"Chennai Central Bus Stand","droppingPoint":"Tirupati Main Bus Depot","fare":1450,"totalSeats":40,"availableSeats":15},'
                + '"seatNumbers":["2A"],'
                + '"seats":[{"number":"2A","deck":null,"category":"seater","fare":1450}],'
                + '"passengers":[{"seatNumber":"2A","name":"Jane Doe","age":30,"gender":"Female","email":"jane@example.com","phone":"9876543210"}],'
                + '"contactEmail":"jane@example.com","contactPhone":"9876543210","totalAmount":1450,'
                + '"cancelledAt":null,"cancellationReason":null,"refundAmount":null'
                + '}';
        }

        private String cancelledBookingJson() {
            return '{'
                + '"bookingReferenceId":"' + REF + '","pnr":"' + PNR + '","status":"Cancelled","createdAt":"2026-09-09T12:35:47Z",'
                + '"trip":{"tripId":"TRIP-OLD","operator":"Greenline Travels","busName":"Greenline Travels 100","busType":"AC Sleeper","rating":4.3,'
                + '"fromCity":"Chennai","toCity":"Tirupati","travelDate":"2099-01-01","departureTime":"06:00","arrivalTime":"14:00",'
                + '"durationLabel":"8h 30m","boardingPoint":"Chennai Central Bus Stand","droppingPoint":"Tirupati Main Bus Depot","fare":1272,"totalSeats":36,"availableSeats":21},'
                + '"seatNumbers":[],'
                + '"seats":[],'
                + '"passengers":[{"seatNumber":"L1C","name":"Jane Doe","age":30,"gender":"Female","email":"jane@example.com","phone":"9876543210"}],'
                + '"contactEmail":"jane@example.com","contactPhone":"9876543210","totalAmount":1372,'
                + '"cancelledAt":"2026-09-11T10:00:00Z","cancellationReason":"Change of plans","refundAmount":1372'
                + '}';
        }

        private String searchResultsJson() {
            return '['
                + '{"tripId":"TRIP-OLD","operator":"Greenline Travels","busName":"Greenline Travels 100","busType":"AC Sleeper","rating":4.3,'
                + '"fromCity":"Chennai","toCity":"Tirupati","travelDate":"2099-01-01","departureTime":"06:00","arrivalTime":"14:00",'
                + '"durationLabel":"8h 30m","boardingPoint":"Chennai Central Bus Stand","droppingPoint":"Tirupati Main Bus Depot","fare":1272,"totalSeats":36,"availableSeats":20},'
                + '{"tripId":"TRIP-ALT","operator":"Metro Express","busName":"Metro Express 200","busType":"AC Seater","rating":4.1,'
                + '"fromCity":"Chennai","toCity":"Tirupati","travelDate":"2099-01-01","departureTime":"09:00","arrivalTime":"17:00",'
                + '"durationLabel":"8h 00m","boardingPoint":"Chennai Central Bus Stand","droppingPoint":"Tirupati Main Bus Depot","fare":1450,"totalSeats":40,"availableSeats":15}'
                + ']';
        }
    }
}
