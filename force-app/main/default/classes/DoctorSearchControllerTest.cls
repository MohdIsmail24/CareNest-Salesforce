/**
 * @description Comprehensive unit tests for DoctorSearchController verifying security,
 * input validation, user mode execution, booking concurrency, and cancellation.
 */
@isTest
private class DoctorSearchControllerTest {

    private static Integer seq = 8000;

    private static Doctor__c createDoctor(String name, String dept, Decimal fee) {
        seq++;
        Doctor__c doc = new Doctor__c(
            Name = name,
            Registration_No__c = 'REG-' + seq,
            Department__c = dept,
            Specialty__c = 'Family Medicine',
            Consultation_Fee__c = fee,
            Is_Active__c = true
        );
        insert doc;
        return doc;
    }

    private static Contact createPatient(String lastName, String patCode) {
        seq++;
        Contact c = new Contact(
            LastName = lastName,
            Email = lastName.toLowerCase() + seq + '@testcarenest.com',
            Phone = '555000' + seq,
            Patient_Code__c = patCode
        );
        insert c;
        return c;
    }

    private static Appointment_Slot__c createSlot(Id docId, Datetime startTime, Decimal capacity, String mode) {
        Appointment_Slot__c slot = new Appointment_Slot__c(
            Doctor__c = docId,
            Mode__c = mode,
            Slot_Start__c = startTime,
            Total_Capacity__c = capacity
        );
        insert slot;
        return slot;
    }

    @isTest
    static void testGetUserContext() {
        Test.startTest();
        DoctorSearchController.UserContextDto ctx = DoctorSearchController.getUserContext();
        Test.stopTest();
        System.assertNotEquals(null, ctx, 'Context should not be null');
        System.assertEquals(false, ctx.isPatient, 'Admin test user is not a patient');
    }

    @isTest
    static void testGetDoctors() {
        createDoctor('Dr. Alpha Doc', 'General Medicine', 500);
        createDoctor('Dr. Beta Doc', 'Paediatrics', 600);

        Test.startTest();
        List<Doctor__c> allDocs = DoctorSearchController.getDoctors('All', '');
        List<Doctor__c> genMed = DoctorSearchController.getDoctors('General Medicine', '');
        List<Doctor__c> alpha = DoctorSearchController.getDoctors('', 'Alpha');
        Test.stopTest();

        System.assert(allDocs.size() >= 2, 'Should return all active doctors');
        System.assert(genMed.size() >= 1, 'Should filter by department');
        System.assert(alpha.size() >= 1, 'Should filter by doctor name');
    }

    @isTest
    static void testSearchSlots() {
        Doctor__c doc = createDoctor('Dr. Slot Doc', 'General Medicine', 500);
        createSlot(doc.Id, System.now().addDays(3), 5, 'OPD');

        Test.startTest();
        List<DoctorSearchController.SlotOption> slots = DoctorSearchController.searchSlots('General Medicine', 'OPD', System.today().addDays(3));
        List<DoctorSearchController.SlotOption> allSlots = DoctorSearchController.searchSlots('', '', null);
        Test.stopTest();

        System.assertNotEquals(null, slots, 'Slots list should not be null');
        System.assert(allSlots.size() >= 1, 'Should find open slots');
    }

    @isTest
    static void testGetDoctorSlots() {
        Doctor__c doc = createDoctor('Dr. Open Slots', 'Dermatology', 700);
        createSlot(doc.Id, System.now().addDays(2), 4, 'Teleconsult');

        Test.startTest();
        List<DoctorSearchController.SlotOption> slots = DoctorSearchController.getDoctorSlots(doc.Id, null);
        List<DoctorSearchController.SlotOption> datedSlots = DoctorSearchController.getDoctorSlots(doc.Id, System.today().addDays(2));
        Test.stopTest();

        System.assertEquals(1, slots.size(), 'Should find 1 open slot');
        System.assertEquals(1, datedSlots.size(), 'Should find 1 dated open slot');
        System.assertEquals('Teleconsult', slots[0].mode, 'Mode should match');
    }

