List<Bus_Booking__c> bookings = [
    SELECT Id, Booking_Status__c, Bus_Trip__r.External_Trip_Id__c, Bus_Trip__r.Origin_City__c,
           Bus_Trip__r.Destination_City__c, Bus_Trip__r.Travel_Date__c,
           (SELECT Id FROM Bus_Seats__r)
    FROM Bus_Booking__c WHERE Booking_Reference_Id__c = 'BK-PVXZ75'
];
if (bookings.isEmpty()) {
    System.debug('Booking not found in Salesforce');
} else {
    Bus_Booking__c b = bookings[0];
    System.debug('Status: ' + b.Booking_Status__c + ' Current trip: ' + b.Bus_Trip__r.External_Trip_Id__c
        + ' Route: ' + b.Bus_Trip__r.Origin_City__c + ' -> ' + b.Bus_Trip__r.Destination_City__c
        + ' Date: ' + b.Bus_Trip__r.Travel_Date__c + ' Seats needed: ' + b.Bus_Seats__r.size());

    List<Bus_Trip__c> candidates = [
        SELECT External_Trip_Id__c, Travel_Date__c, Bus__r.Total_Seat__c, Base_Fare__c
        FROM Bus_Trip__c
        WHERE Origin_City__c = :b.Bus_Trip__r.Origin_City__c
          AND Destination_City__c = :b.Bus_Trip__r.Destination_City__c
          AND Id != :b.Bus_Trip__c
        LIMIT 5
    ];
    for (Bus_Trip__c t : candidates) {
        System.debug('Candidate: ' + t.External_Trip_Id__c + ' date=' + t.Travel_Date__c + ' totalSeats=' + t.Bus__r.Total_Seat__c + ' fare=' + t.Base_Fare__c);
    }
}
