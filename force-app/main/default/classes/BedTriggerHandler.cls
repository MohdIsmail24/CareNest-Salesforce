/**
 * @description Trigger handler for Bed__c validating ward capacity limits upon bed creation.
 */
public with sharing class BedTriggerHandler extends TriggerHandler {

    protected override void beforeInsert() {
        validateWardCapacity((List<Bed__c>) Trigger.new);
    }

    /**
     * @description Ensures adding new beds does not exceed the parent Ward's defined capacity.
     * @param newBeds List of Bed__c records being inserted.
     */
    private static void validateWardCapacity(List<Bed__c> newBeds) {
        Set<Id> wardIds = new Set<Id>();
        for (Bed__c b : newBeds) {
            if (b.Ward__c != null) {
                wardIds.add(b.Ward__c);
            }
        }
        if (wardIds.isEmpty()) {
            return;
        }

        Map<Id, Ward__c> wards = new Map<Id, Ward__c>([
            SELECT Id, Capacity__c,
                   (SELECT Id FROM Beds__r)
            FROM Ward__c
            WHERE Id IN :wardIds
        ]);

        Map<Id, Integer> newBedsPerWard = new Map<Id, Integer>();
        for (Bed__c b : newBeds) {
            if (b.Ward__c != null) {
                Integer cnt = newBedsPerWard.containsKey(b.Ward__c) ? newBedsPerWard.get(b.Ward__c) : 0;
                newBedsPerWard.put(b.Ward__c, cnt + 1);
            }
        }

        for (Bed__c b : newBeds) {
            if (b.Ward__c != null && wards.containsKey(b.Ward__c)) {
                Ward__c w = wards.get(b.Ward__c);
                Integer existingCount = (w.Beds__r != null) ? w.Beds__r.size() : 0;
                Integer incomingCount = newBedsPerWard.get(b.Ward__c);
                if (w.Capacity__c != null && (existingCount + incomingCount > w.Capacity__c)) {
                    b.addError('Cannot add bed. Ward capacity of ' + w.Capacity__c + ' beds would be exceeded.');
                }
            }
        }
    }
}
