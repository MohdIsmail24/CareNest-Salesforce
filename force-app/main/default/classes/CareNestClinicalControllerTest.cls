@IsTest
private class CareNestClinicalControllerTest {

    @TestSetup
    static void setupTestData() {
        Ward__c ward = new Ward__c(
            Name = 'Clinical Test Ward',
            Ward_Code__c = 'CN-WRD-CLN',
            Ward_Type__c = 'ICU',
            Capacity__c = 5,
            Floor__c = '1'
        );
        insert ward;

        Bed__c bed = new Bed__c(Name = 'Bed CLN-1', Bed_Code__c = 'CLN-01', Ward__c = ward.Id, Status__c = 'Available');
        insert bed;

        Doctor__c doc = new Doctor__c(
            Name = 'Dr. Test Clinician',
            Department__c = 'General Medicine',
            Registration_No__c = 'REG-CLN-01',
            Is_Active__c = true,
            Consultation_Fee__c = 750
        );
        insert doc;

        Contact patient = new Contact(LastName = 'Dev Malhotra', Phone = '9876543210');
        insert patient;

        Admission__c adm = new Admission__c(
            Contact__c = patient.Id,
            Bed__c = bed.Id,
            Attending_Doctor__c = doc.Id,
            Admission_Date__c = System.now(),
            Status__c = 'Admitted',
            Reason__c = 'ICU Respiratory Monitoring'
        );
        insert adm;

        Inpatient_Encounter__c enc = new Inpatient_Encounter__c(
            Admission__c = adm.Id,
            Attending_Doctor__c = doc.Id,
            Encounter_Date__c = System.now(),
            Encounter_Type__c = 'Daily Ward Round',
            Status__c = 'Completed',
            Chief_Complaint__c = 'Dyspnea and chest discomfort',
            Clinical_Notes__c = 'Patient under close monitoring. Oxygen support ongoing.',
            Assessment__c = 'Cardiorespiratory distress. Monitor vitals closely.'
        );
        insert enc;

        Patient_Vital__c vit = new Patient_Vital__c(
            Admission__c = adm.Id,
            Inpatient_Encounter__c = enc.Id,
            Vital_Code__c = 'CN-D10-VIT-007',
            Recorded_Date__c = System.now(),
            Systolic_BP__c = 195,
            Diastolic_BP__c = 115,
            Pulse_BPM__c = 135,
            Temperature_C__c = 39.2,
            SpO2_Percent__c = 86,
            Oxygen_Saturation__c = 86,
            Respiratory_Rate__c = 30,
            Notes__c = 'Critical ICU vital: Severe hypoxemia and hypertensive crisis.'
        );
        insert vit;
    }

    @IsTest
    static void testClinicalEncountersAndVitals() {
        Admission__c adm = [SELECT Id FROM Admission__c LIMIT 1];

        Test.startTest();
        List<CareNestClinicalController.ClinicalEncounterDto> encs = CareNestClinicalController.getEncounters(adm.Id);
        List<CareNestClinicalController.PatientVitalDto> vitals = CareNestClinicalController.getVitals(adm.Id);
        CareNestClinicalController.AdmissionClinicalBundleDto bundle = CareNestClinicalController.getAdmissionClinicalBundle(adm.Id);
        CareNestClinicalController.PatientVitalDto icuVital = CareNestClinicalController.getDevMalhotraIcuVital();
        Test.stopTest();

        Assert.areEqual(1, encs.size(), 'Should return 1 encounter');
        Assert.areEqual(1, vitals.size(), 'Should return 1 vital record');
        Assert.isNotNull(bundle, 'Bundle should not be null');
        Assert.isTrue(bundle.hasActiveAlert, 'Should detect active abnormal alert');
        Assert.isNotNull(icuVital.id, 'Should locate Dev Malhotra ICU vital');
        Assert.isTrue(icuVital.alertFlag, 'Dev Malhotra ICU vital must have alertFlag true');
    }

