/**
 * @description Nightly batch job that marks past Confirmed appointments as 'No Show'
 * if no Visit Record was logged within 2 hours after slot start.
 * Implements Schedulable for automated nightly scheduling.
 */
public with sharing class NoShowBatch implements Database.Batchable<sObject>, Schedulable {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Datetime twoHoursAgo = Datetime.now().addHours(-2);
        return Database.getQueryLocator([
            SELECT Id, Status__c, Slot__c, Slot__r.Slot_Start__c,
                   (SELECT Id FROM Visit_Records__r LIMIT 1)
            FROM Appointment__c
            WHERE Status__c = 'Confirmed'
              AND Slot__r.Slot_Start__c < :twoHoursAgo
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Appointment__c> scope) {
        List<Appointment__c> toUpdate = new List<Appointment__c>();
        for (Appointment__c appt : scope) {
            if (appt.Visit_Records__r == null || appt.Visit_Records__r.isEmpty()) {
                appt.Status__c = 'No Show';
                toUpdate.add(appt);
            }
        }

        if (!toUpdate.isEmpty()) {
            Database.SaveResult[] srList = Database.update(toUpdate, false);
            for (Database.SaveResult sr : srList) {
                if (!sr.isSuccess()) {
                    for (Database.Error err : sr.getErrors()) {
                        System.debug(LoggingLevel.ERROR, 'NoShowBatch DML Error on ' + sr.getId() + ': ' + err.getMessage());
                    }
                }
            }
        }
    }

    public void finish(Database.BatchableContext bc) {
        System.debug(LoggingLevel.INFO, 'NoShowBatch execution completed successfully.');
    }

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new NoShowBatch(), 200);
    }
}
