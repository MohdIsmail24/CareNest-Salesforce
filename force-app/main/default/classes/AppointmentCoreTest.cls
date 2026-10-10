/**
 * @description Comprehensive unit tests for Phase 07 Apex Core layer:
 * Trigger, TriggerHandler, AppointmentService, CancellationService, and CancelAppointmentAction.
 */
@isTest
private class AppointmentCoreTest {

    private static Integer regSeq = 1000;

    private static Doctor__c createDoctor(String name, Decimal fee) {
        regSeq++;
        Doctor__c doc = new Doctor__c(
            Name = name,
            Registration_No__c = 'R-' + regSeq,
            Department__c = 'General Medicine',
            Specialty__c = 'Family Physician',
            Consultation_Fee__c = fee,
            Is_Active__c = true
        );
        insert doc;
        return doc;
    }

    private static Contact createPatient(String lastName) {
        Contact c = new Contact(
            LastName = lastName,
            Email = lastName.toLowerCase() + '@testcarenest.com'
        );
        insert c;
        return c;
    }

    private static Appointment_Slot__c createSlot(Id docId, Datetime startTime, Decimal capacity) {
        Appointment_Slot__c slot = new Appointment_Slot__c(
            Doctor__c = docId,
            Mode__c = 'OPD',
            Slot_Start__c = startTime,
            Total_Capacity__c = capacity
        );
        insert slot;
        return slot;
    }

    @isTest
    static void testValidBookingAndTotalsCalculation() {
        Doctor__c doc = createDoctor('Dr. Test Setup', 800);
        Contact pat = createPatient('PatOne');
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addDays(3), 2);

        Test.startTest();
        // Insert appointment with null fee (should copy from doctor) and 10% discount
        Appointment__c appt = new Appointment__c(
            Slot__c = slot.Id,
            Patient__c = pat.Id,
            Status__c = 'Confirmed',
            Discount_Percent__c = 10
        );
        insert appt;
        Test.stopTest();

        Appointment__c refreshed = [SELECT Id, Fee_Amount__c, Discount_Percent__c, Total_Amount__c FROM Appointment__c WHERE Id = :appt.Id];
        System.assertEquals(800, refreshed.Fee_Amount__c, 'Fee should copy from Doctor');
        // 800 * (1 - 0.10) = 720
        System.assertEquals(720, refreshed.Total_Amount__c, 'Total should equal Fee minus Discount');

