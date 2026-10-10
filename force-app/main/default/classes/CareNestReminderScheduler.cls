/**
 * @description Schedulable orchestrator for dispatching ReminderSmsJob on a periodic schedule.
 * Enforces a bounded 24-hour eligibility window and supports deterministic mock time injection for testing.
 */
public with sharing class CareNestReminderScheduler implements Schedulable {

    @TestVisible
    private static Datetime mockCurrentTime = null;

    /**
     * @description Default reminder eligibility window: appointments starting within the next 24 hours.
     * Aligned with the approved CareNest clinical journey and legacy scheduled flow window.
     */
    @TestVisible
    public static final Integer REMINDER_WINDOW_HOURS = 24;

    public void execute(SchedulableContext sc) {
        enqueueReminders();
    }

    /**
     * @description Queries eligible confirmed appointments starting within the 24-hour window
     * that have not received reminders, and enqueues ReminderSmsJob.
     * @return Job ID of the enqueued Queueable job, or null if no appointments eligible.
     */
    public static Id enqueueReminders() {
        Datetime now = mockCurrentTime != null ? mockCurrentTime : Datetime.now();
        Datetime windowEnd = now.addHours(REMINDER_WINDOW_HOURS);

        List<Appointment__c> upcomingAppointments = [
            SELECT Id, Slot__r.Slot_Start__c
            FROM Appointment__c
            WHERE Reminder_Sent__c = false
              AND Status__c = 'Confirmed'
              AND Slot__r.Slot_Start__c >= :now
              AND Slot__r.Slot_Start__c <= :windowEnd
            WITH USER_MODE
            LIMIT 500
        ];

        List<Id> apptIds = new List<Id>();
        for (Appointment__c appt : upcomingAppointments) {
            apptIds.add(appt.Id);
        }

        if (!apptIds.isEmpty()) {
            return System.enqueueJob(new ReminderSmsJob(apptIds));
        }
        return null;
    }
}
