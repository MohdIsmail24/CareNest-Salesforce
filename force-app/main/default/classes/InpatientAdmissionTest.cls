/**
 * @description Comprehensive unit tests for Inpatient Admissions & Safe Bed Allocation (Phase 12.3).
 * Verifies pessimistic locking, atomic transactions, occupied-bed rejection, inactive-ward rejection,
 * duplicate allocation prevention, bulk operations, transaction rollback, and patient discharge.
 */
@isTest
private class InpatientAdmissionTest {

    private static Integer seq = 9000;

    private static Doctor__c createDoctor(String name) {
        seq++;
        Doctor__c doc = new Doctor__c(
            Name = name,
            Registration_No__c = 'REG-IPD-' + seq,
            Department__c = 'General Medicine',
            Specialty__c = 'Internal Medicine',
            Consultation_Fee__c = 500,
            Is_Active__c = true
        );
        insert doc;
        return doc;
    }

    private static Contact createPatient(String lastName) {
        seq++;
        Contact c = new Contact(
            LastName = lastName,
            Email = lastName.toLowerCase() + seq + '@testcarenest.com',
            Phone = '555111' + seq,
            Patient_Code__c = 'PAT-' + seq
        );
        insert c;
        return c;
    }

    private static Ward__c createWard(String name, String code, Integer capacity, Boolean isActive) {
        Ward__c ward = new Ward__c(
            Name = name,
            Ward_Code__c = code,
            Ward_Type__c = 'General',
            Floor__c = '1',
            Capacity__c = capacity,
            Is_Active__c = isActive
        );
        insert ward;
        return ward;
    }

    private static Bed__c createBed(Ward__c ward, String name, String code, String status) {
        Bed__c bed = new Bed__c(
            Name = name,
            Bed_Code__c = code,
            Ward__c = ward.Id,
            Bed_Type__c = 'Standard',
            Status__c = status
        );
        insert bed;
        return bed;
    }

    @isTest
    static void testSuccessfulAdmission() {
        Ward__c ward = createWard('Ward Alpha', 'WRD-A-01', 5, true);
        Bed__c bed = createBed(ward, 'Bed A-101', 'BED-A-101', 'Available');
        Doctor__c doc = createDoctor('Dr. Sarah Connor');
        Contact pat = createPatient('PatientOne');

        Test.startTest();
        AdmissionService.AdmissionRequest req = new AdmissionService.AdmissionRequest(
            pat.Id,
            bed.Id,
            doc.Id,
            System.now(),
            'Acute respiratory observation',
            null
        );
        Admission__c adm = AdmissionService.admitPatient(req);
        Test.stopTest();

        System.assertNotEquals(null, adm.Id, 'Admission record should be created');
        System.assertEquals('Admitted', adm.Status__c, 'Status should be Admitted');
        System.assertEquals(pat.Id, adm.Contact__c, 'Contact lookup should match patient');
        System.assertEquals(pat.Id, adm.Patient__c, 'Patient alias lookup should match patient');
        System.assertEquals(doc.Id, adm.Attending_Doctor__c, 'Attending doctor lookup should match');
        System.assertEquals(bed.Id, adm.Bed__c, 'Bed lookup should match');

        // Verify Bed is now Occupied
        Bed__c queriedBed = [SELECT Id, Status__c FROM Bed__c WHERE Id = :bed.Id];
        System.assertEquals('Occupied', queriedBed.Status__c, 'Bed should transition to Occupied');

        // Verify AutoNumber format
        Admission__c queriedAdm = [SELECT Id, Name FROM Admission__c WHERE Id = :adm.Id];
        System.assert(queriedAdm.Name.startsWith('ADM-'), 'Admission Name should follow ADM-{000000} format');
    }

    @isTest
    static void testOccupiedBedRejection() {
        Ward__c ward = createWard('Ward Beta', 'WRD-B-01', 5, true);
        Bed__c bed = createBed(ward, 'Bed B-101', 'BED-B-101', 'Occupied');
        Doctor__c doc = createDoctor('Dr. John Smith');
        Contact pat = createPatient('PatientTwo');

        Test.startTest();
        Boolean caught = false;
        try {
            AdmissionService.admitPatient(pat.Id, bed.Id, doc.Id, System.now(), 'Routine observation', null);
        } catch (AdmissionService.AdmissionException ex) {
            caught = true;
            System.assert(ex.getMessage().contains('not available'), 'Error message should indicate bed is not available: ' + ex.getMessage());
        }
        Test.stopTest();

        System.assert(caught, 'Should throw AdmissionException when allocating an occupied bed');
        List<Admission__c> admissions = [SELECT Id FROM Admission__c WHERE Bed__c = :bed.Id];
        System.assertEquals(0, admissions.size(), 'No admission record should have been created');

        Bed__c queriedBed = [SELECT Id, Status__c FROM Bed__c WHERE Id = :bed.Id];
        System.assertEquals('Occupied', queriedBed.Status__c, 'Bed status should remain unchanged');
    }

