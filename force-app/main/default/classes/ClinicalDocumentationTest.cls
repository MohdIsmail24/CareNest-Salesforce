/**
 * @description Comprehensive unit tests for CareNest Inpatient Clinical Documentation (Phase 12.4).
 * Verifies Inpatient_Encounter__c and Patient_Vital__c creation, physiological range validation,
 * inactive admission restrictions, atomic transactions and rollbacks, bulk safety, and CRUD/FLS handling.
 */
@isTest
private class ClinicalDocumentationTest {

    private static Integer seq = 9100;

    private static Doctor__c createDoctor(String name) {
        seq++;
        Doctor__c doc = new Doctor__c(
            Name = name,
            Registration_No__c = 'REG-DOC-' + seq,
            Department__c = 'General Medicine',
            Specialty__c = 'Internal Medicine',
            Consultation_Fee__c = 450,
            Is_Active__c = true
        );
        insert doc;
        return doc;
    }

    private static Contact createPatient(String lastName) {
        seq++;
        Contact c = new Contact(
            LastName = lastName,
            Email = lastName.toLowerCase() + seq + '@carenest-test.org',
            Phone = '555222' + seq,
            Patient_Code__c = 'PAT-CLN-' + seq
        );
        insert c;
        return c;
    }

    private static Ward__c createWard(String name, String code, Integer capacity, Boolean isActive) {
        Ward__c ward = new Ward__c(
            Name = name,
            Ward_Code__c = code,
            Ward_Type__c = 'General',
            Floor__c = '2',
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

    private static Admission__c createAdmission(Contact pat, Bed__c bed, Doctor__c doc, String status) {
        Admission__c adm = new Admission__c(
            Contact__c = pat.Id,
            Patient__c = pat.Id,
            Bed__c = bed.Id,
            Attending_Doctor__c = doc.Id,
            Doctor__c = doc.Id,
            Admission_Date__c = System.now().addDays(-1),
            Reason__c = 'Post-operative monitoring',
            Status__c = status
        );
        insert adm;
        return adm;
    }

    @isTest
    static void testCreateEncounterSuccess() {
        Ward__c ward = createWard('Ward Cardio', 'WRD-CARD-01', 5, true);
        Bed__c bed = createBed(ward, 'Bed C-101', 'BED-C-101', 'Available');
        Doctor__c doc = createDoctor('Dr. Gregory House');
        Contact pat = createPatient('PatEncounter1');
        Admission__c adm = createAdmission(pat, bed, doc, 'Admitted');

        Test.startTest();
        ClinicalDocumentationService.EncounterRequest req = new ClinicalDocumentationService.EncounterRequest(
            adm.Id,
            doc.Id,
            System.now(),
            'Mild chest tightness',
            'Cardiorespiratory stable, continue telemetry',
            'Patient resting comfortably. Vitals stable.'
        );
        Inpatient_Encounter__c result = ClinicalDocumentationService.createEncounter(req);
        Test.stopTest();

        System.assertNotEquals(null, result.Id, 'Encounter should be persisted');
        Inpatient_Encounter__c queried = [
            SELECT Id, Name, Admission__c, Attending_Doctor__c, Doctor__c,
                   Chief_Complaint__c, Assessment__c, Clinical_Notes__c, Status__c, Encounter_Type__c
            FROM Inpatient_Encounter__c
            WHERE Id = :result.Id
        ];
        System.assertEquals(adm.Id, queried.Admission__c, 'Admission should match');
        System.assertEquals(doc.Id, queried.Attending_Doctor__c, 'Attending doctor should match');
        System.assertEquals(doc.Id, queried.Doctor__c, 'Doctor alias should match');
        System.assertEquals('Completed', queried.Status__c, 'Status should default to Completed');
        System.assertEquals('Daily Ward Round', queried.Encounter_Type__c, 'Encounter type should match');
        System.assert(queried.Name.startsWith('ENC-'), 'Encounter Name should have ENC- prefix');
    }

    @isTest
    static void testRecordVitalsSuccess() {
        Ward__c ward = createWard('Ward Neuro', 'WRD-NEUR-01', 5, true);
        Bed__c bed = createBed(ward, 'Bed N-101', 'BED-N-101', 'Available');
        Doctor__c doc = createDoctor('Dr. John Watson');
        Contact pat = createPatient('PatVital1');
        Admission__c adm = createAdmission(pat, bed, doc, 'Admitted');

        Test.startTest();
        ClinicalDocumentationService.VitalRequest vReq = new ClinicalDocumentationService.VitalRequest(
            adm.Id,
            null,
            98.6,
            72,
            16,
            120,
            80,
            99,
            70.5
        );
        vReq.notes = 'Normal sinus rhythm';
        Patient_Vital__c result = ClinicalDocumentationService.recordVitals(vReq);
        Test.stopTest();

        System.assertNotEquals(null, result.Id, 'Vital record should be persisted');
        Patient_Vital__c queried = [
            SELECT Id, Name, Admission__c, Temperature__c, Temperature_Unit__c, Pulse__c,
                   Respiratory_Rate__c, Systolic_BP__c, Diastolic_BP__c, Blood_Pressure__c,
                   Oxygen_Saturation__c, Weight__c, Weight_Unit__c, Notes__c
            FROM Patient_Vital__c
            WHERE Id = :result.Id
        ];
        System.assertEquals(adm.Id, queried.Admission__c, 'Admission should match');
        System.assertEquals(98.6, queried.Temperature__c, 'Temperature should match');
        System.assertEquals('°F', queried.Temperature_Unit__c, 'Unit should default to °F');
        System.assertEquals(72, queried.Pulse__c, 'Pulse should match');
        System.assertEquals(16, queried.Respiratory_Rate__c, 'RR should match');
        System.assertEquals(120, queried.Systolic_BP__c, 'Systolic should match');
        System.assertEquals(80, queried.Diastolic_BP__c, 'Diastolic should match');
        System.assertEquals('120/80', queried.Blood_Pressure__c, 'Blood Pressure string should be formatted as 120/80');
        System.assertEquals(99, queried.Oxygen_Saturation__c, 'Oxygen saturation should match');
        System.assertEquals(70.5, queried.Weight__c, 'Weight should match');
        System.assertEquals('kg', queried.Weight_Unit__c, 'Weight unit should default to kg');
        System.assert(queried.Name.startsWith('VIT-'), 'Vital Name should have VIT- prefix');
    }

    @isTest
    static void testEncounterWithVitalsCompositeSuccess() {
        Ward__c ward = createWard('Ward Pulm', 'WRD-PULM-01', 5, true);
        Bed__c bed = createBed(ward, 'Bed P-101', 'BED-P-101', 'Available');
        Doctor__c doc = createDoctor('Dr. Allison Cameron');
        Contact pat = createPatient('PatComposite1');
        Admission__c adm = createAdmission(pat, bed, doc, 'Admitted');

        ClinicalDocumentationService.EncounterRequest encReq = new ClinicalDocumentationService.EncounterRequest(
            adm.Id,
            doc.Id,
            System.now(),
            'Morning rounds',
            'Progressing well',
            'Lungs clear bilaterally'
        );

        ClinicalDocumentationService.VitalRequest v1 = new ClinicalDocumentationService.VitalRequest(
            adm.Id, null, 98.4, 68, 14, 118, 76, 98, 65.0
        );
        ClinicalDocumentationService.VitalRequest v2 = new ClinicalDocumentationService.VitalRequest(
            adm.Id, null, 98.6, 70, 16, 122, 78, 99, 65.0
        );

        Test.startTest();
        ClinicalDocumentationService.EncounterWithVitalsResult compositeResult =
            ClinicalDocumentationService.createEncounterWithVitals(encReq, new List<ClinicalDocumentationService.VitalRequest>{ v1, v2 });
        Test.stopTest();

        System.assertNotEquals(null, compositeResult.encounter.Id, 'Encounter must be created');
        System.assertEquals(2, compositeResult.vitals.size(), 'Two vitals records must be created');

        List<Patient_Vital__c> queriedVitals = [
            SELECT Id, Admission__c, Inpatient_Encounter__c, Blood_Pressure__c
            FROM Patient_Vital__c
            WHERE Inpatient_Encounter__c = :compositeResult.encounter.Id
        ];
        System.assertEquals(2, queriedVitals.size(), 'Both vitals should link to the encounter');
        for (Patient_Vital__c v : queriedVitals) {
            System.assertEquals(adm.Id, v.Admission__c, 'Admission must be linked to vital');
        }
    }

    @isTest
    static void testPreventEncounterOnDischargedAdmission() {
        Ward__c ward = createWard('Ward Rehab', 'WRD-RHB-01', 5, true);
        Bed__c bed = createBed(ward, 'Bed R-101', 'BED-R-101', 'Available');
        Doctor__c doc = createDoctor('Dr. Eric Foreman');
        Contact pat = createPatient('PatDischarged');
        Admission__c adm = createAdmission(pat, bed, doc, 'Discharged');

        Test.startTest();
        // Test via service
        Boolean exceptionThrown = false;
        try {
            ClinicalDocumentationService.EncounterRequest req = new ClinicalDocumentationService.EncounterRequest(
                adm.Id, doc.Id, System.now(), 'Followup', 'Discharged already', 'Notes'
            );
            ClinicalDocumentationService.createEncounter(req);
        } catch (ClinicalDocumentationService.ClinicalException ex) {
            exceptionThrown = true;
            System.assert(ex.getMessage().contains('Cannot document encounter for inactive admission'), 'Expected inactive admission error message');
        }
        System.assert(exceptionThrown, 'Service should throw ClinicalException for discharged admission');

        // Test via direct DML
        Boolean dmlFailed = false;
        try {
            Inpatient_Encounter__c directEnc = new Inpatient_Encounter__c(
                Admission__c = adm.Id,
                Attending_Doctor__c = doc.Id,
                Encounter_Date__c = System.now(),
                Status__c = 'Completed'
            );
            insert directEnc;
        } catch (DmlException ex) {
            dmlFailed = true;
            System.assert(ex.getMessage().contains('discharged or cancelled'), 'Expected trigger validation error');
        }
        System.assert(dmlFailed, 'Direct DML should fail on discharged admission');
        Test.stopTest();
    }

    @isTest
    static void testPreventEncounterOnCancelledAdmission() {
        Ward__c ward = createWard('Ward Gastro', 'WRD-GAS-01', 5, true);
        Bed__c bed = createBed(ward, 'Bed G-101', 'BED-G-101', 'Available');
        Doctor__c doc = createDoctor('Dr. Lisa Cuddy');
        Contact pat = createPatient('PatCancelled');
        Admission__c adm = createAdmission(pat, bed, doc, 'Cancelled');

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            ClinicalDocumentationService.EncounterRequest req = new ClinicalDocumentationService.EncounterRequest(
                adm.Id, doc.Id, System.now(), 'Exam', 'Cancelled admission', 'Notes'
            );
            ClinicalDocumentationService.createEncounter(req);
        } catch (ClinicalDocumentationService.ClinicalException ex) {
            exceptionThrown = true;
            System.assert(ex.getMessage().contains('Cannot document encounter for inactive admission'), 'Expected inactive admission error');
        }
        System.assert(exceptionThrown, 'Service should reject cancelled admission');
        Test.stopTest();
    }

    @isTest
    static void testPreventVitalsOnDischargedAdmission() {
        Ward__c ward = createWard('Ward Ortho', 'WRD-ORT-01', 5, true);
        Bed__c bed = createBed(ward, 'Bed O-101', 'BED-O-101', 'Available');
        Doctor__c doc = createDoctor('Dr. Robert Chase');
        Contact pat = createPatient('PatVitalDischarged');
        Admission__c adm = createAdmission(pat, bed, doc, 'Discharged');

        Test.startTest();
        // Test via service
        Boolean exceptionThrown = false;
        try {
            ClinicalDocumentationService.VitalRequest vReq = new ClinicalDocumentationService.VitalRequest(
                adm.Id, null, 98.6, 75, 18, 120, 80, 98, 72.0
            );
            ClinicalDocumentationService.recordVitals(vReq);
        } catch (ClinicalDocumentationService.ClinicalException ex) {
            exceptionThrown = true;
            System.assert(ex.getMessage().contains('Cannot record vitals for inactive admission'), 'Expected inactive admission message');
        }
        System.assert(exceptionThrown, 'Service should reject vitals on discharged admission');

        // Test via direct DML
        Boolean dmlFailed = false;
        try {
            Patient_Vital__c directVital = new Patient_Vital__c(
                Admission__c = adm.Id,
                Recorded_Date__c = System.now(),
                Temperature__c = 98.6
            );
            insert directVital;
        } catch (DmlException ex) {
            dmlFailed = true;
            System.assert(ex.getMessage().contains('discharged or cancelled'), 'Expected trigger validation message');
        }
        System.assert(dmlFailed, 'Direct DML should fail on discharged admission');
        Test.stopTest();
    }

    @isTest
    static void testInvalidVitalRangesRejection() {
        Ward__c ward = createWard('Ward ICU', 'WRD-ICU-01', 5, true);
        Bed__c bed = createBed(ward, 'Bed I-101', 'BED-I-101', 'Available');
        Doctor__c doc = createDoctor('Dr. James Wilson');
        Contact pat = createPatient('PatRanges');
        Admission__c adm = createAdmission(pat, bed, doc, 'Admitted');

        Test.startTest();

        // 1. Invalid Temperature (< 85 or > 110)
        try {
            ClinicalDocumentationService.VitalRequest v = new ClinicalDocumentationService.VitalRequest(adm.Id, null, 80.0, 70, 16, 120, 80, 98, 70);
            ClinicalDocumentationService.recordVitals(v);
            System.assert(false, 'Should have failed for low temp');
        } catch (ClinicalDocumentationService.ClinicalException ex) {
            System.assert(ex.getMessage().contains('Temperature'), 'Should fail for temp: ' + ex.getMessage());
        }

        try {
            ClinicalDocumentationService.VitalRequest v = new ClinicalDocumentationService.VitalRequest(adm.Id, null, 115.0, 70, 16, 120, 80, 98, 70);
            ClinicalDocumentationService.recordVitals(v);
            System.assert(false, 'Should have failed for high temp');
        } catch (ClinicalDocumentationService.ClinicalException ex) {
            System.assert(ex.getMessage().contains('Temperature'), 'Should fail for high temp: ' + ex.getMessage());
        }

        // 2. Invalid Pulse (< 30 or > 250)
        try {
            ClinicalDocumentationService.VitalRequest v = new ClinicalDocumentationService.VitalRequest(adm.Id, null, 98.6, 20, 16, 120, 80, 98, 70);
            ClinicalDocumentationService.recordVitals(v);
            System.assert(false, 'Should have failed for low pulse');
        } catch (ClinicalDocumentationService.ClinicalException ex) {
            System.assert(ex.getMessage().contains('Pulse'), 'Should fail for pulse: ' + ex.getMessage());
        }

        // 3. Invalid Respiratory Rate (< 5 or > 70)
        try {
            ClinicalDocumentationService.VitalRequest v = new ClinicalDocumentationService.VitalRequest(adm.Id, null, 98.6, 70, 80, 120, 80, 98, 70);
            ClinicalDocumentationService.recordVitals(v);
            System.assert(false, 'Should have failed for high RR');
        } catch (ClinicalDocumentationService.ClinicalException ex) {
            System.assert(ex.getMessage().contains('Respiratory rate'), 'Should fail for RR: ' + ex.getMessage());
        }

        // 4. Invalid Blood Pressure (Systolic <= Diastolic)
        try {
            ClinicalDocumentationService.VitalRequest v = new ClinicalDocumentationService.VitalRequest(adm.Id, null, 98.6, 70, 16, 80, 120, 98, 70);
            ClinicalDocumentationService.recordVitals(v);
            System.assert(false, 'Should have failed when systolic <= diastolic');
        } catch (ClinicalDocumentationService.ClinicalException ex) {
            System.assert(ex.getMessage().contains('Systolic BP'), 'Should fail for BP: ' + ex.getMessage());
        }

        // 5. Invalid Oxygen Saturation (< 50 or > 100)
        try {
            ClinicalDocumentationService.VitalRequest v = new ClinicalDocumentationService.VitalRequest(adm.Id, null, 98.6, 70, 16, 120, 80, 105, 70);
            ClinicalDocumentationService.recordVitals(v);
            System.assert(false, 'Should have failed for SpO2 > 100');
        } catch (ClinicalDocumentationService.ClinicalException ex) {
            System.assert(ex.getMessage().contains('Oxygen saturation'), 'Should fail for SpO2: ' + ex.getMessage());
        }

        // 6. Invalid Weight (<= 0 or > 500)
        try {
            ClinicalDocumentationService.VitalRequest v = new ClinicalDocumentationService.VitalRequest(adm.Id, null, 98.6, 70, 16, 120, 80, 98, -5);
            ClinicalDocumentationService.recordVitals(v);
            System.assert(false, 'Should have failed for negative weight');
        } catch (ClinicalDocumentationService.ClinicalException ex) {
            System.assert(ex.getMessage().contains('Weight'), 'Should fail for weight: ' + ex.getMessage());
        }

        Test.stopTest();
    }

    @isTest
    static void testMismatchedEncounterAdmissionRejection() {
        Ward__c ward = createWard('Ward Stepdown', 'WRD-SD-01', 5, true);
        Bed__c bed1 = createBed(ward, 'Bed S-101', 'BED-S-101', 'Available');
        Bed__c bed2 = createBed(ward, 'Bed S-102', 'BED-S-102', 'Available');
        Doctor__c doc = createDoctor('Dr. Remy Hadley');
        Contact pat1 = createPatient('PatMismatch1');
        Contact pat2 = createPatient('PatMismatch2');
        Admission__c adm1 = createAdmission(pat1, bed1, doc, 'Admitted');
        Admission__c adm2 = createAdmission(pat2, bed2, doc, 'Admitted');

        Inpatient_Encounter__c encAdm1 = new Inpatient_Encounter__c(
            Admission__c = adm1.Id,
            Attending_Doctor__c = doc.Id,
            Encounter_Date__c = System.now(),
            Status__c = 'Completed'
        );
        insert encAdm1;

        Test.startTest();
        Boolean dmlFailed = false;
        try {
            // Attempt to link a vital to adm2 while pointing to encAdm1 (which belongs to adm1)
            Patient_Vital__c mismatchedVital = new Patient_Vital__c(
                Admission__c = adm2.Id,
                Inpatient_Encounter__c = encAdm1.Id,
                Recorded_Date__c = System.now(),
                Temperature__c = 98.6,
                Pulse__c = 72,
                Respiratory_Rate__c = 16,
                Systolic_BP__c = 120,
                Diastolic_BP__c = 80,
                Oxygen_Saturation__c = 98,
                Weight__c = 70
            );
            insert mismatchedVital;
        } catch (DmlException ex) {
            dmlFailed = true;
            System.assert(ex.getMessage().contains('Mismatched relationship'), 'Expected mismatched relationship error: ' + ex.getMessage());
        }
        System.assert(dmlFailed, 'Vital with mismatched encounter and admission must be rejected');
        Test.stopTest();
    }

    @isTest
    static void testVitalAdmissionDerivationFromEncounter() {
        Ward__c ward = createWard('Ward Dialysis', 'WRD-DIA-01', 5, true);
        Bed__c bed = createBed(ward, 'Bed D-101', 'BED-D-101', 'Available');
        Doctor__c doc = createDoctor('Dr. Lawrence Kutner');
        Contact pat = createPatient('PatDerive');
        Admission__c adm = createAdmission(pat, bed, doc, 'Admitted');

        Inpatient_Encounter__c enc = new Inpatient_Encounter__c(
            Admission__c = adm.Id,
            Attending_Doctor__c = doc.Id,
            Encounter_Date__c = System.now(),
            Status__c = 'In Progress'
        );
        insert enc;

        Test.startTest();
        // Insert vital with null Admission__c but valid Inpatient_Encounter__c
        Patient_Vital__c vital = new Patient_Vital__c(
            Inpatient_Encounter__c = enc.Id,
            Recorded_Date__c = System.now(),
            Temperature__c = 98.7,
            Pulse__c = 75,
            Respiratory_Rate__c = 18,
            Systolic_BP__c = 118,
            Diastolic_BP__c = 78,
            Oxygen_Saturation__c = 99,
            Weight__c = 72.5
        );
        insert vital;
        Test.stopTest();

        Patient_Vital__c queried = [
            SELECT Id, Admission__c, Inpatient_Encounter__c, Blood_Pressure__c
            FROM Patient_Vital__c
            WHERE Id = :vital.Id
        ];
        System.assertEquals(adm.Id, queried.Admission__c, 'Trigger handler should have derived Admission__c from encounter');
        System.assertEquals('118/78', queried.Blood_Pressure__c, 'Trigger handler should have formatted BP');
    }

    @isTest
    static void testBulkEncountersAndVitals() {
        Ward__c ward = createWard('Ward Oncology', 'WRD-ONC-01', 50, true);
        Bed__c bed = createBed(ward, 'Bed O-500', 'BED-O-500', 'Available');
        Doctor__c doc = createDoctor('Dr. Chris Taub');
        Contact pat = createPatient('PatBulkDoc');
        Admission__c adm = createAdmission(pat, bed, doc, 'Admitted');

        List<ClinicalDocumentationService.EncounterRequest> encRequests = new List<ClinicalDocumentationService.EncounterRequest>();
        List<ClinicalDocumentationService.VitalRequest> vitalRequests = new List<ClinicalDocumentationService.VitalRequest>();

        for (Integer i = 0; i < 20; i++) {
            encRequests.add(new ClinicalDocumentationService.EncounterRequest(
                adm.Id,
                doc.Id,
                System.now().addHours(-i),
                'Chief Complaint ' + i,
                'Assessment ' + i,
                'Notes ' + i
            ));
            vitalRequests.add(new ClinicalDocumentationService.VitalRequest(
                adm.Id,
                null,
                98.6 + (i * 0.1),
                70 + i,
                16,
                120,
                80,
                98,
                70.0
            ));
        }

        Test.startTest();
        List<Inpatient_Encounter__c> createdEncounters = ClinicalDocumentationService.createEncounters(encRequests);
        List<Patient_Vital__c> createdVitals = ClinicalDocumentationService.recordVitals(vitalRequests);
        Test.stopTest();

        System.assertEquals(20, createdEncounters.size(), 'All 20 encounters must be created');
        System.assertEquals(20, createdVitals.size(), 'All 20 vitals must be created');
    }

    @isTest
    static void testAtomicRollbackOnFailure() {
        Ward__c ward = createWard('Ward Rollback', 'WRD-RBK-01', 5, true);
        Bed__c bed = createBed(ward, 'Bed RBK-1', 'BED-RBK-1', 'Available');
        Doctor__c doc = createDoctor('Dr. Amber Volakis');
        Contact pat = createPatient('PatRollback');
        Admission__c adm = createAdmission(pat, bed, doc, 'Admitted');

        ClinicalDocumentationService.EncounterRequest encReq = new ClinicalDocumentationService.EncounterRequest(
            adm.Id,
            doc.Id,
            System.now(),
            'Pre-op check',
            'Ready',
            'Clinical notes'
        );

        // One valid vital, one invalid vital (temp = 200)
        ClinicalDocumentationService.VitalRequest validVital = new ClinicalDocumentationService.VitalRequest(
            adm.Id, null, 98.6, 72, 16, 120, 80, 98, 70.0
        );
        ClinicalDocumentationService.VitalRequest invalidVital = new ClinicalDocumentationService.VitalRequest(
            adm.Id, null, 200.0, 72, 16, 120, 80, 98, 70.0 // Invalid temperature
        );

        Test.startTest();
        Boolean exceptionCaught = false;
        try {
            ClinicalDocumentationService.createEncounterWithVitals(encReq, new List<ClinicalDocumentationService.VitalRequest>{ validVital, invalidVital });
        } catch (ClinicalDocumentationService.ClinicalException ex) {
            exceptionCaught = true;
        }
        Test.stopTest();

        System.assert(exceptionCaught, 'ClinicalException must be thrown on invalid vital');

        // Confirm encounter and vitals were rolled back
        List<Inpatient_Encounter__c> encounters = [SELECT Id FROM Inpatient_Encounter__c WHERE Admission__c = :adm.Id];
        System.assertEquals(0, encounters.size(), 'Encounter should be rolled back when child vital fails');

        List<Patient_Vital__c> vitals = [SELECT Id FROM Patient_Vital__c WHERE Admission__c = :adm.Id];
        System.assertEquals(0, vitals.size(), 'No vitals should be committed');
    }

    @isTest
    static void testDirectDmlAndBypassFlags() {
        Ward__c ward = createWard('Ward Direct', 'WRD-DIR-01', 5, true);
        Bed__c bed = createBed(ward, 'Bed D-201', 'BED-D-201', 'Available');
        Doctor__c doc = createDoctor('Dr. Martha Masters');
        Contact pat = createPatient('PatDirectDml');
        Admission__c adm = createAdmission(pat, bed, doc, 'Admitted');

        // Test alias sync: populate Doctor__c only
        Inpatient_Encounter__c enc = new Inpatient_Encounter__c(
            Admission__c = adm.Id,
            Doctor__c = doc.Id,
            Chief_Complaint__c = 'Fever',
            Status__c = 'In Progress'
        );
        insert enc;

        Inpatient_Encounter__c queriedEnc = [
            SELECT Id, Attending_Doctor__c, Doctor__c, Encounter_Date__c
            FROM Inpatient_Encounter__c
            WHERE Id = :enc.Id
        ];
        System.assertEquals(doc.Id, queriedEnc.Attending_Doctor__c, 'Attending doctor should be synced from Doctor__c');
        System.assertNotEquals(null, queriedEnc.Encounter_Date__c, 'Encounter date should default to now');

        // Update encounter
        queriedEnc.Clinical_Notes__c = 'Updated clinical progress note.';
        update queriedEnc;

        // Test bypass flags
        InpatientEncounterTriggerHandler.bypassTrigger = true;
        PatientVitalTriggerHandler.bypassTrigger = true;

        Patient_Vital__c bypassedVital = new Patient_Vital__c(
            Admission__c = adm.Id,
            Recorded_Date__c = System.now(),
            Temperature__c = 98.6
        );
        insert bypassedVital;
        update bypassedVital;

        InpatientEncounterTriggerHandler.bypassTrigger = false;
        PatientVitalTriggerHandler.bypassTrigger = false;
    }

    @isTest
    static void testServiceValidationEdgeCases() {
        Test.startTest();

        // 1. Null single encounter request
        try {
            ClinicalDocumentationService.createEncounter(null);
            System.assert(false, 'Should throw for null encounter');
        } catch (ClinicalDocumentationService.ClinicalException ex) {
            System.assert(ex.getMessage().contains('cannot be null'));
        }

        // 2. Empty encounter requests list
        try {
            ClinicalDocumentationService.createEncounters(new List<ClinicalDocumentationService.EncounterRequest>());
            System.assert(false, 'Should throw for empty list');
        } catch (ClinicalDocumentationService.ClinicalException ex) {
            System.assert(ex.getMessage().contains('cannot be null or empty'));
        }

        // 3. Null item in requests
        try {
            ClinicalDocumentationService.createEncounters(new List<ClinicalDocumentationService.EncounterRequest>{ null });
            System.assert(false, 'Should throw for null item');
        } catch (ClinicalDocumentationService.ClinicalException ex) {
            System.assert(ex.getMessage().contains('cannot be null'));
        }

        // 4. Missing Admission ID
        try {
            ClinicalDocumentationService.EncounterRequest req = new ClinicalDocumentationService.EncounterRequest();
            req.doctorId = '001000000000000AAA';
            ClinicalDocumentationService.createEncounter(req);
            System.assert(false, 'Should throw for missing admission');
        } catch (ClinicalDocumentationService.ClinicalException ex) {
            System.assert(ex.getMessage().contains('Admission ID is required'));
        }

        // 5. Missing Doctor ID
        try {
            ClinicalDocumentationService.EncounterRequest req = new ClinicalDocumentationService.EncounterRequest();
            req.admissionId = '001000000000000AAA';
            ClinicalDocumentationService.createEncounter(req);
            System.assert(false, 'Should throw for missing doctor');
        } catch (ClinicalDocumentationService.ClinicalException ex) {
            System.assert(ex.getMessage().contains('Doctor ID is required'));
        }

        // 6. Null single vital request
        try {
            ClinicalDocumentationService.recordVitals((ClinicalDocumentationService.VitalRequest) null);
            System.assert(false, 'Should throw for null vital');
        } catch (ClinicalDocumentationService.ClinicalException ex) {
            System.assert(ex.getMessage().contains('cannot be null'));
        }

        // 7. Empty vitals list
        try {
            ClinicalDocumentationService.recordVitals(new List<ClinicalDocumentationService.VitalRequest>());
            System.assert(false, 'Should throw for empty vitals list');
        } catch (ClinicalDocumentationService.ClinicalException ex) {
            System.assert(ex.getMessage().contains('cannot be null or empty'));
        }

        // 8. Missing both Admission ID and Encounter ID for vitals
        try {
            ClinicalDocumentationService.VitalRequest vr = new ClinicalDocumentationService.VitalRequest();
            vr.temperature = 98.6;
            ClinicalDocumentationService.recordVitals(vr);
            System.assert(false, 'Should throw for missing parent');
        } catch (ClinicalDocumentationService.ClinicalException ex) {
            System.assert(ex.getMessage().contains('Either Admission ID or Encounter ID must be specified'));
        }

        // 9. Null composite request
        try {
            ClinicalDocumentationService.createEncounterWithVitals(null, null);
            System.assert(false, 'Should throw for null composite');
        } catch (ClinicalDocumentationService.ClinicalException ex) {
            System.assert(ex.getMessage().contains('Encounter request cannot be null'));
        }

        Test.stopTest();
    }
}
