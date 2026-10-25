/**
 * @description Bulk-safe trigger handler for Inpatient_Encounter__c.
 * Enforces business rules: doctor alias synchronization, admission status verification,
 * and defaults handling.
 */
public inherited sharing class InpatientEncounterTriggerHandler {

    public static Boolean bypassTrigger = false;

    private static final Set<String> INACTIVE_ADMISSION_STATUSES = new Set<String>{
        'Discharged',
        'Cancelled'
    };

    public void beforeInsert(List<Inpatient_Encounter__c> newList) {
        if (bypassTrigger) {
            return;
        }

        syncDoctorAliasesAndDefaults(newList);
        validateParentAdmissions(newList);
    }

    public void afterInsert(List<Inpatient_Encounter__c> newList) {
        if (bypassTrigger) {
            return;
        }

        ClinicalSharingService.grantEncounterShares(newList);
    }

    public void beforeUpdate(List<Inpatient_Encounter__c> newList, Map<Id, Inpatient_Encounter__c> oldMap) {
        if (bypassTrigger) {
            return;
        }

        syncDoctorAliasesAndDefaults(newList);
        validateParentAdmissions(newList);
    }

    /**
     * Synchronizes Attending_Doctor__c and Doctor__c, and populates default encounter values.
     */
    private void syncDoctorAliasesAndDefaults(List<Inpatient_Encounter__c> records) {
        for (Inpatient_Encounter__c enc : records) {
            if (enc.Attending_Doctor__c != null && enc.Doctor__c == null) {
                enc.Doctor__c = enc.Attending_Doctor__c;
            } else if (enc.Doctor__c != null && enc.Attending_Doctor__c == null) {
                enc.Attending_Doctor__c = enc.Doctor__c;
            }

            if (String.isNotBlank(enc.Notes__c) && String.isBlank(enc.Clinical_Notes__c)) {
                enc.Clinical_Notes__c = enc.Notes__c;
            } else if (String.isNotBlank(enc.Clinical_Notes__c) && String.isBlank(enc.Notes__c)) {
                enc.Notes__c = enc.Clinical_Notes__c.left(255);
            }

            if (enc.Encounter_Date__c == null) {
                enc.Encounter_Date__c = System.now();
            }

            if (enc.Status__c == null) {
                enc.Status__c = 'Completed';
            }
        }
    }

    /**
     * Ensures parent Admission is active and exists.
     */
    private void validateParentAdmissions(List<Inpatient_Encounter__c> records) {
        Set<Id> admissionIds = new Set<Id>();
        for (Inpatient_Encounter__c enc : records) {
            if (enc.Admission__c != null) {
                admissionIds.add(enc.Admission__c);
            }
        }

        if (admissionIds.isEmpty()) {
            return;
        }

        Map<Id, Admission__c> admissions = new Map<Id, Admission__c>([
            SELECT Id, Name, Status__c
            FROM Admission__c
            WHERE Id IN :admissionIds
        ]);

        for (Inpatient_Encounter__c enc : records) {
            if (enc.Admission__c != null) {
                Admission__c adm = admissions.get(enc.Admission__c);
                if (adm == null) {
                    enc.addError('Specified Admission record was not found.');
                } else if (String.isBlank(enc.Encounter_Code__c) && INACTIVE_ADMISSION_STATUSES.contains(adm.Status__c)) {
                    enc.addError('Cannot create or update encounters for discharged or cancelled admissions (Admission status: ' + adm.Status__c + ').');
                }
            }
        }
    }
}
