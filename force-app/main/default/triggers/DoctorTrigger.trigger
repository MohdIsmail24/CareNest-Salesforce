/**
 * @description Trigger on Doctor__c delegating to DoctorTriggerHandler.
 */
trigger DoctorTrigger on Doctor__c (before insert, before update, after update) {
    DoctorTriggerHandler handler = new DoctorTriggerHandler();

    if (Trigger.isBefore && Trigger.isInsert) {
        handler.beforeInsert(Trigger.new);
    } else if (Trigger.isBefore && Trigger.isUpdate) {
        handler.beforeUpdate(Trigger.new, Trigger.oldMap);
    } else if (Trigger.isAfter && Trigger.isUpdate) {
        handler.afterUpdate(Trigger.new, Trigger.oldMap);
    }
}
