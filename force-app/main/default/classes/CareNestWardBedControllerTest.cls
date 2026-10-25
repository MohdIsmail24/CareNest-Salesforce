@IsTest
private class CareNestWardBedControllerTest {

    @TestSetup
    static void setupTestData() {
        Ward__c ward = new Ward__c(
            Name = 'Ward Bed Test Ward',
            Ward_Code__c = 'CN-WRD-WB',
            Ward_Type__c = 'ICU',
            Capacity__c = 5,
            Floor__c = '2'
        );
        insert ward;

        List<Bed__c> beds = new List<Bed__c>{
            new Bed__c(Name = 'Bed WB-1', Bed_Code__c = 'WB-01', Ward__c = ward.Id, Status__c = 'Available'),
            new Bed__c(Name = 'Bed WB-2', Bed_Code__c = 'WB-02', Ward__c = ward.Id, Status__c = 'Available')
        };
        insert beds;

        Doctor__c doc = new Doctor__c(
            Name = 'Dr. Test WardBed',
            Department__c = 'General Medicine',
            Registration_No__c = 'REG-WB-01',
            Is_Active__c = true,
            Consultation_Fee__c = 600
        );
        insert doc;

        Contact patient = new Contact(LastName = 'WBPatient');
        insert patient;

        Admission__c adm = new Admission__c(
            Contact__c = patient.Id,
            Bed__c = beds[1].Id,
            Attending_Doctor__c = doc.Id,
            Admission_Date__c = System.now(),
            Status__c = 'Admitted'
        );
        insert adm;
    }

    @IsTest
    static void testGetWardsWithBedsAll() {
        Test.startTest();
        List<CareNestWardBedController.WardWithBedsDto> results = CareNestWardBedController.getWardsWithBeds('All', 'All');
        Test.stopTest();

        Assert.isNotNull(results, 'Results should not be null');
        Assert.isFalse(results.isEmpty(), 'Should return wards with beds');
    }

    @IsTest
    static void testGetWardsWithBedsFiltered() {
        Ward__c w = [SELECT Id FROM Ward__c WHERE Ward_Code__c = 'CN-WRD-WB' LIMIT 1];
        Test.startTest();
        List<CareNestWardBedController.WardWithBedsDto> results = CareNestWardBedController.getWardsWithBeds(w.Id, 'Available');
        Test.stopTest();

        Assert.isNotNull(results, 'Filtered results should not be null');
        Assert.areEqual(1, results.size(), 'Should find 1 ward');
        Assert.areEqual(1, results[0].availableBeds, 'Should find 1 available bed');
    }
}
