/**
 * @description Comprehensive test suite for Phase 17B.5 Clinical Record Sharing.
 * Validates dynamic least-privilege access, Attending & Care Team custom sharing reasons,
 * cross-cover time-bounded sharing and reconciliation, post-discharge access downgrades,
 * identity mapping normalization & uniqueness, inactive user protections, and deterministic rollback isolation.
 */
@isTest
private class ClinicalSharingTest {

    private static Integer seq = 8400;

    private static User createTestUser(String aliasPrefix, String permSetName, Boolean isActive) {
        User runningUser = new User(Id = UserInfo.getUserId());
        User u;
        System.runAs(runningUser) {
            seq++;
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
            String uniqueName = aliasPrefix + seq + '@test-carenest-sharing.org';
            u = new User(
                LastName = 'TestUser' + seq,
                Email = uniqueName,
                Username = uniqueName,
                Alias = (aliasPrefix + seq).left(8),
                TimeZoneSidKey = 'America/Los_Angeles',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                ProfileId = p.Id,
                LanguageLocaleKey = 'en_US',
                IsActive = isActive
            );
            insert u;

            if (isActive && String.isNotBlank(permSetName)) {
                PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = :permSetName LIMIT 1];
                insert new PermissionSetAssignment(
                    AssigneeId = u.Id,
                    PermissionSetId = ps.Id
                );
            }
        }
        return u;
    }

    private static Doctor__c createDoctor(String name, Id userId) {
        seq++;
        Doctor__c doc = new Doctor__c(
            Name = name,
            Registration_No__c = 'REG-SHR-' + seq,
            Department__c = 'General Medicine',
            Specialty__c = 'Internal Medicine',
            Consultation_Fee__c = 500,
            Is_Active__c = true,
            User__c = userId
        );
        insert doc;
        return doc;
    }

    private static Contact createPatient(String lastName) {
        seq++;
        Contact c = new Contact(
            LastName = lastName,
            Email = lastName.toLowerCase() + seq + '@test-sharing.org',
            Phone = '555444' + seq,
            Patient_Code__c = 'PAT-SHR-' + seq
        );
        insert c;
        return c;
    }

    private static Ward__c createWard(String name, String code) {
        Ward__c ward = new Ward__c(
            Name = name,
            Ward_Code__c = code,
            Ward_Type__c = 'General',
            Floor__c = '2',
            Capacity__c = 10,
            Is_Active__c = true
        );
        insert ward;
        return ward;
    }

    private static Bed__c createBed(Ward__c ward, String name, String code) {
        Bed__c bed = new Bed__c(
            Name = name,
            Bed_Code__c = code,
            Ward__c = ward.Id,
            Bed_Type__c = 'Standard',
            Status__c = 'Available'
        );
        insert bed;
        return bed;
    }

    private static Admission__c createAdmission(Contact pat, Bed__c bed, Doctor__c attendingDoc) {
        AdmissionService.AdmissionRequest req = new AdmissionService.AdmissionRequest(
            pat.Id,
            bed.Id,
            attendingDoc.Id,
            System.now().addDays(-2),
            'Inpatient admission for clinical sharing verification',
            null
        );
        return AdmissionService.admitPatient(req);
    }

    private static Inpatient_Encounter__c createEncounter(Id admissionId, Id docId) {
        Inpatient_Encounter__c enc = new Inpatient_Encounter__c(
            Admission__c = admissionId,
            Attending_Doctor__c = docId,
            Encounter_Date__c = System.now(),
            Chief_Complaint__c = 'Routine clinical checkup',
            Assessment__c = 'Clinically stable',
            Clinical_Notes__c = 'Continue current care regimen',
            Status__c = 'Completed',
            Encounter_Type__c = 'Daily Ward Round'
        );
        insert enc;
        return enc;
    }

    private static Patient_Vital__c createVital(Id admissionId, Id encounterId) {
        Patient_Vital__c vit = new Patient_Vital__c(
            Admission__c = admissionId,
            Inpatient_Encounter__c = encounterId,
            Recorded_Date__c = System.now(),
            Temperature__c = 98.6,
            Pulse__c = 72,
            Respiratory_Rate__c = 16,
            Systolic_BP__c = 120,
            Diastolic_BP__c = 80,
            Oxygen_Saturation__c = 98,
            Weight__c = 70.0
        );
        insert vit;
        return vit;
    }

    /**
     * Scenario 1: Attending physician automatically receives Edit on Encounter and Read on Vital.
     */
    @isTest
    static void testAttendingPhysicianAutoShare_Success() {
        User docUser = createTestUser('doc1', 'CareNest_Doctor', true);
        Doctor__c attendingDoc = createDoctor('Dr. Sarah Lin', docUser.Id);
        Ward__c ward = createWard('Ward Alpha', 'WRD-SHR-01');
        Bed__c bed = createBed(ward, 'Bed A1', 'BED-SHR-A1');
        Contact pat = createPatient('PatAlpha');

        Admission__c adm = createAdmission(pat, bed, attendingDoc);

        Test.startTest();
        Inpatient_Encounter__c enc = createEncounter(adm.Id, attendingDoc.Id);
        Patient_Vital__c vit = createVital(adm.Id, enc.Id);
        Test.stopTest();

        List<Inpatient_Encounter__Share> encShares = [
            SELECT Id, AccessLevel, RowCause
            FROM Inpatient_Encounter__Share
            WHERE ParentId = :enc.Id
              AND UserOrGroupId = :docUser.Id
              AND RowCause = :Schema.Inpatient_Encounter__Share.RowCause.Attending_Physician__c
        ];
        System.assertEquals(1, encShares.size(), 'Attending physician must receive 1 Encounter share');
        System.assertEquals('Edit', encShares[0].AccessLevel, 'Attending Encounter share access level must be Edit');

        List<Patient_Vital__Share> vitShares = [
            SELECT Id, AccessLevel, RowCause
            FROM Patient_Vital__Share
            WHERE ParentId = :vit.Id
              AND UserOrGroupId = :docUser.Id
              AND RowCause = :Schema.Patient_Vital__Share.RowCause.Attending_Physician__c
        ];
        System.assertEquals(1, vitShares.size(), 'Attending physician must receive 1 Vital share');
        System.assertEquals('Read', vitShares[0].AccessLevel, 'Attending Vital share access level must be Read');
    }

    /**
     * Scenario 2: Active covering doctor receives Read access on Encounter & Vital with Care_Team__c.
     */
    @isTest
    static void testConsultingCoveringPhysician_CrossCover() {
        User docUser1 = createTestUser('docatt', 'CareNest_Doctor', true);
        User docUser2 = createTestUser('doccov', 'CareNest_Doctor', true);
        Doctor__c attendingDoc = createDoctor('Dr. Alice Grey', docUser1.Id);
        Doctor__c coveringDoc = createDoctor('Dr. Bob White', docUser2.Id);
        Ward__c ward = createWard('Ward Beta', 'WRD-SHR-02');
        Bed__c bed = createBed(ward, 'Bed B1', 'BED-SHR-B1');
        Contact pat = createPatient('PatBeta');

        Admission__c adm = createAdmission(pat, bed, attendingDoc);
        adm.Covering_Doctor__c = coveringDoc.Id;
        adm.Covering_Start_Time__c = System.now().addHours(-2);
        adm.Covering_End_Time__c = System.now().addHours(10);
        update adm;

        Test.startTest();
        Inpatient_Encounter__c enc = createEncounter(adm.Id, attendingDoc.Id);
        Patient_Vital__c vit = createVital(adm.Id, enc.Id);
        Test.stopTest();

        List<Inpatient_Encounter__Share> encCoverShares = [
            SELECT Id, AccessLevel, RowCause
            FROM Inpatient_Encounter__Share
            WHERE ParentId = :enc.Id
              AND UserOrGroupId = :docUser2.Id
              AND RowCause = :Schema.Inpatient_Encounter__Share.RowCause.Care_Team__c
        ];
        System.assertEquals(1, encCoverShares.size(), 'Covering doctor must receive 1 Encounter share');
        System.assertEquals('Read', encCoverShares[0].AccessLevel, 'Covering doctor Encounter share must be Read');

        List<Patient_Vital__Share> vitCoverShares = [
            SELECT Id, AccessLevel, RowCause
            FROM Patient_Vital__Share
            WHERE ParentId = :vit.Id
              AND UserOrGroupId = :docUser2.Id
              AND RowCause = :Schema.Patient_Vital__Share.RowCause.Care_Team__c
        ];
        System.assertEquals(1, vitCoverShares.size(), 'Covering doctor must receive 1 Vital share');
        System.assertEquals('Read', vitCoverShares[0].AccessLevel, 'Covering doctor Vital share must be Read');
    }

    /**
     * Scenario 3: Expired cross-cover generates no shares upon record creation.
     */
    @isTest
    static void testExpiredCrossCover_NoAccess() {
        User docUser1 = createTestUser('docatt3', 'CareNest_Doctor', true);
        User docUser2 = createTestUser('doccov3', 'CareNest_Doctor', true);
        Doctor__c attendingDoc = createDoctor('Dr. Attending Three', docUser1.Id);
        Doctor__c coveringDoc = createDoctor('Dr. Expired Three', docUser2.Id);
        Ward__c ward = createWard('Ward Gamma', 'WRD-SHR-03');
        Bed__c bed = createBed(ward, 'Bed G1', 'BED-SHR-G1');
        Contact pat = createPatient('PatGamma');

        Admission__c adm = createAdmission(pat, bed, attendingDoc);
        adm.Covering_Doctor__c = coveringDoc.Id;
        adm.Covering_Start_Time__c = System.now().addHours(-4);
        adm.Covering_End_Time__c = System.now().addHours(-1); // Expired
        update adm;

        Test.startTest();
        Inpatient_Encounter__c enc = createEncounter(adm.Id, attendingDoc.Id);
        Patient_Vital__c vit = createVital(adm.Id, enc.Id);
        Test.stopTest();

        List<Inpatient_Encounter__Share> encCoverShares = [
            SELECT Id FROM Inpatient_Encounter__Share
            WHERE ParentId = :enc.Id
              AND UserOrGroupId = :docUser2.Id
              AND RowCause = :Schema.Inpatient_Encounter__Share.RowCause.Care_Team__c
        ];
        System.assertEquals(0, encCoverShares.size(), 'Expired covering doctor must receive 0 Encounter shares');
    }

    /**
     * Scenario 4: Distinct physician not attending or covering cannot access records.
     */
    @isTest
    static void testUnrelatedClinician_CannotAccess() {
        User docUser1 = createTestUser('docatt4', 'CareNest_Doctor', true);
        User docUser3 = createTestUser('docunrel', 'CareNest_Doctor', true);
        Doctor__c attendingDoc = createDoctor('Dr. Four Att', docUser1.Id);
        Doctor__c unrelatedDoc = createDoctor('Dr. Four Unrelated', docUser3.Id);
        Ward__c ward = createWard('Ward Delta', 'WRD-SHR-04');
        Bed__c bed = createBed(ward, 'Bed D1', 'BED-SHR-D1');
        Contact pat = createPatient('PatDelta');

        Admission__c adm = createAdmission(pat, bed, attendingDoc);
        Inpatient_Encounter__c enc = createEncounter(adm.Id, attendingDoc.Id);

        Test.startTest();
        List<Inpatient_Encounter__Share> shares = [
            SELECT Id FROM Inpatient_Encounter__Share
            WHERE ParentId = :enc.Id AND UserOrGroupId = :docUser3.Id
        ];
        System.assertEquals(0, shares.size(), 'Unrelated clinician must have 0 shares');

        System.runAs(docUser3) {
            List<Inpatient_Encounter__c> visibleEncounters = [
                SELECT Id FROM Inpatient_Encounter__c WHERE Id = :enc.Id
            ];
            System.assertEquals(0, visibleEncounters.size(), 'Unrelated clinician cannot view encounter under Private OWD');
        }
        Test.stopTest();
    }

    /**
     * Scenario 5: Front Desk staff cannot view clinical encounter records under Private OWD.
     */
    @isTest
    static void testFrontDeskStaff_CannotAccessClinicalRecords() {
        User docUser = createTestUser('docatt5', 'CareNest_Doctor', true);
        User frontDeskUser = createTestUser('fdusr5', 'CareNest_Front_Desk', true);
        Doctor__c attendingDoc = createDoctor('Dr. Five Att', docUser.Id);
        Ward__c ward = createWard('Ward Epsilon', 'WRD-SHR-05');
        Bed__c bed = createBed(ward, 'Bed E1', 'BED-SHR-E1');
        Contact pat = createPatient('PatEpsilon');

        Admission__c adm = createAdmission(pat, bed, attendingDoc);
        Inpatient_Encounter__c enc = createEncounter(adm.Id, attendingDoc.Id);

        Test.startTest();
        System.runAs(frontDeskUser) {
            List<Inpatient_Encounter__c> visibleEncounters = [
                SELECT Id FROM Inpatient_Encounter__c WHERE Id = :enc.Id
            ];
            System.assertEquals(0, visibleEncounters.size(), 'Front desk staff cannot view clinical encounters');
        }
        Test.stopTest();
    }

    /**
     * Scenario 6: Ops Manager permissions behavior verification.
     */
    @isTest
    static void testOpsManager_ReadAccess() {
        User opsUser = createTestUser('opsusr6', 'CareNest_Ops_Manager', true);
        User docUser = createTestUser('docatt6', 'CareNest_Doctor', true);
        Doctor__c attendingDoc = createDoctor('Dr. Six Att', docUser.Id);
        Ward__c ward = createWard('Ward Zeta', 'WRD-SHR-06');
        Bed__c bed = createBed(ward, 'Bed Z1', 'BED-SHR-Z1');
        Contact pat = createPatient('PatZeta');

        Admission__c adm = createAdmission(pat, bed, attendingDoc);

        Test.startTest();
        System.runAs(opsUser) {
            List<Admission__c> visibleAdms = [
                SELECT Id, Status__c FROM Admission__c WHERE Id = :adm.Id
            ];
            System.assertEquals(1, visibleAdms.size(), 'Ops Manager can view admissions for operational monitoring');
        }
        Test.stopTest();
    }

    /**
     * Scenario 7: Discharge transitions downgrade Attending share on Encounter from Edit to Read.
     */
    @isTest
    static void testDischargeDowngradesAttendingToReadOnly() {
        User docUser = createTestUser('docatt7', 'CareNest_Doctor', true);
        Doctor__c attendingDoc = createDoctor('Dr. Seven Att', docUser.Id);
        Ward__c ward = createWard('Ward Eta', 'WRD-SHR-07');
        Bed__c bed = createBed(ward, 'Bed H1', 'BED-SHR-H1');
        Contact pat = createPatient('PatEta');

        Admission__c adm = createAdmission(pat, bed, attendingDoc);
        Inpatient_Encounter__c enc = createEncounter(adm.Id, attendingDoc.Id);

        // Pre-discharge: Edit
        List<Inpatient_Encounter__Share> preShares = [
            SELECT Id, AccessLevel FROM Inpatient_Encounter__Share
            WHERE ParentId = :enc.Id AND UserOrGroupId = :docUser.Id
              AND RowCause = :Schema.Inpatient_Encounter__Share.RowCause.Attending_Physician__c
        ];
        System.assertEquals(1, preShares.size());
        System.assertEquals('Edit', preShares[0].AccessLevel);

        Test.startTest();
        AdmissionService.dischargePatient(new AdmissionService.DischargeRequest(
            adm.Id, System.now(), 'Patient discharged in stable condition.', 'Home', attendingDoc.Id
        ));
        Test.stopTest();

        List<Inpatient_Encounter__Share> postShares = [
            SELECT Id, AccessLevel FROM Inpatient_Encounter__Share
            WHERE ParentId = :enc.Id AND UserOrGroupId = :docUser.Id
              AND RowCause = :Schema.Inpatient_Encounter__Share.RowCause.Attending_Physician__c
        ];
        System.assertEquals(1, postShares.size());
        System.assertEquals('Read', postShares[0].AccessLevel, 'Attending Encounter share must downgrade to Read upon discharge');
    }

    /**
     * Scenario 8: Reassigning Attending Doctor revokes old doctor's shares and grants new doctor shares.
     */
    @isTest
    static void testReassignedAttendingDoctor() {
        User docUser1 = createTestUser('docatt8a', 'CareNest_Doctor', true);
        User docUser2 = createTestUser('docatt8b', 'CareNest_Doctor', true);
        Doctor__c doc1 = createDoctor('Dr. Eight Alpha', docUser1.Id);
        Doctor__c doc2 = createDoctor('Dr. Eight Beta', docUser2.Id);
        Ward__c ward = createWard('Ward Theta', 'WRD-SHR-08');
        Bed__c bed = createBed(ward, 'Bed T1', 'BED-SHR-T1');
        Contact pat = createPatient('PatTheta');

        Admission__c adm = createAdmission(pat, bed, doc1);
        Inpatient_Encounter__c enc = createEncounter(adm.Id, doc1.Id);

        Test.startTest();
        adm.Attending_Doctor__c = doc2.Id;
        update adm;
        Test.stopTest();

        List<Inpatient_Encounter__Share> oldDocShares = [
            SELECT Id FROM Inpatient_Encounter__Share
            WHERE ParentId = :enc.Id AND UserOrGroupId = :docUser1.Id
              AND RowCause = :Schema.Inpatient_Encounter__Share.RowCause.Attending_Physician__c
        ];
        System.assertEquals(0, oldDocShares.size(), 'Old attending doctor share must be removed on reassignment');

        List<Inpatient_Encounter__Share> newDocShares = [
            SELECT Id, AccessLevel FROM Inpatient_Encounter__Share
            WHERE ParentId = :enc.Id AND UserOrGroupId = :docUser2.Id
              AND RowCause = :Schema.Inpatient_Encounter__Share.RowCause.Attending_Physician__c
        ];
        System.assertEquals(1, newDocShares.size(), 'New attending doctor must receive share on reassignment');
        System.assertEquals('Edit', newDocShares[0].AccessLevel);
    }

    /**
     * Scenario 9: Placeholder doctor without User__c does not crash sharing engine.
     */
    @isTest
    static void testPlaceholderDoctorWithoutUser_NoCrash() {
        Doctor__c placeholderDoc = createDoctor('Dr. External Locum', null);
        Ward__c ward = createWard('Ward Iota', 'WRD-SHR-09');
        Bed__c bed = createBed(ward, 'Bed I1', 'BED-SHR-I1');
        Contact pat = createPatient('PatIota');

        Admission__c adm = createAdmission(pat, bed, placeholderDoc);

        Test.startTest();
        Inpatient_Encounter__c enc = createEncounter(adm.Id, placeholderDoc.Id);
        Patient_Vital__c vit = createVital(adm.Id, enc.Id);
        Test.stopTest();

        System.assertNotEquals(null, enc.Id, 'Encounter created safely');
        System.assertNotEquals(null, vit.Id, 'Vital created safely');
    }

    /**
     * Scenario 10: Uniqueness enforcement on Doctor__c.User_Id_Unique__c prevents duplicate user mappings.
     */
    @isTest
    static void testDoctorUserUniqueMapping_Enforcement() {
        User u1 = createTestUser('uniq1', 'CareNest_Doctor', true);
        Doctor__c doc1 = createDoctor('Dr. Uniq One', u1.Id);
        System.assertNotEquals(null, doc1.Id);

        Test.startTest();
        Boolean duplicateRejected = false;
        try {
            Doctor__c doc2 = new Doctor__c(
                Name = 'Dr. Uniq Duplicate',
                Registration_No__c = 'REG-UNIQ-DUP',
                Department__c = 'General Medicine',
                Specialty__c = 'Internal Medicine',
                Consultation_Fee__c = 500,
                Is_Active__c = true,
                User__c = u1.Id
            );
            insert doc2;
        } catch (DmlException ex) {
            duplicateRejected = true;
            System.assert(ex.getMessage().contains('duplicate value') || ex.getMessage().contains('DUPLICATE_VALUE') || ex.getMessage().contains('already mapped'),
                'Expected duplicate value error: ' + ex.getMessage());
        }
        System.assert(duplicateRejected, 'Second doctor mapped to same User must fail uniqueness constraint');

        // Multiple nulls are allowed
        Doctor__c nullDoc1 = createDoctor('Dr. Null One', null);
        Doctor__c nullDoc2 = createDoctor('Dr. Null Two', null);
        System.assertNotEquals(null, nullDoc1.Id);
        System.assertNotEquals(null, nullDoc2.Id);
        Test.stopTest();
    }

    /**
     * Scenario 11: User_Id_Unique__c normalization stores 18-character uppercase string.
     */
    @isTest
    static void test18CharacterUserIdNormalization() {
        User u = createTestUser('norm11', 'CareNest_Doctor', true);

        Test.startTest();
        Doctor__c doc = createDoctor('Dr. Normalized', u.Id);
        Test.stopTest();

        Doctor__c queriedDoc = [
            SELECT Id, User__c, User_Id_Unique__c
            FROM Doctor__c
            WHERE Id = :doc.Id
        ];
        System.assertEquals(18, queriedDoc.User_Id_Unique__c.length(), 'User_Id_Unique__c must be 18 characters');
        System.assertEquals(String.valueOf(u.Id).toUpperCase(), queriedDoc.User_Id_Unique__c);
    }

    /**
     * Scenario 12: Inactive user cannot be mapped to Doctor__c.User__c.
     */
    @isTest
    static void testInactiveUserMapping_Rejection() {
        User inactiveUser = createTestUser('inact12', null, false);

        Test.startTest();
        Boolean inactiveRejected = false;
        try {
            Doctor__c doc = new Doctor__c(
                Name = 'Dr. Inactive Test',
                Registration_No__c = 'REG-INACT-12',
                Department__c = 'General Medicine',
                Specialty__c = 'Internal Medicine',
                Consultation_Fee__c = 500,
                Is_Active__c = true,
                User__c = inactiveUser.Id
            );
            insert doc;
        } catch (DmlException ex) {
            inactiveRejected = true;
            System.assert(ex.getMessage().contains('inactive') || ex.getMessage().contains('Cannot map doctor'), 'Expected inactive user error: ' + ex.getMessage());
        }
        System.assert(inactiveRejected, 'Cannot map inactive user to Doctor__c');
        Test.stopTest();
    }

    /**
     * Scenario 13: Bulk encounter and vital insert creates shares within governor limits.
     */
    @isTest
    static void testBulkEncounterVitalInsert_SharingPerformance() {
        User docUser = createTestUser('docblk13', 'CareNest_Doctor', true);
        Doctor__c attendingDoc = createDoctor('Dr. Bulk Att', docUser.Id);
        Ward__c ward = createWard('Ward Bulk', 'WRD-SHR-13');
        Bed__c bed = createBed(ward, 'Bed BLK-1', 'BED-SHR-BLK1');
        Contact pat = createPatient('PatBulk');

        Admission__c adm = createAdmission(pat, bed, attendingDoc);

        List<Inpatient_Encounter__c> encounters = new List<Inpatient_Encounter__c>();
        for (Integer i = 0; i < 50; i++) {
            encounters.add(new Inpatient_Encounter__c(
                Admission__c = adm.Id,
                Attending_Doctor__c = attendingDoc.Id,
                Encounter_Date__c = System.now().addMinutes(-i),
                Chief_Complaint__c = 'Bulk complaint ' + i,
                Assessment__c = 'Assessment ' + i,
                Clinical_Notes__c = 'Notes ' + i,
                Status__c = 'Completed',
                Encounter_Type__c = 'Daily Ward Round'
            ));
        }

        Test.startTest();
        insert encounters;

        List<Patient_Vital__c> vitals = new List<Patient_Vital__c>();
        for (Integer i = 0; i < 50; i++) {
            vitals.add(new Patient_Vital__c(
                Admission__c = adm.Id,
                Inpatient_Encounter__c = encounters[i].Id,
                Recorded_Date__c = System.now().addMinutes(-i),
                Temperature__c = 98.6,
                Pulse__c = 72,
                Respiratory_Rate__c = 16,
                Systolic_BP__c = 120,
                Diastolic_BP__c = 80,
                Oxygen_Saturation__c = 98,
                Weight__c = 70.0
            ));
        }
        insert vitals;
        Test.stopTest();

        Integer shareCount = [
            SELECT COUNT() FROM Inpatient_Encounter__Share
            WHERE UserOrGroupId = :docUser.Id
              AND RowCause = :Schema.Inpatient_Encounter__Share.RowCause.Attending_Physician__c
        ];
        System.assertEquals(50, shareCount, 'All 50 bulk encounters must receive attending shares');
    }

    /**
     * Scenario 14: CrossCoverReconciliationBatch executes and purges expired cross-cover shares.
     */
    @isTest
    static void testCrossCoverReconciliationBatch_Execution() {
        User docUser1 = createTestUser('doc14a', 'CareNest_Doctor', true);
        User docUser2 = createTestUser('doc14b', 'CareNest_Doctor', true);
        Doctor__c attendingDoc = createDoctor('Dr. Fourteen Att', docUser1.Id);
        Doctor__c coveringDoc = createDoctor('Dr. Fourteen Cov', docUser2.Id);
        Ward__c ward = createWard('Ward Batch', 'WRD-SHR-14');
        Bed__c bed = createBed(ward, 'Bed BCH-1', 'BED-SHR-BCH1');
        Contact pat = createPatient('PatBatch');

        Admission__c adm = createAdmission(pat, bed, attendingDoc);
        adm.Covering_Doctor__c = coveringDoc.Id;
        adm.Covering_Start_Time__c = System.now().addHours(-3);
        adm.Covering_End_Time__c = System.now().addHours(2); // Initially active
        update adm;

        Inpatient_Encounter__c enc = createEncounter(adm.Id, attendingDoc.Id);
        Patient_Vital__c vit = createVital(adm.Id, enc.Id);

        // Verify shares exist initially
        List<Inpatient_Encounter__Share> initialShares = [
            SELECT Id FROM Inpatient_Encounter__Share
            WHERE ParentId = :enc.Id AND UserOrGroupId = :docUser2.Id
              AND RowCause = :Schema.Inpatient_Encounter__Share.RowCause.Care_Team__c
        ];
        System.assertEquals(1, initialShares.size(), 'Covering encounter share must exist initially');

        List<Patient_Vital__Share> initialVitalShares = [
            SELECT Id FROM Patient_Vital__Share
            WHERE ParentId = :vit.Id AND UserOrGroupId = :docUser2.Id
              AND RowCause = :Schema.Patient_Vital__Share.RowCause.Care_Team__c
        ];
        System.assertEquals(1, initialVitalShares.size(), 'Covering vital share must exist initially');

        // Expire covering window with trigger bypass so batch is responsible for cleanup
        AdmissionTriggerHandler.bypassTrigger = true;
        adm.Covering_End_Time__c = System.now().addHours(-1);
        update adm;
        AdmissionTriggerHandler.bypassTrigger = false;

        Test.startTest();
        Database.executeBatch(new CrossCoverReconciliationBatch());
        Test.stopTest();

        List<Inpatient_Encounter__Share> postBatchShares = [
            SELECT Id FROM Inpatient_Encounter__Share
            WHERE ParentId = :enc.Id AND UserOrGroupId = :docUser2.Id
              AND RowCause = :Schema.Inpatient_Encounter__Share.RowCause.Care_Team__c
        ];
        System.assertEquals(0, postBatchShares.size(), 'Expired covering encounter share must be revoked by batch');

        List<Patient_Vital__Share> postBatchVitalShares = [
            SELECT Id FROM Patient_Vital__Share
            WHERE ParentId = :vit.Id AND UserOrGroupId = :docUser2.Id
              AND RowCause = :Schema.Patient_Vital__Share.RowCause.Care_Team__c
        ];
        System.assertEquals(0, postBatchVitalShares.size(), 'Expired covering vital share must be revoked by batch');
    }

    /**
     * Scenario 15: CrossCoverReconciliationBatch is schedulable without error.
     */
    @isTest
    static void testCrossCoverReconciliationBatch_Schedulable() {
        Test.startTest();
        String cronExp = '0 0 1 * * ?';
        String jobId = System.schedule('TestCrossCoverReconJob', cronExp, new CrossCoverReconciliationBatch());
        Test.stopTest();

        CronTrigger ct = [SELECT Id, CronExpression, TimesTriggered FROM CronTrigger WHERE Id = :jobId];
        System.assertEquals(cronExp, ct.CronExpression, 'Batch job should be scheduled with given cron expression');
    }

    /**
     * Scenario 16: Encounter Author distinct from Admission Attending receives Edit share.
     */
    @isTest
    static void testEncounterAuthor_DistinctFromAttending() {
        User docUser1 = createTestUser('doc16a', 'CareNest_Doctor', true);
        User docUser2 = createTestUser('doc16b', 'CareNest_Doctor', true);
        Doctor__c admissionAttending = createDoctor('Dr. Sixteen Adm', docUser1.Id);
        Doctor__c encounterAuthor = createDoctor('Dr. Sixteen Author', docUser2.Id);
        Ward__c ward = createWard('Ward Author', 'WRD-SHR-16');
        Bed__c bed = createBed(ward, 'Bed AUT-1', 'BED-SHR-AUT1');
        Contact pat = createPatient('PatAuthor');

        Admission__c adm = createAdmission(pat, bed, admissionAttending);

        Test.startTest();
        Inpatient_Encounter__c enc = createEncounter(adm.Id, encounterAuthor.Id);
        Test.stopTest();

        List<Inpatient_Encounter__Share> authorShares = [
            SELECT Id, AccessLevel, RowCause FROM Inpatient_Encounter__Share
            WHERE ParentId = :enc.Id AND UserOrGroupId = :docUser2.Id
              AND RowCause = :Schema.Inpatient_Encounter__Share.RowCause.Attending_Physician__c
        ];
        System.assertEquals(1, authorShares.size(), 'Distinct encounter author must receive Edit share');
        System.assertEquals('Edit', authorShares[0].AccessLevel);

        List<Inpatient_Encounter__Share> admAttendingShares = [
            SELECT Id, AccessLevel, RowCause FROM Inpatient_Encounter__Share
            WHERE ParentId = :enc.Id AND UserOrGroupId = :docUser1.Id
              AND RowCause = :Schema.Inpatient_Encounter__Share.RowCause.Attending_Physician__c
        ];
        System.assertEquals(1, admAttendingShares.size(), 'Admission attending must also receive Edit share');
        System.assertEquals('Edit', admAttendingShares[0].AccessLevel);
    }

    /**
     * Scenario 17: Post-discharge vitals blocked by PatientVitalTriggerHandler.
     */
    @isTest
    static void testDischargePostProtection_VitalsBlocked() {
        Doctor__c doc = createDoctor('Dr. Seventeen Guard', null);
        Ward__c ward = createWard('Ward Guard17', 'WRD-SHR-17');
        Bed__c bed = createBed(ward, 'Bed GD-1', 'BED-SHR-GD1');
        Contact pat = createPatient('PatGuard17');

        Admission__c adm = createAdmission(pat, bed, doc);

        // Discharge admission
        AdmissionService.dischargePatient(new AdmissionService.DischargeRequest(adm.Id, 'Discharged.'));

        Test.startTest();
        Boolean vitalBlocked = false;
        try {
            createVital(adm.Id, null);
        } catch (DmlException ex) {
            vitalBlocked = true;
            System.assert(ex.getMessage().contains('discharged or cancelled'), 'Expected inactive admission error: ' + ex.getMessage());
        }
        System.assert(vitalBlocked, 'Cannot record vitals on discharged admission');
        Test.stopTest();
    }

    /**
     * Scenario 18: Deterministic rollback isolation targets only CareNest custom shares, preserving Owner shares.
     */
    @isTest
    static void testRollbackSafety_OnlyCareNestSharesTargeted() {
        User docUser = createTestUser('doc18', 'CareNest_Doctor', true);
        Doctor__c attendingDoc = createDoctor('Dr. Eighteen Roll', docUser.Id);
        Ward__c ward = createWard('Ward Rollback', 'WRD-SHR-18');
        Bed__c bed = createBed(ward, 'Bed RL-1', 'BED-SHR-RL1');
        Contact pat = createPatient('PatRollback');

        Admission__c adm = createAdmission(pat, bed, attendingDoc);
        Inpatient_Encounter__c enc = createEncounter(adm.Id, attendingDoc.Id);

        Test.startTest();
        // Rollback query simulation
        List<Inpatient_Encounter__Share> featureShares = [
            SELECT Id, RowCause FROM Inpatient_Encounter__Share
            WHERE ParentId = :enc.Id
              AND RowCause IN ('Attending_Physician__c', 'Care_Team__c')
        ];
        System.assert(featureShares.size() > 0, 'Feature shares identified');

        List<Inpatient_Encounter__Share> ownerShares = [
            SELECT Id, RowCause FROM Inpatient_Encounter__Share
            WHERE ParentId = :enc.Id
              AND RowCause = 'Owner'
        ];
        System.assertEquals(1, ownerShares.size(), 'Owner share must exist');

        // Delete feature shares
        delete featureShares;

        List<Inpatient_Encounter__Share> remainingOwnerShares = [
            SELECT Id, RowCause FROM Inpatient_Encounter__Share
            WHERE ParentId = :enc.Id AND RowCause = 'Owner'
        ];
        System.assertEquals(1, remainingOwnerShares.size(), 'Owner share remains completely intact after rollback deletion');
        Test.stopTest();
    }

    /**
     * Scenario 19: Doctor User__c reassignment and clearing coverage.
     */
    @isTest
    static void testDoctorUserMappingUpdate_AndClearing() {
        User u1 = createTestUser('upd19a', 'CareNest_Doctor', true);
        User u2 = createTestUser('upd19b', 'CareNest_Doctor', true);
        Doctor__c doc = createDoctor('Dr. Update Test', u1.Id);

        Ward__c ward = createWard('Ward Upd', 'WRD-SHR-19');
        Bed__c bed = createBed(ward, 'Bed U1', 'BED-SHR-U1');
        Contact pat = createPatient('PatUpd19');
        Admission__c adm = createAdmission(pat, bed, doc);
        Inpatient_Encounter__c enc = createEncounter(adm.Id, doc.Id);

        Test.startTest();
        // Update to u2
        doc.User__c = u2.Id;
        update doc;

        Doctor__c queried1 = [SELECT Id, User__c, User_Id_Unique__c FROM Doctor__c WHERE Id = :doc.Id];
        System.assertEquals(u2.Id, queried1.User__c);
        System.assertEquals(String.valueOf(u2.Id).toUpperCase(), queried1.User_Id_Unique__c);

        // Clear User__c to null
        doc.User__c = null;
        update doc;

        Doctor__c queried2 = [SELECT Id, User__c, User_Id_Unique__c FROM Doctor__c WHERE Id = :doc.Id];
        System.assertEquals(null, queried2.User__c);
        System.assertEquals(null, queried2.User_Id_Unique__c);
        Test.stopTest();
    }

    /**
     * Scenario 20: Cross-cover change on Admission directly re-reconciles shares.
     */
    @isTest
    static void testCrossCoverUpdate_DirectReconciliation() {
        User docUser1 = createTestUser('doc20a', 'CareNest_Doctor', true);
        User docUser2 = createTestUser('doc20b', 'CareNest_Doctor', true);
        Doctor__c attendingDoc = createDoctor('Dr. Twenty Att', docUser1.Id);
        Doctor__c coveringDoc = createDoctor('Dr. Twenty Cov', docUser2.Id);
        Ward__c ward = createWard('Ward CovUpd', 'WRD-SHR-20');
        Bed__c bed = createBed(ward, 'Bed C20', 'BED-SHR-C20');
        Contact pat = createPatient('PatTwenty');

        Admission__c adm = createAdmission(pat, bed, attendingDoc);
        Inpatient_Encounter__c enc = createEncounter(adm.Id, attendingDoc.Id);

        Test.startTest();
        adm.Covering_Doctor__c = coveringDoc.Id;
        adm.Covering_Start_Time__c = System.now().addHours(-1);
        adm.Covering_End_Time__c = System.now().addHours(4);
        update adm;
        Test.stopTest();

        List<Inpatient_Encounter__Share> shares = [
            SELECT Id FROM Inpatient_Encounter__Share
            WHERE ParentId = :enc.Id AND UserOrGroupId = :docUser2.Id
              AND RowCause = :Schema.Inpatient_Encounter__Share.RowCause.Care_Team__c
        ];
        System.assertEquals(1, shares.size(), 'Direct cross-cover update should immediately reconcile shares');
    }

    /**
     * Scenario 21: Handler bypass flags and edge coverage.
     */
    @isTest
    static void testHandlerBypasses() {
        DoctorTriggerHandler.bypassTrigger = true;
        Doctor__c d = new Doctor__c(
            Name = 'Bypass Doc',
            Registration_No__c = 'REG-BYP-1',
            Consultation_Fee__c = 500
        );
        insert d;
        update d;
        DoctorTriggerHandler.bypassTrigger = false;

        ClinicalSharingService.bypassSharing = true;
        ClinicalSharingService.grantEncounterShares(new List<Inpatient_Encounter__c>());
        ClinicalSharingService.grantVitalShares(new List<Patient_Vital__c>());
        ClinicalSharingService.downgradeSharesOnDischarge(new Set<Id>());
        ClinicalSharingService.reconcileCrossCoverShares(new Set<Id>());
        ClinicalSharingService.bypassSharing = false;

        System.assertNotEquals(null, d.Id);
    }

    /**
     * Scenario 22: Active cross-cover retains both Encounter and Vital shares after reconciliation.
     */
    @isTest
    static void testCrossCoverActive_VitalsPreserved() {
        User docUser1 = createTestUser('doc22a', 'CareNest_Doctor', true);
        User docUser2 = createTestUser('doc22b', 'CareNest_Doctor', true);
        Doctor__c attendingDoc = createDoctor('Dr. TwentyTwo Att', docUser1.Id);
        Doctor__c coveringDoc = createDoctor('Dr. TwentyTwo Cov', docUser2.Id);
        Ward__c ward = createWard('Ward Cov22', 'WRD-SHR-22');
        Bed__c bed = createBed(ward, 'Bed C22', 'BED-SHR-C22');
        Contact pat = createPatient('PatTwentyTwo');

        Admission__c adm = createAdmission(pat, bed, attendingDoc);
        adm.Covering_Doctor__c = coveringDoc.Id;
        adm.Covering_Start_Time__c = System.now().addHours(-2);
        adm.Covering_End_Time__c = System.now().addHours(6);
        update adm;

        Inpatient_Encounter__c enc = createEncounter(adm.Id, attendingDoc.Id);
        Patient_Vital__c vit = createVital(adm.Id, enc.Id);

        Test.startTest();
        ClinicalSharingService.reconcileCrossCoverShares(new Set<Id>{ adm.Id });
        Test.stopTest();

        List<Inpatient_Encounter__Share> encShares = [
            SELECT Id, AccessLevel FROM Inpatient_Encounter__Share
            WHERE ParentId = :enc.Id AND UserOrGroupId = :docUser2.Id
              AND RowCause = :Schema.Inpatient_Encounter__Share.RowCause.Care_Team__c
        ];
        System.assertEquals(1, encShares.size(), 'Active covering doctor must retain Encounter share');
        System.assertEquals('Read', encShares[0].AccessLevel);

        List<Patient_Vital__Share> vitShares = [
            SELECT Id, AccessLevel FROM Patient_Vital__Share
            WHERE ParentId = :vit.Id AND UserOrGroupId = :docUser2.Id
              AND RowCause = :Schema.Patient_Vital__Share.RowCause.Care_Team__c
        ];
        System.assertEquals(1, vitShares.size(), 'Active covering doctor must retain Vital share');
        System.assertEquals('Read', vitShares[0].AccessLevel);
    }

    /**
     * Scenario 23: Idempotent reconciliation preserves Attending and Owner shares while removing expired Care_Team__c.
     */
    @isTest
    static void testCrossCoverReconciliation_IdempotentAndUnrelatedPreserved() {
        User docUser1 = createTestUser('doc23a', 'CareNest_Doctor', true);
        User docUser2 = createTestUser('doc23b', 'CareNest_Doctor', true);
        Doctor__c attendingDoc = createDoctor('Dr. TwentyThree Att', docUser1.Id);
        Doctor__c coveringDoc = createDoctor('Dr. TwentyThree Cov', docUser2.Id);
        Ward__c ward = createWard('Ward Cov23', 'WRD-SHR-23');
        Bed__c bed = createBed(ward, 'Bed C23', 'BED-SHR-C23');
        Contact pat = createPatient('PatTwentyThree');

        Admission__c adm = createAdmission(pat, bed, attendingDoc);
        adm.Covering_Doctor__c = coveringDoc.Id;
        adm.Covering_Start_Time__c = System.now().addHours(-4);
        adm.Covering_End_Time__c = System.now().addHours(2);
        update adm;

        Inpatient_Encounter__c enc = createEncounter(adm.Id, attendingDoc.Id);
        Patient_Vital__c vit = createVital(adm.Id, enc.Id);

        // Expire covering
        AdmissionTriggerHandler.bypassTrigger = true;
        adm.Covering_End_Time__c = System.now().addHours(-1);
        update adm;
        AdmissionTriggerHandler.bypassTrigger = false;

        Test.startTest();
        // First reconciliation
        ClinicalSharingService.reconcileCrossCoverShares(new Set<Id>{ adm.Id });
        // Second run to verify idempotency
        ClinicalSharingService.reconcileCrossCoverShares(new Set<Id>{ adm.Id });
        Test.stopTest();

        // Expired Care_Team__c shares must be zero
        List<Inpatient_Encounter__Share> encCoverShares = [
            SELECT Id FROM Inpatient_Encounter__Share
            WHERE ParentId = :enc.Id AND UserOrGroupId = :docUser2.Id
              AND RowCause = :Schema.Inpatient_Encounter__Share.RowCause.Care_Team__c
        ];
        System.assertEquals(0, encCoverShares.size(), 'Expired covering encounter share must be revoked');

        List<Patient_Vital__Share> vitCoverShares = [
            SELECT Id FROM Patient_Vital__Share
            WHERE ParentId = :vit.Id AND UserOrGroupId = :docUser2.Id
              AND RowCause = :Schema.Patient_Vital__Share.RowCause.Care_Team__c
        ];
        System.assertEquals(0, vitCoverShares.size(), 'Expired covering vital share must be revoked');

        // Attending shares must remain intact
        List<Inpatient_Encounter__Share> attendingEncShares = [
            SELECT Id FROM Inpatient_Encounter__Share
            WHERE ParentId = :enc.Id AND UserOrGroupId = :docUser1.Id
              AND RowCause = :Schema.Inpatient_Encounter__Share.RowCause.Attending_Physician__c
        ];
        System.assertEquals(1, attendingEncShares.size(), 'Attending physician Encounter share must be preserved');

        List<Patient_Vital__Share> attendingVitShares = [
            SELECT Id FROM Patient_Vital__Share
            WHERE ParentId = :vit.Id AND UserOrGroupId = :docUser1.Id
              AND RowCause = :Schema.Patient_Vital__Share.RowCause.Attending_Physician__c
        ];
        System.assertEquals(1, attendingVitShares.size(), 'Attending physician Vital share must be preserved');
    }

    /**
     * Scenario 24: Clinicians operating under CareNest_Doctor cannot edit Doctor__c.User__c mapping.
     */
    @isTest
    static void testCareNestDoctor_CannotEditDoctorUserMapping() {
        User docUser = createTestUser('doc24', 'CareNest_Doctor', true);

        Test.startTest();
        System.runAs(docUser) {
            Boolean canEditUser = Schema.sObjectType.Doctor__c.fields.User__c.isUpdateable();
            System.assertEquals(false, canEditUser, 'Doctor__c.User__c must not be updateable by CareNest_Doctor user');
        }
        Test.stopTest();
    }
}
