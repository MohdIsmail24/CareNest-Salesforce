// Run once after data load (Apex trigger arrives in Chunk 2).
List<Appointment__c> appts = [SELECT Id, Fee_Amount__c, Discount_Percent__c FROM Appointment__c];
for (Appointment__c a : appts) {
    Decimal fee = a.Fee_Amount__c == null ? 0 : a.Fee_Amount__c;
    Decimal disc = a.Discount_Percent__c == null ? 0 : a.Discount_Percent__c;
    a.Total_Amount__c = (fee * (1 - disc / 100)).setScale(2);
}
update appts;

Map<Id, Integer> counts = new Map<Id, Integer>();
for (AggregateResult ar : [SELECT Slot__c s, COUNT(Id) c FROM Appointment__c
                           WHERE Status__c IN ('Pending','Confirmed') AND Slot__c != null GROUP BY Slot__c]) {
    counts.put((Id) ar.get('s'), (Integer) ar.get('c'));
}
List<Appointment_Slot__c> slots = [SELECT Id FROM Appointment_Slot__c];
for (Appointment_Slot__c s : slots) {
    s.Booked_Count__c = counts.containsKey(s.Id) ? counts.get(s.Id) : 0;
}
update slots;
System.debug('Recalculated ' + appts.size() + ' appointments and ' + slots.size() + ' slots');
