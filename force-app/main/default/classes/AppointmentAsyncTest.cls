/**
 * @description Comprehensive unit tests for Phase 08 Advanced Apex components:
 * ReminderSmsJob (Queueable), NoShowBatch (Batchable & Schedulable),
 * PendingExpiryBatch (Batchable & Schedulable), and CareNestReminderScheduler.
 */
@isTest
private class AppointmentAsyncTest {

    private static Integer regSeq = 5000;

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
            Email = lastName.toLowerCase() + '@testcarenest.com',
            Phone = '+1555000' + String.valueOf(regSeq)
        );
        insert c;
        return c;
    }

    private static Appointment_Slot__c createSlot(Id docId, Datetime startTime, Decimal capacity) {
        Datetime insertTime = (startTime <= System.now()) ? System.now().addDays(1) : startTime;
        Appointment_Slot__c slot = new Appointment_Slot__c(
            Doctor__c = docId,
            Mode__c = 'OPD',
            Slot_Start__c = insertTime,
            Total_Capacity__c = capacity
        );
        insert slot;
        if (insertTime != startTime) {
            slot.Slot_Start__c = startTime;
            update slot;
        }
        return slot;
    }

    @isTest
    static void testReminderSmsJobExecution() {
        Doctor__c doc = createDoctor('Dr. Reminder Test', 500);
        Contact pat = createPatient('PatReminder');
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addDays(1), 5);

        List<Appointment__c> appts = new List<Appointment__c>();
        for (Integer i = 0; i < 3; i++) {
            appts.add(new Appointment__c(
                Slot__c = slot.Id,
                Patient__c = pat.Id,
                Status__c = 'Confirmed',
                Reminder_Sent__c = false
            ));
        }
        insert appts;

        List<Id> apptIds = new List<Id>();
        for (Appointment__c a : appts) {
            apptIds.add(a.Id);
        }

        Test.startTest();
        System.enqueueJob(new ReminderSmsJob(apptIds));
        Test.stopTest();

        List<Appointment__c> updated = [
            SELECT Id, Reminder_Sent__c
            FROM Appointment__c
            WHERE Id IN :apptIds
        ];
        System.assertEquals(3, updated.size(), 'Should find all 3 appointments');
        for (Appointment__c a : updated) {
            System.assertEquals(true, a.Reminder_Sent__c, 'Reminder_Sent__c should be true');
        }
    }

    @isTest
    static void testReminderSmsJobIdempotency() {
        Doctor__c doc = createDoctor('Dr. Idempotent Test', 500);
        Contact pat = createPatient('PatIdempotent');
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addDays(1), 5);

        Appointment__c appt = new Appointment__c(
            Slot__c = slot.Id,
            Patient__c = pat.Id,
            Status__c = 'Confirmed',
            Reminder_Sent__c = true
        );
        insert appt;

        Test.startTest();
        // Enqueue job with appointment that already has Reminder_Sent__c = true
        System.enqueueJob(new ReminderSmsJob(new List<Id>{ appt.Id }));
        Test.stopTest();

        Appointment__c verified = [
            SELECT Id, Reminder_Sent__c
            FROM Appointment__c
            WHERE Id = :appt.Id
        ];
        System.assertEquals(true, verified.Reminder_Sent__c, 'Reminder_Sent__c remains true without duplicate effect');
    }

    @isTest
    static void testReminderSmsJobChunkingAndNullHandling() {
        Doctor__c doc = createDoctor('Dr. Chunk Test', 500);
        Contact pat = createPatient('PatChunk');
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addDays(1), 5);

        List<Appointment__c> appts = new List<Appointment__c>();
        for (Integer i = 0; i < 3; i++) {
            appts.add(new Appointment__c(
                Slot__c = slot.Id,
                Patient__c = pat.Id,
                Status__c = 'Confirmed',
                Reminder_Sent__c = false
            ));
        }
        insert appts;

        List<Id> apptIds = new List<Id>();
        for (Appointment__c a : appts) {
            apptIds.add(a.Id);
        }

        // Adjust chunk size for testing chunk splitting
        ReminderSmsJob.chunkSize = 2;

        try {
            Test.startTest();
            System.enqueueJob(new ReminderSmsJob(apptIds));
            // Test null/empty constructors
            ReminderSmsJob emptyJob = new ReminderSmsJob();
            emptyJob.execute(null);
            Test.stopTest();
        } finally {
            ReminderSmsJob.chunkSize = 50;
        }

        List<Appointment__c> processed = [
            SELECT Id, Reminder_Sent__c
            FROM Appointment__c
            WHERE Id IN :apptIds AND Reminder_Sent__c = true
        ];
        System.assert(processed.size() >= 2, 'At least the current chunk of 2 should be processed');
    }

    @isTest
    static void testNoShowBatchEligible() {
        Doctor__c doc = createDoctor('Dr. Past Slot', 600);
        Contact pat = createPatient('PatPast');
        // Slot ended > 2 hours ago (e.g. 3 hours ago)
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addHours(-3), 5);

        Appointment__c appt = new Appointment__c(
            Slot__c = slot.Id,
            Patient__c = pat.Id,
            Status__c = 'Confirmed'
        );
        insert appt;

        // Verify initial booked count is 1
        Appointment_Slot__c slotBefore = [SELECT Id, Booked_Count__c FROM Appointment_Slot__c WHERE Id = :slot.Id];
        System.assertEquals(1, slotBefore.Booked_Count__c, 'Initial booked count should be 1');

        Test.startTest();
        Database.executeBatch(new NoShowBatch(), 200);
        Test.stopTest();

        Appointment__c apptAfter = [SELECT Id, Status__c FROM Appointment__c WHERE Id = :appt.Id];
        System.assertEquals('No Show', apptAfter.Status__c, 'Status should transition to No Show');

        // Verify slot capacity released
        Appointment_Slot__c slotAfter = [SELECT Id, Booked_Count__c FROM Appointment_Slot__c WHERE Id = :slot.Id];
        System.assertEquals(0, slotAfter.Booked_Count__c, 'Booked count should decrement to 0');
    }

    @isTest
    static void testNoShowBatchIneligibleWithVisitRecord() {
        Doctor__c doc = createDoctor('Dr. Attended Slot', 600);
        Contact pat = createPatient('PatAttended');
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addHours(-3), 5);

        Appointment__c appt = new Appointment__c(
            Slot__c = slot.Id,
            Patient__c = pat.Id,
            Status__c = 'Confirmed'
        );
        insert appt;

        Visit_Record__c vr = new Visit_Record__c(
            Appointment__c = appt.Id,
            Chief_Complaint__c = 'Routine checkup completed'
        );
        insert vr;

        Test.startTest();
        Database.executeBatch(new NoShowBatch(), 200);
        Test.stopTest();

        Appointment__c apptAfter = [SELECT Id, Status__c FROM Appointment__c WHERE Id = :appt.Id];
        System.assertEquals('Confirmed', apptAfter.Status__c, 'Status should remain Confirmed due to existing Visit Record');
    }

    @isTest
    static void testNoShowBatchIneligibleFutureSlot() {
        Doctor__c doc = createDoctor('Dr. Future Slot', 600);
        Contact pat = createPatient('PatFuture');
        // Future slot
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addHours(2), 5);

        Appointment__c appt = new Appointment__c(
            Slot__c = slot.Id,
            Patient__c = pat.Id,
            Status__c = 'Confirmed'
        );
        insert appt;

        Test.startTest();
        Database.executeBatch(new NoShowBatch(), 200);
        Test.stopTest();

        Appointment__c apptAfter = [SELECT Id, Status__c FROM Appointment__c WHERE Id = :appt.Id];
        System.assertEquals('Confirmed', apptAfter.Status__c, 'Future appointment must not be marked No Show');
    }

    @isTest
    static void testNoShowBatchIdempotency() {
        Doctor__c doc = createDoctor('Dr. NoShow Repeat', 600);
        Contact pat = createPatient('PatRepeat');
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addHours(-3), 5);

        Appointment__c appt = new Appointment__c(
            Slot__c = slot.Id,
            Patient__c = pat.Id,
            Status__c = 'No Show'
        );
        insert appt;

        Test.startTest();
        Database.executeBatch(new NoShowBatch(), 200);
        Test.stopTest();

        Appointment__c apptAfter = [SELECT Id, Status__c FROM Appointment__c WHERE Id = :appt.Id];
        System.assertEquals('No Show', apptAfter.Status__c, 'Status remains No Show with zero modifications');
    }

    @isTest
    static void testPendingExpiryBatchEligible() {
        Doctor__c doc = createDoctor('Dr. Expired Pending', 700);
        Contact pat = createPatient('PatPending');
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addDays(2), 5);

        Appointment__c appt = new Appointment__c(
            Slot__c = slot.Id,
            Patient__c = pat.Id,
            Status__c = 'Pending'
        );
        insert appt;

        // Set created date to 35 minutes ago
        Test.setCreatedDate(appt.Id, Datetime.now().addMinutes(-35));

        Appointment_Slot__c slotBefore = [SELECT Id, Booked_Count__c FROM Appointment_Slot__c WHERE Id = :slot.Id];
        System.assertEquals(1, slotBefore.Booked_Count__c, 'Initial booked count should be 1');

        Test.startTest();
        Database.executeBatch(new PendingExpiryBatch(), 200);
        Test.stopTest();

        Appointment__c apptAfter = [SELECT Id, Status__c FROM Appointment__c WHERE Id = :appt.Id];
        System.assertEquals('Cancelled', apptAfter.Status__c, 'Pending appointment without payment should be Cancelled');

        Appointment_Slot__c slotAfter = [SELECT Id, Booked_Count__c FROM Appointment_Slot__c WHERE Id = :slot.Id];
        System.assertEquals(0, slotAfter.Booked_Count__c, 'Slot capacity should be released');
    }

    @isTest
    static void testPendingExpiryBatchIneligibleWithPayment() {
        Doctor__c doc = createDoctor('Dr. Paid Pending', 700);
        Contact pat = createPatient('PatPaid');
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addDays(2), 5);

        Appointment__c appt = new Appointment__c(
            Slot__c = slot.Id,
            Patient__c = pat.Id,
            Status__c = 'Pending'
        );
        insert appt;

        Test.setCreatedDate(appt.Id, Datetime.now().addMinutes(-35));

        Payment__c p = new Payment__c(
            Appointment__c = appt.Id,
            Amount__c = 700,
            Status__c = 'Success',
            Method__c = 'Card',
            Paid_On__c = Datetime.now()
        );
        insert p;

        Test.startTest();
        Database.executeBatch(new PendingExpiryBatch(), 200);
        Test.stopTest();

        Appointment__c apptAfter = [SELECT Id, Status__c FROM Appointment__c WHERE Id = :appt.Id];
        System.assertEquals('Pending', apptAfter.Status__c, 'Paid pending appointment must not be cancelled');
    }

    @isTest
    static void testPendingExpiryBatchIneligibleRecent() {
        Doctor__c doc = createDoctor('Dr. Recent Pending', 700);
        Contact pat = createPatient('PatRecent');
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addDays(2), 5);

        Appointment__c appt = new Appointment__c(
            Slot__c = slot.Id,
            Patient__c = pat.Id,
            Status__c = 'Pending'
        );
        insert appt;

        Test.startTest();
        Database.executeBatch(new PendingExpiryBatch(), 200);
        Test.stopTest();

        Appointment__c apptAfter = [SELECT Id, Status__c FROM Appointment__c WHERE Id = :appt.Id];
        System.assertEquals('Pending', apptAfter.Status__c, 'Recently created pending appointment must not be cancelled');
    }

    @isTest
    static void testSchedulersExecution() {
        Doctor__c doc = createDoctor('Dr. Scheduler Test', 750);
        Contact pat = createPatient('PatSched');
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addDays(1), 5);

        Appointment__c appt = new Appointment__c(
            Slot__c = slot.Id,
            Patient__c = pat.Id,
            Status__c = 'Confirmed',
            Reminder_Sent__c = false
        );
        insert appt;

        Test.startTest();
        String cronExpr = '0 0 23 * * ?';
        String noShowJobId = System.schedule('Test NoShowBatch Schedule', cronExpr, new NoShowBatch());
        String expiryJobId = System.schedule('Test PendingExpiryBatch Schedule', cronExpr, new PendingExpiryBatch());
        String reminderJobId = System.schedule('Test CareNestReminderScheduler Schedule', '0 0 8 * * ?', new CareNestReminderScheduler());
        Test.stopTest();

        System.assertNotEquals(null, noShowJobId, 'NoShowBatch job ID should not be null');
        System.assertNotEquals(null, expiryJobId, 'PendingExpiryBatch job ID should not be null');
        System.assertNotEquals(null, reminderJobId, 'CareNestReminderScheduler job ID should not be null');

        CronTrigger ct = [SELECT Id, CronExpression FROM CronTrigger WHERE Id = :noShowJobId];
        System.assertEquals(cronExpr, ct.CronExpression, 'Cron expression should match');
    }

    @isTest
    static void testReminderSchedulerEligibilityWindows() {
        Doctor__c doc = createDoctor('Dr. Window Test', 500);
        Contact pat = createPatient('PatWindow');

        Datetime fixedNow = Datetime.newInstance(2026, 10, 15, 10, 0, 0);
        CareNestReminderScheduler.mockCurrentTime = fixedNow;

        try {
            // 1. Past appointment (before window: now - 2h) -> Ineligible
            Appointment_Slot__c slotPast = createSlot(doc.Id, fixedNow.addHours(-2), 2);
            Appointment__c apptPast = new Appointment__c(
                Slot__c = slotPast.Id, Patient__c = pat.Id, Status__c = 'Confirmed', Reminder_Sent__c = false
            );

            // 2. Exact lower boundary (Slot_Start__c == now) -> Eligible
            Appointment_Slot__c slotExactNow = createSlot(doc.Id, fixedNow, 2);
            Appointment__c apptExactNow = new Appointment__c(
                Slot__c = slotExactNow.Id, Patient__c = pat.Id, Status__c = 'Confirmed', Reminder_Sent__c = false
            );

            // 3. Inside window (now + 12h) -> Eligible
            Appointment_Slot__c slotMidWindow = createSlot(doc.Id, fixedNow.addHours(12), 2);
            Appointment__c apptMidWindow = new Appointment__c(
                Slot__c = slotMidWindow.Id, Patient__c = pat.Id, Status__c = 'Confirmed', Reminder_Sent__c = false
            );

            // 4. Exact upper boundary (Slot_Start__c == now + 24h) -> Eligible
            Appointment_Slot__c slotExactWindowEnd = createSlot(doc.Id, fixedNow.addHours(24), 2);
            Appointment__c apptExactWindowEnd = new Appointment__c(
                Slot__c = slotExactWindowEnd.Id, Patient__c = pat.Id, Status__c = 'Confirmed', Reminder_Sent__c = false
            );

            // 5. Far future / outside window (now + 48h) -> Ineligible
            Appointment_Slot__c slotFuture = createSlot(doc.Id, fixedNow.addHours(48), 2);
            Appointment__c apptFuture = new Appointment__c(
                Slot__c = slotFuture.Id, Patient__c = pat.Id, Status__c = 'Confirmed', Reminder_Sent__c = false
            );

            // 6. Inside window but already sent (now + 6h, Reminder_Sent__c = true) -> Ineligible
            Appointment_Slot__c slotSent = createSlot(doc.Id, fixedNow.addHours(6), 2);
            Appointment__c apptSent = new Appointment__c(
                Slot__c = slotSent.Id, Patient__c = pat.Id, Status__c = 'Confirmed', Reminder_Sent__c = true
            );

            // 7. Inside window but status not Confirmed (now + 8h, Status__c = 'Cancelled') -> Ineligible
            Appointment_Slot__c slotCancelled = createSlot(doc.Id, fixedNow.addHours(8), 2);
            Appointment__c apptCancelled = new Appointment__c(
                Slot__c = slotCancelled.Id, Patient__c = pat.Id, Status__c = 'Cancelled', Reminder_Sent__c = false
            );

            insert new List<Appointment__c>{
                apptPast, apptExactNow, apptMidWindow, apptExactWindowEnd, apptFuture, apptSent, apptCancelled
            };

            Test.startTest();
            // Test enqueueing distinction: enqueueReminders returns the queueable Job ID
            Id jobId = CareNestReminderScheduler.enqueueReminders();
            Assert.isNotNull(jobId, 'Should enqueue Queueable job for eligible appointments');

            // Verify that BEFORE Test.stopTest() executes the Queueable, DB records are unchanged
            Appointment__c beforeExecution = [SELECT Reminder_Sent__c FROM Appointment__c WHERE Id = :apptMidWindow.Id];
            Assert.isFalse(beforeExecution.Reminder_Sent__c, 'Before stopTest() executes the queueable, Reminder_Sent__c remains false');

            Test.stopTest(); // Synchronously executes enqueued ReminderSmsJob

            Map<Id, Appointment__c> results = new Map<Id, Appointment__c>([
                SELECT Id, Reminder_Sent__c FROM Appointment__c
                WHERE Id IN (
                    :apptPast.Id, :apptExactNow.Id, :apptMidWindow.Id,
                    :apptExactWindowEnd.Id, :apptFuture.Id, :apptSent.Id, :apptCancelled.Id
                )
            ]);

            // Assert eligible boundaries (lower boundary, inside window, upper boundary)
            Assert.isTrue(results.get(apptExactNow.Id).Reminder_Sent__c, 'Exact lower boundary (Slot_Start == now) must be eligible');
            Assert.isTrue(results.get(apptMidWindow.Id).Reminder_Sent__c, 'Mid-window appointment must be eligible');
            Assert.isTrue(results.get(apptExactWindowEnd.Id).Reminder_Sent__c, 'Exact upper boundary (Slot_Start == now + 24h) must be eligible');

            // Assert ineligible boundaries (past, outside upper boundary, cancelled, already sent)
            Assert.isFalse(results.get(apptPast.Id).Reminder_Sent__c, 'Past appointment (< now) must NOT be eligible');
            Assert.isFalse(results.get(apptFuture.Id).Reminder_Sent__c, 'Future appointment (> windowEnd) must NOT be eligible');
            Assert.isFalse(results.get(apptCancelled.Id).Reminder_Sent__c, 'Cancelled appointment must NOT be eligible');
            Assert.isTrue(results.get(apptSent.Id).Reminder_Sent__c, 'Already sent appointment retains Reminder_Sent__c = true');
        } finally {
            CareNestReminderScheduler.mockCurrentTime = null;
        }
    }

    @isTest
    static void testReminderSchedulerEmptyEligibleReturnsNull() {
        Doctor__c doc = createDoctor('Dr. Empty Test', 500);
        Contact pat = createPatient('PatEmpty');

        Datetime fixedNow = Datetime.newInstance(2026, 10, 20, 10, 0, 0);
        CareNestReminderScheduler.mockCurrentTime = fixedNow;

        try {
            // Only far-future appointment exists
            Appointment_Slot__c slotFuture = createSlot(doc.Id, fixedNow.addHours(72), 2);
            Appointment__c apptFuture = new Appointment__c(
                Slot__c = slotFuture.Id, Patient__c = pat.Id, Status__c = 'Confirmed', Reminder_Sent__c = false
            );
            insert apptFuture;

            Test.startTest();
            Id jobId = CareNestReminderScheduler.enqueueReminders();
            Test.stopTest();

            Assert.isNull(jobId, 'Should return null when zero appointments are eligible');
        } finally {
            CareNestReminderScheduler.mockCurrentTime = null;
        }
    }

    @isTest
    static void testReminderSmsJobExcludesCancelledRaceCondition() {
        Doctor__c doc = createDoctor('Dr. Race Condition', 500);
        Contact pat = createPatient('PatRace');
        Appointment_Slot__c slot = createSlot(doc.Id, System.now().addHours(10), 2);

        // Created as Confirmed (eligible at scheduler inspection time)
        Appointment__c appt = new Appointment__c(
            Slot__c = slot.Id, Patient__c = pat.Id, Status__c = 'Confirmed', Reminder_Sent__c = false
        );
        insert appt;

        // Scheduler collected the Confirmed appointment ID for enqueueing
        List<Id> previouslyQueuedIds = new List<Id>{ appt.Id };

        // Race condition: Patient cancels appointment before the queueable chunk executes
        appt.Status__c = 'Cancelled';
        update appt;

        // Queueable runs with the previously queued ID
        Test.startTest();
        System.enqueueJob(new ReminderSmsJob(previouslyQueuedIds));
        Test.stopTest();

        Appointment__c refreshed = [SELECT Reminder_Sent__c FROM Appointment__c WHERE Id = :appt.Id];
        Assert.isFalse(refreshed.Reminder_Sent__c, 'Cancelled appointment must be excluded by ReminderSmsJob idempotency guard');
    }
}
