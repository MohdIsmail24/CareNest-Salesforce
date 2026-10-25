@IsTest
private class CareNestAppointmentControllerTest {

    @TestSetup
    static void setupTestData() {
        Doctor__c doc1 = new Doctor__c(
            Name = 'Dr. Anita Roy',
            Department__c = 'General Medicine',
            Specialty__c = 'Internal Medicine',
            Registration_No__c = 'REG-APPT-01',
            Consultation_Fee__c = 1200,
            Is_Active__c = true
        );
        Doctor__c doc2 = new Doctor__c(
            Name = 'Dr. Rajesh Khanna',
            Department__c = 'General Medicine',
            Specialty__c = 'Internal Medicine',
            Registration_No__c = 'REG-APPT-02',
            Consultation_Fee__c = 1000,
            Is_Active__c = true
        );
        insert new List<Doctor__c>{ doc1, doc2 };

        Datetime tmrw = Datetime.now().addDays(1);
        Datetime slot1Start = Datetime.newInstance(tmrw.year(), tmrw.month(), tmrw.day(), 10, 0, 0);
        Datetime slot2Start = Datetime.newInstance(tmrw.year(), tmrw.month(), tmrw.day(), 11, 0, 0);

        Appointment_Slot__c slot1 = new Appointment_Slot__c(
            Doctor__c = doc1.Id,
            Slot_Start__c = slot1Start,
            Total_Capacity__c = 1,
            Booked_Count__c = 0,
            Mode__c = 'OPD'
        );
        Appointment_Slot__c slot2 = new Appointment_Slot__c(
            Doctor__c = doc2.Id,
            Slot_Start__c = slot2Start,
            Total_Capacity__c = 2,
            Booked_Count__c = 0,
            Mode__c = 'OPD'
        );
        insert new List<Appointment_Slot__c>{ slot1, slot2 };

        Contact pat1 = new Contact(
            FirstName = 'Rohan',
            LastName = 'Kapoor',
            Phone = '9998887771',
            Email = 'rohan@example.com',
            Patient_Code__c = 'CN-PAT-90001'
        );
        Contact pat2 = new Contact(
            FirstName = 'Simran',
            LastName = 'Kaur',
            Phone = '9998887772',
            Email = 'simran@example.com',
            Patient_Code__c = 'CN-PAT-90002'
        );
        insert new List<Contact>{ pat1, pat2 };
    }

    @IsTest
    static void testGetSchedulingInitData() {
        Test.startTest();
        CareNestAppointmentController.AppointmentInitDto initData = CareNestAppointmentController.getSchedulingInitData();
        Test.stopTest();

        System.assertNotEquals(null, initData, 'Init data should not be null');
        System.assert(initData.departments.size() > 0, 'Departments should be populated');
        System.assert(initData.doctors.size() >= 2, 'At least 2 doctors configured');
    }

    @IsTest
    static void testFindAvailableSlots() {
        Doctor__c doc = [SELECT Id FROM Doctor__c WHERE Name = 'Dr. Anita Roy' LIMIT 1];
        Date targetDate = Date.today().addDays(1);

        Test.startTest();
        List<CareNestAppointmentController.FlexibleSlotDto> slotsForDoc = CareNestAppointmentController.findAvailableSlots(doc.Id, null, targetDate, 'OPD');
        List<CareNestAppointmentController.FlexibleSlotDto> slotsAnyDoc = CareNestAppointmentController.findAvailableSlots(null, 'General Medicine', targetDate, 'OPD');
        Test.stopTest();

        System.assertEquals(1, slotsForDoc.size(), 'Doctor Anita should have 1 slot');
        System.assertEquals(2, slotsAnyDoc.size(), 'General Medicine department should have 2 slots');
    }

    @IsTest
    static void testBookFlexibleAppointmentSuccessAndConflictAlternatives() {
        Appointment_Slot__c slot = [SELECT Id, Doctor__c FROM Appointment_Slot__c WHERE Total_Capacity__c = 1 LIMIT 1];
        Contact pat1 = [SELECT Id FROM Contact WHERE Email = 'rohan@example.com' LIMIT 1];
        Contact pat2 = [SELECT Id FROM Contact WHERE Email = 'simran@example.com' LIMIT 1];

        Test.startTest();
        // First booking should succeed and fill slot (capacity = 1)
        CareNestAppointmentController.BookingResultDto res1 = CareNestAppointmentController.bookFlexibleAppointment(
            pat1.Id, slot.Doctor__c, 'General Medicine', slot.Id, null, null, 'OPD'
        );

        // Second booking on full slot should detect conflict and return alternative slots
        CareNestAppointmentController.BookingResultDto res2 = CareNestAppointmentController.bookFlexibleAppointment(
            pat2.Id, slot.Doctor__c, 'General Medicine', slot.Id, null, null, 'OPD'
        );
        Test.stopTest();

        System.assertEquals(true, res1.isSuccess, 'First booking must succeed');
        System.assertNotEquals(null, res1.appointmentId, 'Appointment record created');

        System.assertEquals(false, res2.isSuccess, 'Second booking on full slot must not succeed');
        System.assertEquals(true, res2.isConflict, 'Conflict flag must be set');
        System.assert(res2.alternativeSlots.size() > 0, 'Alternative slot suggestions must be returned');
    }

