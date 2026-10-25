/**
 * @description Scheduled batch job to reconcile and revoke expired cross-cover clinical shares
 * on Inpatient_Encounter__c and Patient_Vital__c records across CareNest HMS.
 */
public inherited sharing class CrossCoverReconciliationBatch implements Database.Batchable<SObject>, Schedulable, Database.Stateful {

    public Integer recordsProcessed = 0;

    public Database.QueryLocator start(Database.BatchableContext bc) {
        Datetime nowTime = System.now();
        return Database.getQueryLocator([
            SELECT Id
            FROM Admission__c
            WHERE Covering_Doctor__c != null
              AND (Covering_End_Time__c < :nowTime OR Status__c IN ('Discharged', 'Cancelled'))
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Admission__c> scope) {
        Set<Id> admissionIds = new Set<Id>();
        for (Admission__c adm : scope) {
            admissionIds.add(adm.Id);
            recordsProcessed++;
        }
        if (!admissionIds.isEmpty()) {
            ClinicalSharingService.reconcileCrossCoverShares(admissionIds);
        }
    }

    public void finish(Database.BatchableContext bc) {
        // Optional completion tracking
    }

    public void execute(SchedulableContext sc) {
        Database.executeBatch(new CrossCoverReconciliationBatch(), 200);
    }
}
