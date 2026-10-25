/**
 * @description Comprehensive unit tests for Inpatient Discharge Management & Safe Bed Release (Phase 12.5).
 * Tests authoritative discharge workflow, Discharge Pending transitions, invalid state rejection,
 * bed release and conflict protections, bulk discharges, atomic rollback, direct DML terminal guards,
 * and clinical documentation integration protections.
 */
@isTest
private class InpatientDischargeTest {

    private static Integer seq = 9300;

    private static Doctor__c createDoctor(String name) {
        seq++;
        Doctor__c doc = new Doctor__c(
            Name = name,
            Registration_No__c = 'REG-DIS-' + seq,
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
            Email = lastName.toLowerCase() + seq + '@test-discharge.org',
            Phone = '555333' + seq,
            Patient_Code__c = 'PAT-DIS-' + seq
        );
        insert c;
        return c;
    }

    private static Ward__c createWard(String name, String code, Integer capacity, Boolean isActive) {
        Ward__c ward = new Ward__c(
            Name = name,
            Ward_Code__c = code,
            Ward_Type__c = 'General',
            Floor__c = '3',
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

    private static Admission__c admitPatientHelper(Contact pat, Bed__c bed, Doctor__c doc, String reason) {
        AdmissionService.AdmissionRequest req = new AdmissionService.AdmissionRequest(
            pat.Id,
            bed.Id,
            doc.Id,
            System.now().addDays(-2),
            reason,
            null
        );
        return AdmissionService.admitPatient(req);
    }

    @isTest
    static void testSuccessfulDischargeWithDetails() {
        Ward__c ward = createWard('Ward Med A', 'WRD-MA-01', 5, true);
        Bed__c bed = createBed(ward, 'Bed MA-101', 'BED-MA-101', 'Available');
        Doctor__c attendingDoc = createDoctor('Dr. Gregory House');
        Doctor__c dischargingDoc = createDoctor('Dr. James Wilson');
        Contact pat = createPatient('PatDischarge1');

        Admission__c adm = admitPatientHelper(pat, bed, attendingDoc, 'Pneumonia observation');

        // Confirm bed is occupied before discharge
        Bed__c bOccupied = [SELECT Id, Status__c FROM Bed__c WHERE Id = :bed.Id];
        System.assertEquals('Occupied', bOccupied.Status__c, 'Bed must be Occupied after admission');

        Test.startTest();
        Datetime dischargeDt = System.now();
        AdmissionService.DischargeRequest dReq = new AdmissionService.DischargeRequest(
            adm.Id,
            dischargeDt,
            'Patient recovered well. Afebrile for 48 hours. Discharge with oral antibiotics.',
            'Home',
            dischargingDoc.Id
        );
        Admission__c dischargedAdm = AdmissionService.dischargePatient(dReq);
        Test.stopTest();

        System.assertEquals('Discharged', dischargedAdm.Status__c, 'Status should transition to Discharged');

        // Verify persisted fields on Admission__c
        Admission__c queriedAdm = [
            SELECT Id, Status__c, Discharge_Date__c, Discharge_Summary__c, Discharge_Disposition__c, Discharging_Doctor__c
            FROM Admission__c
            WHERE Id = :adm.Id
        ];
        System.assertEquals('Discharged', queriedAdm.Status__c, 'Persisted status must be Discharged');
        System.assertEquals(dischargeDt, queriedAdm.Discharge_Date__c, 'Discharge date must match');
        System.assert(queriedAdm.Discharge_Summary__c.contains('Patient recovered well'), 'Discharge summary must match');
        System.assertEquals('Home', queriedAdm.Discharge_Disposition__c, 'Disposition must be Home');
        System.assertEquals(dischargingDoc.Id, queriedAdm.Discharging_Doctor__c, 'Discharging doctor must match');

        // Verify Bed is released to Available
        Bed__c bReleased = [SELECT Id, Status__c FROM Bed__c WHERE Id = :bed.Id];
        System.assertEquals('Available', bReleased.Status__c, 'Bed should be safely released to Available');
    }

    @isTest
    static void testDischargeFromDischargePending() {
        Ward__c ward = createWard('Ward Med B', 'WRD-MB-01', 5, true);
        Bed__c bed = createBed(ward, 'Bed MB-101', 'BED-MB-101', 'Available');
        Doctor__c doc = createDoctor('Dr. Allison Cameron');
        Contact pat = createPatient('PatPending');

        Admission__c adm = admitPatientHelper(pat, bed, doc, 'Post-op observation');

        // Transition to Discharge Pending
        Test.startTest();
        Admission__c pendingAdm = AdmissionService.markDischargePending(adm.Id);
        System.assertEquals('Discharge Pending', pendingAdm.Status__c, 'Status must be Discharge Pending');

        // Verify Bed remains Occupied while in Discharge Pending
        Bed__c bStillOccupied = [SELECT Id, Status__c FROM Bed__c WHERE Id = :bed.Id];
        System.assertEquals('Occupied', bStillOccupied.Status__c, 'Bed must remain Occupied while Discharge Pending');

        // Finalize discharge from Discharge Pending
        AdmissionService.DischargeRequest dReq = new AdmissionService.DischargeRequest(
            adm.Id,
            System.now(),
            'Discharge medications reviewed. Transportation arranged.',
            'Home Health Care',
            doc.Id
        );
        Admission__c finalAdm = AdmissionService.dischargePatient(dReq);
        Test.stopTest();

        System.assertEquals('Discharged', finalAdm.Status__c, 'Status must be Discharged');
        Bed__c bReleased = [SELECT Id, Status__c FROM Bed__c WHERE Id = :bed.Id];
        System.assertEquals('Available', bReleased.Status__c, 'Bed must be Available after discharge');
    }

    @isTest
    static void testPreventDischargeFromCancelledOrRepeated() {
        Ward__c ward = createWard('Ward Med C', 'WRD-MC-01', 5, true);
        Bed__c bed1 = createBed(ward, 'Bed MC-101', 'BED-MC-101', 'Available');
        Bed__c bed2 = createBed(ward, 'Bed MC-102', 'BED-MC-102', 'Available');
        Doctor__c doc = createDoctor('Dr. Eric Foreman');
        Contact pat1 = createPatient('PatRepeat');
        Contact pat2 = createPatient('PatCancel');

        Admission__c adm1 = admitPatientHelper(pat1, bed1, doc, 'Cardiac workup');
        Admission__c adm2 = admitPatientHelper(pat2, bed2, doc, 'Pre-op prep');

        // Discharge adm1
        AdmissionService.dischargePatient(new AdmissionService.DischargeRequest(adm1.Id, 'Discharged successfully.'));

        Test.startTest();
        // 1. Attempt repeat discharge on adm1
        Boolean repeatFailed = false;
        try {
            AdmissionService.dischargePatient(new AdmissionService.DischargeRequest(adm1.Id, 'Second discharge attempt.'));
        } catch (AdmissionService.AdmissionException ex) {
            repeatFailed = true;
            System.assert(ex.getMessage().contains('already discharged'), 'Expected repeated discharge error message: ' + ex.getMessage());
        }
        System.assert(repeatFailed, 'Repeated discharge must be rejected');

        // 2. Cancel adm2 directly
        adm2.Status__c = 'Cancelled';
        update adm2;

        Boolean cancelFailed = false;
        try {
            AdmissionService.dischargePatient(new AdmissionService.DischargeRequest(adm2.Id, 'Attempting discharge on cancelled admission.'));
        } catch (AdmissionService.AdmissionException ex) {
            cancelFailed = true;
            System.assert(ex.getMessage().contains('cancelled'), 'Expected cancelled admission error: ' + ex.getMessage());
        }
        System.assert(cancelFailed, 'Discharge on cancelled admission must be rejected');
        Test.stopTest();
    }

    @isTest
    static void testMissingRequiredDischargeDetails() {
        Ward__c ward = createWard('Ward Med D', 'WRD-MD-01', 5, true);
        Bed__c bed = createBed(ward, 'Bed MD-101', 'BED-MD-101', 'Available');
        Doctor__c doc = createDoctor('Dr. Robert Chase');
        Contact pat = createPatient('PatMissing');

        // Admit with null reason
        AdmissionService.AdmissionRequest admReq = new AdmissionService.AdmissionRequest(
            pat.Id, bed.Id, doc.Id, System.now().addDays(-1), null, null
        );
        Admission__c adm = AdmissionService.admitPatient(admReq);

        Test.startTest();
        // Missing discharge summary when Reason__c is also null
        Boolean summaryFailed = false;
        try {
            AdmissionService.DischargeRequest req = new AdmissionService.DischargeRequest(
                adm.Id, System.now(), '   ', 'Home', doc.Id
            );
            AdmissionService.dischargePatient(req);
        } catch (AdmissionService.AdmissionException ex) {
            summaryFailed = true;
            System.assert(ex.getMessage().contains('Discharge summary or documented discharge reason is required'), 'Expected summary error: ' + ex.getMessage());
        }
        System.assert(summaryFailed, 'Missing discharge summary and reason must be rejected');

        // Discharge date earlier than admission date
        Boolean dateFailed = false;
        try {
            AdmissionService.DischargeRequest req = new AdmissionService.DischargeRequest(
                adm.Id, System.now().addDays(-5), 'Summary valid.', 'Home', doc.Id
            );
            AdmissionService.dischargePatient(req);
        } catch (AdmissionService.AdmissionException ex) {
            dateFailed = true;
            System.assert(ex.getMessage().contains('cannot be earlier than admission date'), 'Expected date error: ' + ex.getMessage());
        }
        System.assert(dateFailed, 'Discharge date before admission date must be rejected');
        Test.stopTest();
    }

    @isTest
    static void testBedInconsistentStateDetection() {
        Ward__c ward = createWard('Ward Med E', 'WRD-ME-01', 5, true);
        Bed__c bed = createBed(ward, 'Bed ME-101', 'BED-ME-101', 'Available');
        Doctor__c doc = createDoctor('Dr. Lisa Cuddy');
        Contact pat = createPatient('PatInconsistent');

        Admission__c adm = admitPatientHelper(pat, bed, doc, 'Observation');

        // Artificially change bed status to 'Cleaning' to create inconsistency
        bed.Status__c = 'Cleaning';
        update bed;

        Test.startTest();
        Boolean threwInconsistent = false;
        try {
            AdmissionService.dischargePatient(new AdmissionService.DischargeRequest(adm.Id, 'Discharge notes.'));
        } catch (AdmissionService.AdmissionException ex) {
            threwInconsistent = true;
            System.assert(ex.getMessage().contains('Inconsistent record state'), 'Expected inconsistent state error: ' + ex.getMessage());
        }
        System.assert(threwInconsistent, 'Discharge must reject inconsistent bed state');
        Test.stopTest();
    }

    @isTest
    static void testBedConflictSafeguard() {
        Ward__c ward = createWard('Ward Med F', 'WRD-MF-01', 5, true);
        Bed__c bed = createBed(ward, 'Bed MF-101', 'BED-MF-101', 'Available');
        Doctor__c doc = createDoctor('Dr. Chris Taub');
        Contact pat1 = createPatient('PatConflict1');
        Contact pat2 = createPatient('PatConflict2');

        // Admit first patient
        Admission__c adm1 = admitPatientHelper(pat1, bed, doc, 'Observation 1');

        // Force a second admission onto same bed by bypassing trigger to simulate conflicting data
        AdmissionTriggerHandler.bypassTrigger = true;
        Admission__c adm2 = new Admission__c(
            Contact__c = pat2.Id,
            Patient__c = pat2.Id,
            Bed__c = bed.Id,
            Attending_Doctor__c = doc.Id,
            Doctor__c = doc.Id,
            Admission_Date__c = System.now(),
            Reason__c = 'Observation 2',
            Status__c = 'Admitted'
        );
        insert adm2;
        AdmissionTriggerHandler.bypassTrigger = false;

        Test.startTest();
        // Attempting to discharge adm1 should detect that bed is also assigned to adm2 and abort
        Boolean conflictCaught = false;
        try {
            AdmissionService.dischargePatient(new AdmissionService.DischargeRequest(adm1.Id, 'Discharge notes.'));
        } catch (AdmissionService.AdmissionException ex) {
            conflictCaught = true;
            System.assert(ex.getMessage().contains('Bed conflict'), 'Expected bed conflict error: ' + ex.getMessage());
        }
        System.assert(conflictCaught, 'Service must abort discharge if bed is associated with another active admission');

        // Bed must remain Occupied to protect other admission
        Bed__c bStillOccupied = [SELECT Id, Status__c FROM Bed__c WHERE Id = :bed.Id];
        System.assertEquals('Occupied', bStillOccupied.Status__c, 'Bed must remain Occupied');
        Test.stopTest();
    }

    @isTest
    static void testBulkDischarges() {
        Ward__c ward = createWard('Ward Bulk Dis', 'WRD-BD-01', 30, true);
        Doctor__c doc = createDoctor('Dr. Remy Hadley');

        List<AdmissionService.AdmissionRequest> admRequests = new List<AdmissionService.AdmissionRequest>();
        List<Bed__c> beds = new List<Bed__c>();
        for (Integer i = 0; i < 20; i++) {
            Bed__c b = new Bed__c(
                Name = 'Bed BD-' + i,
                Bed_Code__c = 'BED-BD-' + i,
                Ward__c = ward.Id,
                Bed_Type__c = 'Standard',
                Status__c = 'Available'
            );
            beds.add(b);
        }
        insert beds;

        List<Contact> patients = new List<Contact>();
        for (Integer i = 0; i < 20; i++) {
            patients.add(new Contact(
                LastName = 'BulkPat' + i,
                Email = 'bulkpat' + i + '@test.org',
                Patient_Code__c = 'PAT-BD-' + i
            ));
        }
        insert patients;

        for (Integer i = 0; i < 20; i++) {
            admRequests.add(new AdmissionService.AdmissionRequest(
                patients[i].Id,
                beds[i].Id,
                doc.Id,
                System.now().addDays(-2),
                'Bulk condition ' + i,
                null
            ));
        }
        List<Admission__c> admissions = AdmissionService.admitPatients(admRequests);
        System.assertEquals(20, admissions.size());

        // Prepare bulk discharge requests
        List<AdmissionService.DischargeRequest> dischargeRequests = new List<AdmissionService.DischargeRequest>();
        for (Integer i = 0; i < 20; i++) {
            dischargeRequests.add(new AdmissionService.DischargeRequest(
                admissions[i].Id,
                System.now(),
                'Patient ' + i + ' discharged in stable condition.',
                'Home',
                doc.Id
            ));
        }

        Test.startTest();
        List<Admission__c> dischargedList = AdmissionService.dischargePatients(dischargeRequests);
        Test.stopTest();

        System.assertEquals(20, dischargedList.size(), 'All 20 admissions should be discharged');

        // Verify beds are all Available
        List<Bed__c> queriedBeds = [SELECT Id, Status__c FROM Bed__c WHERE Id IN :beds];
        for (Bed__c b : queriedBeds) {
            System.assertEquals('Available', b.Status__c, 'Bed ' + b.Id + ' must be released to Available');
        }
    }

    @isTest
    static void testRollbackOnBatchFailure() {
        Ward__c ward = createWard('Ward Rollback Dis', 'WRD-RBD-01', 5, true);
        Bed__c bed1 = createBed(ward, 'Bed RBD-1', 'BED-RBD-1', 'Available');
        Doctor__c doc = createDoctor('Dr. Lawrence Kutner');
        Contact pat1 = createPatient('PatRollback1');

        Admission__c adm1 = admitPatientHelper(pat1, bed1, doc, 'Observation');

        // Request 1 is valid, Request 2 has fake admission ID
        AdmissionService.DischargeRequest validReq = new AdmissionService.DischargeRequest(adm1.Id, 'Valid summary');
        AdmissionService.DischargeRequest invalidReq = new AdmissionService.DischargeRequest('001000000000000AAA', 'Invalid ID');

        Test.startTest();
        Boolean batchFailed = false;
        try {
            AdmissionService.dischargePatients(new List<AdmissionService.DischargeRequest>{ validReq, invalidReq });
        } catch (AdmissionService.AdmissionException ex) {
            batchFailed = true;
        }
        Test.stopTest();

        System.assert(batchFailed, 'Batch must fail when one request is invalid');

        // Verify adm1 was rolled back and remains Admitted
        Admission__c queriedAdm = [SELECT Id, Status__c FROM Admission__c WHERE Id = :adm1.Id];
        System.assertEquals('Admitted', queriedAdm.Status__c, 'Admission status should be rolled back to Admitted');

        // Bed remains Occupied
        Bed__c queriedBed = [SELECT Id, Status__c FROM Bed__c WHERE Id = :bed1.Id];
        System.assertEquals('Occupied', queriedBed.Status__c, 'Bed status should remain Occupied');
    }

    @isTest
    static void testTerminalStateProtectionDirectDml() {
        Ward__c ward = createWard('Ward Terminal', 'WRD-TRM-01', 5, true);
        Bed__c bed = createBed(ward, 'Bed TRM-1', 'BED-TRM-1', 'Available');
        Doctor__c doc = createDoctor('Dr. Martha Masters');
        Contact pat = createPatient('PatTerminal');

        Admission__c adm = admitPatientHelper(pat, bed, doc, 'Observation');

        // Discharge admission
        AdmissionService.dischargePatient(new AdmissionService.DischargeRequest(adm.Id, 'Discharge summary.'));

        Test.startTest();
        // Attempt to reactivate discharged admission directly via DML
        Boolean reactivationBlocked = false;
        try {
            adm.Status__c = 'Admitted';
            update adm;
        } catch (DmlException ex) {
            reactivationBlocked = true;
            System.assert(ex.getMessage().contains('terminal'), 'Expected terminal state error: ' + ex.getMessage());
        }
        System.assert(reactivationBlocked, 'Direct DML cannot reactivate an already discharged admission');
        Test.stopTest();
    }

    @isTest
    static void testDischargedAdmissionBlocksEncountersAndVitals() {
        Ward__c ward = createWard('Ward Clinical Guard', 'WRD-CG-01', 5, true);
        Bed__c bed = createBed(ward, 'Bed CG-1', 'BED-CG-1', 'Available');
        Doctor__c doc = createDoctor('Dr. John Watson');
        Contact pat = createPatient('PatClinGuard');

        Admission__c adm = admitPatientHelper(pat, bed, doc, 'Observation');

        // Successfully discharge
        AdmissionService.dischargePatient(new AdmissionService.DischargeRequest(adm.Id, 'Routine discharge notes.'));

        Test.startTest();
        // 1. Attempt encounter on discharged admission
        Boolean encounterBlocked = false;
        try {
            ClinicalDocumentationService.EncounterRequest encReq = new ClinicalDocumentationService.EncounterRequest(
                adm.Id, doc.Id, System.now(), 'Complaint', 'Assessment', 'Notes'
            );
            ClinicalDocumentationService.createEncounter(encReq);
        } catch (ClinicalDocumentationService.ClinicalException ex) {
            encounterBlocked = true;
            System.assert(ex.getMessage().contains('inactive admission'), 'Expected inactive admission error: ' + ex.getMessage());
        }
        System.assert(encounterBlocked, 'ClinicalDocumentationService must reject encounters for discharged admissions');

        // 2. Attempt vitals on discharged admission
        Boolean vitalsBlocked = false;
        try {
            ClinicalDocumentationService.VitalRequest vReq = new ClinicalDocumentationService.VitalRequest(
                adm.Id, null, 98.6, 72, 16, 120, 80, 98, 70.0
            );
            ClinicalDocumentationService.recordVitals(vReq);
        } catch (ClinicalDocumentationService.ClinicalException ex) {
            vitalsBlocked = true;
            System.assert(ex.getMessage().contains('inactive admission'), 'Expected inactive admission error: ' + ex.getMessage());
        }
        System.assert(vitalsBlocked, 'ClinicalDocumentationService must reject vitals for discharged admissions');
        Test.stopTest();
    }

    @isTest
    static void testOverloadsAndEdgeCases() {
        Ward__c ward = createWard('Ward Edge', 'WRD-EDG-01', 5, true);
        Bed__c bed = createBed(ward, 'Bed EDG-1', 'BED-EDG-1', 'Available');
        Doctor__c doc = createDoctor('Dr. Amber Volakis');
        Contact pat = createPatient('PatEdge');

        Admission__c adm = admitPatientHelper(pat, bed, doc, 'Routine');

        Test.startTest();
        // Overload: dischargePatient(Id, Datetime, String, String, Id)
        Admission__c discharged = AdmissionService.dischargePatient(
            adm.Id, System.now(), 'Comprehensive summary', 'Referred to Specialist', doc.Id
        );
        System.assertEquals('Discharged', discharged.Status__c);
        System.assertEquals('Referred to Specialist', discharged.Discharge_Disposition__c);

        // Null request
        Boolean nullReqFailed = false;
        try {
            AdmissionService.dischargePatient((AdmissionService.DischargeRequest) null);
        } catch (AdmissionService.AdmissionException ex) {
            nullReqFailed = true;
        }
        System.assert(nullReqFailed, 'Null request must be rejected');

        // Null list
        Boolean nullListFailed = false;
        try {
            AdmissionService.dischargePatients((List<AdmissionService.DischargeRequest>) null);
        } catch (AdmissionService.AdmissionException ex) {
            nullListFailed = true;
        }
        System.assert(nullListFailed, 'Null list must be rejected');

        // Duplicate IDs in batch
        Boolean dupBatchFailed = false;
        try {
            AdmissionService.dischargePatients(new List<AdmissionService.DischargeRequest>{
                new AdmissionService.DischargeRequest(adm.Id, 'First'),
                new AdmissionService.DischargeRequest(adm.Id, 'Second')
            });
        } catch (AdmissionService.AdmissionException ex) {
            dupBatchFailed = true;
            System.assert(ex.getMessage().contains('Duplicate discharge request'), 'Expected duplicate in batch error');
        }
        System.assert(dupBatchFailed, 'Duplicate admission IDs in batch must be rejected');

        // Mark Discharge Pending on non-admitted
        Boolean invalidPendingFailed = false;
        try {
            AdmissionService.markDischargePending(adm.Id);
        } catch (AdmissionService.AdmissionException ex) {
            invalidPendingFailed = true;
            System.assert(ex.getMessage().contains('Only active Admitted patients'), 'Expected only admitted error');
        }
        System.assert(invalidPendingFailed, 'Cannot mark discharge pending on already discharged admission');

        // Null admissionId in markDischargePending
        Boolean nullPendingId = false;
        try {
            AdmissionService.markDischargePending(null);
        } catch (AdmissionService.AdmissionException ex) {
            nullPendingId = true;
        }
        System.assert(nullPendingId, 'Null ID in markDischargePending must be rejected');

        Test.stopTest();
    }

    private static User createTestUserWithPermissionSet(String permSetName, String aliasPrefix) {
        User u;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
            String uniqueName = 'cn' + aliasPrefix + Datetime.now().getTime() + Math.round(Math.random() * 10000) + '@testcarenest.org';
            u = new User(
                FirstName = 'Test',
                LastName = aliasPrefix + 'User',
                Email = uniqueName,
                Username = uniqueName,
                Alias = aliasPrefix.left(8),
                TimeZoneSidKey = 'America/Los_Angeles',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                ProfileId = p.Id,
                LanguageLocaleKey = 'en_US'
            );
            insert u;

            if (String.isNotBlank(permSetName)) {
                PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = :permSetName LIMIT 1];
                insert new PermissionSetAssignment(
                    AssigneeId = u.Id,
                    PermissionSetId = ps.Id
                );
            }
        }
        return u;
    }

