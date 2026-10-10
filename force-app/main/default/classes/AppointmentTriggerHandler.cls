/**
 * @description Trigger handler for Appointment__c dispatching events to AppointmentService.
 */
public with sharing class AppointmentTriggerHandler extends TriggerHandler {

    protected override void beforeInsert() {
        AppointmentService.populateFeesAndTotals((List<Appointment__c>) Trigger.new);
        AppointmentService.validateAndReserve((List<Appointment__c>) Trigger.new);
    }

    protected override void beforeUpdate() {
        AppointmentService.validateAndReserve((List<Appointment__c>) Trigger.new, (Map<Id, Appointment__c>) Trigger.oldMap);
        AppointmentService.recalculateTotals((List<Appointment__c>) Trigger.new, (Map<Id, Appointment__c>) Trigger.oldMap);
    }

    protected override void afterInsert() {
        AppointmentService.updateBookedCounts((List<Appointment__c>) Trigger.new, null);
    }

    protected override void afterUpdate() {
        AppointmentService.updateBookedCounts((List<Appointment__c>) Trigger.new, (Map<Id, Appointment__c>) Trigger.oldMap);
    }

    protected override void afterDelete() {
        AppointmentService.updateBookedCounts(null, (Map<Id, Appointment__c>) Trigger.oldMap);
    }

    protected override void afterUndelete() {
        AppointmentService.updateBookedCounts((List<Appointment__c>) Trigger.new, null);
    }
}
