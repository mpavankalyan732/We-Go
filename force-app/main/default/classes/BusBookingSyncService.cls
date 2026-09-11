/**
 * Upserts a booking (and its trip/bus/seats/passengers/payment) into Salesforce
 * from the JSON shape returned by the external Bus API's booking endpoints.
 * Called by BusBookingSyncResource, which the Bus API POSTs to right after a
 * booking is created (see bus-booking-app/api/src/services/salesforceSync.js).
 */
public without sharing class BusBookingSyncService {
    public class TripPayload {
        public String tripId;
        public String operator;
        public String busName;
        public String busType;
        public Decimal rating;
        public String fromCity;
        public String toCity;
        public String travelDate;
        public String departureTime;
        public String arrivalTime;
        public String durationLabel;
        public String boardingPoint;
        public String droppingPoint;
        public Decimal fare;
        public Integer totalSeats;
    }

    // Seats are deliberately NOT a typed field on BookingPayload: their JSON
    // key "number" is a reserved identifier in Apex, and typed JSON.deserialize
    // also doesn't support Object/List<Object> fields at all. They're pulled
    // out separately via JSON.deserializeUntyped() in syncBooking() instead —
    // typed deserialize just ignores the "seats" property it doesn't know about.

    public class PassengerPayload {
        public String seatNumber;
        public String name;
        public Integer age;
        public String gender;
        public String email;
        public String phone;
    }

    public class BookingPayload {
        public String bookingReferenceId;
        public String pnr;
        public String status;
        public TripPayload trip;
        public List<PassengerPayload> passengers;
        public String contactEmail;
        public String contactPhone;
        public Decimal totalAmount;
    }

    public class BusBookingSyncException extends Exception {}

    public static Id syncBooking(String jsonBody) {
        BookingPayload payload = (BookingPayload) JSON.deserialize(jsonBody, BookingPayload.class);
        if (String.isBlank(payload.bookingReferenceId)) {
            throw new BusBookingSyncException('bookingReferenceId is required');
        }
        if (payload.trip == null || String.isBlank(payload.trip.tripId)) {
            throw new BusBookingSyncException('trip.tripId is required');
        }

        Bus__c bus = upsertBus(payload.trip);
        Bus_Trip__c trip = upsertTrip(payload.trip, bus.Id);
        Bus_Booking__c booking = upsertBooking(payload, trip.Id);

        // Idempotent: a retried sync for the same booking shouldn't duplicate children.
        List<Bus_Seat__c> already = [SELECT Id FROM Bus_Seat__c WHERE Bus_Booking__c = :booking.Id LIMIT 1];
        if (already.isEmpty()) {
            Map<String, Object> rawPayload = (Map<String, Object>) JSON.deserializeUntyped(jsonBody);
            List<Object> rawSeats = (List<Object>) rawPayload.get('seats');
            Map<String, Id> seatIdByNumber = insertSeats(rawSeats, booking.Id, trip.Id);
            insertPassengers(payload.passengers, booking.Id, seatIdByNumber);
            insertTransaction(payload, booking.Id);
        }

        return booking.Id;
    }

    // Bus__c.External_Bus_Id__c is not flagged as a true External ID field in
    // this org, so native `upsert ... External_Bus_Id__c` isn't available —
    // query-then-insert/update instead.
    // Public: also reused by BusRescheduleAction to upsert the bus/trip a
    // booking is being moved to.
    public static Bus__c upsertBus(TripPayload trip) {
        String externalBusId = trip.busName;
        List<Bus__c> existing = [SELECT Id FROM Bus__c WHERE External_Bus_Id__c = :externalBusId LIMIT 1];
        Bus__c bus = existing.isEmpty() ? new Bus__c(External_Bus_Id__c = externalBusId) : existing[0];
        bus.Operator_Name__c = trip.operator;
        bus.Bus_Type__c = trip.busType;
        bus.Rating__c = trip.rating;
        bus.Total_Seat__c = trip.totalSeats;
        upsert bus;
        return bus;
    }

    public static Bus_Trip__c upsertTrip(TripPayload trip, Id busId) {
        Bus_Trip__c t = new Bus_Trip__c(
            External_Trip_Id__c = trip.tripId,
            Bus__c = busId,
            Origin_City__c = trip.fromCity,
            Destination_City__c = trip.toCity,
            Travel_Date__c = Date.valueOf(trip.travelDate),
            Departure_Time__c = parseTime(trip.departureTime),
            Arrival_Time__c = parseTime(trip.arrivalTime),
            Boarding_Point__c = trip.boardingPoint,
            Dropping_Point__c = trip.droppingPoint,
            Base_Fare__c = trip.fare,
            Duration_Label__c = trip.durationLabel
        );
        upsert t External_Trip_Id__c;
        return t;
    }

    private static Bus_Booking__c upsertBooking(BookingPayload payload, Id tripId) {
        Bus_Booking__c b = new Bus_Booking__c(
            Booking_Reference_Id__c = payload.bookingReferenceId,
            PNR__c = payload.pnr,
            Bus_Trip__c = tripId,
            Booking_Status__c = payload.status,
            Total_Amount__c = payload.totalAmount,
            Primary_Contact_Email__c = payload.contactEmail,
            Primary_Contact_Phone__c = payload.contactPhone,
            Source_Channel__c = 'Website'
        );
        upsert b Booking_Reference_Id__c;
        return b;
    }

    // NOTE: Bus_Seat__c.Seat_Number__c is currently a formula (= Name, an
    // auto-number), so the real seat position ("L1A" etc.) can't be written
    // to it from here — Deck__c/Seat_Category__c/Fare__c are set instead.
    // Fix: change Seat_Number__c to a plain editable Text field if the real
    // seat position needs to show on this object.
    private static Map<String, Id> insertSeats(List<Object> rawSeats, Id bookingId, Id tripId) {
        List<Bus_Seat__c> toInsert = new List<Bus_Seat__c>();
        List<String> seatNumbers = new List<String>();

        for (Object rawSeat : rawSeats) {
            Map<String, Object> seat = (Map<String, Object>) rawSeat;
            seatNumbers.add((String) seat.get('number'));
            toInsert.add(new Bus_Seat__c(
                Bus_Booking__c = bookingId,
                Bus_Trip__c = tripId,
                Deck__c = (String) seat.get('deck'), // Bus API already sends "Lower"/"Upper" — matches the picklist as-is
                Seat_Category__c = mapSeatCategory((String) seat.get('category')),
                Fare__c = (Decimal) seat.get('fare')
            ));
        }
        insert toInsert;

        Map<String, Id> seatIdByNumber = new Map<String, Id>();
        for (Integer i = 0; i < seatNumbers.size(); i++) {
            seatIdByNumber.put(seatNumbers[i], toInsert[i].Id);
        }
        return seatIdByNumber;
    }

    private static void insertPassengers(List<PassengerPayload> passengers, Id bookingId, Map<String, Id> seatIdByNumber) {
        List<Booking_Passenger__c> toInsert = new List<Booking_Passenger__c>();
        for (Integer i = 0; i < passengers.size(); i++) {
            PassengerPayload p = passengers[i];
            toInsert.add(new Booking_Passenger__c(
                Name = p.name,
                Bus_Booking__c = bookingId,
                Bus_Seat__c = seatIdByNumber.get(p.seatNumber),
                Full_Name__c = p.name,
                Age__c = p.age,
                Gender__c = p.gender,
                Email__c = p.email,
                Phone__c = p.phone,
                Is_Primary_Contact__c = (i == 0)
            ));
        }
        insert toInsert;
    }

    private static void insertTransaction(BookingPayload payload, Id bookingId) {
        insert new Booking_Transaction__c(
            Bus_Booking__c = bookingId,
            Transaction_Type__c = 'Payment',
            Amount__c = payload.totalAmount,
            Payment_Method__c = 'Card',
            Payment_Status__c = 'Success',
            Transaction_Date__c = System.now()
        );
    }

    // Translates the Bus API's internal seat category codes to the
    // Seat_Category__c picklist labels. Expects the picklist to read exactly
    // "Single Berth" | "Double Berth" | "Seater" — fix the org's current
    // picklist values (currently mistyped) to match if this starts failing.
    public static String mapSeatCategory(String rawCategory) {
        if (rawCategory == 'single-berth') return 'Single Berth';
        if (rawCategory == 'double-berth') return 'Double Berth';
        if (rawCategory == 'seater') return 'Seater';
        return rawCategory;
    }

    public static Time parseTime(String hhmm) {
        List<String> parts = hhmm.split(':');
        return Time.newInstance(Integer.valueOf(parts[0]), Integer.valueOf(parts[1]), 0, 0);
    }
}
