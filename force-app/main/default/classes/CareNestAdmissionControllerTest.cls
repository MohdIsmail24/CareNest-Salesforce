@IsTest
private class CareNestAdmissionControllerTest {

    @TestSetup
    static void setupTestData() {
        Account regAcc = new Account(Name = CareNestAdmissionController.REGISTRY_ACCOUNT_NAME);
        insert regAcc;

        Ward__c ward = new Ward__c(
            Name = 'Admission Test Ward',
            Ward_Code__c = 'CN-WRD-ADM',
            Ward_Type__c = 'General',
            Capacity__c = 10,
            Floor__c = '1'
        );
        insert ward;

        List<Bed__c> beds = new List<Bed__c>{
            new Bed__c(Name = 'Bed ADM-1', Bed_Code__c = 'ADM-01', Ward__c = ward.Id, Status__c = 'Available', Daily_Charge__c = 1500, Floor__c = 1),
            new Bed__c(Name = 'Bed ADM-2', Bed_Code__c = 'ADM-02', Ward__c = ward.Id, Status__c = 'Available', Daily_Charge__c = 1500, Floor__c = 1)
        };
        insert beds;

        Doctor__c doc = new Doctor__c(
            Name = 'Dr. Test Admission',
            Department__c = 'General Medicine',
            Specialty__c = 'Internal Medicine',
            Registration_No__c = 'REG-ADM-01',
            Is_Active__c = true,
            Consultation_Fee__c = 500
        );
        insert doc;

        Appointment_Slot__c slot = new Appointment_Slot__c(
            Doctor__c = doc.Id,
            Slot_Start__c = System.now().addDays(1),
            Mode__c = 'OPD',
            Total_Capacity__c = 10,
            Booked_Count__c = 2
        );
        insert slot;

        Contact patient = new Contact(
            FirstName = 'Aarav',
            LastName = 'AdmPatient',
            Phone = '9998887776',
            Email = 'aarav.adm@example.test',
            Patient_Code__c = 'CN-PAT-00050',
            MC_Is_Patient__c = true
        );
        insert patient;
    }

    @IsTest
    static void testRegisterPatientValid() {
        Test.startTest();
        CareNestAdmissionController.PatientRegistrationResultDto res = CareNestAdmissionController.registerPatient(
            'Kavita',
            'Verma',
            '9876543210',
            'kavita.verma@example.test',
            Date.newInstance(1995, 5, 20),
            false
        );
        Test.stopTest();

        Assert.isTrue(res.isSuccess, 'Patient registration should succeed');
        Assert.isNotNull(res.contactId, 'Created Contact ID should not be null');
        Assert.isTrue(res.patientCode.startsWith('CN-PAT-'), 'Patient Code should follow CN-PAT- format');
        Assert.areEqual('Kavita Verma', res.patientName, 'Patient Name should be populated');

        Contact insertedContact = [SELECT Id, MC_Is_Patient__c, Patient_Code__c FROM Contact WHERE Id = :res.contactId];
        Assert.isTrue(insertedContact.MC_Is_Patient__c, 'MC_Is_Patient__c should be true');
    }

    @IsTest
    static void testRegisterPatientBlankLastName() {
        Boolean caught = false;
        Test.startTest();
        try {
            CareNestAdmissionController.registerPatient('Kavita', '', '9876543210', 'kavita@test.com', null, false);
        } catch (AuraHandledException e) {
            caught = true;
        }
        Test.stopTest();
        Assert.isTrue(caught, 'Should throw exception on blank LastName');
    }

    @IsTest
    static void testRegisterPatientDuplicateDetection() {
        Test.startTest();
        // Exact phone match
        CareNestAdmissionController.PatientRegistrationResultDto dupRes = CareNestAdmissionController.registerPatient(
            'DifferentFirst',
            'AdmPatient',
            '9998887776',
            'newemail@test.com',
            null,
            false
        );
        Test.stopTest();

        Assert.isFalse(dupRes.isSuccess, 'Should not succeed when duplicate phone detected without allowDuplicate');
        Assert.isTrue(dupRes.isDuplicate, 'isDuplicate flag should be true');
        Assert.isNotNull(dupRes.duplicateContactId, 'duplicateContactId should be populated');
    }

