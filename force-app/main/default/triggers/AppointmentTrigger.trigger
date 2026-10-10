/**
 * @description Thin trigger on Appointment__c delegating all operations to AppointmentTriggerHandler.
 */
trigger AppointmentTrigger on Appointment__c (before insert, before update, before delete, after insert, after update, after delete, after undelete) {
    new AppointmentTriggerHandler().run();
}