    @isTest
    static void testAuthorizedDoctorDischargeAndBedRelease() {
        User docUser = createTestUserWithPermissionSet('CareNest_Doctor', 'docdis');

        Ward__c ward = createWard('Ward Auth Doc', 'WRD-AD-01', 5, true);
        Bed__c bed = createBed(ward, 'Bed AD-1', 'BED-AD-1', 'Available');
        Doctor__c attendingDoc = createDoctor('Dr. Gregory House');
        Doctor__c dischargingDoc = createDoctor('Dr. James Wilson');
        Contact pat = createPatient('PatAuthDoc');

        Admission__c adm = admitPatientHelper(pat, bed, attendingDoc, 'Pneumonia observation');

        // Confirm bed is occupied before discharge
        Bed__c bOccupied = [SELECT Id, Status__c FROM Bed__c WHERE Id = :bed.Id];
        System.assertEquals('Occupied', bOccupied.Status__c, 'Bed must be Occupied after admission');

        Test.startTest();
        Admission__c dischargedAdm;
        System.runAs(docUser) {
            AdmissionService.DischargeRequest dReq = new AdmissionService.DischargeRequest(
                adm.Id,
                System.now(),
                'Patient recovered well and is medically stable for home discharge.',
                'Home',
                dischargingDoc.Id
            );
            dischargedAdm = AdmissionService.dischargePatient(dReq);
        }
        Test.stopTest();

        System.assertNotEquals(null, dischargedAdm, 'Discharge should succeed under authorized doctor');
        System.assertEquals('Discharged', dischargedAdm.Status__c, 'Status should transition to Discharged');

        // Verify persisted admission fields
        Admission__c queriedAdm = [
            SELECT Id, Status__c, Discharge_Date__c, Discharge_Summary__c, Discharge_Disposition__c, Discharging_Doctor__c
            FROM Admission__c
            WHERE Id = :adm.Id
        ];
        System.assertEquals('Discharged', queriedAdm.Status__c);
        System.assert(queriedAdm.Discharge_Summary__c.contains('medically stable'));
        System.assertEquals('Home', queriedAdm.Discharge_Disposition__c);

        // Verify bed is released to Available via system context helper
        Bed__c bReleased = [SELECT Id, Status__c FROM Bed__c WHERE Id = :bed.Id];
        System.assertEquals('Available', bReleased.Status__c, 'Bed must be released to Available even though doctor lacks Bed edit permission');
    }

