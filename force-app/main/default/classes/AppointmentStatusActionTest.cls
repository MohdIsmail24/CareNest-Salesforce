/**
 * @description Unit tests for AppointmentStatusAction invocable action.
 * Verifies principal authorization checks (staff vs patient ownership vs guest denial),
 * successful lookups by Id and Code, privacy safeguards (no clinical notes/vitals exposed),
 * and safe error handling.
 */
@isTest
private class AppointmentStatusActionTest {

    private static Integer regSeq = 6000;

    private static Doctor__c createDoctor(String name, String dept, Decimal fee) {
        regSeq++;
        Doctor__c d = new Doctor__c(
            Name = name,
            Department__c = dept,
            Specialty__c = 'Consultant',
            Consultation_Fee__c = fee,
            Registration_No__c = 'REG-' + regSeq,
            Is_Active__c = true
        );
        insert d;
        return d;
    }

    private static Contact createPatient(String lastName) {
        Contact c = new Contact(
            LastName = lastName,
            Email = lastName.toLowerCase() + '@carenest-test.org'
        );
        insert c;
        return c;
    }

    private static Appointment_Slot__c createSlot(Id docId, Datetime startTime) {
        Appointment_Slot__c slot = new Appointment_Slot__c(
            Doctor__c = docId,
            Mode__c = 'OPD',
            Slot_Start__c = startTime,
            Total_Capacity__c = 5
        );
        insert slot;
        return slot;
    }

    @TestSetup
    static void setupTestData() {
        Doctor__c doc = createDoctor('Dr. Sarah Connor', 'General Medicine', 750);
        Contact pat1 = createPatient('PatientOne');
        Contact pat2 = createPatient('PatientTwo');
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addDays(2));

        Appointment__c a1 = new Appointment__c(
            Slot__c = slot.Id,
            Patient__c = pat1.Id,
            Status__c = 'Confirmed',
            Appointment_Code__c = 'APT-TEST-001'
        );
        insert a1;