    @IsTest
    static void testManualDateTimeBookingValidation() {
        Doctor__c doc = [SELECT Id FROM Doctor__c WHERE Name = 'Dr. Rajesh Khanna' LIMIT 1];
        Contact pat = [SELECT Id FROM Contact WHERE Email = 'rohan@example.com' LIMIT 1];
        Date targetDate = Date.today().addDays(2);

        Test.startTest();
        // 1. Valid operating hours (14:30)
        CareNestAppointmentController.BookingResultDto validRes = CareNestAppointmentController.bookFlexibleAppointment(
            pat.Id, doc.Id, 'General Medicine', null, targetDate, '14:30', 'OPD'
        );

        // 2. Outside operating hours (22:00)
        CareNestAppointmentController.BookingResultDto invalidHoursRes = CareNestAppointmentController.bookFlexibleAppointment(
            pat.Id, doc.Id, 'General Medicine', null, targetDate, '22:00', 'OPD'
        );
        Test.stopTest();

        System.assertEquals(true, validRes.isSuccess, 'Valid working hours booking must succeed');
        System.assertEquals(true, invalidHoursRes.isConflict, 'Outside hours booking must trigger conflict');
        System.assert(invalidHoursRes.message.contains('operating hours'), 'Message mentions operating hours');
    }

    @IsTest
    static void testRescheduleAndCancelAppointment() {
        Appointment_Slot__c slot1 = [SELECT Id, Doctor__c FROM Appointment_Slot__c WHERE Total_Capacity__c = 1 LIMIT 1];
        Appointment_Slot__c slot2 = [SELECT Id FROM Appointment_Slot__c WHERE Total_Capacity__c = 2 LIMIT 1];
        Contact pat = [SELECT Id FROM Contact WHERE Email = 'rohan@example.com' LIMIT 1];

        CareNestAppointmentController.BookingResultDto bookRes = CareNestAppointmentController.bookFlexibleAppointment(
            pat.Id, slot1.Doctor__c, 'General Medicine', slot1.Id, null, null, 'OPD'
        );

        Test.startTest();
        // Reschedule to slot 2
        CareNestAppointmentController.BookingResultDto reschedRes = CareNestAppointmentController.rescheduleAppointment(
            bookRes.appointmentId, slot2.Id
        );

        // Cancel booking
        Boolean cancelSuccess = CareNestAppointmentController.cancelAppointmentBooking(bookRes.appointmentId, 'Patient requested');
        Test.stopTest();

        System.assertEquals(true, reschedRes.isSuccess, 'Reschedule should succeed');
        System.assertEquals(true, cancelSuccess, 'Cancel should succeed');

        Appointment__c appt = [SELECT Id, Status__c, Slot__c FROM Appointment__c WHERE Id = :bookRes.appointmentId];
        System.assertEquals('Cancelled', appt.Status__c, 'Appointment status should be Cancelled');
        System.assertEquals(slot2.Id, appt.Slot__c, 'Slot should be updated to slot 2');
    }

    @IsTest
    static void testManualDateTimeOverlappingConcurrentBookingPrevention() {
        Doctor__c doc = [SELECT Id FROM Doctor__c WHERE Name = 'Dr. Anita Roy' LIMIT 1];
        Contact pat1 = [SELECT Id FROM Contact WHERE Email = 'rohan@example.com' LIMIT 1];
        Contact pat2 = [SELECT Id FROM Contact WHERE Email = 'simran@example.com' LIMIT 1];
        Date targetDate = Date.today().addDays(1);

        Test.startTest();
        // First manual booking for Dr. Anita at 14:30 (creates/reserves slot with capacity=1)
        CareNestAppointmentController.BookingResultDto res1 = CareNestAppointmentController.bookFlexibleAppointment(
            pat1.Id, doc.Id, 'General Medicine', null, targetDate, '14:30', 'OPD'
        );

        // Second manual booking attempting to overlap same doctor in the same 30-min window (14:40 -> rounds to 14:30)
        CareNestAppointmentController.BookingResultDto res2 = CareNestAppointmentController.bookFlexibleAppointment(
            pat2.Id, doc.Id, 'General Medicine', null, targetDate, '14:40', 'OPD'
        );
        Test.stopTest();

        System.assertEquals(true, res1.isSuccess, 'First manual booking must succeed');
        System.assertNotEquals(null, res1.appointmentId, 'First appointment must have Id');

        System.assertEquals(false, res2.isSuccess, 'Second overlapping manual booking must NOT succeed');
        System.assertEquals(true, res2.isConflict, 'Second overlapping booking must trigger conflict flag');
        System.assertNotEquals(null, res2.alternativeSlots, 'Alternative slots list must not be null');
        System.assert(res2.alternativeSlots.size() > 0, 'Must return alternative slots for conflict');
    }
}