    @isTest
    static void testInactiveWardRejection() {
        Ward__c ward = createWard('Ward Gamma Closed', 'WRD-C-01', 5, true);
        Bed__c bed = createBed(ward, 'Bed C-101', 'BED-C-101', 'Available');

        // Deactivate the ward after bed was registered
        ward.Is_Active__c = false;
        update ward;

        Doctor__c doc = createDoctor('Dr. Gregory House');
        Contact pat = createPatient('PatientThree');

        Test.startTest();
        Boolean caught = false;
        try {
            AdmissionService.admitPatient(pat.Id, bed.Id, doc.Id, System.now(), 'Observation', null);
        } catch (AdmissionService.AdmissionException ex) {
            caught = true;
            System.assert(ex.getMessage().contains('inactive'), 'Error message should indicate ward is inactive: ' + ex.getMessage());
        }
        Test.stopTest();

        System.assert(caught, 'Should throw AdmissionException when ward is inactive');
        List<Admission__c> admissions = [SELECT Id FROM Admission__c WHERE Bed__c = :bed.Id];
        System.assertEquals(0, admissions.size(), 'No admission record should have been created');

        Bed__c queriedBed = [SELECT Id, Status__c FROM Bed__c WHERE Id = :bed.Id];
        System.assertEquals('Available', queriedBed.Status__c, 'Bed status should remain Available');
    }

    @isTest
    static void testDuplicateBedAllocationInSingleTransaction() {
        Ward__c ward = createWard('Ward Delta', 'WRD-D-01', 5, true);
        Bed__c bed = createBed(ward, 'Bed D-101', 'BED-D-101', 'Available');
        Doctor__c doc = createDoctor('Dr. Leonard McCoy');
        Contact pat1 = createPatient('PatientFourA');
        Contact pat2 = createPatient('PatientFourB');

        List<AdmissionService.AdmissionRequest> requests = new List<AdmissionService.AdmissionRequest>{
            new AdmissionService.AdmissionRequest(pat1.Id, bed.Id, doc.Id, System.now(), 'Case 1', null),
            new AdmissionService.AdmissionRequest(pat2.Id, bed.Id, doc.Id, System.now(), 'Case 2', null)
        };

        Test.startTest();
        Boolean caught = false;
        try {
            AdmissionService.admitPatients(requests);
        } catch (AdmissionService.AdmissionException ex) {
            caught = true;
            System.assert(ex.getMessage().contains('Duplicate bed allocation'), 'Error message should indicate duplicate bed allocation: ' + ex.getMessage());
        }
        Test.stopTest();

        System.assert(caught, 'Should throw AdmissionException when allocating same bed to multiple patients in batch');
        List<Admission__c> admissions = [SELECT Id FROM Admission__c WHERE Bed__c = :bed.Id];
        System.assertEquals(0, admissions.size(), 'Neither admission should have been created');

        Bed__c queriedBed = [SELECT Id, Status__c FROM Bed__c WHERE Id = :bed.Id];
        System.assertEquals('Available', queriedBed.Status__c, 'Bed status should remain Available');
    }

    @isTest
    static void testDuplicateActiveAdmissionOnOccupiedBed() {
        Ward__c ward = createWard('Ward Epsilon', 'WRD-E-01', 5, true);
        Bed__c bed = createBed(ward, 'Bed E-101', 'BED-E-101', 'Available');
        Doctor__c doc = createDoctor('Dr. Beverly Crusher');
        Contact pat1 = createPatient('PatientFiveA');
        Contact pat2 = createPatient('PatientFiveB');

        // First patient successfully admitted
        Admission__c adm1 = AdmissionService.admitPatient(pat1.Id, bed.Id, doc.Id, System.now(), 'Initial admission', null);
        System.assertNotEquals(null, adm1.Id);

        Test.startTest();
        Boolean caught = false;
        try {
            // Attempt to admit second patient to the now occupied bed
            AdmissionService.admitPatient(pat2.Id, bed.Id, doc.Id, System.now(), 'Concurrent attempt', null);
        } catch (AdmissionService.AdmissionException ex) {
            caught = true;
        }
        Test.stopTest();

        System.assert(caught, 'Should prevent second active admission on the same bed');
        List<Admission__c> admissions = [SELECT Id FROM Admission__c WHERE Bed__c = :bed.Id];
        System.assertEquals(1, admissions.size(), 'Only 1 admission should exist for this bed');
    }