    @IsTest
    static void testRegisterPatientAllowDuplicate() {
        Test.startTest();
        CareNestAdmissionController.PatientRegistrationResultDto forcedRes = CareNestAdmissionController.registerPatient(
            'DifferentFirst',
            'AdmPatient',
            '9998887776',
            'newemail@test.com',
            null,
            true
        );
        Test.stopTest();

        Assert.isTrue(forcedRes.isSuccess, 'Should succeed when allowDuplicate is true');
        Assert.isNotNull(forcedRes.contactId);
    }

    @IsTest
    static void testSearchPatientsAcrossFields() {
        Test.startTest();
        List<CareNestAdmissionController.PatientLookupDto> byName = CareNestAdmissionController.searchPatients('AdmPatient');
        List<CareNestAdmissionController.PatientLookupDto> byPhone = CareNestAdmissionController.searchPatients('999888');
        List<CareNestAdmissionController.PatientLookupDto> byCode = CareNestAdmissionController.searchPatients('CN-PAT-00050');
        List<CareNestAdmissionController.PatientLookupDto> emptySearch = CareNestAdmissionController.searchPatients('A');
        Test.stopTest();

        Assert.isFalse(byName.isEmpty(), 'Search by name should return records');
        Assert.isFalse(byPhone.isEmpty(), 'Search by phone should return records');
        Assert.isFalse(byCode.isEmpty(), 'Search by code should return records');
        Assert.isTrue(emptySearch.isEmpty(), 'Short term (< 2 chars) should return empty list');
    }

    @IsTest
    static void testWardAndBedAvailability() {
        Ward__c ward = [SELECT Id FROM Ward__c WHERE Ward_Code__c = 'CN-WRD-ADM' LIMIT 1];

        Test.startTest();
        List<CareNestAdmissionController.WardAvailabilityDto> wards = CareNestAdmissionController.getWardsWithAvailability();
        List<CareNestAdmissionController.SelectOptionDto> beds = CareNestAdmissionController.getAvailableBeds(ward.Id);
        List<CareNestAdmissionController.BedDetailOptionDto> bedDetails = CareNestAdmissionController.getAvailableBedDetails(ward.Id);
        Test.stopTest();

        Assert.isFalse(wards.isEmpty(), 'Wards list should not be empty');
        Assert.areEqual(10, wards[0].plannedCapacity, 'Planned capacity should be 10');
        Assert.areEqual(2, wards[0].totalInstalledBeds, 'Installed beds count should be 2');
        Assert.areEqual(2, wards[0].availableBeds, 'Available beds count should be 2');
        Assert.isTrue(wards[0].isSelectable, 'Ward should be selectable');

        Assert.areEqual(2, beds.size(), 'Should find 2 available beds');
        Assert.areEqual(2, bedDetails.size(), 'Should find 2 bed details');
        Assert.areEqual(1500, bedDetails[0].dailyCharge, 'Daily charge should be 1500');
    }

    @IsTest
    static void testDoctorAvailabilityResolution() {
        Test.startTest();
        List<CareNestAdmissionController.DoctorAvailabilityDto> docs = CareNestAdmissionController.getDoctorsWithAvailability('General Medicine', 'Admission');
        List<CareNestAdmissionController.SelectOptionDto> activeDocs = CareNestAdmissionController.getActiveDoctors();
        List<CareNestAdmissionController.SelectOptionDto> availDocs = CareNestAdmissionController.getAvailableDoctors();
        Test.stopTest();

        Assert.isFalse(docs.isEmpty(), 'Doctors with availability should return records');
        Assert.areEqual('Verified OPD Schedule (1 Open Slots)', docs[0].availabilityStatus);
        Assert.areEqual(1, docs[0].openSlotsCount);
        Assert.isFalse(activeDocs.isEmpty());
        Assert.isFalse(availDocs.isEmpty());
    }

