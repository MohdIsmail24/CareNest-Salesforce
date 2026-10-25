/**
 * @description Inpatient encounter trigger delegating to InpatientEncounterTriggerHandler.
 */
trigger InpatientEncounterTrigger on Inpatient_Encounter__c (before insert, before update, after insert) {
    InpatientEncounterTriggerHandler handler = new InpatientEncounterTriggerHandler();

    if (Trigger.isBefore && Trigger.isInsert) {
        handler.beforeInsert(Trigger.new);
    } else if (Trigger.isBefore && Trigger.isUpdate) {
        handler.beforeUpdate(Trigger.new, Trigger.oldMap);
    } else if (Trigger.isAfter && Trigger.isInsert) {
        handler.afterInsert(Trigger.new);
    }
}