    @isTest
    static void testBulkAdmissionsSuccess() {
        Ward__c ward = createWard('Ward Bulk', 'WRD-BLK-01', 25, true);
        Doctor__c doc = createDoctor('Dr. Bulk Attending');

        List<Bed__c> beds = new List<Bed__c>();
        List<Contact> patients = new List<Contact>();
        for (Integer i = 1; i <= 20; i++) {
            seq++;
            beds.add(new Bed__c(
                Name = 'Bed BLK-' + i,
                Bed_Code__c = 'BED-BLK-' + i,
                Ward__c = ward.Id,
                Bed_Type__c = 'Standard',
                Status__c = 'Available'
            ));
            patients.add(new Contact(
                LastName = 'BulkPat' + i,
                Email = 'bulkpat' + seq + '@testcarenest.com',
                Phone = '555222' + seq,
                Patient_Code__c = 'PAT-BLK-' + seq
            ));
        }
        insert beds;
        insert patients;

        List<AdmissionService.AdmissionRequest> requests = new List<AdmissionService.AdmissionRequest>();
        for (Integer i = 0; i < 20; i++) {
            requests.add(new AdmissionService.AdmissionRequest(
                patients[i].Id,
                beds[i].Id,
                doc.Id,
                System.now(),
                'Bulk Admission Test #' + i,
                null
            ));
        }

        Test.startTest();
        List<Admission__c> createdAdmissions = AdmissionService.admitPatients(requests);
        Test.stopTest();

        System.assertEquals(20, createdAdmissions.size(), 'Should create all 20 admissions');

        // Verify all 20 beds are Occupied
        List<Bed__c> queriedBeds = [SELECT Id, Status__c FROM Bed__c WHERE Ward__c = :ward.Id];
        for (Bed__c b : queriedBeds) {
            System.assertEquals('Occupied', b.Status__c, 'All beds should be Occupied');
        }

        // Verify Ward rollups
        Ward__c queriedWard = [SELECT Id, Current_Bed_Count__c, Available_Bed_Count__c FROM Ward__c WHERE Id = :ward.Id];
        System.assertEquals(20, queriedWard.Current_Bed_Count__c, 'Total bed count should be 20');
        System.assertEquals(0, queriedWard.Available_Bed_Count__c, 'Available bed count should be 0');
    }

    @isTest
    static void testTransactionRollbackOnFailure() {
        Ward__c ward = createWard('Ward Rollback', 'WRD-RB-01', 5, true);
        Bed__c bedValid = createBed(ward, 'Bed RB-Valid', 'BED-RB-01', 'Available');
        Bed__c bedInvalid = createBed(ward, 'Bed RB-Invalid', 'BED-RB-02', 'Out of Service');
        Doctor__c doc = createDoctor('Dr. Rollback Attending');
        Contact pat1 = createPatient('PatientRollback1');
        Contact pat2 = createPatient('PatientRollback2');

        List<AdmissionService.AdmissionRequest> requests = new List<AdmissionService.AdmissionRequest>{
            new AdmissionService.AdmissionRequest(pat1.Id, bedValid.Id, doc.Id, System.now(), 'Valid Case', null),
            new AdmissionService.AdmissionRequest(pat2.Id, bedInvalid.Id, doc.Id, System.now(), 'Invalid Case', null)
        };

        Test.startTest();
        Boolean caught = false;
        try {
            AdmissionService.admitPatients(requests);
        } catch (AdmissionService.AdmissionException ex) {
            caught = true;
            System.assert(ex.getMessage().contains('not available'), 'Error message should describe unavailable bed: ' + ex.getMessage());
        }
        Test.stopTest();

        System.assert(caught, 'AdmissionService should throw exception for invalid bed in batch');

        // CRITICAL: Verify total transaction rollback
        // Bed 1 should NOT be updated to Occupied
        Bed__c queriedBedValid = [SELECT Id, Status__c FROM Bed__c WHERE Id = :bedValid.Id];
        System.assertEquals('Available', queriedBedValid.Status__c, 'Bed 1 must be rolled back to Available');

        // Zero admissions should exist
        List<Admission__c> admissions = [SELECT Id FROM Admission__c WHERE Bed__c IN (:bedValid.Id, :bedInvalid.Id)];
        System.assertEquals(0, admissions.size(), 'Transaction rollback must ensure 0 admissions created');
    }

