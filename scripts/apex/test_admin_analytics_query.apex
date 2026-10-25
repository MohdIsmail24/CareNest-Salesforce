// Test Admin Analytics Query Script
Id currentUserId = UserInfo.getUserId();
System.debug('Current User ID: ' + currentUserId);

// 1. Check Admin access
List<PermissionSetAssignment> psa = [
    SELECT PermissionSet.Name 
    FROM PermissionSetAssignment 
    WHERE AssigneeId = :currentUserId 
      AND PermissionSet.Name IN ('CareNest_Admin', 'CareNest_Ops_Manager')
];
List<User> usr = [
    SELECT Profile.Name, Profile.PermissionsModifyAllData 
    FROM User 
    WHERE Id = :currentUserId
];
Boolean isAdmin = !psa.isEmpty() || (usr[0].Profile.Name == 'System Administrator' || usr[0].Profile.PermissionsModifyAllData == true);
System.debug('Is Admin: ' + isAdmin);

// 2. Collections by Status & Method
for (AggregateResult ar : [
    SELECT Status__c st, Method__c m, count(Id) cnt, sum(Amount__c) sm 
    FROM Payment__c 
    GROUP BY Status__c, Method__c
]) {
    System.debug('Payment: ' + ar.get('st') + ' | ' + ar.get('m') + ' | Count: ' + ar.get('cnt') + ' | Sum: ' + ar.get('sm'));
}

// 3. Department Revenue
for (AggregateResult ar : [
    SELECT Appointment__r.Slot__r.Doctor__r.Department__c dept, sum(Amount__c) sm, count(Id) cnt 
    FROM Payment__c 
    WHERE Status__c = 'Success' 
    GROUP BY Appointment__r.Slot__r.Doctor__r.Department__c
]) {
    System.debug('Dept: ' + ar.get('dept') + ' | Revenue: ' + ar.get('sm') + ' | Count: ' + ar.get('cnt'));
}

// 4. Receivables Aging
Decimal currentAmt = 0;
Decimal overdue30 = 0;
Decimal overdue60 = 0;
Decimal overdue90 = 0;
Decimal overdueMore = 0;
Date today = Date.today();

for (Appointment__c appt : [
    SELECT Id, Name, Balance_Due__c, Slot__r.Slot_Start__c, CreatedDate 
    FROM Appointment__c 
    WHERE Balance_Due__c > 0
]) {
    Date apptDate = appt.Slot__r != null && appt.Slot__r.Slot_Start__c != null 
        ? appt.Slot__r.Slot_Start__c.date() 
        : appt.CreatedDate.date();
    Integer daysDiff = apptDate.daysBetween(today);
    Decimal bal = appt.Balance_Due__c != null ? appt.Balance_Due__c : 0;
    if (daysDiff <= 0) {
        currentAmt += bal;
    } else if (daysDiff <= 30) {
        overdue30 += bal;
    } else if (daysDiff <= 60) {
        overdue60 += bal;
    } else if (daysDiff <= 90) {
        overdue90 += bal;
    } else {
        overdueMore += bal;
    }
}
System.debug('Aging: Current=' + currentAmt + ', 1-30d=' + overdue30 + ', 31-60d=' + overdue60 + ', 61-90d=' + overdue90 + ', 90+d=' + overdueMore);
System.debug('=== SCRIPT EXECUTION SUCCESSFUL ===');