    @isTest
    static void testUnauthorizedUserDischargeRejected() {
        User unauthUser = createTestUserWithPermissionSet(null, 'unauth');

        Ward__c ward = createWard('Ward Unauth', 'WRD-UA-01', 5, true);
        Bed__c bed = createBed(ward, 'Bed UA-1', 'BED-UA-1', 'Available');
        Doctor__c doc = createDoctor('Dr. Eric Foreman');
        Contact pat = createPatient('PatUnauth');

        Admission__c adm = admitPatientHelper(pat, bed, doc, 'Observation');

        Test.startTest();
        Boolean dischargeBlocked = false;
        System.runAs(unauthUser) {
            try {
                AdmissionService.DischargeRequest dReq = new AdmissionService.DischargeRequest(
                    adm.Id,
                    System.now(),
                    'Unauthorized discharge attempt by front desk.',
                    'Home',
                    doc.Id
                );
                AdmissionService.dischargePatient(dReq);
            } catch (AdmissionService.AdmissionException ex) {
                dischargeBlocked = true;
                System.assert(ex.getMessage().contains('Insufficient permissions'), 'Expected permissions error: ' + ex.getMessage());
            }
        }
        Test.stopTest();

        System.assert(dischargeBlocked, 'Unauthorized user must be rejected from performing discharge');

        // Verify admission is still Admitted and bed is still Occupied
        Admission__c queriedAdm = [SELECT Id, Status__c FROM Admission__c WHERE Id = :adm.Id];
        System.assertEquals('Admitted', queriedAdm.Status__c, 'Admission must remain Admitted');

        Bed__c queriedBed = [SELECT Id, Status__c FROM Bed__c WHERE Id = :bed.Id];
        System.assertEquals('Occupied', queriedBed.Status__c, 'Bed must remain Occupied');
    }