    @isTest
    static void testGetDoctorSlotsInvalidId() {
        Boolean caught = false;
        Test.startTest();
        try {
            DoctorSearchController.getDoctorSlots(null, null);
        } catch (AuraHandledException e) {
            caught = true;
        }
        Test.stopTest();
        System.assert(caught, 'Should catch invalid doctor ID');
    }

    @isTest
    static void testSearchPatients() {
        createPatient('Sharma', 'CN-PAT-TEST1');

        Test.startTest();
        List<Contact> emptyQuery = DoctorSearchController.searchPatients('A');
        List<Contact> byCode = DoctorSearchController.searchPatients('CN-PAT-TEST1');
        List<Contact> byName = DoctorSearchController.searchPatients('Shar');
        Test.stopTest();

        System.assertEquals(0, emptyQuery.size(), 'Short query returns empty list');
        System.assertEquals(1, byCode.size(), 'Should find patient by code');
        System.assertEquals(1, byName.size(), 'Should find patient by partial name');
    }

    @isTest
    static void testBookAppointmentSuccess() {
        Doctor__c doc = createDoctor('Dr. Book Doc', 'ENT', 750);
        Contact pat = createPatient('PatBook', 'CN-PAT-BOOK');
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addDays(4), 5, 'OPD');

        Test.startTest();
        Appointment__c appt = DoctorSearchController.bookAppointment(slot.Id, pat.Id);
        Test.stopTest();

        System.assertNotEquals(null, appt, 'Appointment should be returned');
        System.assertEquals('Confirmed', appt.Status__c, 'Status should be Confirmed');
        System.assertEquals(750, appt.Fee_Amount__c, 'Fee should be copied from Doctor');
        System.assertEquals(750, appt.Total_Amount__c, 'Total amount should be calculated');