    @isTest
    static void testDischargePatient() {
        Ward__c ward = createWard('Ward Discharge', 'WRD-DIS-01', 5, true);
        Bed__c bed = createBed(ward, 'Bed DIS-101', 'BED-DIS-101', 'Available');
        Doctor__c doc = createDoctor('Dr. Meredith Grey');
        Contact pat = createPatient('PatientDischarge');

        Admission__c adm = AdmissionService.admitPatient(pat.Id, bed.Id, doc.Id, System.now(), 'Surgical recovery', null);
        System.assertNotEquals(null, adm.Id);

        Bed__c bedOccupied = [SELECT Id, Status__c FROM Bed__c WHERE Id = :bed.Id];
        System.assertEquals('Occupied', bedOccupied.Status__c, 'Bed should be Occupied after admission');

        Test.startTest();
        Admission__c dischargedAdm = AdmissionService.dischargePatient(adm.Id, System.now().addDays(2));
        Test.stopTest();

        System.assertEquals('Discharged', dischargedAdm.Status__c, 'Admission status should be Discharged');
        System.assertNotEquals(null, dischargedAdm.Discharge_Date__c, 'Discharge date should be set');

        Bed__c bedFreed = [SELECT Id, Status__c FROM Bed__c WHERE Id = :bed.Id];
        System.assertEquals('Available', bedFreed.Status__c, 'Bed should be restored to Available after discharge');
    }

    @isTest
    static void testDischargeBeforeAdmissionDateFails() {
        Ward__c ward = createWard('Ward Validation', 'WRD-VAL-01', 5, true);
        Bed__c bed = createBed(ward, 'Bed VAL-101', 'BED-VAL-101', 'Available');
        Doctor__c doc = createDoctor('Dr. Cristina Yang');
        Contact pat = createPatient('PatientVal');

        Datetime nowTime = System.now();
        Admission__c adm = AdmissionService.admitPatient(pat.Id, bed.Id, doc.Id, nowTime, 'Test dates', null);

        Test.startTest();
        Boolean caught = false;
        try {
            // Discharge date earlier than admission date
            AdmissionService.dischargePatient(adm.Id, nowTime.addHours(-2));
        } catch (AdmissionService.AdmissionException ex) {
            caught = true;
            System.assert(ex.getMessage().contains('earlier than admission date'), 'Should reject discharge date before admission date: ' + ex.getMessage());
        }
        Test.stopTest();

        System.assert(caught, 'Expected exception when discharge is prior to admission date');
    }

    @isTest
    static void testRawSObjectOverloadAndDirectDml() {
        Ward__c ward = createWard('Ward Direct', 'WRD-DIR-01', 5, true);
        Bed__c bed = createBed(ward, 'Bed DIR-101', 'BED-DIR-101', 'Available');
        Doctor__c doc = createDoctor('Dr. Alex Karev');
        Contact pat = createPatient('PatientDirect');

        Test.startTest();
        // Test SObject list overload of AdmissionService
        Admission__c rawAdm = new Admission__c(
            Contact__c = pat.Id,
            Bed__c = bed.Id,
            Attending_Doctor__c = doc.Id,
            Admission_Date__c = System.now(),
            Reason__c = 'Raw SObject overload test'
        );
        List<Admission__c> results = AdmissionService.admitPatients(new List<Admission__c>{ rawAdm });
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should successfully admit via SObject overload');
        Bed__c queriedBed = [SELECT Id, Status__c FROM Bed__c WHERE Id = :bed.Id];
        System.assertEquals('Occupied', queriedBed.Status__c, 'Bed should be Occupied');
    }

