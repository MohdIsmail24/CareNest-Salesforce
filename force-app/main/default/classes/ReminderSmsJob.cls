/**
 * @description Queueable job that processes SMS reminder dispatch for appointments in chunks of 50.
 * Updates Reminder_Sent__c = true and serves as an abstraction boundary for Phase 10 SMS integrations.
 */
public with sharing class ReminderSmsJob implements Queueable {

    @TestVisible
    private static Integer chunkSize = 50;
    private List<Id> appointmentIds;

    public ReminderSmsJob() {
        this(new List<Id>());
    }

    public ReminderSmsJob(List<Id> appointmentIds) {
        this.appointmentIds = (appointmentIds != null) ? new List<Id>(appointmentIds) : new List<Id>();
    }

    public void execute(QueueableContext context) {
        if (this.appointmentIds == null || this.appointmentIds.isEmpty()) {
            return;
        }

        List<Id> currentChunk = new List<Id>();
        List<Id> remainingChunk = new List<Id>();

        for (Integer i = 0; i < this.appointmentIds.size(); i++) {
            if (i < chunkSize) {
                currentChunk.add(this.appointmentIds[i]);
            } else {
                remainingChunk.add(this.appointmentIds[i]);
            }
        }

        // Idempotency: Process only appointments where Reminder_Sent__c is false and status is still Confirmed
        List<Appointment__c> appointmentsToProcess = [
            SELECT Id, Reminder_Sent__c, Status__c, Patient__c, Patient__r.Phone, Slot__r.Slot_Start__c
            FROM Appointment__c
            WHERE Id IN :currentChunk
              AND Reminder_Sent__c = false
              AND Status__c = 'Confirmed'
        ];

        List<Appointment__c> recordsToUpdate = new List<Appointment__c>();
        for (Appointment__c appt : appointmentsToProcess) {
            dispatchReminder(appt);
            appt.Reminder_Sent__c = true;
            recordsToUpdate.add(appt);
        }

        if (!recordsToUpdate.isEmpty()) {
            Database.SaveResult[] srList = Database.update(recordsToUpdate, false);
            for (Database.SaveResult sr : srList) {
                if (!sr.isSuccess()) {
                    for (Database.Error err : sr.getErrors()) {
                        System.debug(LoggingLevel.ERROR, 'ReminderSmsJob DML Error on ' + sr.getId() + ': ' + err.getMessage());
                    }
                }
            }
        }

        // Chain subsequent chunk of appointments if any remain
        // Avoid chaining in test execution to respect Queueable test limits
        if (!remainingChunk.isEmpty() && !Test.isRunningTest() && Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()) {
            System.enqueueJob(new ReminderSmsJob(remainingChunk));
        }
    }

    /**
     * @description Abstraction boundary for SMS notification. Phase 10 will hook outbound HTTP callouts here.
     * @param appt Appointment record being processed.
     */
    private void dispatchReminder(Appointment__c appt) {
        System.debug(LoggingLevel.INFO, 'CareNest: Dispatched SMS reminder notification for Appointment ' + appt.Id);
    }
}