        Appointment_Slot__c slotAfter = [SELECT Id, Booked_Count__c FROM Appointment_Slot__c WHERE Id = :slot.Id];
        System.assertEquals(1, slotAfter.Booked_Count__c, 'Slot Booked_Count__c should be updated to 1');
    }

    @isTest
    static void testBookAppointmentSlotFull() {
        Doctor__c doc = createDoctor('Dr. Full Slot', 'General Medicine', 500);
        Contact pat1 = createPatient('PatOne', 'CN-PAT-01');
        Contact pat2 = createPatient('PatTwo', 'CN-PAT-02');
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addDays(4), 1, 'OPD');

        // Book first seat
        DoctorSearchController.bookAppointment(slot.Id, pat1.Id);

        Boolean caught = false;
        Test.startTest();
        try {
            // Attempt to book full slot
            DoctorSearchController.bookAppointment(slot.Id, pat2.Id);
        } catch (AuraHandledException e) {
            caught = true;
        }
        Test.stopTest();

        System.assert(caught, 'Should reject booking into full slot');
    }

    @isTest
    static void testCancelAppointment() {
        Doctor__c doc = createDoctor('Dr. Cancel Doc', 'Orthopaedics', 800);
        Contact pat = createPatient('PatCancel', 'CN-PAT-CNCL');
        // More than 24 hours in future (0% cancellation fee)
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addDays(3), 5, 'OPD');
        Appointment__c appt = DoctorSearchController.bookAppointment(slot.Id, pat.Id);

        Test.startTest();
        DoctorSearchController.CancelResultDto res = DoctorSearchController.cancelAppointment(appt.Id, 'Schedule conflict');
        Test.stopTest();

        System.assertNotEquals(null, res, 'Result should not be null');
        System.assertEquals(true, res.isSuccess, 'Cancellation should succeed');
        System.assertEquals(0, res.fee, 'Fee should be 0 for >24h cancellation');

        Appointment__c apptAfter = [SELECT Id, Status__c FROM Appointment__c WHERE Id = :appt.Id];
        System.assertEquals('Cancelled', apptAfter.Status__c, 'Status should be Cancelled');

        Appointment_Slot__c slotAfter = [SELECT Id, Booked_Count__c FROM Appointment_Slot__c WHERE Id = :slot.Id];
        System.assertEquals(0, slotAfter.Booked_Count__c, 'Slot booked count should decrement to 0');
    }

    @isTest
    static void testGetMyAppointmentsWithoutPortalContext() {
        Boolean caught = false;
        Test.startTest();
        try {
            DoctorSearchController.getMyAppointments();
        } catch (AuraHandledException e) {
            caught = true;
        }
        Test.stopTest();
        System.assert(caught, 'Internal users without contact identity must be rejected securely');
    }

    @isTest
    static void testSearchPatientsPortalUserForbidden() {
        Contact pat = createPatient('PortalUser', 'CN-PAT-PRTL');
        DoctorSearchController.mockContactId = pat.Id;

        Boolean caught = false;
        Test.startTest();
        try {
            DoctorSearchController.searchPatients('Shar');
        } catch (AuraHandledException e) {
            caught = true;
        }
        Test.stopTest();

        System.assert(caught, 'Portal users must be forbidden from searching patient directory');
    }

    @isTest
    static void testPortalUserContextAndAppointments() {
        Contact pat = createPatient('PortalPat', 'CN-PAT-PORT');
        Doctor__c doc = createDoctor('Dr. Portal Doc', 'Dermatology', 600);
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addDays(5), 3, 'Teleconsult');

        DoctorSearchController.mockContactId = pat.Id;

        Test.startTest();
        DoctorSearchController.UserContextDto ctx = DoctorSearchController.getUserContext();
        Appointment__c appt = DoctorSearchController.bookAppointment(slot.Id, null);
        List<Appointment__c> myAppts = DoctorSearchController.getMyAppointments();
        Test.stopTest();

        System.assertEquals(true, ctx.isPatient, 'Should identify as portal patient');
        System.assertEquals(pat.Id, ctx.contactId, 'ContactId should match mock');
        System.assertNotEquals(null, appt, 'Appointment should be booked for portal patient');
        System.assertEquals(1, myAppts.size(), 'Should retrieve patient appointment');
    }

    @isTest
    static void testCancelAppointmentPortalUserForbiddenForOtherPatient() {
        Contact pat1 = createPatient('OwnerPat', 'CN-PAT-OWN');
        Contact pat2 = createPatient('AttackerPat', 'CN-PAT-ATK');
        Doctor__c doc = createDoctor('Dr. Owner Doc', 'ENT', 550);
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addDays(6), 3, 'OPD');

        DoctorSearchController.mockContactId = pat1.Id;
        Appointment__c appt = DoctorSearchController.bookAppointment(slot.Id, null);

        // Switch identity to pat2
        DoctorSearchController.mockContactId = pat2.Id;

        Boolean caught = false;
        Test.startTest();
        try {
            DoctorSearchController.cancelAppointment(appt.Id, 'Malicious cancel');
        } catch (AuraHandledException e) {
            caught = true;
        }
        Test.stopTest();

        System.assert(caught, 'Portal user must not be able to cancel another patient appointment');
    }

    @isTest
    static void testGetBillingDetailsSuccess() {
        Contact pat = createPatient('BillingPat', 'CN-PAT-BILL');
        Doctor__c doc = createDoctor('Dr. Bill Doc', 'General Medicine', 500);
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addDays(4), 5, 'OPD');

        DoctorSearchController.mockContactId = pat.Id;
        Appointment__c appt = DoctorSearchController.bookAppointment(slot.Id, null);

        Test.startTest();
        Appointment__c bill = DoctorSearchController.getBillingDetails(appt.Id);
        Test.stopTest();

        System.assertNotEquals(null, bill, 'Billing details should not be null');
        System.assertEquals(appt.Id, bill.Id, 'ID should match');
        System.assertEquals(500, bill.Fee_Amount__c, 'Fee should match doctor consultation fee');
        System.assertEquals(pat.Id, bill.Patient__c, 'Patient should match');
    }

    @isTest
    static void testGetBillingDetailsInvalidId() {
        Boolean caught = false;
        Test.startTest();
        try {
            DoctorSearchController.getBillingDetails(null);
        } catch (AuraHandledException e) {
            caught = true;
        }
        Test.stopTest();

        System.assert(caught, 'Null ID should be rejected');
    }

    @isTest
    static void testGetBillingDetailsPortalUserForbidden() {
        Contact pat1 = createPatient('BillOwner', 'CN-PAT-BOWN');
        Contact pat2 = createPatient('BillAttacker', 'CN-PAT-BATK');
        Doctor__c doc = createDoctor('Dr. BDoc', 'General Medicine', 750);
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addDays(4), 5, 'OPD');

        DoctorSearchController.mockContactId = pat1.Id;
        Appointment__c appt = DoctorSearchController.bookAppointment(slot.Id, null);

        // Switch to attacker portal user
        DoctorSearchController.mockContactId = pat2.Id;

        Boolean caught = false;
        Test.startTest();
        try {
            DoctorSearchController.getBillingDetails(appt.Id);
        } catch (AuraHandledException e) {
            caught = true;
        }
        Test.stopTest();

        System.assert(caught, 'Portal user should not be able to view billing details of other patient');
    }

    @isTest
    static void testPatientPortalDataIsolationAcrossUsers() {
        Contact pat1 = createPatient('IsolationPat1', 'CN-PAT-ISO1');
        Contact pat2 = createPatient('IsolationPat2', 'CN-PAT-ISO2');
        Doctor__c doc = createDoctor('Dr. Iso Doc', 'General Medicine', 650);
        Appointment_Slot__c slot1 = createSlot(doc.Id, System.now().addDays(3), 5, 'OPD');
        Appointment_Slot__c slot2 = createSlot(doc.Id, System.now().addDays(4), 5, 'OPD');

        // Book appointment for Patient 1
        DoctorSearchController.mockContactId = pat1.Id;
        Appointment__c appt1 = DoctorSearchController.bookAppointment(slot1.Id, null);

        // Book appointment for Patient 2
        DoctorSearchController.mockContactId = pat2.Id;
        Appointment__c appt2 = DoctorSearchController.bookAppointment(slot2.Id, null);

        Test.startTest();
        // Verify Patient 1 only sees their own appointment
        DoctorSearchController.mockContactId = pat1.Id;
        List<Appointment__c> apptsPat1 = DoctorSearchController.getMyAppointments();
        System.assertEquals(1, apptsPat1.size(), 'Patient 1 must only see 1 appointment');
        System.assertEquals(appt1.Id, apptsPat1[0].Id, 'Patient 1 must see their own appointment ID');

        // Verify Patient 2 only sees their own appointment
        DoctorSearchController.mockContactId = pat2.Id;
        List<Appointment__c> apptsPat2 = DoctorSearchController.getMyAppointments();
        System.assertEquals(1, apptsPat2.size(), 'Patient 2 must only see 1 appointment');
        System.assertEquals(appt2.Id, apptsPat2[0].Id, 'Patient 2 must see their own appointment ID');
        Test.stopTest();
    }

    @isTest
    static void testInternalAdminContextAndEmptyPatientResults() {
        // 1. Verify empty appointment results for a portal patient with no appointments
        Contact emptyPat = createPatient('EmptyPat', 'CN-PAT-EMPTY');
        DoctorSearchController.mockContactId = emptyPat.Id;
        List<Appointment__c> emptyAppts = DoctorSearchController.getMyAppointments();
        System.assertEquals(0, emptyAppts.size(), 'Portal patient with no appointments should receive empty list gracefully');

        // 2. Verify internal System Administrator context (no associated contact profile)
        DoctorSearchController.mockContactId = null;

        Test.startTest();
        DoctorSearchController.UserContextDto adminCtx = DoctorSearchController.getUserContext();
        System.assertEquals(false, adminCtx.isPatient, 'Admin should not be identified as patient portal user');
        System.assertEquals(null, adminCtx.contactId, 'Admin contact ID must be null');

        Boolean caught = false;
        String caughtMessage = '';
        try {
            DoctorSearchController.getMyAppointments();
        } catch (AuraHandledException e) {
            caught = true;
            caughtMessage = e.getMessage();
        }
        Test.stopTest();

        System.assert(caught, 'Admin user without contact identity must fail closed with AuraHandledException');
    }
}
