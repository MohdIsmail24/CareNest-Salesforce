/**
 * @description Asynchronous consumer trigger for Error_Log_Event__e platform events.
 * Persists durable error diagnostic events into Error_Log__c out-of-transaction.
 */
trigger ErrorLogEventTrigger on Error_Log_Event__e (after insert) {
    ErrorLogService.handleEvents(Trigger.new);
}
