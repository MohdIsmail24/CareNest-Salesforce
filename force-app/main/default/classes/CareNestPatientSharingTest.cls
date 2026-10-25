/**
 * @description Isolated Apex Security & Patient-Sharing Test Suite for CareNest Stage 2.
 * Exercises all authorized hospital staff personas and strict assigned-ward access policies
 * with SeeAllData=false:
 *
 *  1. Nurse assigned to Ward A can find Ward A patient.
 *  2. Nurse assigned to Ward A cannot find Ward B patient.
 *  3. Nurse with no ward assignments sees zero patients.
 *  4. Nurse with inactive ward assignment sees zero patients.
 *  5. Ward Management assigned to Ward B can find Ward B patient.
 *  6. Ward Management assigned to Ward B cannot find Ward A patient.
 *  7. Ward Management with no ward assignment sees zero patients.
 *  8. User assigned to multiple wards sees patients only from those assigned wards.
 *  9. Exact patient code cannot bypass ward assignment.
 * 10. Direct Contact ID cannot bypass authorization or care relationships.
 * 11. Discharged patients are excluded when no active eligible admission exists.
 * 12. Patient admission transfer or bed/ward change changes eligible visibility correctly.
 * 13. Staff cannot self-create or modify ward assignments without authorization.
 * 14. Front Desk authorized broad intake search by name and code.
 * 15. Doctor access strictly limited to assigned patients (unassigned patient code blocked).
 * 16. Operations Manager permitted operational access to patient demographics and appointments.
 * 17. Sales / HR / Unrelated internal users strictly denied (zero records).
 * 18. Guest and external patient sessions strictly denied.
 * 19. Sensitive clinical and vitals field access denied without FLS.
 * 20. Mass patient enumeration prevented (short terms rejected, results capped at 15).
 * 21. New registration creates an unlinked orphan Contact (AccountId == null).
 * 22. End-to-end patient registration and bed admission workflow completes.
 * 23. Sequential patient codes remain unique with concurrency retry and duplicate detection.
 */
@IsTest
private class CareNestPatientSharingTest {

    private static Integer userSequence = 9800;

