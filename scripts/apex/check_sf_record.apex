List<Bus_Booking__c> bookings = [SELECT Id, Booking_Reference_Id__c, PNR__c, Booking_Status__c, CreatedDate FROM Bus_Booking__c WHERE Booking_Reference_Id__c = 'BK-PVXZ75'];
System.debug('Found in Salesforce: ' + bookings.size());
for (Bus_Booking__c b : bookings) {
    System.debug('PNR: ' + b.PNR__c + ' Status: ' + b.Booking_Status__c + ' Created: ' + b.CreatedDate);
}
