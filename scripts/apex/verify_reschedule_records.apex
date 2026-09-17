Bus_Booking__c b = [SELECT Id, Booking_Status__c, Total_Amount__c, Bus_Trip__r.External_Trip_Id__c FROM Bus_Booking__c WHERE Booking_Reference_Id__c = 'BK-PVXZ75'];
System.debug('Booking status: ' + b.Booking_Status__c + ' trip: ' + b.Bus_Trip__r.External_Trip_Id__c + ' amount: ' + b.Total_Amount__c);

List<Bus_Seat__c> seats = [SELECT Deck__c, Seat_Category__c, Fare__c, Bus_Trip__r.External_Trip_Id__c FROM Bus_Seat__c WHERE Bus_Booking__c = :b.Id];
for (Bus_Seat__c s : seats) System.debug('Seat: trip=' + s.Bus_Trip__r.External_Trip_Id__c + ' deck=' + s.Deck__c + ' category=' + s.Seat_Category__c + ' fare=' + s.Fare__c);

List<Booking_Passenger__c> passengers = [SELECT Full_Name__c, Bus_Seat__r.Bus_Trip__r.External_Trip_Id__c FROM Booking_Passenger__c WHERE Bus_Booking__c = :b.Id];
for (Booking_Passenger__c p : passengers) System.debug('Passenger: ' + p.Full_Name__c + ' seat trip=' + p.Bus_Seat__r.Bus_Trip__r.External_Trip_Id__c);

List<Bus_Reschedule__c> history = [SELECT Old_Trip__r.External_Trip_Id__c, New_Trip__r.External_Trip_Id__c, Fare_Difference__c, Requested_Via__c, Status__c FROM Bus_Reschedule__c WHERE Bus_Booking__c = :b.Id ORDER BY CreatedDate DESC LIMIT 1];
for (Bus_Reschedule__c h : history) System.debug('Reschedule history: old=' + h.Old_Trip__r.External_Trip_Id__c + ' new=' + h.New_Trip__r.External_Trip_Id__c + ' diff=' + h.Fare_Difference__c + ' via=' + h.Requested_Via__c + ' status=' + h.Status__c);