    @IsTest
    static void testAdmitAndDischargeWorkflow() {
        Contact patient = [SELECT Id, Name FROM Contact WHERE LastName = 'AdmPatient' LIMIT 1];
        Doctor__c doc = [SELECT Id FROM Doctor__c WHERE Name = 'Dr. Test Admission' LIMIT 1];
        Bed__c bed = [SELECT Id, Bed_Code__c FROM Bed__c WHERE Bed_Code__c = 'ADM-01' LIMIT 1];

        Test.startTest();
        CareNestAdmissionController.AdmissionActionResultDto admitRes = CareNestAdmissionController.admitPatient(
            patient.Id, bed.Id, doc.Id, 'Planned', 'Observation of hypertension'
        );
        Assert.isTrue(admitRes.isSuccess, 'Admission should succeed');
        Assert.isNotNull(admitRes.admissionId, 'Admission ID should not be null');
        Assert.isTrue(admitRes.admissionNumber.startsWith('ADM-'), 'Real admission number should start with ADM-');

        // Verify Bed is now Occupied
        Bed__c occupiedBed = [SELECT Status__c FROM Bed__c WHERE Id = :bed.Id];
        Assert.areEqual('Occupied', occupiedBed.Status__c, 'Bed status must transition to Occupied');

        // Test Concurrency / Double-booking attempt on same bed
        CareNestAdmissionController.AdmissionActionResultDto conflictRes = CareNestAdmissionController.admitPatient(
            patient.Id, bed.Id, doc.Id, 'Emergency', 'Second patient conflict'
        );
        Assert.isFalse(conflictRes.isSuccess, 'Double booking occupied bed should fail');

        // Discharge
        CareNestAdmissionController.AdmissionActionResultDto dischargeRes = CareNestAdmissionController.dischargePatient(
            admitRes.admissionId, 'Patient stable and ambulating well', 'Home'
        );
        Assert.isTrue(dischargeRes.isSuccess, 'Discharge should succeed');
        Test.stopTest();

        Bed__c releasedBed = [SELECT Status__c FROM Bed__c WHERE Id = :bed.Id];
        Assert.areEqual('Available', releasedBed.Status__c, 'Bed status must transition back to Available');
    }

    @IsTest
    static void testAdmitValidationErrors() {
        Doctor__c doc = [SELECT Id FROM Doctor__c WHERE Name = 'Dr. Test Admission' LIMIT 1];
        Bed__c bed = [SELECT Id FROM Bed__c WHERE Bed_Code__c = 'ADM-02' LIMIT 1];

        Boolean nullPatientCaught = false;
        try {
            CareNestAdmissionController.admitPatientRecord(null, bed.Id, doc.Id, 'Reason', 'Emergency');
        } catch (AuraHandledException e) {
            nullPatientCaught = true;
        }
        Assert.isTrue(nullPatientCaught, 'Null patient should be rejected');

        Boolean nullBedCaught = false;
        try {
            CareNestAdmissionController.admitPatientRecord(doc.Id, null, doc.Id, 'Reason', 'Emergency');
        } catch (AuraHandledException e) {
            nullBedCaught = true;
        }
        Assert.isTrue(nullBedCaught, 'Null bed should be rejected');

        Boolean nullDoctorCaught = false;
        try {
            CareNestAdmissionController.admitPatientRecord(doc.Id, bed.Id, null, 'Reason', 'Emergency');
        } catch (AuraHandledException e) {
            nullDoctorCaught = true;
        }
        Assert.isTrue(nullDoctorCaught, 'Null doctor should be rejected');
    }

    @IsTest
    static void testAdditionalCoverage() {
        Test.startTest();
        List<CareNestAdmissionController.SelectOptionDto> availDocs = CareNestAdmissionController.getAvailableDoctors();
        Assert.isNotNull(availDocs);

        List<CareNestAdmissionController.DoctorAvailabilityDto> docsByDept = CareNestAdmissionController.getDoctorsWithAvailability('General Medicine', 'Dr');
        Assert.isNotNull(docsByDept);

        List<CareNestAdmissionController.DoctorAvailabilityDto> docsAll = CareNestAdmissionController.getDoctorsWithAvailability('All', '');
        Assert.isNotNull(docsAll);

        List<CareNestAdmissionController.AdmissionSummaryDto> admsAll = CareNestAdmissionController.getAdmissions('All', '');
        Assert.isNotNull(admsAll);

        List<CareNestAdmissionController.AdmissionSummaryDto> activeAdms = CareNestAdmissionController.getActiveAdmissions('');
        Assert.isNotNull(activeAdms);

        List<CareNestAdmissionController.AdmissionSummaryDto> dischargedAdms = CareNestAdmissionController.getAdmissions('Discharged', 'Adm');
        Assert.isNotNull(dischargedAdms);
        Test.stopTest();
    }
}
