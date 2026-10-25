/**
 * @description Isolated Five-Persona Apex Security Test Suite for CareNest Phase 24.
 * Exercises genuine Salesforce least-privilege security boundaries using System.runAs()
 * across Front Desk, Doctor, Nurse, Ward Management, and Operations Manager.
 *
 * Explicitly asserts:
 *  - Object-level and Field-level security (CRUD/FLS describes)
 *  - WITH USER_MODE query rejection on shielded records
 *  - User-mode DML and controller authorization
 *  - Cross-patient billing privacy enforcement
 *  - Zero mutation of production data (isolated test records only)
 */
@IsTest
private class CareNestStaffSecurityTest {

    private static Integer userSequence = 9300;

    /**
     * @description Test setup creating synthetic hospital foundation records.
     * All records are test-isolated and automatically rolled back after execution.
     */
    @TestSetup
    static void setupHospitalData() {
        Ward__c testWard = new Ward__c(
            Name = 'Security Test Ward',
            Ward_Code__c = 'SEC-WRD-01',
            Ward_Type__c = 'General',
            Capacity__c = 10,
            Floor__c = '1'
        );
        insert testWard;

        Bed__c testBed = new Bed__c(
            Name = 'Sec Bed 01',
            Bed_Code__c = 'SEC-BED-01',
            Ward__c = testWard.Id,
            Status__c = 'Available',
            Daily_Charge__c = 1000,
            Floor__c = 1
        );
        insert testBed;

        Doctor__c testDoc = new Doctor__c(
            Name = 'Dr. Security Examiner',
            Department__c = 'General Medicine',
            Specialty__c = 'Internal Medicine',
            Registration_No__c = 'SEC-REG-01',
            Is_Active__c = true,
            Consultation_Fee__c = 500
        );
        insert testDoc;

        Account testAcc = new Account(Name = 'CareNest Security Test Hospital');
        insert testAcc;

        Contact testPatient = new Contact(
            AccountId = testAcc.Id,
            FirstName = 'Synthetic',
            LastName = 'SecPatient',
            Email = 'synthetic.secpatient@carenest.test.invalid',
            Phone = '5551119999',
            Patient_Code__c = 'CN-SEC-001'
        );
        insert testPatient;

        Admission__c testAdm = new Admission__c(
            Contact__c = testPatient.Id,
            Patient__c = testPatient.Id,
            Bed__c = testBed.Id,
            Doctor__c = testDoc.Id,
            Attending_Doctor__c = testDoc.Id,
            Admission_Date__c = System.now().addDays(-2),
            Status__c = 'Admitted',
            Admission_Type__c = 'Planned',
            Reason__c = 'Security isolation verification'
        );
        insert testAdm;

        Inpatient_Encounter__c testEnc = new Inpatient_Encounter__c(
            Admission__c = testAdm.Id,
            Doctor__c = testDoc.Id,
            Attending_Doctor__c = testDoc.Id,
            Encounter_Date__c = System.now().addDays(-1),
            Encounter_Type__c = 'Daily Ward Round',
            Status__c = 'Completed',
            Chief_Complaint__c = 'Routine clinical check',
            Clinical_Notes__c = 'CONFIDENTIAL CLINICAL NOTE: Patient recovering well.',
            Assessment__c = 'Stable'
        );
        insert testEnc;

        Patient_Vital__c testVit = new Patient_Vital__c(
            Admission__c = testAdm.Id,
            Recorded_Date__c = System.now().addHours(-4),
            Recorded_At__c = System.now().addHours(-4),
            Systolic_BP__c = 120,
            Diastolic_BP__c = 80,
            Pulse__c = 72,
            Pulse_BPM__c = 72,
            Temperature__c = 98.4,
            Temperature_C__c = 36.9,
            Oxygen_Saturation__c = 98,
            SpO2_Percent__c = 98,
            Respiratory_Rate__c = 16,
            Notes__c = 'Normal vitals'
        );
        insert testVit;
    }