    @isTest
    static void testWardManagementCannotDischargeWithoutSummaryFLS() {
        User wardUser = createTestUserWithPermissionSet('CareNest_Ward_Management', 'wardusr');

        Ward__c ward = createWard('Ward Staff Guard', 'WRD-WG-01', 5, true);
        Bed__c bed = createBed(ward, 'Bed WG-1', 'BED-WG-1', 'Available');
        Doctor__c doc = createDoctor('Dr. Robert Chase');
        Contact pat = createPatient('PatWardGuard');

        Admission__c adm = admitPatientHelper(pat, bed, doc, 'Pre-op observation');

        Test.startTest();
        Boolean dischargeBlocked = false;
        System.runAs(wardUser) {
            try {
                AdmissionService.DischargeRequest dReq = new AdmissionService.DischargeRequest(
                    adm.Id,
                    System.now(),
                    'Ward staff attempting clinical discharge summary update.',
                    'Home',
                    doc.Id
                );
                AdmissionService.dischargePatient(dReq);
            } catch (AdmissionService.AdmissionException ex) {
                dischargeBlocked = true;
                System.assert(ex.getMessage().contains('Insufficient permissions') || ex.getMessage().contains('field-level security'),
                    'Expected FLS permission error: ' + ex.getMessage());
            }
        }
        Test.stopTest();

        System.assert(dischargeBlocked, 'Ward staff lacking Discharge_Summary__c edit FLS must not be able to discharge');

        // Confirm admission remains Admitted
        Admission__c queriedAdm = [SELECT Id, Status__c FROM Admission__c WHERE Id = :adm.Id];
        System.assertEquals('Admitted', queriedAdm.Status__c);
    }