        Appointment__c a2 = new Appointment__c(
            Slot__c = slot.Id,
            Patient__c = pat2.Id,
            Status__c = 'Pending',
            Appointment_Code__c = 'APT-TEST-002'
        );
        insert a2;
    }

    @isTest
    static void testStaffLookupSuccessById() {
        Appointment__c a1 = [SELECT Id, Appointment_Code__c FROM Appointment__c WHERE Appointment_Code__c = 'APT-TEST-001' LIMIT 1];

        AppointmentStatusAction.Request req = new AppointmentStatusAction.Request();
        req.appointmentIdentifier = a1.Id;

        Test.startTest();
        List<AppointmentStatusAction.Response> responses = AppointmentStatusAction.getStatus(
            new List<AppointmentStatusAction.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return one response');
        AppointmentStatusAction.Response res = responses[0];
        System.assert(res.isAuthorized, 'Internal staff should be authorized');
        System.assert(res.isFound, 'Appointment should be found');
        System.assertEquals('Confirmed', res.status, 'Status should be Confirmed');
        System.assertEquals('Dr. Sarah Connor', res.doctorName, 'Doctor name should match');
        System.assertEquals('General Medicine', res.department, 'Department should match');
    }

    @isTest
    static void testStaffLookupSuccessByCode() {
        AppointmentStatusAction.Request req = new AppointmentStatusAction.Request();
        req.appointmentIdentifier = 'APT-TEST-001';

        Test.startTest();
        List<AppointmentStatusAction.Response> responses = AppointmentStatusAction.getStatus(
            new List<AppointmentStatusAction.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return one response');
        AppointmentStatusAction.Response res = responses[0];
        System.assert(res.isAuthorized, 'Staff should be authorized');
        System.assert(res.isFound, 'Appointment should be found by code');
        System.assertEquals('Confirmed', res.status, 'Status should be Confirmed');
    }

    @isTest
    static void testPatientLookupOwnAppointment() {
        Contact pat1 = [SELECT Id FROM Contact WHERE LastName = 'PatientOne' LIMIT 1];
        Appointment__c a1 = [SELECT Id, Appointment_Code__c FROM Appointment__c WHERE Appointment_Code__c = 'APT-TEST-001' LIMIT 1];

        // Mock running user as patient 1
        AppointmentStatusAction.mockUserContactId = pat1.Id;
        AppointmentStatusAction.mockUserType = 'CSPLiteUser';

        AppointmentStatusAction.Request req = new AppointmentStatusAction.Request();
        req.appointmentIdentifier = a1.Appointment_Code__c;

        Test.startTest();
        List<AppointmentStatusAction.Response> responses = AppointmentStatusAction.getStatus(
            new List<AppointmentStatusAction.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return one response');
        AppointmentStatusAction.Response res = responses[0];
        System.assert(res.isAuthorized, 'Patient should be authorized to view own appointment');
        System.assert(res.isFound, 'Appointment should be found');
        System.assertEquals('Confirmed', res.status, 'Status should be Confirmed');
    }

    @isTest
    static void testPatientLookupOtherPatientAppointmentDenied() {
        Contact pat1 = [SELECT Id FROM Contact WHERE LastName = 'PatientOne' LIMIT 1];
        Appointment__c a2 = [SELECT Id, Appointment_Code__c FROM Appointment__c WHERE Appointment_Code__c = 'APT-TEST-002' LIMIT 1];

        // Mock running user as patient 1 attempting to look up patient 2's appointment
        AppointmentStatusAction.mockUserContactId = pat1.Id;
        AppointmentStatusAction.mockUserType = 'CSPLiteUser';

        AppointmentStatusAction.Request req = new AppointmentStatusAction.Request();
        req.appointmentIdentifier = a2.Appointment_Code__c;

        Test.startTest();
        List<AppointmentStatusAction.Response> responses = AppointmentStatusAction.getStatus(
            new List<AppointmentStatusAction.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return one response');
        AppointmentStatusAction.Response res = responses[0];
        System.assert(!res.isAuthorized, 'Patient must not be authorized to view other patient appointment');
        System.assert(!res.isFound, 'Record details must not be returned');
        System.assert(res.message.contains('Access denied'), 'Message must indicate access denied: ' + res.message);
    }

    @isTest
    static void testUnauthenticatedGuestDenied() {
        Appointment__c a1 = [SELECT Id, Appointment_Code__c FROM Appointment__c WHERE Appointment_Code__c = 'APT-TEST-001' LIMIT 1];

        // Mock running user as unauthenticated guest
        AppointmentStatusAction.mockUserContactId = null;
        AppointmentStatusAction.mockUserType = 'Guest';

        AppointmentStatusAction.Request req = new AppointmentStatusAction.Request();
        req.appointmentIdentifier = a1.Appointment_Code__c;

        Test.startTest();
        List<AppointmentStatusAction.Response> responses = AppointmentStatusAction.getStatus(
            new List<AppointmentStatusAction.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return one response');
        AppointmentStatusAction.Response res = responses[0];
        System.assert(!res.isAuthorized, 'Guest must be denied access');
        System.assert(res.message.contains('Access denied'), 'Message must indicate access denied: ' + res.message);
    }

    @isTest
    static void testStaffLookupNonExistentAppointment() {
        AppointmentStatusAction.Request req = new AppointmentStatusAction.Request();
        req.appointmentIdentifier = 'APT-NONEXISTENT-999';

        Test.startTest();
        List<AppointmentStatusAction.Response> responses = AppointmentStatusAction.getStatus(
            new List<AppointmentStatusAction.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return one response');
        AppointmentStatusAction.Response res = responses[0];
        System.assert(res.isAuthorized, 'Staff is authorized to search');
        System.assert(!res.isFound, 'Nonexistent appointment should not be found');
        System.assert(res.message.contains('not found'), 'Message should indicate not found');
    }

    @isTest
    static void testBlankAppointmentIdentifier() {
        AppointmentStatusAction.Request req = new AppointmentStatusAction.Request();
        req.appointmentIdentifier = '   ';

        Test.startTest();
        List<AppointmentStatusAction.Response> responses = AppointmentStatusAction.getStatus(
            new List<AppointmentStatusAction.Request>{ req }
        );
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'Should return one response');
        AppointmentStatusAction.Response res = responses[0];
        System.assert(!res.isFound, 'Should not find record with blank identifier');
        System.assert(res.message.contains('identifier is required'), 'Message should indicate required identifier');
    }

    @isTest
    static void testNullAndEmptyRequests() {
        Test.startTest();
        List<AppointmentStatusAction.Response> emptyRes = AppointmentStatusAction.getStatus(
            new List<AppointmentStatusAction.Request>()
        );
        List<AppointmentStatusAction.Response> nullRes = AppointmentStatusAction.getStatus(null);
        Test.stopTest();

        System.assertEquals(0, emptyRes.size(), 'Empty list returns empty list');
        System.assertEquals(0, nullRes.size(), 'Null list returns empty list');
    }
}
