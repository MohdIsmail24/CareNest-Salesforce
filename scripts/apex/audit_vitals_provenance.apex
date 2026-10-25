/**
 * @description Deep Dive on Patient_Vital__c Provenance
 */

Integer nullEncounter = [SELECT count() FROM Patient_Vital__c WHERE Inpatient_Encounter__c = null];
System.debug('Vitals with Inpatient_Encounter__c == null: ' + nullEncounter);

// Check if Patient_Vital__c has a direct Patient__c lookup or other lookup
Map<String, Schema.SObjectField> vFields = Schema.SObjectType.Patient_Vital__c.fields.getMap();
System.debug('Patient_Vital__c fields: ' + vFields.keySet());

// Check encounters without admission
Integer nullAdmissionEncounters = [SELECT count() FROM Inpatient_Encounter__c WHERE Admission__c = null];
System.debug('Encounters with Admission__c == null: ' + nullAdmissionEncounters);

// Inspect all 339 vitals
Integer cnCount = 0;
Integer otherCount = 0;
Map<String, Integer> otherReason = new Map<String, Integer>();

for (Patient_Vital__c pv : [
    SELECT Id, Name, Inpatient_Encounter__c, 
           Inpatient_Encounter__r.Admission__c, 
           Inpatient_Encounter__r.Admission__r.Patient__c,
           Inpatient_Encounter__r.Admission__r.Patient__r.Patient_Code__c
    FROM Patient_Vital__c
]) {
    if (pv.Inpatient_Encounter__c == null) {
        Integer cur = otherReason.containsKey('NULL_ENC') ? otherReason.get('NULL_ENC') : 0;
        otherReason.put('NULL_ENC', cur + 1);
        otherCount++;
    } else if (pv.Inpatient_Encounter__r.Admission__c == null) {
        Integer cur = otherReason.containsKey('NULL_ADM') ? otherReason.get('NULL_ADM') : 0;
        otherReason.put('NULL_ADM', cur + 1);
        otherCount++;
    } else if (pv.Inpatient_Encounter__r.Admission__r.Patient__c == null) {
        Integer cur = otherReason.containsKey('NULL_PAT') ? otherReason.get('NULL_PAT') : 0;
        otherReason.put('NULL_PAT', cur + 1);
        otherCount++;
    } else {
        String code = pv.Inpatient_Encounter__r.Admission__r.Patient__r.Patient_Code__c;
        if (code != null && code.startsWith('CN-')) {
            cnCount++;
        } else {
            Integer cur = otherReason.containsKey('NON_CN_CODE: ' + code) ? otherReason.get('NON_CN_CODE: ' + code) : 0;
            otherReason.put('NON_CN_CODE: ' + code, cur + 1);
            otherCount++;
        }
    }
}

System.debug('Vitals CN Count: ' + cnCount);
System.debug('Vitals Other Count: ' + otherCount);
System.debug('Vitals Other Breakdown: ' + otherReason);