    @IsTest
    static void testAddEncounterNote() {
        Admission__c adm = [SELECT Id FROM Admission__c LIMIT 1];

        Test.startTest();
        Map<String, Object> res = CareNestClinicalController.addEncounterNote(adm.Id, 'Consultation', 'Consulting physician note.', 'Stable.');
        Test.stopTest();

        Assert.areEqual(true, res.get('success'), 'Should create encounter note');
    }

    @IsTest
    static void testInpatientWorkspaceAndRecordVitals() {
        Admission__c adm = [SELECT Id FROM Admission__c LIMIT 1];

        Test.startTest();
        List<CareNestClinicalController.InpatientCardDto> cards = CareNestClinicalController.getInpatientAdmissions('');
        CareNestClinicalController.ClinicalOperationResultDto vRes = CareNestClinicalController.recordVital(
            adm.Id, 120, 80, 72, 36.8, 98, 16, 'Routine stable vital.'
        );
        CareNestClinicalController.ClinicalOperationResultDto eRes = CareNestClinicalController.createEncounter(
            adm.Id, 'Daily Ward Round', 'Follow up check', 'Chest clear.', 'Discharge planning.'
        );
        Test.stopTest();

        Assert.isFalse(cards.isEmpty(), 'Should return inpatient cards');
        Assert.isTrue(vRes.isSuccess, 'Should record vital');
        Assert.isTrue(eRes.isSuccess, 'Should create encounter');
    }

    @IsTest
    static void testAcknowledgeAndResolveVitalAlert() {
        Admission__c adm = [SELECT Id FROM Admission__c LIMIT 1];
        Patient_Vital__c vit = [SELECT Id FROM Patient_Vital__c WHERE Alert_Flag__c = true LIMIT 1];

        Test.startTest();
        // 1. Acknowledge Alert
        CareNestClinicalController.PatientVitalDto ackDto = CareNestClinicalController.acknowledgeVitalAlert(
            vit.Id, 'Nurse acknowledged ICU hypertensive crisis.'
        );

        // 2. Resolve Alert
        CareNestClinicalController.PatientVitalDto resDto = CareNestClinicalController.resolveVitalAlert(
            vit.Id, 'Administered IV labetalol and titrated high-flow nasal cannula. Hemodynamics stabilized.'
        );

        // 3. Verify bundle no longer flags active alert
        CareNestClinicalController.AdmissionClinicalBundleDto bundle = CareNestClinicalController.getAdmissionClinicalBundle(adm.Id);

        // 4. Verify dashboard metrics exclude resolved alert
        CareNestDashboardController.DashboardMetricsDto dashMetrics = CareNestDashboardController.getDashboardMetrics();
        Test.stopTest();

        Assert.areEqual('Acknowledged', ackDto.alertStatus, 'Alert status must transition to Acknowledged');
        Assert.isNotNull(ackDto.acknowledgedAt, 'Acknowledged timestamp must be set');

        Assert.areEqual('Resolved', resDto.alertStatus, 'Alert status must transition to Resolved');
        Assert.isNotNull(resDto.resolvedAt, 'Resolved timestamp must be set');
        Assert.isTrue(resDto.resolutionNotes.contains('labetalol'), 'Resolution notes preserved');

        Assert.isFalse(bundle.hasActiveAlert, 'Resolved alert must clear hasActiveAlert flag on patient bundle');
        Assert.areEqual(0, dashMetrics.activeClinicalAlerts, 'Resolved alerts must be excluded from active clinical alerts count');
    }

    @IsTest
    static void testResolveVitalAlertRequiresNotes() {
        Patient_Vital__c vit = [SELECT Id FROM Patient_Vital__c WHERE Alert_Flag__c = true LIMIT 1];
        Boolean caught = false;
        try {
            CareNestClinicalController.resolveVitalAlert(vit.Id, '   ');
        } catch (AuraHandledException e) {
            caught = true;
        }
        Assert.isTrue(caught, 'Resolving without notes must throw an AuraHandledException');
    }
}
