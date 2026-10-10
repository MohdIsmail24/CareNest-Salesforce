/**
 * @description Periodic batch job that cancels unconfirmed 'Pending' appointments older than 30 minutes
 * that have not received any successful payments.
 * Cancelling automatically releases slot capacity via AppointmentService.
 * Implements Schedulable for automated periodic scheduling.
 */
public with sharing class PendingExpiryBatch implements Database.Batchable<sObject>, Schedulable {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Datetime thirtyMinutesAgo = Datetime.now().addMinutes(-30);
        return Database.getQueryLocator([
            SELECT Id, Status__c, Slot__c, Amount_Paid__c, CreatedDate
            FROM Appointment__c
            WHERE Status__c = 'Pending'
              AND CreatedDate <= :thirtyMinutesAgo
              AND (Amount_Paid__c = null OR Amount_Paid__c = 0)
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Appointment__c> scope) {
        List<Appointment__c> toCancel = new List<Appointment__c>();
        for (Appointment__c appt : scope) {
            if (appt.Amount_Paid__c == null || appt.Amount_Paid__c == 0) {
                appt.Status__c = 'Cancelled';
                toCancel.add(appt);
            }
        }

        if (!toCancel.isEmpty()) {
            Database.SaveResult[] srList = Database.update(toCancel, false);
            for (Database.SaveResult sr : srList) {
                if (!sr.isSuccess()) {
                    for (Database.Error err : sr.getErrors()) {
                        System.debug(LoggingLevel.ERROR, 'PendingExpiryBatch DML Error on ' + sr.getId() + ': ' + err.getMessage());
                    }
                }
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.INFO, 'PendingExpiryBatch execution completed successfully.');
    }

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new PendingExpiryBatch(), 200);
    }
}