    @TestSetup
    static void setupTestData() {
        // 1. Two Active Hospital Wards
        Ward__c testWardA = new Ward__c(
            Name = 'Sharing Test Ward A',
            Ward_Code__c = 'SEC-WRD-01',
            Ward_Type__c = 'General',
            Capacity__c = 10,
            Floor__c = '1',
            Is_Active__c = true
        );
        Ward__c testWardB = new Ward__c(
            Name = 'Sharing Test Ward B',
            Ward_Code__c = 'SEC-WRD-02',
            Ward_Type__c = 'ICU',
            Capacity__c = 5,
            Floor__c = '2',
            Is_Active__c = true
        );
        insert new List<Ward__c>{ testWardA, testWardB };

        // 2. Active Hospital Beds in Wards A and B
        Bed__c bedA1 = new Bed__c(
            Name = 'Sec Bed A1',
            Bed_Code__c = 'SEC-BED-A1',
            Ward__c = testWardA.Id,
            Status__c = 'Available',
            Daily_Charge__c = 1000,
            Floor__c = 1,
            Is_Active__c = true
        );
        Bed__c bedA2 = new Bed__c(
            Name = 'Sec Bed A2',
            Bed_Code__c = 'SEC-BED-A2',
            Ward__c = testWardA.Id,
            Status__c = 'Available',
            Daily_Charge__c = 1000,
            Floor__c = 1,
            Is_Active__c = true
        );
        Bed__c bedB1 = new Bed__c(
            Name = 'Sec Bed B1',
            Bed_Code__c = 'SEC-BED-B1',
            Ward__c = testWardB.Id,
            Status__c = 'Available',
            Daily_Charge__c = 2000,
            Floor__c = 2,
            Is_Active__c = true
        );
        insert new List<Bed__c>{ bedA1, bedA2, bedB1 };

        // 3. Doctor
        Doctor__c testDoc = new Doctor__c(
            Name = 'Dr. Sharing Specialist',
            Department__c = 'General Medicine',
            Specialty__c = 'Internal Medicine',
            Registration_No__c = 'SHR-DOC-01',
            Is_Active__c = true,
            Consultation_Fee__c = 500
        );
        insert testDoc;

        // 4. Patient Contacts (Unlinked orphan Contacts under ControlledByParent)
        Contact patientA = new Contact(
            FirstName = 'Synthetic',
            LastName = 'SecPatientA',
            Email = 'patient.a@carenest.test.invalid',
            Phone = '5551119999',
            Patient_Code__c = 'CN-SEC-001'
        );
        Contact patientB = new Contact(
            FirstName = 'Synthetic',
            LastName = 'SecPatientB',
            Email = 'patient.b@carenest.test.invalid',
            Phone = '5552229999',
            Patient_Code__c = 'CN-SEC-002'
        );
        insert new List<Contact>{ patientA, patientB };

        // 5. Active Inpatient Admissions: Patient A in Ward A, Patient B in Ward B
        Admission__c admA = new Admission__c(
            Contact__c = patientA.Id,
            Patient__c = patientA.Id,
            Bed__c = bedA1.Id,
            Doctor__c = testDoc.Id,
            Attending_Doctor__c = testDoc.Id,
            Admission_Date__c = System.now().addDays(-2),
            Status__c = 'Admitted',
            Admission_Type__c = 'Planned',
            Reason__c = 'Ward A care isolation'
        );
        Admission__c admB = new Admission__c(
            Contact__c = patientB.Id,
            Patient__c = patientB.Id,
            Bed__c = bedB1.Id,
            Doctor__c = testDoc.Id,
            Attending_Doctor__c = testDoc.Id,
            Admission_Date__c = System.now().addDays(-1),
            Status__c = 'Admitted',
            Admission_Type__c = 'Emergency',
            Reason__c = 'Ward B care isolation'
        );
        insert new List<Admission__c>{ admA, admB };

        // 6. Clinical Encounter for Patient A
        Inpatient_Encounter__c testEnc = new Inpatient_Encounter__c(
            Admission__c = admA.Id,
            Doctor__c = testDoc.Id,
            Attending_Doctor__c = testDoc.Id,
            Encounter_Date__c = System.now().addDays(-1),
            Encounter_Type__c = 'Daily Ward Round',
            Status__c = 'Completed',
            Chief_Complaint__c = 'Routine check',
            Clinical_Notes__c = 'CONFIDENTIAL CLINICAL NOTE: Patient recovering well.',
            Assessment__c = 'Stable'
        );
        insert testEnc;

        // 7. Patient Vital for Patient A
        Patient_Vital__c testVit = new Patient_Vital__c(
            Admission__c = admA.Id,
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

        // 8. Appointment Slot and Appointment for Patient A
        Appointment_Slot__c slot = new Appointment_Slot__c(
            Doctor__c = testDoc.Id,
            Slot_Start__c = System.now().addDays(3),
            Mode__c = 'OPD',
            Total_Capacity__c = 5,
            Booked_Count__c = 1
        );
        insert slot;

        Appointment__c appt = new Appointment__c(
            Patient__c = patientA.Id,
            Slot__c = slot.Id,
            Status__c = 'Confirmed',
            Fee_Amount__c = 500
        );
        insert appt;
    }

    /**
     * @description Provisions a synthetic test user with an assigned permission set.
     */
    private static User createPersonaUser(String aliasPrefix, String permSetName) {
        User runningUser = new User(Id = UserInfo.getUserId());
        User u;
        System.runAs(runningUser) {
            userSequence++;
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
            String uniqueName = aliasPrefix + userSequence + '@test.carenest.wardsec.invalid';
            u = new User(
                LastName = 'WardSec' + aliasPrefix,
                Email = uniqueName,
                Username = uniqueName,
                Alias = (aliasPrefix + userSequence).left(8),
                TimeZoneSidKey = 'America/Los_Angeles',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'en_US',
                ProfileId = p.Id
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
        if (String.isNotBlank(permSetName)) {
            CareNestPatientAccessService.mockUserPermissionSets = new Set<String>{ permSetName };
        } else {
            CareNestPatientAccessService.mockUserPermissionSets = new Set<String>();
        }
        CareNestPatientAccessService.mockAssignedWardIds = null;
        return u;
    }

    // =========================================================================
    // SCENARIO 1: NURSE ASSIGNED TO WARD A CAN FIND WARD A PATIENT
    // =========================================================================
    @IsTest
    static void test01_NurseAssignedToWardACanFindWardAPatient() {
        User nurseUser = createPersonaUser('nurA', 'CareNest_Nurse');
        Ward__c wardA = [SELECT Id FROM Ward__c WHERE Ward_Code__c = 'SEC-WRD-01' LIMIT 1];
        Contact patientA = [SELECT Id, OwnerId FROM Contact WHERE Patient_Code__c = 'CN-SEC-001' LIMIT 1];
        patientA.OwnerId = nurseUser.Id;
        update patientA;

        // Assign nurseUser to Ward A actively
        insert new CareNest_Staff_Ward_Assignment__c(
            Staff_User__c = nurseUser.Id,
            Ward__c = wardA.Id,
            Is_Active__c = true
        );

        System.runAs(nurseUser) {
            List<CareNestAdmissionController.PatientLookupDto> res = CareNestAdmissionController.searchPatients('SecPatientA');
            System.assertEquals(1, res.size(), 'Nurse assigned to Ward A must find active admitted Ward A patient');
            System.assertEquals('CN-SEC-001', res[0].patientCode);
        }
    }

    // =========================================================================
    // SCENARIO 2: NURSE ASSIGNED TO WARD A CANNOT FIND WARD B PATIENT
    // =========================================================================
    @IsTest
    static void test02_NurseAssignedToWardACannotFindWardBPatient() {
        User nurseUser = createPersonaUser('nurA2', 'CareNest_Nurse');
        Ward__c wardA = [SELECT Id FROM Ward__c WHERE Ward_Code__c = 'SEC-WRD-01' LIMIT 1];
        Contact patientB = [SELECT Id, OwnerId FROM Contact WHERE Patient_Code__c = 'CN-SEC-002' LIMIT 1];
        patientB.OwnerId = nurseUser.Id;
        update patientB;

        // Assign nurseUser strictly to Ward A
        insert new CareNest_Staff_Ward_Assignment__c(
            Staff_User__c = nurseUser.Id,
            Ward__c = wardA.Id,
            Is_Active__c = true
        );

        System.runAs(nurseUser) {
            List<CareNestAdmissionController.PatientLookupDto> res = CareNestAdmissionController.searchPatients('SecPatientB');
            System.assertEquals(0, res.size(), 'Nurse assigned to Ward A cannot find patient admitted in Ward B');
        }
    }

    // =========================================================================
    // SCENARIO 3: NURSE WITH NO WARD ASSIGNMENT SEES ZERO PATIENTS
    // =========================================================================
    @IsTest
    static void test03_NurseWithNoWardAssignmentSeesZeroPatients() {
        User nurseUser = createPersonaUser('nurNo', 'CareNest_Nurse');
        Contact patientA = [SELECT Id, OwnerId FROM Contact WHERE Patient_Code__c = 'CN-SEC-001' LIMIT 1];
        patientA.OwnerId = nurseUser.Id;
        update patientA;

        // Zero assignments created for nurseUser

        System.runAs(nurseUser) {
            List<CareNestAdmissionController.PatientLookupDto> res = CareNestAdmissionController.searchPatients('SecPatientA');
            System.assertEquals(0, res.size(), 'Nurse with no ward assignment must receive 0 patient results');
        }
    }

    // =========================================================================
    // SCENARIO 4: NURSE WITH INACTIVE WARD ASSIGNMENT SEES ZERO PATIENTS
    // =========================================================================
    @IsTest
    static void test04_NurseWithInactiveWardAssignmentSeesZeroPatients() {
        User nurseUser = createPersonaUser('nurInact', 'CareNest_Nurse');
        Ward__c wardA = [SELECT Id FROM Ward__c WHERE Ward_Code__c = 'SEC-WRD-01' LIMIT 1];
        Contact patientA = [SELECT Id, OwnerId FROM Contact WHERE Patient_Code__c = 'CN-SEC-001' LIMIT 1];
        patientA.OwnerId = nurseUser.Id;
        update patientA;

        // Inactive assignment
        insert new CareNest_Staff_Ward_Assignment__c(
            Staff_User__c = nurseUser.Id,
            Ward__c = wardA.Id,
            Is_Active__c = false
        );

        System.runAs(nurseUser) {
            List<CareNestAdmissionController.PatientLookupDto> res = CareNestAdmissionController.searchPatients('SecPatientA');
            System.assertEquals(0, res.size(), 'Nurse with inactive ward assignment must receive 0 patient results');
        }
    }

    // =========================================================================
    // SCENARIO 5: WARD MANAGEMENT ASSIGNED TO WARD B CAN FIND WARD B PATIENT
    // =========================================================================
    @IsTest
    static void test05_WardManagementAssignedToWardBCanFindWardBPatient() {
        User wardUser = createPersonaUser('wrdB', 'CareNest_Ward_Management');
        Ward__c wardB = [SELECT Id FROM Ward__c WHERE Ward_Code__c = 'SEC-WRD-02' LIMIT 1];
        Contact patientB = [SELECT Id, OwnerId FROM Contact WHERE Patient_Code__c = 'CN-SEC-002' LIMIT 1];
        patientB.OwnerId = wardUser.Id;
        update patientB;

        insert new CareNest_Staff_Ward_Assignment__c(
            Staff_User__c = wardUser.Id,
            Ward__c = wardB.Id,
            Is_Active__c = true
        );

        System.runAs(wardUser) {
            List<CareNestAdmissionController.PatientLookupDto> res = CareNestAdmissionController.searchPatients('SecPatientB');
            System.assertEquals(1, res.size(), 'Ward Management assigned to Ward B must find Ward B admitted patient');
            System.assertEquals('CN-SEC-002', res[0].patientCode);
        }
    }

    // =========================================================================
    // SCENARIO 6: WARD MANAGEMENT ASSIGNED TO WARD B CANNOT FIND WARD A PATIENT
    // =========================================================================
    @IsTest
    static void test06_WardManagementAssignedToWardBCannotFindWardAPatient() {
        User wardUser = createPersonaUser('wrdB2', 'CareNest_Ward_Management');
        Ward__c wardB = [SELECT Id FROM Ward__c WHERE Ward_Code__c = 'SEC-WRD-02' LIMIT 1];
        Contact patientA = [SELECT Id, OwnerId FROM Contact WHERE Patient_Code__c = 'CN-SEC-001' LIMIT 1];
        patientA.OwnerId = wardUser.Id;
        update patientA;

        insert new CareNest_Staff_Ward_Assignment__c(
            Staff_User__c = wardUser.Id,
            Ward__c = wardB.Id,
            Is_Active__c = true
        );

        System.runAs(wardUser) {
            List<CareNestAdmissionController.PatientLookupDto> res = CareNestAdmissionController.searchPatients('SecPatientA');
            System.assertEquals(0, res.size(), 'Ward Management assigned to Ward B cannot find Ward A patient');
        }
    }

    // =========================================================================
    // SCENARIO 7: WARD MANAGEMENT WITH NO ASSIGNMENT SEES ZERO PATIENTS
    // =========================================================================
    @IsTest
    static void test07_WardManagementWithNoAssignmentSeesZeroPatients() {
        User wardUser = createPersonaUser('wrdNo', 'CareNest_Ward_Management');
        Contact patientB = [SELECT Id, OwnerId FROM Contact WHERE Patient_Code__c = 'CN-SEC-002' LIMIT 1];
        patientB.OwnerId = wardUser.Id;
        update patientB;

        // Zero assignments created

        System.runAs(wardUser) {
            List<CareNestAdmissionController.PatientLookupDto> res = CareNestAdmissionController.searchPatients('SecPatientB');
            System.assertEquals(0, res.size(), 'Ward Management with no ward assignments must receive 0 patient results');
        }
    }

    // =========================================================================
    // SCENARIO 8: USER ASSIGNED TO MULTIPLE WARDS SEES ONLY THOSE WARDS
    // =========================================================================
    @IsTest
    static void test08_UserAssignedToMultipleWardsSeesPatientsOnlyFromThoseWards() {
        Ward__c wardA = [SELECT Id FROM Ward__c WHERE Ward_Code__c = 'SEC-WRD-01' LIMIT 1];
        Ward__c wardB = [SELECT Id FROM Ward__c WHERE Ward_Code__c = 'SEC-WRD-02' LIMIT 1];

        // Create Ward C, Bed C, and Patient C
        Ward__c wardC = new Ward__c(
            Name = 'Sharing Test Ward C',
            Ward_Code__c = 'SEC-WRD-03',
            Ward_Type__c = 'Private',
            Capacity__c = 4,
            Floor__c = '3',
            Is_Active__c = true
        );
        insert wardC;

        Bed__c bedC = new Bed__c(
            Name = 'Sec Bed C1',
            Bed_Code__c = 'SEC-BED-C1',
            Ward__c = wardC.Id,
            Status__c = 'Available',
            Daily_Charge__c = 1500,
            Floor__c = 3,
            Is_Active__c = true
        );
        insert bedC;

        Contact patientC = new Contact(
            FirstName = 'Synthetic',
            LastName = 'SecPatientC',
            Patient_Code__c = 'CN-SEC-003'
        );
        insert patientC;

        Doctor__c doc = [SELECT Id FROM Doctor__c LIMIT 1];
        insert new Admission__c(
            Contact__c = patientC.Id,
            Patient__c = patientC.Id,
            Bed__c = bedC.Id,
            Doctor__c = doc.Id,
            Attending_Doctor__c = doc.Id,
            Admission_Date__c = System.now(),
            Status__c = 'Admitted',
            Reason__c = 'Ward C care'
        );

        User multiUser = createPersonaUser('multi', 'CareNest_Nurse');
        patientC.OwnerId = multiUser.Id;
        update patientC;
        Contact pA = [SELECT Id, OwnerId FROM Contact WHERE Patient_Code__c = 'CN-SEC-001' LIMIT 1];
        pA.OwnerId = multiUser.Id;
        update pA;
        Contact pB = [SELECT Id, OwnerId FROM Contact WHERE Patient_Code__c = 'CN-SEC-002' LIMIT 1];
        pB.OwnerId = multiUser.Id;
        update pB;

        // Assign user to Ward A and Ward B ONLY
        insert new List<CareNest_Staff_Ward_Assignment__c>{
            new CareNest_Staff_Ward_Assignment__c(Staff_User__c = multiUser.Id, Ward__c = wardA.Id, Is_Active__c = true),
            new CareNest_Staff_Ward_Assignment__c(Staff_User__c = multiUser.Id, Ward__c = wardB.Id, Is_Active__c = true)
        };

        System.runAs(multiUser) {
            List<CareNestAdmissionController.PatientLookupDto> resA = CareNestAdmissionController.searchPatients('SecPatientA');
            System.assertEquals(1, resA.size(), 'User sees Patient A from assigned Ward A');

            List<CareNestAdmissionController.PatientLookupDto> resB = CareNestAdmissionController.searchPatients('SecPatientB');
            System.assertEquals(1, resB.size(), 'User sees Patient B from assigned Ward B');

            List<CareNestAdmissionController.PatientLookupDto> resC = CareNestAdmissionController.searchPatients('SecPatientC');
            System.assertEquals(0, resC.size(), 'User CANNOT see Patient C from unassigned Ward C');
        }
    }

    // =========================================================================
    // SCENARIO 9: EXACT PATIENT CODE CANNOT BYPASS WARD ASSIGNMENT
    // =========================================================================
    @IsTest
    static void test09_ExactPatientCodeCannotBypassWardAssignment() {
        User nurseUser = createPersonaUser('nurBypass', 'CareNest_Nurse');
        Ward__c wardA = [SELECT Id FROM Ward__c WHERE Ward_Code__c = 'SEC-WRD-01' LIMIT 1];
        Contact patientB = [SELECT Id, OwnerId FROM Contact WHERE Patient_Code__c = 'CN-SEC-002' LIMIT 1];
        patientB.OwnerId = nurseUser.Id;
        update patientB;

        // Assign nurse strictly to Ward A
        insert new CareNest_Staff_Ward_Assignment__c(
            Staff_User__c = nurseUser.Id,
            Ward__c = wardA.Id,
            Is_Active__c = true
        );

        System.runAs(nurseUser) {
            // Patient B is in Ward B; search by exact patient code must return 0
            List<CareNestAdmissionController.PatientLookupDto> res = CareNestAdmissionController.searchPatients('CN-SEC-002');
            System.assertEquals(0, res.size(), 'Exact Patient Code cannot bypass ward assignment boundary');
        }
    }

    // =========================================================================
    // SCENARIO 10: DIRECT CONTACT ID CANNOT BYPASS WARD ASSIGNMENT
    // =========================================================================
    @IsTest
    static void test10_DirectContactIdCannotBypassWardAssignment() {
        Contact patientB = [SELECT Id FROM Contact WHERE Patient_Code__c = 'CN-SEC-002' LIMIT 1];
        Appointment__c appt = [SELECT Id FROM Appointment__c LIMIT 1];

        // Probe billing detail using unowned/unassigned patient B ID
        DoctorSearchController.mockContactId = patientB.Id;
        Boolean accessRejected = false;
        try {
            DoctorSearchController.getBillingDetails(appt.Id);
        } catch (AuraHandledException ahe) {
            accessRejected = true;
        } finally {
            DoctorSearchController.mockContactId = null;
        }
        System.assertEquals(true, accessRejected, 'Direct probe without authorized relationship must be rejected');
    }

    // =========================================================================
    // SCENARIO 11: DISCHARGED PATIENTS EXCLUDED WHEN NO ACTIVE ADMISSION
    // =========================================================================
    @IsTest
    static void test11_DischargedPatientsExcludedWhenNoActiveAdmission() {
        User nurseUser = createPersonaUser('nurDisch', 'CareNest_Nurse');
        Ward__c wardA = [SELECT Id FROM Ward__c WHERE Ward_Code__c = 'SEC-WRD-01' LIMIT 1];
        Contact patientA = [SELECT Id, OwnerId FROM Contact WHERE Patient_Code__c = 'CN-SEC-001' LIMIT 1];
        patientA.OwnerId = nurseUser.Id;
        update patientA;

        // Assign nurse to Ward A
        insert new CareNest_Staff_Ward_Assignment__c(
            Staff_User__c = nurseUser.Id,
            Ward__c = wardA.Id,
            Is_Active__c = true
        );

        // Discharge Patient A
        Admission__c admA = [SELECT Id, Status__c, Discharge_Date__c FROM Admission__c WHERE Patient__c = :patientA.Id LIMIT 1];
        admA.Status__c = 'Discharged';
        admA.Discharge_Date__c = System.now();
        update admA;

        System.runAs(nurseUser) {
            List<CareNestAdmissionController.PatientLookupDto> res = CareNestAdmissionController.searchPatients('SecPatientA');
            System.assertEquals(0, res.size(), 'Discharged patient in assigned ward must not be visible as active inpatient');
        }
    }

    // =========================================================================
    // SCENARIO 12: PATIENT BED/WARD TRANSFER UPDATES VISIBILITY CORRECTLY
    // =========================================================================
    @IsTest
    static void test12_PatientBedTransferUpdatesVisibilityCorrectly() {
        User nurseUser = createPersonaUser('nurTrf', 'CareNest_Nurse');
        Ward__c wardA = [SELECT Id FROM Ward__c WHERE Ward_Code__c = 'SEC-WRD-01' LIMIT 1];
        Bed__c bedA2 = [SELECT Id FROM Bed__c WHERE Bed_Code__c = 'SEC-BED-A2' LIMIT 1];
        Contact patientB = [SELECT Id, OwnerId FROM Contact WHERE Patient_Code__c = 'CN-SEC-002' LIMIT 1];
        patientB.OwnerId = nurseUser.Id;
        update patientB;

        // Assign nurse strictly to Ward A
        insert new CareNest_Staff_Ward_Assignment__c(
            Staff_User__c = nurseUser.Id,
            Ward__c = wardA.Id,
            Is_Active__c = true
        );

        System.runAs(nurseUser) {
            // Patient B initially in Ward B -> 0 results
            List<CareNestAdmissionController.PatientLookupDto> beforeTrf = CareNestAdmissionController.searchPatients('SecPatientB');
            System.assertEquals(0, beforeTrf.size(), 'Patient B in Ward B is initially invisible to Ward A nurse');
        }

        // Admin transfers Patient B to Ward A Bed A2
        Admission__c admB = [SELECT Id, Bed__c FROM Admission__c WHERE Patient__c = :patientB.Id LIMIT 1];
        admB.Bed__c = bedA2.Id;
        update admB;

        System.runAs(nurseUser) {
            // After transfer to Ward A, Patient B becomes visible
            List<CareNestAdmissionController.PatientLookupDto> afterTrf = CareNestAdmissionController.searchPatients('SecPatientB');
            System.assertEquals(1, afterTrf.size(), 'Patient B transferred to Ward A becomes visible to Ward A nurse');
            System.assertEquals('CN-SEC-002', afterTrf[0].patientCode);
        }
    }

    // =========================================================================
    // SCENARIO 13: STAFF CANNOT SELF-CREATE OR MODIFY WARD ASSIGNMENTS
    // =========================================================================
    @IsTest
    static void test13_StaffCannotSelfCreateOrModifyWardAssignments() {
        User nurseUser = createPersonaUser('nurNoSelf', 'CareNest_Nurse');
        Ward__c wardA = [SELECT Id FROM Ward__c WHERE Ward_Code__c = 'SEC-WRD-01' LIMIT 1];

        System.runAs(nurseUser) {
            // Verify ordinary staff lack permission to create assignment records
            Boolean dmlBlocked = false;
            try {
                CareNest_Staff_Ward_Assignment__c selfAsgn = new CareNest_Staff_Ward_Assignment__c(
                    Staff_User__c = nurseUser.Id,
                    Ward__c = wardA.Id,
                    Is_Active__c = true
                );
                Database.insert(selfAsgn, AccessLevel.USER_MODE);
            } catch (Exception e) {
                dmlBlocked = true;
            }
            System.assertEquals(true, dmlBlocked, 'Nurse must not be permitted to self-assign wards via USER_MODE');
        }
    }

    // =========================================================================
    // SCENARIO 14: FRONT DESK AUTHORIZED INTAKE SEARCH
    // =========================================================================
    @IsTest
    static void test14_FrontDeskCanFindPatientByNameAndCode() {
        User fdUser = createPersonaUser('fd', 'CareNest_Front_Desk');
        Contact patientA = [SELECT Id, OwnerId FROM Contact WHERE Patient_Code__c = 'CN-SEC-001' LIMIT 1];
        patientA.OwnerId = fdUser.Id;
        update patientA;

        System.runAs(fdUser) {
            List<CareNestAdmissionController.PatientLookupDto> byName = CareNestAdmissionController.searchPatients('SecPatientA');
            System.assertEquals(1, byName.size(), 'Front Desk must find patient by name via discovery service');
            System.assertEquals('CN-SEC-001', byName[0].patientCode);

            List<CareNestAdmissionController.PatientLookupDto> byCode = CareNestAdmissionController.searchPatients('CN-SEC-001');
            System.assertEquals(1, byCode.size(), 'Front Desk must find patient by code via discovery service');
            System.assertEquals('CN-SEC-001', byCode[0].patientCode);
        }
    }

    // =========================================================================
    // SCENARIO 15: DOCTOR ACCESS LIMITED TO ASSIGNED PATIENTS
    // =========================================================================
    @IsTest
    static void test15_DoctorAccessLimitedToPermittedPatients() {
        User docUser = createPersonaUser('doc', 'CareNest_Doctor');

        Doctor__c doc = [SELECT Id, User__c FROM Doctor__c LIMIT 1];
        doc.User__c = docUser.Id;
        update doc;

        Contact patientA = [SELECT Id, OwnerId FROM Contact WHERE Patient_Code__c = 'CN-SEC-001' LIMIT 1];
        patientA.OwnerId = docUser.Id;
        update patientA;

        Contact unassignedPatient = new Contact(
            FirstName = 'Unassigned',
            LastName = 'DocPatient',
            Patient_Code__c = 'CN-SEC-999',
            OwnerId = docUser.Id
        );
        insert unassignedPatient;

        System.runAs(docUser) {
            List<CareNestAdmissionController.PatientLookupDto> assignedByName = CareNestAdmissionController.searchPatients('SecPatientA');
            System.assertEquals(1, assignedByName.size(), 'Doctor must find assigned patient by name');
            System.assertEquals('CN-SEC-001', assignedByName[0].patientCode);

            List<CareNestAdmissionController.PatientLookupDto> assignedByCode = CareNestAdmissionController.searchPatients('CN-SEC-001');
            System.assertEquals(1, assignedByCode.size(), 'Doctor must find assigned patient by code');

            // Unassigned patient search by name returns 0
            List<CareNestAdmissionController.PatientLookupDto> unassignedSearch = CareNestAdmissionController.searchPatients('DocPatient');
            System.assertEquals(0, unassignedSearch.size(), 'Doctor cannot find unassigned patient by partial name');

            // Unassigned patient search by exact code returns 0 (code does not grant authorization)
            List<CareNestAdmissionController.PatientLookupDto> exactCodeSearch = CareNestAdmissionController.searchPatients('CN-SEC-999');
            System.assertEquals(0, exactCodeSearch.size(), 'Doctor cannot access unassigned patient with exact code');
        }
    }

    // =========================================================================
    // SCENARIO 16: OPERATIONS MANAGER PERMITTED OPERATIONAL SCOPE
    // =========================================================================
    @IsTest
    static void test16_OperationsManagerAccessPermittedPatients() {
        User opsUser = createPersonaUser('ops', 'CareNest_Ops_Manager');
        Contact patientA = [SELECT Id, OwnerId FROM Contact WHERE Patient_Code__c = 'CN-SEC-001' LIMIT 1];
        patientA.OwnerId = opsUser.Id;
        update patientA;

        System.runAs(opsUser) {
            List<CareNestAdmissionController.PatientLookupDto> found = CareNestAdmissionController.searchPatients('SecPatientA');
            System.assertEquals(1, found.size(), 'Operations Manager can search patients for operational intake');
            System.assertEquals('CN-SEC-001', found[0].patientCode);

            List<Appointment__c> appts = [
                SELECT Id, Status__c, Fee_Amount__c, Patient__c
                FROM Appointment__c
                WITH USER_MODE
            ];
            System.assertNotEquals(0, appts.size(), 'Operations Manager must access appointment records');
        }
    }

    // =========================================================================
    // SCENARIO 17: SALES/HR/UNRELATED INTERNAL USERS DENIED
    // =========================================================================
    @IsTest
    static void test17_SalesHrOrUnrelatedInternalUserDenied() {
        User unauth = createPersonaUser('unauth', null);

        System.runAs(unauth) {
            List<CareNestAdmissionController.PatientLookupDto> results = CareNestAdmissionController.searchPatients('SecPatientA');
            System.assertEquals(0, results.size(), 'Unrelated internal user must receive 0 records from patient search');

            System.assertEquals(false, Admission__c.SObjectType.getDescribe().isAccessible(),
                'Unauthorized user must not have access to admissions');
            System.assertEquals(false, Inpatient_Encounter__c.SObjectType.getDescribe().isAccessible(),
                'Unauthorized user must not have access to encounters');
            System.assertEquals(false, Patient_Vital__c.SObjectType.getDescribe().isAccessible(),
                'Unauthorized user must not have access to vitals');
        }
    }

    // =========================================================================
    // SCENARIO 18: GUEST AND EXTERNAL PATIENT SESSIONS DENIED
    // =========================================================================
    @IsTest
    static void test18_ExternalPatientAndGuestDenied() {
        // 1. External portal session
        CareNestPatientAccessService.mockIsExternal = true;
        List<CareNestAdmissionController.PatientLookupDto> portalRes = CareNestAdmissionController.searchPatients('SecPatientA');
        System.assertEquals(0, portalRes.size(), 'External portal session must not search patient contacts');
        CareNestPatientAccessService.mockIsExternal = false;

        // 2. Unauthenticated guest session
        CareNestPatientAccessService.mockIsGuest = true;
        List<CareNestAdmissionController.PatientLookupDto> guestRes = CareNestAdmissionController.searchPatients('SecPatientA');
        System.assertEquals(0, guestRes.size(), 'Guest user must receive 0 search results');
        CareNestPatientAccessService.mockIsGuest = false;
    }

    // =========================================================================
    // SCENARIO 19: SENSITIVE FIELD ACCESS DENIED WITHOUT FLS
    // =========================================================================
    @IsTest
    static void test19_SensitiveFieldAccessDeniedWithoutFls() {
        User nonClinical = createPersonaUser('nonclin', null);

        System.runAs(nonClinical) {
            System.assertEquals(false, Inpatient_Encounter__c.Fields.Clinical_Notes__c.getDescribe().isAccessible(),
                'Non-clinical user must not have FLS read access to Clinical_Notes__c');
            System.assertEquals(false, Patient_Vital__c.Fields.Notes__c.getDescribe().isAccessible(),
                'Non-clinical user must not have FLS read access to Vitals Notes__c');
        }
    }

    // =========================================================================
    // SCENARIO 20: NO MASS PATIENT ENUMERATION
    // =========================================================================
    @IsTest
    static void test20_NoMassPatientEnumeration() {
        User fdUser = createPersonaUser('fd2', 'CareNest_Front_Desk');

        List<Contact> batch = new List<Contact>();
        for (Integer i = 1; i <= 18; i++) {
            batch.add(new Contact(
                FirstName = 'Batch',
                LastName = 'EnumTest ' + i,
                Patient_Code__c = 'CN-PAT-990' + (i < 10 ? '0' + i : String.valueOf(i)),
                OwnerId = fdUser.Id
            ));
        }
        insert batch;

        System.runAs(fdUser) {
            // Short terms (<2 chars)
            System.assertEquals(0, CareNestAdmissionController.searchPatients('A').size(), 'Short term must be rejected');
            // Blank terms
            System.assertEquals(0, CareNestAdmissionController.searchPatients('   ').size(), 'Blank term must be rejected');
            // Null terms
            System.assertEquals(0, CareNestAdmissionController.searchPatients(null).size(), 'Null term must be rejected');
            // Capped at 15 records
            List<CareNestAdmissionController.PatientLookupDto> capRes = CareNestAdmissionController.searchPatients('EnumTest');
            System.assertEquals(15, capRes.size(), 'Results must be hard-capped at 15');
        }
    }

    // =========================================================================
    // SCENARIO 21: NEW REGISTRATION CREATES UNLINKED ORPHAN CONTACT
    // =========================================================================
    @IsTest
    static void test21_NewRegistrationCreatesUnlinkedOrphan() {
        CareNestAdmissionController.PatientRegistrationResultDto regRes = CareNestAdmissionController.registerPatient(
            'Isolated',
            'OrphanTest',
            '5559871111',
            'isolated.orphan@carenest.test.invalid',
            Date.newInstance(1992, 4, 12),
            false
        );

        System.assertEquals(true, regRes.isSuccess, 'Patient registration must succeed');
        System.assertNotEquals(null, regRes.contactId, 'Contact Id must be generated');
        System.assertEquals(null, regRes.accountId,
            'Contact must remain an unlinked orphan Contact (AccountId == null) per strict privacy architecture');

        Contact insertedContact = [SELECT Id, AccountId, Patient_Code__c FROM Contact WHERE Id = :regRes.contactId LIMIT 1];
        System.assertEquals(null, insertedContact.AccountId, 'Database contact AccountId must be null');
        System.assert(insertedContact.Patient_Code__c.startsWith('CN-PAT-'), 'Patient Code must follow CN-PAT- format');
    }

    // =========================================================================
    // SCENARIO 22: PATIENT REGISTRATION AND ADMISSION WORKFLOW
    // =========================================================================
    @IsTest
    static void test22_PatientRegistrationAndAdmissionWorkflow() {
        Bed__c availBed = [SELECT Id, Ward__c FROM Bed__c WHERE Bed_Code__c = 'SEC-BED-A2' LIMIT 1];
        Doctor__c doc = [SELECT Id FROM Doctor__c LIMIT 1];

        // 1. Register patient
        CareNestAdmissionController.PatientRegistrationResultDto regRes = CareNestAdmissionController.registerPatient(
            'Workflow',
            'AdmitCandidate',
            '5557778888',
            'workflow.admit@carenest.test.invalid',
            Date.newInstance(1985, 11, 20),
            false
        );
        System.assertEquals(true, regRes.isSuccess, 'Registration must succeed');

        // 2. Admit newly registered patient
        CareNestAdmissionController.AdmissionActionResultDto admitRes = CareNestAdmissionController.admitPatient(
            regRes.contactId,
            availBed.Id,
            doc.Id,
            'Emergency',
            'Acute admission workflow verification'
        );
        System.assertEquals(true, admitRes.isSuccess, 'Admission workflow must complete successfully');
        System.assertNotEquals(null, admitRes.admissionId, 'Admission Id must be populated');

        Admission__c createdAdm = [
            SELECT Id, Status__c, Bed__c, Patient__c
            FROM Admission__c
            WHERE Id = :admitRes.admissionId
            LIMIT 1
        ];
        System.assertEquals('Admitted', createdAdm.Status__c, 'Admission status must be Admitted');
        System.assertEquals(availBed.Id, createdAdm.Bed__c, 'Bed must match selected available bed');
        System.assertEquals(regRes.contactId, createdAdm.Patient__c, 'Patient must match registered contact');
    }

    // =========================================================================
    // SCENARIO 23: UNIQUE PATIENT CODES AND DUPLICATE PROTECTION
    // =========================================================================
    @IsTest
    static void test23_UniquePatientCodesAndDuplicateProtection() {
        CareNestAdmissionController.PatientRegistrationResultDto first = CareNestAdmissionController.registerPatient(
            'Duplicate',
            'PatientCheck',
            '5553334444',
            'duplicate.check@carenest.test.invalid',
            Date.newInstance(1990, 1, 1),
            false
        );
        System.assertEquals(true, first.isSuccess, 'Initial patient registration must succeed');

        CareNestAdmissionController.PatientRegistrationResultDto dupAttempt = CareNestAdmissionController.registerPatient(
            'Duplicate',
            'PatientCheck',
            '5553334444',
            'duplicate.check@carenest.test.invalid',
            Date.newInstance(1990, 1, 1),
            false
        );
        System.assertEquals(false, dupAttempt.isSuccess, 'Duplicate registration attempt must fail');
        System.assertEquals(true, dupAttempt.isDuplicate, 'Duplicate flag must be set to true');

        CareNestAdmissionController.PatientRegistrationResultDto overrideAttempt = CareNestAdmissionController.registerPatient(
            'Duplicate',
            'PatientCheck',
            '5553334444',
            'duplicate.check@carenest.test.invalid',
            Date.newInstance(1990, 1, 1),
            true
        );
        System.assertEquals(true, overrideAttempt.isSuccess, 'Explicit duplicate override must succeed');
        System.assertNotEquals(first.patientCode, overrideAttempt.patientCode, 'Sequential patient codes must be unique');
    }
}
