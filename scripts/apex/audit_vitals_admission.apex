/**
 * @description Check Admission__c on Patient_Vital__c
 */

Integer vitalsDirectAdmCN = [
    SELECT count()
    FROM Patient_Vital__c
    WHERE Admission__r.Patient__r.Patient_Code__c LIKE 'CN-%'
];
System.debug('Vitals with Direct Admission__r.Patient CN: ' + vitalsDirectAdmCN);

Integer vitalsAnyCN = [
    SELECT count()
    FROM Patient_Vital__c
    WHERE (Inpatient_Encounter__r.Admission__r.Patient__r.Patient_Code__c LIKE 'CN-%')
       OR (Admission__r.Patient__r.Patient_Code__c LIKE 'CN-%')
];
System.debug('Vitals linked to CN either via Encounter OR direct Admission: ' + vitalsAnyCN);

Integer vitalsWithNullAdmAndEnc = [
    SELECT count()
    FROM Patient_Vital__c
    WHERE Inpatient_Encounter__c = null AND Admission__c = null
];
System.debug('Vitals with both Inpatient_Encounter__c == null AND Admission__c == null: ' + vitalsWithNullAdmAndEnc);

// Check sample of those with null encounter
for (Patient_Vital__c pv : [SELECT Id, Name, Admission__c, Admission__r.Name, Admission__r.Patient__r.Name, Admission__r.Patient__r.Patient_Code__c FROM Patient_Vital__c WHERE Inpatient_Encounter__c = null LIMIT 10]) {
    System.debug('Sample Null Enc Vital: Id=' + pv.Id + ', Adm=' + pv.Admission__r.Name + ', Patient=' + pv.Admission__r.Patient__r.Name + ', Code=' + pv.Admission__r.Patient__r.Patient_Code__c);
}
