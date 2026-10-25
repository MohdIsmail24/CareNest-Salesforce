/**
 * @description Read-Only Data Ownership Audit Script for CareNest vs MiniCare
 */

System.debug('====================================================');
System.debug('   CARENEST VS MINICARE DATA OWNERSHIP AUDIT');
System.debug('====================================================');

// 1. Account Records
System.debug('--- 1. ACCOUNTS ---');
for (Account a : [SELECT Id, Name, Type, CreatedDate FROM Account ORDER BY CreatedDate ASC LIMIT 50]) {
    System.debug('Account: Id=' + a.Id + ', Name=' + a.Name + ', Type=' + a.Type);
}

// 2. Contact / Patient Analysis
System.debug('--- 2. CONTACTS / PATIENTS ---');
Integer totalContacts = [SELECT count() FROM Contact];
Integer nullAccountContacts = [SELECT count() FROM Contact WHERE AccountId = null];
Integer nonNullAccountContacts = [SELECT count() FROM Contact WHERE AccountId != null];
Integer mcIsPatientTrue = [SELECT count() FROM Contact WHERE MC_Is_Patient__c = true];
Integer mcIsPatientFalse = [SELECT count() FROM Contact WHERE MC_Is_Patient__c = false OR MC_Is_Patient__c = null];
System.debug('Total Contacts: ' + totalContacts);
System.debug('Contacts with AccountId = null: ' + nullAccountContacts);
System.debug('Contacts with AccountId != null: ' + nonNullAccountContacts);
System.debug('Contacts with MC_Is_Patient__c = true: ' + mcIsPatientTrue);
System.debug('Contacts with MC_Is_Patient__c = false/null: ' + mcIsPatientFalse);

// Breakdown of Contact AccountIds
AggregateResult[] contactPrefixAgg = [
    SELECT Account.Name accName, count(Id) cnt
    FROM Contact
    GROUP BY Account.Name
];
for (AggregateResult ar : contactPrefixAgg) {
    System.debug('Contacts by Account: Account=' + ar.get('accName') + ', Count=' + ar.get('cnt'));
}

// Sample contacts
for (Contact c : [SELECT Id, Name, Patient_Code__c, AccountId, Account.Name, MC_Is_Patient__c FROM Contact LIMIT 15]) {
    System.debug('Sample Contact: Id=' + c.Id + ', Name=' + c.Name + ', Code=' + c.Patient_Code__c + ', Account=' + c.Account.Name + ', MC_Is_Patient=' + c.MC_Is_Patient__c);
}

// 3. Doctor__c Analysis
System.debug('--- 3. DOCTORS ---');
Integer totalDoctors = [SELECT count() FROM Doctor__c];
System.debug('Total Doctors: ' + totalDoctors);
for (Doctor__c d : [SELECT Id, Name, Department__c, Specialty__c, Consultation_Fee__c, Is_Active__c FROM Doctor__c LIMIT 30]) {
    System.debug('Doctor: Id=' + d.Id + ', Name=' + d.Name + ', Dept=' + d.Department__c + ', Specialty=' + d.Specialty__c + ', Active=' + d.Is_Active__c);
}

// 4. Appointment__c Analysis
System.debug('--- 4. APPOINTMENTS ---');
Integer totalAppts = [SELECT count() FROM Appointment__c];
System.debug('Total Appointments: ' + totalAppts);
AggregateResult[] apptStatusAgg = [SELECT Status__c st, count(Id) cnt FROM Appointment__c GROUP BY Status__c];
for (AggregateResult ar : apptStatusAgg) {
    System.debug('Appointments by Status: ' + ar.get('st') + ' = ' + ar.get('cnt'));
}

for (Appointment__c app : [SELECT Id, Name, Status__c, Patient__c, Slot__r.Doctor__r.Name, Total_Amount__c, CreatedDate FROM Appointment__c LIMIT 10]) {
    System.debug('Sample Appt: Id=' + app.Id + ', Name=' + app.Name + ', Status=' + app.Status__c + ', Patient=' + app.Patient__c + ', Doctor=' + app.Slot__r.Doctor__r.Name + ', Amount=' + app.Total_Amount__c);
}

