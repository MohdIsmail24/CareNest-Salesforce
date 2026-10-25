/**
 * @description Senior Solution Architect End-to-End Inpatient Lifecycle Verification Test (Phase 12.6).
 * Explicitly verifies all 12 core lifecycle and safety scenarios:
 * 1. Active Ward and Available Bed setup.
 * 2. Patient admission to the bed.
 * 3. Bed occupancy transition to Occupied.
 * 4. Inpatient encounter creation linked to admission.
 * 5. Multiple vitals recorded linked to encounter and admission.
 * 6. Rejection of encounters and vitals on discharged or cancelled admissions.
 * 7. Transition to Discharge Pending with bed remaining occupied.
 * 8. Authoritative discharge with required clinical details.
 * 9. Status transition to Discharged and safe bed release to Available.
 * 10. Protection against reactivation and post-discharge documentation.
 * 11. Bed isolation ensuring discharge does not release another admission's bed.
 * 12. Physiological range validation, status transition guards, and inconsistent bed state detection.
 */
@isTest
private class InpatientLifecycleE2ETest {

    private static Integer seq = 9500;

    private static Doctor__c createDoctor(String name) {
        seq++;
        Doctor__c doc = new Doctor__c(
            Name = name,
            Registration_No__c = 'REG-E2E-' + seq,
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
            Email = lastName.toLowerCase() + seq + '@carenest-e2e.org',
            Phone = '555444' + seq,
            Patient_Code__c = 'PAT-E2E-' + seq
        );
        insert c;
        return c;
    }