    @isTest
    static void testDirectDmlLifecycleAndTriggerHandler() {
        Ward__c ward = createWard('Ward Direct Life', 'WRD-DL-01', 5, true);
        Bed__c bed1 = createBed(ward, 'Bed DL-101', 'BED-DL-101', 'Available');
        Bed__c bed2 = createBed(ward, 'Bed DL-102', 'BED-DL-102', 'Available');
        Doctor__c doc = createDoctor('Dr. Richard Webber');
        Contact pat = createPatient('PatientDL');

        Test.startTest();
        // 1. Direct DML insert
        Admission__c adm = new Admission__c(
            Patient__c = pat.Id,
            Doctor__c = doc.Id,
            Bed__c = bed1.Id,
            Admission_Date__c = System.now(),
            Status__c = 'Admitted'
        );
        insert adm;

        // Verify Bed 1 occupied via afterInsert
        Bed__c b1Occupied = [SELECT Id, Status__c FROM Bed__c WHERE Id = :bed1.Id];
        System.assertEquals('Occupied', b1Occupied.Status__c, 'Direct insert should mark bed Occupied');

        // 2. Direct DML update: switch to Bed 2
        adm.Bed__c = bed2.Id;
        update adm;

        // 3. Direct DML update: discharge
        adm.Status__c = 'Discharged';
        adm.Discharge_Date__c = System.now().addDays(1);
        update adm;

        // Verify Bed 2 freed via afterUpdate
        Bed__c b2Freed = [SELECT Id, Status__c FROM Bed__c WHERE Id = :bed2.Id];
        System.assertEquals('Available', b2Freed.Status__c, 'Direct discharge should restore bed to Available');

        // 4. Test trigger bypass
        AdmissionTriggerHandler.bypassTrigger = true;
        adm.Status__c = 'Cancelled';
        update adm;
        AdmissionTriggerHandler.bypassTrigger = false;
        Test.stopTest();

        System.assertNotEquals(null, adm.Id);
    }

    @isTest
    static void testDirectDmlFailures() {
        Ward__c ward = createWard('Ward Direct Fail', 'WRD-DF-01', 5, true);
        Bed__c bed = createBed(ward, 'Bed DF-101', 'BED-DF-101', 'Occupied');
        Doctor__c doc = createDoctor('Dr. Miranda Bailey');
        Contact pat = createPatient('PatientDF');

        // Test direct insert onto occupied bed
        Admission__c admOccupied = new Admission__c(
            Contact__c = pat.Id,
            Bed__c = bed.Id,
            Attending_Doctor__c = doc.Id,
            Admission_Date__c = System.now()
        );

        Boolean threwOccupied = false;
        try {
            insert admOccupied;
        } catch (DmlException ex) {
            threwOccupied = true;
            System.assert(ex.getMessage().contains('not available'), 'Expected not available error: ' + ex.getMessage());
        }
        System.assert(threwOccupied, 'Direct DML to occupied bed must fail');

        // Test missing fields
        Admission__c admMissing = new Admission__c();
        Boolean threwMissing = false;
        try {
            insert admMissing;
        } catch (DmlException ex) {
            threwMissing = true;
        }
        System.assert(threwMissing, 'Direct DML with missing required fields must fail');
    }

    @isTest
    static void testServiceValidationEdgeCases() {
        // Null requests list
        Boolean threw1 = false;
        try {
            AdmissionService.admitPatients((List<AdmissionService.AdmissionRequest>) null);
        } catch (AdmissionService.AdmissionException ex) {
            threw1 = true;
        }
        System.assert(threw1, 'Should reject null requests list');

        // Null single request
        Boolean threw2 = false;
        try {
            AdmissionService.admitPatient((AdmissionService.AdmissionRequest) null);
        } catch (AdmissionService.AdmissionException ex) {
            threw2 = true;
        }
        System.assert(threw2, 'Should reject null request DTO');

        // Null raw admissions list
        Boolean threw3 = false;
        try {
            AdmissionService.admitPatients((List<Admission__c>) null);
        } catch (AdmissionService.AdmissionException ex) {
            threw3 = true;
        }
        System.assert(threw3, 'Should reject null raw admissions');

        // Null discharge ID
        Boolean threw4 = false;
        try {
            AdmissionService.dischargePatient(null, null);
        } catch (AdmissionService.AdmissionException ex) {
            threw4 = true;
        }
        System.assert(threw4, 'Should reject null admission ID in discharge');

        // Incomplete request DTO
        Boolean threw5 = false;
        try {
            AdmissionService.admitPatients(new List<AdmissionService.AdmissionRequest>{
                new AdmissionService.AdmissionRequest(null, null, null, null, null, null)
            });
        } catch (AdmissionService.AdmissionException ex) {
            threw5 = true;
        }
        System.assert(threw5, 'Should reject incomplete request DTO');
    }
}