// 5. Payment__c Analysis
System.debug('--- 5. PAYMENTS ---');
Integer totalPayments = [SELECT count() FROM Payment__c];
System.debug('Total Payments: ' + totalPayments);
AggregateResult[] payStatusAgg = [SELECT Status__c st, Method__c pm, count(Id) cnt, sum(Amount__c) sm FROM Payment__c GROUP BY Status__c, Method__c];
for (AggregateResult ar : payStatusAgg) {
    System.debug('Payments by Status/Method: ' + ar.get('st') + ' / ' + ar.get('pm') + ' = ' + ar.get('cnt') + ', Sum=' + ar.get('sm'));
}

// 6. Cancellation__c Analysis
System.debug('--- 6. CANCELLATIONS ---');
Integer totalCancellations = [SELECT count() FROM Cancellation__c];
System.debug('Total Cancellations: ' + totalCancellations);

// 7. Inpatient Encounters, Admissions, Wards, Beds
System.debug('--- 7. INPATIENT / ADMISSION / WARD / BED ---');
Integer totalWards = [SELECT count() FROM Ward__c];
Integer totalBeds = [SELECT count() FROM Bed__c];
Integer totalAdmissions = [SELECT count() FROM Admission__c];
Integer totalEncounters = [SELECT count() FROM Inpatient_Encounter__c];
Integer totalVitals = [SELECT count() FROM Patient_Vital__c];
System.debug('Wards: ' + totalWards + ', Beds: ' + totalBeds + ', Admissions: ' + totalAdmissions + ', Encounters: ' + totalEncounters + ', Vitals: ' + totalVitals);

for (Ward__c w : [SELECT Id, Name, Ward_Code__c, Ward_Type__c, Capacity__c FROM Ward__c]) {
    System.debug('Ward: ' + w.Name + ' (' + w.Ward_Code__c + '), Type=' + w.Ward_Type__c + ', Capacity=' + w.Capacity__c);
}

// 8. Inspect Custom Fields for any discriminator (Hospital, Facility, App, Org, Project, MC, CareNest)
System.debug('--- 8. SCHEMA DISCRIMINATOR SEARCH ---');
String[] objectsToCheck = new String[]{
    'Contact', 'Doctor__c', 'Appointment__c', 'Payment__c', 
    'Cancellation__c', 'Admission__c', 'Ward__c', 'Bed__c', 'Patient_Vital__c', 'Inpatient_Encounter__c'
};
for (String objName : objectsToCheck) {
    Schema.SObjectType sType = Schema.getGlobalDescribe().get(objName);
    if (sType != null) {
        Map<String, Schema.SObjectField> fields = sType.getDescribe().fields.getMap();
        List<String> matchingFields = new List<String>();
        for (String fName : fields.keySet()) {
            if (fName.contains('hospital') || fName.contains('facility') || fName.contains('project') || 
                fName.contains('app') || fName.contains('tenant') || fName.contains('carenest') || 
                fName.contains('minicare') || fName.contains('mc_') || fName.contains('source') || fName.contains('system')) {
                matchingFields.add(fName);
            }
        }
        System.debug('Object ' + objName + ' potential discriminator fields: ' + matchingFields);
    }
}

// 9. Check RecordTypes on these objects
System.debug('--- 9. RECORD TYPES ON OBJECTS ---');
for (String objName : objectsToCheck) {
    Schema.SObjectType sType = Schema.getGlobalDescribe().get(objName);
    if (sType != null) {
        List<Schema.RecordTypeInfo> rtList = sType.getDescribe().getRecordTypeInfos();
        List<String> rtNames = new List<String>();
        for (Schema.RecordTypeInfo rt : rtList) {
            if (rt.getName() != 'Master') {
                rtNames.add(rt.getName());
            }
        }
        if (!rtNames.isEmpty()) {
            System.debug('Object ' + objName + ' RecordTypes: ' + rtNames);
        } else {
            System.debug('Object ' + objName + ' has NO custom RecordTypes (only Master)');
        }
    }
}

// 10. Reports in Org
System.debug('--- 10. REPORTS IN ORG ---');
for (Report r : [SELECT Id, Name, DeveloperName, FolderName FROM Report WHERE DeveloperName LIKE '%Care%' OR DeveloperName LIKE '%MC%' OR DeveloperName LIKE '%Inpatient%' OR DeveloperName LIKE '%Billing%' LIMIT 30]) {
    System.debug('Report: Id=' + r.Id + ', Name=' + r.Name + ', DevName=' + r.DeveloperName + ', Folder=' + r.FolderName);
}