        Appointment_Slot__c slotRefreshed = [SELECT Id, Booked_Count__c FROM Appointment_Slot__c WHERE Id = :slot.Id];
        System.assertEquals(1, slotRefreshed.Booked_Count__c, 'Booked count on slot should increment to 1');
    }

    @isTest
    static void testDoubleBookingSlotFullRejected() {
        Doctor__c doc = createDoctor('Dr. Capacity Test', 600);
        Contact pat1 = createPatient('PatFull1');
        Contact pat2 = createPatient('PatFull2');
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addDays(4), 1);

        // First booking succeeds
        Appointment__c appt1 = new Appointment__c(
            Slot__c = slot.Id,
            Patient__c = pat1.Id,
            Status__c = 'Confirmed',
            Fee_Amount__c = 600,
            Discount_Percent__c = 0
        );
        insert appt1;

        Test.startTest();
        Boolean exceptionCaught = false;
        try {
            // Second booking should fail capacity check
            Appointment__c appt2 = new Appointment__c(
                Slot__c = slot.Id,
                Patient__c = pat2.Id,
                Status__c = 'Confirmed',
                Fee_Amount__c = 600,
                Discount_Percent__c = 0
            );
            insert appt2;
        } catch (DmlException e) {
            exceptionCaught = true;
            System.assert(e.getMessage().contains('This slot is full. Please choose another time.'),
                'Expected slot full error message, got: ' + e.getMessage());
        }
        Test.stopTest();

        System.assert(exceptionCaught, 'Expected DmlException when attempting to exceed slot capacity');
    }

    @isTest
    static void testStatusChangeAndBookedCountRecalculation() {
        Doctor__c doc = createDoctor('Dr. Status Change', 500);
        Contact pat = createPatient('PatStatus');
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addDays(5), 3);

        Appointment__c appt = new Appointment__c(
            Slot__c = slot.Id,
            Patient__c = pat.Id,
            Status__c = 'Pending',
            Fee_Amount__c = 500,
            Discount_Percent__c = 0
        );
        insert appt;

        Appointment_Slot__c s1 = [SELECT Booked_Count__c FROM Appointment_Slot__c WHERE Id = :slot.Id];
        System.assertEquals(1, s1.Booked_Count__c, 'Pending counts as booked seat');

        Test.startTest();
        // Update status to Cancelled (should decrement booked count)
        appt.Status__c = 'Cancelled';
        update appt;
        Test.stopTest();

        Appointment_Slot__c s2 = [SELECT Booked_Count__c FROM Appointment_Slot__c WHERE Id = :slot.Id];
        System.assertEquals(0, s2.Booked_Count__c, 'Cancelled status releases booked seat');
    }

    @isTest
    static void testCancellationServiceMoreThan24Hours() {
        Doctor__c doc = createDoctor('Dr. Policy 24h', 1000);
        Contact pat = createPatient('PatPolicy1');
        // Slot is 48 hours away (> 24h -> 0% fee, 100% refund)
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addHours(48), 5);

        Appointment__c appt = new Appointment__c(
            Slot__c = slot.Id,
            Patient__c = pat.Id,
            Status__c = 'Confirmed',
            Fee_Amount__c = 1000,
            Discount_Percent__c = 0
        );
        insert appt;

        Test.startTest();
        CancellationService.CancellationResult res = CancellationService.cancel(appt.Id, 'Schedule conflict');
        Test.stopTest();

        System.assert(res.isSuccess, 'Cancellation should succeed');
        System.assertEquals(0, res.fee, 'Cancellation fee for >24h should be 0');
        System.assertEquals(1000, res.refund, 'Refund amount should equal total');

        Appointment__c updatedAppt = [SELECT Status__c FROM Appointment__c WHERE Id = :appt.Id];
        System.assertEquals('Cancelled', updatedAppt.Status__c, 'Status should be Cancelled');

        List<Cancellation__c> records = [SELECT Id, Cancellation_Fee__c, Refund_Amount__c, Reason__c FROM Cancellation__c WHERE Appointment__c = :appt.Id];
        System.assertEquals(1, records.size(), 'One cancellation record should exist');
        System.assertEquals(0, records[0].Cancellation_Fee__c);
        System.assertEquals(1000, records[0].Refund_Amount__c);
    }

    @isTest
    static void testCancellationServiceBetween4And24Hours() {
        Doctor__c doc = createDoctor('Dr. Policy Mid', 1000);
        Contact pat = createPatient('PatPolicy2');
        // Slot is 10 hours away (between 4 and 24h -> 25% fee, 75% refund)
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addHours(10), 5);

        Appointment__c appt = new Appointment__c(
            Slot__c = slot.Id,
            Patient__c = pat.Id,
            Status__c = 'Confirmed',
            Fee_Amount__c = 1000,
            Discount_Percent__c = 0
        );
        insert appt;

        Test.startTest();
        CancellationService.CancellationResult res = CancellationService.cancel(appt.Id, 'Emergency');
        Test.stopTest();

        System.assert(res.isSuccess, 'Cancellation should succeed');
        System.assertEquals(250, res.fee, 'Cancellation fee should be 25%');
        System.assertEquals(750, res.refund, 'Refund amount should be 75%');
    }

    @isTest
    static void testCancellationServiceUnder4Hours() {
        Doctor__c doc = createDoctor('Dr. Policy Short', 1000);
        Contact pat = createPatient('PatPolicy3');
        // Slot is 2 hours away (< 4h -> 100% fee, 0% refund)
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addHours(2), 5);

        Appointment__c appt = new Appointment__c(
            Slot__c = slot.Id,
            Patient__c = pat.Id,
            Status__c = 'Confirmed',
            Fee_Amount__c = 1000,
            Discount_Percent__c = 0
        );
        insert appt;

        Test.startTest();
        CancellationService.CancellationResult res = CancellationService.cancel(appt.Id, 'Last minute call off');
        Test.stopTest();

        System.assert(res.isSuccess, 'Cancellation should succeed');
        System.assertEquals(1000, res.fee, 'Cancellation fee should be 100%');
        System.assertEquals(0, res.refund, 'Refund amount should be 0');
    }

    @isTest
    static void testCancelAppointmentActionInvocable() {
        Doctor__c doc = createDoctor('Dr. Invocable Action', 400);
        Contact pat = createPatient('PatInvocable');
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addHours(30), 5);

        Appointment__c appt = new Appointment__c(
            Slot__c = slot.Id,
            Patient__c = pat.Id,
            Status__c = 'Confirmed',
            Fee_Amount__c = 400,
            Discount_Percent__c = 0
        );
        insert appt;

        CancelAppointmentAction.Request req = new CancelAppointmentAction.Request();
        req.appointmentId = appt.Id;
        req.reason = 'Patient requested via flow';

        Test.startTest();
        List<CancelAppointmentAction.Result> results = CancelAppointmentAction.cancel(new List<CancelAppointmentAction.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return one result');
        System.assertEquals(0, results[0].fee);
        System.assertEquals(400, results[0].refund);
    }

    @isTest
    static void testBulkAppointmentsAndCancellation() {
        Doctor__c doc = createDoctor('Dr. Bulk Operator', 500);
        Contact pat = createPatient('PatBulk');
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addDays(6), 25);

        List<Appointment__c> bulkList = new List<Appointment__c>();
        for (Integer i = 0; i < 20; i++) {
            bulkList.add(new Appointment__c(
                Slot__c = slot.Id,
                Patient__c = pat.Id,
                Status__c = 'Confirmed',
                Fee_Amount__c = 500,
                Discount_Percent__c = 0
            ));
        }

        Test.startTest();
        insert bulkList;

        Appointment_Slot__c slotChecked = [SELECT Booked_Count__c FROM Appointment_Slot__c WHERE Id = :slot.Id];
        System.assertEquals(20, slotChecked.Booked_Count__c, 'Booked count should reflect all 20 inserted appointments');

        List<CancellationService.CancellationRequest> cancelReqs = new List<CancellationService.CancellationRequest>();
        for (Appointment__c a : bulkList) {
            cancelReqs.add(new CancellationService.CancellationRequest(a.Id, 'Bulk batch cancel'));
        }
        List<CancellationService.CancellationResult> cancelResults = CancellationService.cancel(cancelReqs);
        Test.stopTest();

        System.assertEquals(20, cancelResults.size(), 'All 20 should be processed');
        for (CancellationService.CancellationResult cr : cancelResults) {
            System.assert(cr.isSuccess, 'Each cancellation should succeed');
        }

        Appointment_Slot__c slotFinal = [SELECT Booked_Count__c FROM Appointment_Slot__c WHERE Id = :slot.Id];
        System.assertEquals(0, slotFinal.Booked_Count__c, 'Booked count should be 0 after bulk cancellation');
    }

    @isTest
    static void testDeleteAndUndelete() {
        Doctor__c doc = createDoctor('Dr. Delete Test', 500);
        Contact pat = createPatient('PatDelete');
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addDays(4), 2);

        Appointment__c appt = new Appointment__c(
            Slot__c = slot.Id,
            Patient__c = pat.Id,
            Status__c = 'Confirmed',
            Fee_Amount__c = 500,
            Discount_Percent__c = 0
        );
        insert appt;

        Test.startTest();
        delete appt;
        Appointment_Slot__c sAfterDel = [SELECT Booked_Count__c FROM Appointment_Slot__c WHERE Id = :slot.Id];
        System.assertEquals(0, sAfterDel.Booked_Count__c, 'Booked count should be 0 after delete');

        undelete appt;
        Appointment_Slot__c sAfterUndel = [SELECT Booked_Count__c FROM Appointment_Slot__c WHERE Id = :slot.Id];
        System.assertEquals(1, sAfterUndel.Booked_Count__c, 'Booked count should be 1 after undelete');
        Test.stopTest();
    }

    @isTest
    static void testTriggerBypass() {
        TriggerHandler.bypass('AppointmentTriggerHandler');
        System.assert(TriggerHandler.isBypassed('AppointmentTriggerHandler'), 'Handler should be bypassed');

        TriggerHandler.clearBypass('AppointmentTriggerHandler');
        System.assert(!TriggerHandler.isBypassed('AppointmentTriggerHandler'), 'Bypass should be cleared');
    }

    @isTest
    static void testAlreadyCancelledException() {
        Doctor__c doc = createDoctor('Dr. Already Cancelled', 500);
        Contact pat = createPatient('PatAlready');
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addDays(2), 2);

        Appointment__c appt = new Appointment__c(
            Slot__c = slot.Id,
            Patient__c = pat.Id,
            Status__c = 'Cancelled',
            Fee_Amount__c = 500,
            Discount_Percent__c = 0
        );
        insert appt;

        Test.startTest();
        Boolean caught = false;
        try {
            CancellationService.cancel(appt.Id, 'Duplicate attempt');
        } catch (Exception e) {
            caught = true;
        }
        Test.stopTest();

        System.assert(caught, 'Cancelling an already cancelled appointment should throw exception');
    }

    @isTest
    static void testDiscountBelow10Percent() {
        Doctor__c doc = createDoctor('Dr. Low Disc', 1000);
        Contact pat = createPatient('PatLowDisc');
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addDays(4), 2);

        Test.startTest();
        Appointment__c appt = new Appointment__c(
            Slot__c = slot.Id,
            Patient__c = pat.Id,
            Status__c = 'Confirmed',
            Discount_Percent__c = 5
        );
        insert appt;
        Test.stopTest();

        Appointment__c refreshed = [SELECT Total_Amount__c, Discount_Percent__c, Approval_Status__c FROM Appointment__c WHERE Id = :appt.Id];
        Assert.areEqual(950.00, refreshed.Total_Amount__c, '5% discount should be applied directly');
    }

    @isTest
    static void testDiscountExactly10Percent() {
        Doctor__c doc = createDoctor('Dr. Ten Disc', 1000);
        Contact pat = createPatient('PatTenDisc');
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addDays(4), 2);

        Test.startTest();
        Appointment__c appt = new Appointment__c(
            Slot__c = slot.Id,
            Patient__c = pat.Id,
            Status__c = 'Confirmed',
            Discount_Percent__c = 10
        );
        insert appt;
        Test.stopTest();

        Appointment__c refreshed = [SELECT Total_Amount__c, Discount_Percent__c, Approval_Status__c FROM Appointment__c WHERE Id = :appt.Id];
        Assert.areEqual(900.00, refreshed.Total_Amount__c, '10% discount should be applied without requiring approval');
    }

    @isTest
    static void testDiscountAbove10PercentWithoutApprovalOnConfirmedThrows() {
        Doctor__c doc = createDoctor('Dr. Unapproved Disc', 1000);
        Contact pat = createPatient('PatUnapproved');
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addDays(4), 2);

        Test.startTest();
        Appointment__c appt = new Appointment__c(
            Slot__c = slot.Id,
            Patient__c = pat.Id,
            Status__c = 'Confirmed',
            Discount_Percent__c = 15
        );
        Boolean caught = false;
        try {
            insert appt;
        } catch (DmlException e) {
            caught = true;
            Assert.isTrue(e.getMessage().contains('Discounts exceeding 10% require an approved discount request'),
                'Expected discount approval validation rule message, got: ' + e.getMessage());
        }
        Test.stopTest();

        Assert.isTrue(caught, 'Confirmed appointment with unapproved discount > 10% must be rejected');
    }

    @isTest
    static void testDiscountAbove10PercentPendingHoldsUndiscountedTotal() {
        Doctor__c doc = createDoctor('Dr. Pending Disc', 1000);
        Contact pat = createPatient('PatPendingDisc');
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addDays(4), 2);

        Test.startTest();
        Appointment__c appt = new Appointment__c(
            Slot__c = slot.Id,
            Patient__c = pat.Id,
            Status__c = 'Pending',
            Discount_Percent__c = 15,
            Approval_Status__c = 'Pending'
        );
        insert appt;
        Test.stopTest();

        Appointment__c refreshed = [SELECT Total_Amount__c, Discount_Percent__c, Approval_Status__c, Status__c FROM Appointment__c WHERE Id = :appt.Id];
        Assert.areEqual(1000.00, refreshed.Total_Amount__c, 'Pending approval discount > 10% must hold undiscounted total');
    }

    @isTest
    static void testDiscountAbove10PercentApproved() {
        Doctor__c doc = createDoctor('Dr. Approved Disc', 1000);
        Contact pat = createPatient('PatApprovedDisc');
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addDays(4), 2);

        Appointment__c appt = new Appointment__c(
            Slot__c = slot.Id,
            Patient__c = pat.Id,
            Status__c = 'Pending',
            Discount_Percent__c = 15,
            Approval_Status__c = 'Pending'
        );
        insert appt;

        Test.startTest();
        appt.Approval_Status__c = 'Approved';
        update appt;

        Appointment__c afterApproval = [SELECT Total_Amount__c, Discount_Percent__c, Approval_Status__c FROM Appointment__c WHERE Id = :appt.Id];
        Assert.areEqual(850.00, afterApproval.Total_Amount__c, 'Approved 15% discount must be applied to Total_Amount__c');

        appt.Status__c = 'Confirmed';
        update appt;
        Test.stopTest();

        Appointment__c confirmed = [SELECT Status__c, Total_Amount__c FROM Appointment__c WHERE Id = :appt.Id];
        Assert.areEqual('Confirmed', confirmed.Status__c, 'Approved appointment can transition to Confirmed');
        Assert.areEqual(850.00, confirmed.Total_Amount__c, 'Confirmed appointment retains approved discounted total');
    }

    @isTest
    static void testDiscountRejectedHoldsUndiscountedTotal() {
        Doctor__c doc = createDoctor('Dr. Rejected Disc', 1000);
        Contact pat = createPatient('PatRejectedDisc');
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addDays(4), 2);

        Appointment__c appt = new Appointment__c(
            Slot__c = slot.Id,
            Patient__c = pat.Id,
            Status__c = 'Pending',
            Discount_Percent__c = 15,
            Approval_Status__c = 'Pending'
        );
        insert appt;

        Test.startTest();
        appt.Approval_Status__c = 'Rejected';
        update appt;

        Appointment__c afterReject = [SELECT Total_Amount__c, Approval_Status__c FROM Appointment__c WHERE Id = :appt.Id];
        Assert.areEqual(1000.00, afterReject.Total_Amount__c, 'Rejected discount must not reduce Total_Amount__c');

        Boolean caught = false;
        try {
            appt.Status__c = 'Confirmed';
            update appt;
        } catch (DmlException e) {
            caught = true;
            Assert.isTrue(e.getMessage().contains('Discounts exceeding 10% require an approved discount request'),
                'Expected validation message on trying to confirm rejected discount, got: ' + e.getMessage());
        }
        Test.stopTest();

        Assert.isTrue(caught, 'Transitioning to Confirmed with rejected discount > 10% must be rejected');
    }

    @isTest
    static void testUpdateExistingAppointmentToUnapprovedDiscountThrows() {
        Doctor__c doc = createDoctor('Dr. Update Disc', 1000);
        Contact pat = createPatient('PatUpdateDisc');
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addDays(4), 2);

        Appointment__c appt = new Appointment__c(
            Slot__c = slot.Id,
            Patient__c = pat.Id,
            Status__c = 'Confirmed',
            Discount_Percent__c = 0
        );
        insert appt;

        Test.startTest();
        Boolean caught = false;
        try {
            appt.Discount_Percent__c = 15;
            update appt;
        } catch (DmlException e) {
            caught = true;
            Assert.isTrue(e.getMessage().contains('Discounts exceeding 10% require an approved discount request'),
                'Expected discount approval validation message, got: ' + e.getMessage());
        }
        Test.stopTest();

        Assert.isTrue(caught, 'Updating confirmed appointment to discount > 10% without approval must be blocked');
    }

    @isTest
    static void testChangeDiscountAfterApprovalResetsStaleApproval() {
        Doctor__c doc = createDoctor('Dr. Stale Approval', 1000);
        Contact pat = createPatient('PatStaleApproval');
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addDays(4), 2);

        Appointment__c appt = new Appointment__c(
            Slot__c = slot.Id,
            Patient__c = pat.Id,
            Status__c = 'Pending',
            Discount_Percent__c = 15,
            Approval_Status__c = 'Approved'
        );
        insert appt;

        Test.startTest();
        // Changing discount from 15% to 18% on pending appointment must reset approval to Pending
        appt.Discount_Percent__c = 18;
        update appt;

        Appointment__c refreshed = [SELECT Id, Slot__c, Patient__c, Status__c, Fee_Amount__c, Total_Amount__c, Discount_Percent__c, Approval_Status__c FROM Appointment__c WHERE Id = :appt.Id];
        Assert.areEqual('Pending', refreshed.Approval_Status__c, 'Approval status must reset to Pending upon discount modification');
        Assert.areEqual(1000.00, refreshed.Total_Amount__c, 'Total must recalculate to undiscounted fee when approval is reset');

        // Confirming the appointment now must throw validation error because approval is Pending
        Boolean caught = false;
        try {
            refreshed.Status__c = 'Confirmed';
            update refreshed;
        } catch (DmlException e) {
            caught = true;
            Assert.isTrue(e.getMessage().contains('Discounts exceeding 10% require an approved discount request'),
                'Expected validation failure on stale/unapproved discount, got: ' + e.getMessage());
        }
        Test.stopTest();

        Assert.isTrue(caught, 'Confirming appointment with changed discount must fail until re-approved');
    }

    @isTest
    static void testDiscountAbove20PercentRequiresPermissionEvenWhenApproved() {
        User stdUser;
        System.runAs(new User(Id = UserInfo.getUserId())) {
            Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
            String uniqueName = 'carenesttest' + Datetime.now().getTime() + '@testcarenest.org';
            stdUser = new User(
                FirstName = 'Test',
                LastName = 'FrontDesk',
                Email = uniqueName,
                Username = uniqueName,
                Alias = 'tfd',
                TimeZoneSidKey = 'America/Los_Angeles',
                LocaleSidKey = 'en_US',
                EmailEncodingKey = 'UTF-8',
                ProfileId = p.Id,
                LanguageLocaleKey = 'en_US'
            );
            insert stdUser;

            PermissionSet ps = [SELECT Id FROM PermissionSet WHERE Name = 'CareNest_Front_Desk' LIMIT 1];
            insert new PermissionSetAssignment(
                AssigneeId = stdUser.Id,
                PermissionSetId = ps.Id
            );
        }

        Doctor__c doc = createDoctor('Dr. TwentyFive', 1000);
        Contact pat = new Contact(
            LastName = 'PatTwentyFive',
            Email = 'pattwentyfive@testcarenest.com',
            OwnerId = stdUser.Id
        );
        insert pat;
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addDays(4), 2);

        Test.startTest();
        Boolean caught = false;
        System.runAs(stdUser) {
            Appointment__c appt = new Appointment__c(
                Slot__c = slot.Id,
                Patient__c = pat.Id,
                Status__c = 'Pending',
                Discount_Percent__c = 25,
                Approval_Status__c = 'Approved'
            );

            try {
                insert appt;
            } catch (DmlException e) {
                caught = true;
                Assert.isTrue(e.getMessage().contains('Discounts above 20% are not allowed without Operations Manager approval permission'),
                    'Expected Discount_Above_20_Not_Allowed message, got: ' + e.getMessage());
            }
        }
        Test.stopTest();

        Assert.isTrue(caught, 'Discount > 20% must be blocked by rule when user lacks Approve_Discount permission');
    }

    @isTest
    static void testFeeCalculationRoundingPreservation() {
        Doctor__c doc = createDoctor('Dr. Rounding', 750);
        Contact pat = createPatient('PatRounding');
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addDays(4), 2);

        Test.startTest();
        Appointment__c appt = new Appointment__c(
            Slot__c = slot.Id,
            Patient__c = pat.Id,
            Status__c = 'Confirmed',
            Discount_Percent__c = 10
        );
        insert appt;
        Test.stopTest();

        Appointment__c refreshed = [SELECT Fee_Amount__c, Discount_Percent__c, Total_Amount__c FROM Appointment__c WHERE Id = :appt.Id];
        Assert.areEqual(750.00, refreshed.Fee_Amount__c, 'Fee amount should be 750.00');
        Assert.areEqual(675.00, refreshed.Total_Amount__c, '750 with 10% discount should round to 675.00');
    }

    @isTest
    static void testCancelAppointmentActionPolicyAndReason() {
        Doctor__c doc = createDoctor('Dr. Invocable Policy', 1000);
        Contact pat = createPatient('PatInvocPolicy');
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addHours(12), 2);

        Appointment__c appt = new Appointment__c(
            Slot__c = slot.Id,
            Patient__c = pat.Id,
            Status__c = 'Confirmed',
            Fee_Amount__c = 1000,
            Discount_Percent__c = 0
        );
        insert appt;

        CancelAppointmentAction.Request req = new CancelAppointmentAction.Request();
        req.appointmentId = appt.Id;
        req.reason = 'Patient requested cancellation via Flow Action';

        Test.startTest();
        List<CancelAppointmentAction.Result> results = CancelAppointmentAction.cancel(new List<CancelAppointmentAction.Request>{ req });
        Test.stopTest();

        Assert.areEqual(1, results.size(), 'Should return one result');
        Assert.isNotNull(results[0].fee, 'Fee should be calculated by policy');
        Assert.isNotNull(results[0].refund, 'Refund should be calculated by policy');

        List<Cancellation__c> cancList = [SELECT Id, Reason__c, Cancellation_Fee__c, Refund_Amount__c FROM Cancellation__c WHERE Appointment__c = :appt.Id];
        Assert.areEqual(1, cancList.size(), 'Exactly one Cancellation__c record should be persisted');
        Assert.areEqual('Patient requested cancellation via Flow Action', cancList[0].Reason__c, 'Reason should be persisted');

        Appointment__c cancelledAppt = [SELECT Status__c FROM Appointment__c WHERE Id = :appt.Id];
        Assert.areEqual('Cancelled', cancelledAppt.Status__c, 'Appointment status should be Cancelled');
    }

    @isTest
    static void testCancelAppointmentActionSlotCountDecrement() {
        Doctor__c doc = createDoctor('Dr. Invocable Slot', 500);
        Contact pat = createPatient('PatInvocSlot');
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addDays(3), 2);

        Appointment__c appt = new Appointment__c(
            Slot__c = slot.Id,
            Patient__c = pat.Id,
            Status__c = 'Confirmed',
            Fee_Amount__c = 500,
            Discount_Percent__c = 0
        );
        insert appt;

        Appointment_Slot__c beforeCancelSlot = [SELECT Booked_Count__c FROM Appointment_Slot__c WHERE Id = :slot.Id];
        Assert.areEqual(1, beforeCancelSlot.Booked_Count__c, 'Slot Booked_Count__c should be 1 before cancel');

        CancelAppointmentAction.Request req = new CancelAppointmentAction.Request();
        req.appointmentId = appt.Id;
        req.reason = 'Flow cancellation freeing slot';

        Test.startTest();
        CancelAppointmentAction.cancel(new List<CancelAppointmentAction.Request>{ req });
        Test.stopTest();

        Appointment_Slot__c afterCancelSlot = [SELECT Booked_Count__c FROM Appointment_Slot__c WHERE Id = :slot.Id];
        Assert.areEqual(0, afterCancelSlot.Booked_Count__c, 'Slot Booked_Count__c should be decremented to 0 after cancellation');
    }

    @isTest
    static void testCancelAppointmentActionDuplicateDoesNotCreateSecondRecord() {
        Doctor__c doc = createDoctor('Dr. Invocable Dupe', 500);
        Contact pat = createPatient('PatInvocDupe');
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addDays(3), 2);

        Appointment__c appt = new Appointment__c(
            Slot__c = slot.Id,
            Patient__c = pat.Id,
            Status__c = 'Confirmed',
            Fee_Amount__c = 500,
            Discount_Percent__c = 0
        );
        insert appt;

        CancelAppointmentAction.Request req = new CancelAppointmentAction.Request();
        req.appointmentId = appt.Id;
        req.reason = 'First cancellation';

        Test.startTest();
        // First cancellation succeeds
        CancelAppointmentAction.cancel(new List<CancelAppointmentAction.Request>{ req });

        // Second duplicate request on the already cancelled appointment
        CancelAppointmentAction.Request dupeReq = new CancelAppointmentAction.Request();
        dupeReq.appointmentId = appt.Id;
        dupeReq.reason = 'Second attempt';
        List<CancelAppointmentAction.Result> dupeResults = CancelAppointmentAction.cancel(new List<CancelAppointmentAction.Request>{ dupeReq });
        Test.stopTest();

        List<Cancellation__c> cancList = [SELECT Id FROM Cancellation__c WHERE Appointment__c = :appt.Id];
        Assert.areEqual(1, cancList.size(), 'Duplicate cancellation should NOT create a second Cancellation__c record');
    }
}