    @isTest
    static void testAuthorizedDoctorCanMarkDischargePending() {
        User docUser = createTestUserWithPermissionSet('CareNest_Doctor', 'docpnd');

        Ward__c ward = createWard('Ward Pen Guard', 'WRD-PG-01', 5, true);
        Bed__c bed = createBed(ward, 'Bed PG-1', 'BED-PG-1', 'Available');
        Doctor__c doc = createDoctor('Dr. Chris Taub');
        Contact pat = createPatient('PatPenGuard');

        Admission__c adm = admitPatientHelper(pat, bed, doc, 'Observation for pending');

        Test.startTest();
        Admission__c pendingAdm;
        System.runAs(docUser) {
            pendingAdm = AdmissionService.markDischargePending(adm.Id);
        }
        Test.stopTest();

        System.assertEquals('Discharge Pending', pendingAdm.Status__c, 'Status must transition to Discharge Pending');

        // Bed must remain Occupied
        Bed__c bStillOccupied = [SELECT Id, Status__c FROM Bed__c WHERE Id = :bed.Id];
        System.assertEquals('Occupied', bStillOccupied.Status__c, 'Bed must remain Occupied while Discharge Pending');
    }

    @isTest
    static void testUnauthorizedUserCannotMarkDischargePending() {
        User unauthUser = createTestUserWithPermissionSet(null, 'unpnd');

        Ward__c ward = createWard('Ward Pen Block', 'WRD-PB-01', 5, true);
        Bed__c bed = createBed(ward, 'Bed PB-1', 'BED-PB-1', 'Available');
        Doctor__c doc = createDoctor('Dr. Remy Hadley');
        Contact pat = createPatient('PatPenBlock');

        Admission__c adm = admitPatientHelper(pat, bed, doc, 'Observation for block');

        Test.startTest();
        Boolean pendingBlocked = false;
        System.runAs(unauthUser) {
            try {
                AdmissionService.markDischargePending(adm.Id);
            } catch (AdmissionService.AdmissionException ex) {
                pendingBlocked = true;
                System.assert(ex.getMessage().contains('Insufficient permissions'), 'Expected permissions error: ' + ex.getMessage());
            }
        }
        Test.stopTest();

        System.assert(pendingBlocked, 'Unauthorized user cannot mark discharge pending');

        Admission__c queriedAdm = [SELECT Id, Status__c FROM Admission__c WHERE Id = :adm.Id];
        System.assertEquals('Admitted', queriedAdm.Status__c, 'Admission must remain Admitted');
    }
}