    /**
     * @description Helper to provision a transient test user with an assigned permission set.
     * Uses Standard User profile which supports all permission set capabilities in unit tests.
     */
    private static User createPersonaUser(String aliasPrefix, String permSetName) {
        User runningUser = new User(Id = UserInfo.getUserId());
        User u;
        System.runAs(runningUser) {
            userSequence++;
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
            String uniqueName = aliasPrefix + userSequence + '@test.carenest.security.invalid';
            u = new User(
                LastName = 'SecTest' + aliasPrefix,
                Email = uniqueName,
                Username = uniqueName,
                Alias = (aliasPrefix + userSequence).left(8),
                TimeZoneSidKey = 'America/Los_Angeles',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                ProfileId = p.Id,
                LanguageLocaleKey = 'en_US',
                IsActive = true
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

    // =========================================================================
    // 1. FRONT DESK PERSONA SECURITY TESTS
    // =========================================================================

    @IsTest
    static void testFrontDesk_AuthorizedRegistrationAndLookup() {
        User fdUser = createPersonaUser('fd', 'CareNest_Front_Desk');

        System.runAs(fdUser) {
            // Assert CRUD describes
            System.assertEquals(true, Contact.SObjectType.getDescribe().isAccessible(), 'Front desk must have Read on Contact');
            System.assertEquals(true, Contact.SObjectType.getDescribe().isCreateable(), 'Front desk must have Create on Contact');
            System.assertEquals(true, Admission__c.SObjectType.getDescribe().isCreateable(), 'Front desk must have Create on Admission');

            // Assert authorized patient search via controller
            List<CareNestAdmissionController.PatientLookupDto> patients = CareNestAdmissionController.searchPatients('SecPatient');
            System.assertNotEquals(0, patients.size(), 'Front desk must be able to search registered patients');
            System.assertEquals('Synthetic SecPatient', patients[0].name, 'Front desk must see correct patient name');
        }
    }

    @IsTest
    static void testFrontDesk_DeniedClinicalEncountersAndVitals() {
        User fdUser = createPersonaUser('fd', 'CareNest_Front_Desk');

        System.runAs(fdUser) {
            // Assert FLS and Object describes deny clinical records
            System.assertEquals(false, Inpatient_Encounter__c.SObjectType.getDescribe().isAccessible(),
                'Front desk must NOT have read access to Inpatient Encounters');
            System.assertEquals(false, Patient_Vital__c.SObjectType.getDescribe().isAccessible(),
                'Front desk must NOT have read access to Patient Vitals');

            // Assert query with USER_MODE fails closed
            Boolean exceptionCaught = false;
            try {
                List<Inpatient_Encounter__c> encs = [
                    SELECT Id, Clinical_Notes__c 
                    FROM Inpatient_Encounter__c 
                    WITH USER_MODE
                ];
                System.assertEquals(0, encs.size(), 'If query succeeds without error, zero clinical encounters must be returned');
            } catch (System.QueryException qe) {
                exceptionCaught = true;
                System.debug('Front Desk USER_MODE query correctly blocked: ' + qe.getMessage());
            }
            // One of either: QueryException thrown, or 0 records accessible
            System.assert(exceptionCaught || !Inpatient_Encounter__c.SObjectType.getDescribe().isAccessible(),
                'Front desk must be blocked from clinical encounters');
        }
    }

    // =========================================================================
    // 2. DOCTOR PERSONA SECURITY TESTS
    // =========================================================================

    @IsTest
    static void testDoctor_AuthorizedClinicalWorkspaceAccess() {
        User docUser = createPersonaUser('doc', 'CareNest_Doctor');
        Admission__c adm = [SELECT Id FROM Admission__c LIMIT 1];

        System.runAs(docUser) {
            // Assert CRUD describes
            System.assertEquals(true, Inpatient_Encounter__c.SObjectType.getDescribe().isAccessible(), 'Doctor must have read on encounters');
            System.assertEquals(true, Inpatient_Encounter__c.SObjectType.getDescribe().isCreateable(), 'Doctor must have create on encounters');
            System.assertEquals(true, Patient_Vital__c.SObjectType.getDescribe().isAccessible(), 'Doctor must have read on vitals');
            System.assertEquals(true, Patient_Vital__c.SObjectType.getDescribe().isCreateable(), 'Doctor must have create on vitals');

            Doctor__c testDoc = [SELECT Id FROM Doctor__c LIMIT 1];
            Inpatient_Encounter__c docEnc = new Inpatient_Encounter__c(
                Admission__c = adm.Id,
                Doctor__c = testDoc.Id,
                Attending_Doctor__c = testDoc.Id,
                Encounter_Date__c = System.now(),
                Encounter_Type__c = 'Daily Ward Round',
                Chief_Complaint__c = 'Clinical workspace round',
                Clinical_Notes__c = 'CONFIDENTIAL CLINICAL NOTE: Patient recovering well.',
                Assessment__c = 'Stable'
            );
            insert docEnc;

            // Assert authorized clinical query WITH USER_MODE on fields granted by CareNest_Doctor
            List<Inpatient_Encounter__c> encs = [
                SELECT Id, Encounter_Type__c, Chief_Complaint__c, Clinical_Notes__c, Assessment__c
                FROM Inpatient_Encounter__c
                WHERE Admission__c = :adm.Id
                WITH USER_MODE
            ];
            System.assertNotEquals(0, encs.size(), 'Doctor must retrieve inpatient encounters');
            System.assertEquals('CONFIDENTIAL CLINICAL NOTE: Patient recovering well.', encs[0].Clinical_Notes__c,
                'Doctor must have access to clinical notes for treatment');
        }
    }

    @IsTest
    static void testDoctor_DeniedHospitalFinancialPayments() {
        User docUser = createPersonaUser('doc', 'CareNest_Doctor');

        System.runAs(docUser) {
            // Assert Doctor is denied payment billing ledger
            System.assertEquals(false, Payment__c.SObjectType.getDescribe().isAccessible(),
                'Doctor must NOT have access to financial payments');

            Boolean paymentBlocked = false;
            try {
                List<Payment__c> payments = [
                    SELECT Id, Amount__c 
                    FROM Payment__c 
                    WITH USER_MODE
                ];
                System.assertEquals(0, payments.size(), 'Doctors must not see payment records');
            } catch (System.QueryException qe) {
                paymentBlocked = true;
            }
            System.assert(paymentBlocked || !Payment__c.SObjectType.getDescribe().isAccessible(),
                'Doctor must be blocked from accessing hospital financial ledger');
        }
    }

    // =========================================================================
    // 3. NURSE PERSONA SECURITY TESTS
    // =========================================================================

    @IsTest
    static void testNurse_AuthorizedVitalsAndRounds() {
        User nurseUser = createPersonaUser('nur', 'CareNest_Nurse');
        Admission__c adm = [SELECT Id FROM Admission__c LIMIT 1];
        Inpatient_Encounter__c enc = [SELECT Id FROM Inpatient_Encounter__c WHERE Admission__c = :adm.Id LIMIT 1];
        Patient_Vital__c vit = [SELECT Id FROM Patient_Vital__c WHERE Admission__c = :adm.Id LIMIT 1];

        // Share clinical records with Nurse user for shift care
        insert new Inpatient_Encounter__Share(
            ParentId = enc.Id,
            UserOrGroupId = nurseUser.Id,
            AccessLevel = 'Read',
            RowCause = 'Manual'
        );
        insert new Patient_Vital__Share(
            ParentId = vit.Id,
            UserOrGroupId = nurseUser.Id,
            AccessLevel = 'Read',
            RowCause = 'Manual'
        );

        System.runAs(nurseUser) {
            // Assert CRUD describes
            System.assertEquals(true, Patient_Vital__c.SObjectType.getDescribe().isAccessible(), 'Nurse must read vitals');
            System.assertEquals(true, Patient_Vital__c.SObjectType.getDescribe().isCreateable(), 'Nurse must record vitals');
            System.assertEquals(true, Inpatient_Encounter__c.SObjectType.getDescribe().isAccessible(), 'Nurse must read encounters');
            System.assertEquals(true, Admission__c.SObjectType.getDescribe().isAccessible(), 'Nurse must read admissions');

            // 1. Nurse queries active admission WITH USER_MODE
            List<Admission__c> admissions = [
                SELECT Id, Status__c, Admission_Type__c
                FROM Admission__c
                WHERE Id = :adm.Id
                WITH USER_MODE
            ];
            System.assertEquals(1, admissions.size(), 'Nurse must be able to view inpatient admission');

            // 2. Nurse queries daily ward rounds WITH USER_MODE on fields granted by CareNest_Nurse
            List<Inpatient_Encounter__c> rounds = [
                SELECT Id, Encounter_Type__c, Notes__c
                FROM Inpatient_Encounter__c
                WHERE Id = :enc.Id
                WITH USER_MODE
            ];
            System.assertEquals(1, rounds.size(), 'Nurse must be able to view daily ward round');

            // 3. Nurse queries patient vitals WITH USER_MODE on fields granted by CareNest_Nurse
            List<Patient_Vital__c> vitals = [
                SELECT Id, Systolic_BP__c, Diastolic_BP__c, Pulse_BPM__c, Temperature_C__c, SpO2_Percent__c
                FROM Patient_Vital__c
                WHERE Id = :vit.Id
                WITH USER_MODE
            ];
            System.assertEquals(1, vitals.size(), 'Nurse must be able to view patient vitals');
            System.assertEquals(120, vitals[0].Systolic_BP__c, 'Nurse must see correct systolic BP');
        }
    }

    @IsTest
    static void testNurse_DeniedFinancialLedgerAndScheduling() {
        User nurseUser = createPersonaUser('nur', 'CareNest_Nurse');

        System.runAs(nurseUser) {
            // Assert Nurse has zero permissions on Payment__c and Appointment__c
            System.assertEquals(false, Payment__c.SObjectType.getDescribe().isAccessible(),
                'Nurse must NOT have access to hospital payments');
            System.assertEquals(false, Appointment__c.SObjectType.getDescribe().isAccessible(),
                'Nurse must NOT have access to OPD appointment scheduling');

            Boolean queryBlocked = false;
            try {
                List<Payment__c> pList = [SELECT Id FROM Payment__c WITH USER_MODE];
                System.assertEquals(0, pList.size(), 'Nurse cannot read payments');
            } catch (System.QueryException qe) {
                queryBlocked = true;
            }
            System.assert(queryBlocked || !Payment__c.SObjectType.getDescribe().isAccessible(),
                'Payment queries must fail closed for Nurse role');
        }
    }

    // =========================================================================
    // 4. WARD MANAGEMENT PERSONA SECURITY TESTS
    // =========================================================================

    @IsTest
    static void testWardManagement_AuthorizedBedAndWardOperations() {
        User wardUser = createPersonaUser('wrd', 'CareNest_Ward_Management');

        System.runAs(wardUser) {
            // Assert CRUD describes
            System.assertEquals(true, Bed__c.SObjectType.getDescribe().isAccessible(), 'Ward Manager must read beds');
            System.assertEquals(true, Bed__c.SObjectType.getDescribe().isUpdateable(), 'Ward Manager must update bed statuses');
            System.assertEquals(true, Ward__c.SObjectType.getDescribe().isAccessible(), 'Ward Manager must read wards');
            System.assertEquals(true, Admission__c.SObjectType.getDescribe().isAccessible(), 'Ward Manager must view admissions');

            // Assert ward availability controller
            List<CareNestAdmissionController.WardAvailabilityDto> wards = CareNestAdmissionController.getWardsWithAvailability();
            System.assertNotEquals(0, wards.size(), 'Ward Manager must retrieve live ward availability');
        }
    }

    @IsTest
    static void testWardManagement_DeniedClinicalEncounterCreationAndPayments() {
        User wardUser = createPersonaUser('wrd', 'CareNest_Ward_Management');

        System.runAs(wardUser) {
            // Assert Ward Manager cannot create clinical encounters
            System.assertEquals(false, Inpatient_Encounter__c.SObjectType.getDescribe().isCreateable(),
                'Ward Manager must NOT be permitted to create clinical encounters');
            System.assertEquals(false, Payment__c.SObjectType.getDescribe().isAccessible(),
                'Ward Manager must NOT have access to payment ledger');
        }
    }

    // =========================================================================
    // 5. OPERATIONS MANAGER PERSONA SECURITY TESTS
    // =========================================================================

    @IsTest
    static void testOperationsManager_AuthorizedAppointmentsAndDoctors() {
        User opsUser = createPersonaUser('ops', 'CareNest_Ops_Manager');

        System.runAs(opsUser) {
            // Assert CRUD describes
            System.assertEquals(true, Appointment__c.SObjectType.getDescribe().isAccessible(), 'Ops Manager must read appointments');
            System.assertEquals(true, Appointment__c.SObjectType.getDescribe().isCreateable(), 'Ops Manager must create appointments');
            System.assertEquals(true, Doctor__c.SObjectType.getDescribe().isAccessible(), 'Ops Manager must read doctors');
            System.assertEquals(true, Payment__c.SObjectType.getDescribe().isAccessible(), 'Ops Manager must read payments');

            // Assert doctor availability resolution
            List<CareNestAdmissionController.DoctorAvailabilityDto> docs = CareNestAdmissionController.getDoctorsWithAvailability(null, null);
            System.assertNotEquals(0, docs.size(), 'Ops Manager must see doctor schedules');
        }
    }

    @IsTest
    static void testOperationsManager_DeniedClinicalNotesAndVitals() {
        User opsUser = createPersonaUser('ops', 'CareNest_Ops_Manager');

        System.runAs(opsUser) {
            // Assert Ops Manager cannot access inpatient encounters or vitals
            System.assertEquals(false, Inpatient_Encounter__c.SObjectType.getDescribe().isAccessible(),
                'Ops Manager must NOT have access to inpatient clinical encounters');
            System.assertEquals(false, Patient_Vital__c.SObjectType.getDescribe().isAccessible(),
                'Ops Manager must NOT have access to inpatient vitals');

            Boolean clinicalBlocked = false;
            try {
                List<Inpatient_Encounter__c> encs = [SELECT Id, Clinical_Notes__c FROM Inpatient_Encounter__c WITH USER_MODE];
                System.assertEquals(0, encs.size(), 'Ops manager cannot view clinical encounters');
            } catch (System.QueryException qe) {
                clinicalBlocked = true;
            }
            System.assert(clinicalBlocked || !Inpatient_Encounter__c.SObjectType.getDescribe().isAccessible(),
                'Clinical encounters must fail closed for Ops Manager');
        }
    }

    // =========================================================================
    // 6. CROSS-PATIENT & DIRECT URL RESTRICTION TESTS
    // =========================================================================

    @IsTest
    static void testCrossPatientBillingIsolation() {
        // Create an appointment for Patient A
        Doctor__c doc = [SELECT Id FROM Doctor__c LIMIT 1];
        Appointment_Slot__c slot = new Appointment_Slot__c(
            Doctor__c = doc.Id,
            Slot_Start__c = System.now().addDays(3),
            Mode__c = 'OPD',
            Total_Capacity__c = 5,
            Booked_Count__c = 1
        );
        insert slot;

        Contact patientA = [SELECT Id FROM Contact LIMIT 1];

        Account acc = [SELECT Id FROM Account LIMIT 1];
        Contact patientB = new Contact(
            AccountId = acc.Id,
            FirstName = 'Unrelated',
            LastName = 'PatientB',
            Email = 'patientb@test.invalid'
        );
        insert patientB;

        Appointment__c appt = new Appointment__c(
            Patient__c = patientA.Id,
            Slot__c = slot.Id,
            Status__c = 'Confirmed',
            Fee_Amount__c = 500
        );
        insert appt;

        // Set mock contact to Patient B and assert cross-patient billing details call throws
        DoctorSearchController.mockContactId = patientB.Id;

        Boolean exceptionThrown = false;
        try {
            Appointment__c result = DoctorSearchController.getBillingDetails(appt.Id);
        } catch (AuraHandledException ahe) {
            exceptionThrown = true;
            System.debug('Cross-patient access properly blocked by controller: ' + ahe.getMessage());
        } finally {
            DoctorSearchController.mockContactId = null;
        }

        System.assertEquals(true, exceptionThrown,
            'Controller must throw AuraHandledException when patient attempts to view another patient billing record');
    }
}
