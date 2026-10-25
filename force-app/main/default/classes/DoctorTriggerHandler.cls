/**
 * @description Bulk-safe trigger handler for Doctor__c.
 * Enforces normalized, unique 1:1 mapping between Doctor__c and Salesforce User,
 * validates active internal user requirements, and delegates identity reconciliation.
 */
public inherited sharing class DoctorTriggerHandler {

    public static Boolean bypassTrigger = false;

    public void beforeInsert(List<Doctor__c> newList) {
        if (bypassTrigger) {
            return;
        }
        normalizeAndValidateUserMappings(newList, null);
    }

    public void beforeUpdate(List<Doctor__c> newList, Map<Id, Doctor__c> oldMap) {
        if (bypassTrigger) {
            return;
        }
        normalizeAndValidateUserMappings(newList, oldMap);
    }

    public void afterUpdate(List<Doctor__c> newList, Map<Id, Doctor__c> oldMap) {
        if (bypassTrigger) {
            return;
        }
        handleUserMappingReassignments(newList, oldMap);
    }

    /**
     * Normalizes User_Id_Unique__c to uppercase 18-character string, handles null clearing,
     * and validates that referenced users are active internal users.
     */
    private void normalizeAndValidateUserMappings(List<Doctor__c> records, Map<Id, Doctor__c> oldMap) {
        Set<Id> userIdsToValidate = new Set<Id>();

        for (Doctor__c doc : records) {
            if (doc.User__c != null) {
                // Canonicalize to 18-character uppercase string
                String normalizedId = String.valueOf(doc.User__c).toUpperCase();
                doc.User_Id_Unique__c = normalizedId;
                userIdsToValidate.add(doc.User__c);
            } else {
                // Explicitly clear unique field when User__c is null
                doc.User_Id_Unique__c = null;
            }
        }

        if (userIdsToValidate.isEmpty()) {
            return;
        }

        // Validate active status and internal user type
        Map<Id, User> users = new Map<Id, User>([
            SELECT Id, IsActive, UserType
            FROM User
            WHERE Id IN :userIdsToValidate
        ]);

        for (Doctor__c doc : records) {
            if (doc.User__c != null) {
                User u = users.get(doc.User__c);
                if (u == null) {
                    doc.addError('Specified Salesforce User record was not found.');
                } else if (!u.IsActive) {
                    doc.addError('Cannot map doctor to an inactive Salesforce User.');
                } else if (u.UserType != 'Standard') {
                    doc.addError('Only internal Standard Users can be mapped to Doctor records.');
                }
            }
        }
    }

    /**
     * Reconciles clinical record sharing when a Doctor record's User__c mapping changes.
     */
    private void handleUserMappingReassignments(List<Doctor__c> records, Map<Id, Doctor__c> oldMap) {
        Map<Id, Id> doctorToOldUserMap = new Map<Id, Id>();
        Map<Id, Id> doctorToNewUserMap = new Map<Id, Id>();

        for (Doctor__c doc : records) {
            Doctor__c oldDoc = oldMap.get(doc.Id);
            if (oldDoc != null && doc.User__c != oldDoc.User__c) {
                doctorToOldUserMap.put(doc.Id, oldDoc.User__c);
                doctorToNewUserMap.put(doc.Id, doc.User__c);
            }
        }

        if (!doctorToNewUserMap.isEmpty()) {
            ClinicalSharingService.handleDoctorUserMappingReassignment(doctorToOldUserMap, doctorToNewUserMap);
        }
    }
}
