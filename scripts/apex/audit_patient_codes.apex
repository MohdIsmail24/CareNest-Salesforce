/**
 * @description Patient Code and Provenance Deep Dive
 */

System.debug('=== PATIENT CODE PATTERNS ON CONTACT ===');
List<AggregateResult> pcAgg = [
    SELECT Patient_Code__c pc, count(Id) cnt
    FROM Contact
    WHERE Patient_Code__c != null
    GROUP BY Patient_Code__c
    ORDER BY count(Id) DESC
];
System.debug('Distinct Patient_Code count: ' + pcAgg.size());

// Check prefixes
Map<String, Integer> prefixCounts = new Map<String, Integer>();
for (Contact c : [SELECT Id, Name, Patient_Code__c, MC_Is_Patient__c, MC_Demo_Key__c, CreatedDate FROM Contact WHERE Patient_Code__c != null]) {
    String prefix = 'OTHER';
    if (c.Patient_Code__c.startsWith('CN-')) {
        prefix = 'CN-';
    } else if (c.Patient_Code__c.startsWith('MC-')) {
        prefix = 'MC-';
    } else if (c.Patient_Code__c.startsWith('P-')) {
        prefix = 'P-';
    }
    Integer cur = prefixCounts.containsKey(prefix) ? prefixCounts.get(prefix) : 0;
    prefixCounts.put(prefix, cur + 1);
}
System.debug('Contact Patient Code Prefixes: ' + prefixCounts);

// Contacts without Patient_Code__c
Integer nullPatientCode = [SELECT count() FROM Contact WHERE Patient_Code__c = null];
System.debug('Contacts with Patient_Code__c == null: ' + nullPatientCode);

// Let's inspect MC_Is_Patient__c and MC_Demo_Key__c
for (Contact c : [SELECT Id, Name, Patient_Code__c, MC_Is_Patient__c, MC_Demo_Key__c, AccountId FROM Contact WHERE MC_Is_Patient__c = true OR MC_Demo_Key__c != null LIMIT 25]) {
    System.debug('MC Flagged Contact: ' + c.Name + ', Code=' + c.Patient_Code__c + ', MC_Is_Patient=' + c.MC_Is_Patient__c + ', DemoKey=' + c.MC_Demo_Key__c + ', Account=' + c.AccountId);
}

// Check Appointments: Which Contacts are they linked to?
Map<String, Integer> apptPatientPrefix = new Map<String, Integer>();
for (Appointment__c a : [SELECT Id, Patient__c, Patient__r.Patient_Code__c, Patient__r.Name FROM Appointment__c]) {
    String pCode = a.Patient__r != null ? a.Patient__r.Patient_Code__c : 'NO_PATIENT';
    String prefix = 'NULL';
    if (pCode != null) {
        if (pCode.startsWith('CN-')) prefix = 'CN-';
        else if (pCode.startsWith('MC-')) prefix = 'MC-';
        else if (pCode.startsWith('P-')) prefix = 'P-';
        else prefix = 'OTHER (' + pCode.substring(0, Math.min(5, pCode.length())) + ')';
    }
    Integer cur = apptPatientPrefix.containsKey(prefix) ? apptPatientPrefix.get(prefix) : 0;
    apptPatientPrefix.put(prefix, cur + 1);
}
System.debug('Appointment Patient Prefixes: ' + apptPatientPrefix);

// Check Admissions: Which Contacts are they linked to?
Map<String, Integer> admPatientPrefix = new Map<String, Integer>();
for (Admission__c a : [SELECT Id, Patient__c, Patient__r.Patient_Code__c FROM Admission__c]) {
    String pCode = a.Patient__r != null ? a.Patient__r.Patient_Code__c : 'NO_PATIENT';
    String prefix = 'NULL';
    if (pCode != null) {
        if (pCode.startsWith('CN-')) prefix = 'CN-';
        else if (pCode.startsWith('MC-')) prefix = 'MC-';
        else if (pCode.startsWith('P-')) prefix = 'P-';
        else prefix = 'OTHER (' + pCode.substring(0, Math.min(5, pCode.length())) + ')';
    }
    Integer cur = admPatientPrefix.containsKey(prefix) ? admPatientPrefix.get(prefix) : 0;
    admPatientPrefix.put(prefix, cur + 1);
}
System.debug('Admission Patient Prefixes: ' + admPatientPrefix);

// Check Inpatient_Encounter__c
Map<String, Integer> encPatientPrefix = new Map<String, Integer>();
for (Inpatient_Encounter__c e : [SELECT Id, Admission__r.Patient__r.Patient_Code__c FROM Inpatient_Encounter__c]) {
    String pCode = e.Admission__r != null && e.Admission__r.Patient__r != null ? e.Admission__r.Patient__r.Patient_Code__c : 'NO_PATIENT';
    String prefix = 'NULL';
    if (pCode != null) {
        if (pCode.startsWith('CN-')) prefix = 'CN-';
        else if (pCode.startsWith('MC-')) prefix = 'MC-';
        else if (pCode.startsWith('P-')) prefix = 'P-';
        else prefix = 'OTHER';
    }
    Integer cur = encPatientPrefix.containsKey(prefix) ? encPatientPrefix.get(prefix) : 0;
    encPatientPrefix.put(prefix, cur + 1);
}
System.debug('Encounter Patient Prefixes: ' + encPatientPrefix);