    private static Ward__c createWard(String name, String code, Integer capacity, Boolean isActive) {
        Ward__c ward = new Ward__c(
            Name = name,
            Ward_Code__c = code,
            Ward_Type__c = 'General',
            Floor__c = '4',
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

    /**
     * @description Scenario 1 through 10: Complete continuous lifecycle chain from admission to discharge and post-discharge safeguards.
     */
    @isTest
    static void testCompleteContinuousInpatientLifecycle() {
        // 1. Create an active ward and available bed
        Ward__c ward = createWard('Ward East', 'WRD-E-01', 10, true);
        Bed__c bed = createBed(ward, 'Bed E-101', 'BED-E-101', 'Available');
        Doctor__c attendingDoctor = createDoctor('Dr. Gregory House');
        Doctor__c dischargingDoctor = createDoctor('Dr. James Wilson');
        Contact patient = createPatient('PatLifecycle');

        Test.startTest();

        // 2. Admit a synthetic patient to the bed
        AdmissionService.AdmissionRequest admReq = new AdmissionService.AdmissionRequest(
            patient.Id,
            bed.Id,
            attendingDoctor.Id,
            System.now().addDays(-3),
            'Acute respiratory distress syndrome evaluation',
            null
        );
        Admission__c admission = AdmissionService.admitPatient(admReq);

        // 3. Confirm the bed becomes Occupied and Admission is Admitted
        System.assertNotEquals(null, admission.Id, 'Admission must be created');
        System.assertEquals('Admitted', admission.Status__c, 'Admission status must be Admitted');
        Bed__c queriedBed = [SELECT Id, Status__c FROM Bed__c WHERE Id = :bed.Id];
        System.assertEquals('Occupied', queriedBed.Status__c, 'Bed must transition to Occupied upon admission');

        // 4. Create an inpatient encounter linked to the admission
        ClinicalDocumentationService.EncounterRequest encReq = new ClinicalDocumentationService.EncounterRequest(
            admission.Id,
            attendingDoctor.Id,
            System.now().addDays(-2),
            'Persistent dyspnea and productive cough',
            'Bilateral basal crackles, improving with bronchodilators',
            'Patient resting in semi-Fowler position. Supplemental O2 2L via nasal cannula.'
        );
        Inpatient_Encounter__c encounter = ClinicalDocumentationService.createEncounter(encReq);
        System.assertNotEquals(null, encounter.Id, 'Encounter must be created');
        System.assertEquals(admission.Id, encounter.Admission__c, 'Encounter must link to admission');
        System.assertEquals(attendingDoctor.Id, encounter.Attending_Doctor__c, 'Attending doctor must match');
        System.assertEquals(attendingDoctor.Id, encounter.Doctor__c, 'Doctor alias must be synchronized');

        // 5. Record multiple vital observations linked to the encounter and same admission
        ClinicalDocumentationService.VitalRequest v1 = new ClinicalDocumentationService.VitalRequest(
            admission.Id,
            encounter.Id,
            99.2,   // Temperature
            88,     // Pulse
            20,     // RR
            128,    // Systolic
            84,     // Diastolic
            96,     // SpO2
            74.5    // Weight
        );
        v1.notes = 'Morning vitals check';

        ClinicalDocumentationService.VitalRequest v2 = new ClinicalDocumentationService.VitalRequest(
            admission.Id,
            encounter.Id,
            98.6,
            76,
            16,
            120,
            80,
            98,
            74.5
        );
        v2.notes = 'Evening vitals check - afebrile';

        List<Patient_Vital__c> vitals = ClinicalDocumentationService.recordVitals(new List<ClinicalDocumentationService.VitalRequest>{ v1, v2 });
        System.assertEquals(2, vitals.size(), 'Two vital observations should be recorded');
        for (Patient_Vital__c v : vitals) {
            System.assertEquals(admission.Id, v.Admission__c, 'Vitals must link to admission');
            System.assertEquals(encounter.Id, v.Inpatient_Encounter__c, 'Vitals must link to encounter');
        }

        // 7. Mark the admission Discharge Pending; confirm the bed remains occupied
        Admission__c pendingAdmission = AdmissionService.markDischargePending(admission.Id);
        System.assertEquals('Discharge Pending', pendingAdmission.Status__c, 'Admission must transition to Discharge Pending');
        Bed__c bedDuringPending = [SELECT Id, Status__c FROM Bed__c WHERE Id = :bed.Id];
        System.assertEquals('Occupied', bedDuringPending.Status__c, 'Bed must remain Occupied while in Discharge Pending');

        // 8. Discharge the admission with required clinical details
        Datetime dischargeTimestamp = System.now();
        AdmissionService.DischargeRequest dischReq = new AdmissionService.DischargeRequest(
            admission.Id,
            dischargeTimestamp,
            'Patient recovered. Lungs clear to auscultation. Completed 5-day course. Discharged with follow-up in OPD.',
            'Home',
            dischargingDoctor.Id
        );
        Admission__c dischargedAdmission = AdmissionService.dischargePatient(dischReq);

        // 9. Confirm the admission is Discharged and the correct bed becomes Available
        System.assertEquals('Discharged', dischargedAdmission.Status__c, 'Admission must transition to Discharged');
        Admission__c finalAdmQuery = [
            SELECT Id, Status__c, Discharge_Date__c, Discharge_Summary__c, Discharge_Disposition__c, Discharging_Doctor__c
            FROM Admission__c
            WHERE Id = :admission.Id
        ];
        System.assertEquals('Discharged', finalAdmQuery.Status__c, 'Admission status must be Discharged');
        System.assertEquals(dischargeTimestamp, finalAdmQuery.Discharge_Date__c, 'Discharge date must match');
        System.assertEquals('Home', finalAdmQuery.Discharge_Disposition__c, 'Disposition must be Home');
        System.assertEquals(dischargingDoctor.Id, finalAdmQuery.Discharging_Doctor__c, 'Discharging doctor must match');

        Bed__c bedAfterDischarge = [SELECT Id, Status__c FROM Bed__c WHERE Id = :bed.Id];
        System.assertEquals('Available', bedAfterDischarge.Status__c, 'Bed must transition to Available after discharge');

        // 10. Confirm the discharged admission cannot be reactivated or receive new encounters/vitals
        // 10a. Reactivation rejection via direct DML
        Boolean reactivateFailed = false;
        try {
            finalAdmQuery.Status__c = 'Admitted';
            update finalAdmQuery;
        } catch (DmlException ex) {
            reactivateFailed = true;
            System.assert(ex.getMessage().contains('terminal'), 'Expected terminal state error: ' + ex.getMessage());
        }
        System.assert(reactivateFailed, 'Discharged admission cannot be reactivated');

        // 10b. Reject new encounter on discharged admission
        Boolean newEncFailed = false;
        try {
            ClinicalDocumentationService.createEncounter(new ClinicalDocumentationService.EncounterRequest(
                admission.Id, attendingDoctor.Id, System.now(), 'Complaint post-discharge', 'Assessment', 'Notes'
            ));
        } catch (ClinicalDocumentationService.ClinicalException ex) {
            newEncFailed = true;
            System.assert(ex.getMessage().contains('inactive admission'), 'Expected inactive admission error');
        }
        System.assert(newEncFailed, 'Encounter on discharged admission must be rejected');

        // 10c. Reject new vitals on discharged admission
        Boolean newVitalsFailed = false;
        try {
            ClinicalDocumentationService.recordVitals(new ClinicalDocumentationService.VitalRequest(
                admission.Id, null, 98.6, 72, 16, 120, 80, 98, 70.0
            ));
        } catch (ClinicalDocumentationService.ClinicalException ex) {
            newVitalsFailed = true;
            System.assert(ex.getMessage().contains('inactive admission'), 'Expected inactive admission error');
        }
        System.assert(newVitalsFailed, 'Vitals on discharged admission must be rejected');

        Test.stopTest();
    }

    /**
     * @description Scenario 6: Rejection of encounters or vitals on cancelled admissions.
     */
    @isTest
    static void testCancelledAdmissionRejection() {
        Ward__c ward = createWard('Ward West', 'WRD-W-01', 5, true);
        Bed__c bed = createBed(ward, 'Bed W-101', 'BED-W-101', 'Available');
        Doctor__c doc = createDoctor('Dr. Allison Cameron');
        Contact pat = createPatient('PatCancelledE2E');

        Admission__c adm = AdmissionService.admitPatient(new AdmissionService.AdmissionRequest(
            pat.Id, bed.Id, doc.Id, System.now().addDays(-1), 'Pre-op cancel', null
        ));

        // Cancel admission
        adm.Status__c = 'Cancelled';
        update adm;

        Test.startTest();
        // 6a. Reject encounter on cancelled admission
        Boolean encBlocked = false;
        try {
            ClinicalDocumentationService.createEncounter(new ClinicalDocumentationService.EncounterRequest(
                adm.Id, doc.Id, System.now(), 'Complaint', 'Assessment', 'Notes'
            ));
        } catch (ClinicalDocumentationService.ClinicalException ex) {
            encBlocked = true;
            System.assert(ex.getMessage().contains('inactive admission'), 'Expected inactive admission error');
        }
        System.assert(encBlocked, 'Encounter on cancelled admission must be rejected');

        // 6b. Reject vitals on cancelled admission
        Boolean vitalsBlocked = false;
        try {
            ClinicalDocumentationService.recordVitals(new ClinicalDocumentationService.VitalRequest(
                adm.Id, null, 98.6, 72, 16, 120, 80, 98, 70.0
            ));
        } catch (ClinicalDocumentationService.ClinicalException ex) {
            vitalsBlocked = true;
            System.assert(ex.getMessage().contains('inactive admission'), 'Expected inactive admission error');
        }
        System.assert(vitalsBlocked, 'Vitals on cancelled admission must be rejected');

        Test.stopTest();
    }

    /**
     * @description Scenario 11: Confirm a different active admission's bed cannot be released by this discharge operation.
     */
    @isTest
    static void testBedIsolationBetweenAdmissions() {
        Ward__c ward = createWard('Ward South', 'WRD-S-01', 5, true);
        Bed__c bed1 = createBed(ward, 'Bed S-101', 'BED-S-101', 'Available');
        Bed__c bed2 = createBed(ward, 'Bed S-102', 'BED-S-102', 'Available');
        Doctor__c doc = createDoctor('Dr. Eric Foreman');
        Contact pat1 = createPatient('PatIso1');
        Contact pat2 = createPatient('PatIso2');

        Admission__c adm1 = AdmissionService.admitPatient(new AdmissionService.AdmissionRequest(
            pat1.Id, bed1.Id, doc.Id, System.now().addDays(-2), 'Observation 1', null
        ));
        Admission__c adm2 = AdmissionService.admitPatient(new AdmissionService.AdmissionRequest(
            pat2.Id, bed2.Id, doc.Id, System.now().addDays(-2), 'Observation 2', null
        ));

        Test.startTest();
        // Discharge only admission 1
        AdmissionService.dischargePatient(new AdmissionService.DischargeRequest(
            adm1.Id, System.now(), 'Discharge summary for admission 1', 'Home', doc.Id
        ));
        Test.stopTest();

        // Verify Bed 1 is Available, but Bed 2 is strictly preserved as Occupied
        Bed__c b1 = [SELECT Id, Status__c FROM Bed__c WHERE Id = :bed1.Id];
        Bed__c b2 = [SELECT Id, Status__c FROM Bed__c WHERE Id = :bed2.Id];
        System.assertEquals('Available', b1.Status__c, 'Bed 1 must be released to Available');
        System.assertEquals('Occupied', b2.Status__c, 'Bed 2 must remain Occupied by admission 2');

        // Confirm admission 2 remains Admitted
        Admission__c queriedAdm2 = [SELECT Id, Status__c FROM Admission__c WHERE Id = :adm2.Id];
        System.assertEquals('Admitted', queriedAdm2.Status__c, 'Admission 2 must remain Admitted');
    }

    /**
     * @description Scenario 12: Invalid vital ranges, invalid status transitions, and inconsistent bed states rejected.
     */
    @isTest
    static void testValidationRulesAndInvalidStateRejection() {
        Ward__c ward = createWard('Ward Central', 'WRD-C-01', 5, true);
        Bed__c bed = createBed(ward, 'Bed C-101', 'BED-C-101', 'Available');
        Doctor__c doc = createDoctor('Dr. Robert Chase');
        Contact pat = createPatient('PatRangesE2E');

        Admission__c adm = AdmissionService.admitPatient(new AdmissionService.AdmissionRequest(
            pat.Id, bed.Id, doc.Id, System.now().addDays(-1), 'Range test', null
        ));

        Test.startTest();

        // 12a. Invalid vital range: Systolic BP <= Diastolic BP
        Boolean bpFailed = false;
        try {
            ClinicalDocumentationService.recordVitals(new ClinicalDocumentationService.VitalRequest(
                adm.Id, null, 98.6, 72, 16, 70, 110, 98, 70.0
            ));
        } catch (ClinicalDocumentationService.ClinicalException ex) {
            bpFailed = true;
            System.assert(ex.getMessage().contains('Systolic BP'), 'Expected systolic error');
        }
        System.assert(bpFailed, 'Inverted BP must be rejected');

        // 12b. Invalid vital range: Temperature > 110
        Boolean tempFailed = false;
        try {
            ClinicalDocumentationService.recordVitals(new ClinicalDocumentationService.VitalRequest(
                adm.Id, null, 115.0, 72, 16, 120, 80, 98, 70.0
            ));
        } catch (ClinicalDocumentationService.ClinicalException ex) {
            tempFailed = true;
            System.assert(ex.getMessage().contains('Temperature'), 'Expected temp error');
        }
        System.assert(tempFailed, 'Extreme temperature must be rejected');

        // 12c. Inconsistent bed state: Bed is not Occupied when attempting discharge
        bed.Status__c = 'Cleaning';
        update bed;

        Boolean dischInconsistentFailed = false;
        try {
            AdmissionService.dischargePatient(new AdmissionService.DischargeRequest(
                adm.Id, System.now(), 'Discharge summary', 'Home', doc.Id
            ));
        } catch (AdmissionService.AdmissionException ex) {
            dischInconsistentFailed = true;
            System.assert(ex.getMessage().contains('Inconsistent record state'), 'Expected inconsistent state error: ' + ex.getMessage());
        }
        System.assert(dischInconsistentFailed, 'Discharge on non-occupied bed must be rejected');

        Test.stopTest();
    }
}
