// Seed standard hospital wards for Bed Master-Detail allocation
List<Ward__c> wards = new List<Ward__c>{
    new Ward__c(Name = 'General Ward', Ward_Code__c = 'CN-WRD-GW', Capacity__c = 25, Floor__c = '1', Ward_Type__c = 'General', Is_Active__c = true),
    new Ward__c(Name = 'Semi-Private', Ward_Code__c = 'CN-WRD-SP', Capacity__c = 15, Floor__c = '2', Ward_Type__c = 'Semi-Private', Is_Active__c = true),
    new Ward__c(Name = 'Private Room', Ward_Code__c = 'CN-WRD-PR', Capacity__c = 15, Floor__c = '3', Ward_Type__c = 'Private', Is_Active__c = true),
    new Ward__c(Name = 'ICU', Ward_Code__c = 'CN-WRD-ICU', Capacity__c = 10, Floor__c = '2', Ward_Type__c = 'ICU', Is_Active__c = true),
    new Ward__c(Name = 'Paediatric Ward', Ward_Code__c = 'CN-WRD-PW', Capacity__c = 10, Floor__c = '4', Ward_Type__c = 'General', Is_Active__c = true)
};
upsert wards Ward_Code__c;
System.debug('Seeded ' + wards.size() + ' wards successfully.');
