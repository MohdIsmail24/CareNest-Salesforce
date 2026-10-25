/**
 * @description Patient vital sign trigger delegating to PatientVitalTriggerHandler.
 */
trigger PatientVitalTrigger on Patient_Vital__c (before insert, before update, after insert) {
    PatientVitalTriggerHandler handler = new PatientVitalTriggerHandler();

    if (Trigger.isBefore && Trigger.isInsert) {
        handler.beforeInsert(Trigger.new);
    } else if (Trigger.isBefore && Trigger.isUpdate) {
        handler.beforeUpdate(Trigger.new, Trigger.oldMap);
    } else if (Trigger.isAfter && Trigger.isInsert) {
        handler.afterInsert(Trigger.new);
    }
}
