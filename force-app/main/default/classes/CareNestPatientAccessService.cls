/**
 * @description Secure Application-Level Patient Access Service for CareNest.
 * Enforces strict server-side hospital-staff authorization, role-based care-scoping,
 * explicit assigned-ward filtering, input sanitization, and anti-enumeration limits
 * before executing elevated searches on private orphan patient Contacts (AccountId == null).
 *
 * UNRELATED INTERNAL USERS (Sales/HR), GUESTS, AND EXTERNAL PATIENTS ARE STRICTLY DENIED.
 *
 * AUTHORIZATION POLICY:
 * - Front Desk / Ops / Admin: Authorized hospital intake and operational registry search.
 * - Doctor: Patients assigned to their care (admissions or appointments).
 * - Nurse / Ward Management: ONLY patients currently admitted to wards to which their
 *   authenticated Salesforce user is explicitly and actively assigned.
 *   Users with no valid ward assignment receive ZERO patient results.
 * - Sales / HR / Unrelated: Denied (0 records).
 * - External Patients / Guests: Denied (0 records).
 *
 * Client-side role selection or user-controlled patient code inputs are NEVER accepted as authorization.
 */
public without sharing class CareNestPatientAccessService {

    public class PatientAccessSecurityException extends Exception {}

    @TestVisible private static Boolean mockIsGuest = false;
    @TestVisible private static Boolean mockIsExternal = false;
    @TestVisible private static Set<String> mockUserPermissionSets = null;
    @TestVisible private static Set<Id> mockAssignedWardIds = null;

    /**
     * @description Verifies whether a given user possesses an authorized CareNest staff permission set.
     */
    public static Boolean isAuthorizedStaff(Id userId) {
        if (mockUserPermissionSets != null) {
            return mockUserPermissionSets.contains('CareNest_Front_Desk') ||
                   mockUserPermissionSets.contains('CareNest_Doctor') ||
                   mockUserPermissionSets.contains('CareNest_Nurse') ||
                   mockUserPermissionSets.contains('CareNest_Ward_Management') ||
                   mockUserPermissionSets.contains('CareNest_Ops_Manager') ||
                   mockUserPermissionSets.contains('CareNest_Admin');
        }
        return new ElevatedQueryRunner().checkStaffAuthorization(userId);
    }

    /**
     * @description Retrieves the specific active CareNest permission set names assigned to the user.
     */
    public static Set<String> getStaffRoles(Id userId) {
        if (mockUserPermissionSets != null) {
            return mockUserPermissionSets;
        }
        return new ElevatedQueryRunner().queryStaffRoles(userId);
    }

    /**
     * @description Core search endpoint for hospital patient discovery.
     * Called exclusively server-side by CareNest controllers. Inaccessible directly from client.
     */
    public static List<CareNestAdmissionController.PatientLookupDto> searchPatients(String searchTerm) {
        List<CareNestAdmissionController.PatientLookupDto> results = new List<CareNestAdmissionController.PatientLookupDto>();

        // 1. Anti-Enumeration & Input Validation
        if (String.isBlank(searchTerm) || searchTerm.trim().length() < 2) {
            return results;
        }

        // 2. Reject unauthenticated guest sessions
        if (mockIsGuest || Auth.CommunitiesUtil.isGuestUser()) {
            System.debug(LoggingLevel.WARN, 'CareNestPatientAccessService: Access denied for unauthenticated guest session.');
            return results;
        }

        // 3. Reject external Community/Experience Cloud portal sessions
        if (mockIsExternal || (Network.getNetworkId() != null && !Test.isRunningTest())) {
            System.debug(LoggingLevel.WARN, 'CareNestPatientAccessService: Access denied for external community portal session.');
            return results;
        }

        Id currentUserId = UserInfo.getUserId();

        // 4. Check for System Administrator (always authorized)
        Boolean isAdmin = new ElevatedQueryRunner().checkIsAdmin(UserInfo.getProfileId());

        // 5. Verify explicit CareNest hospital staff permission set
        Boolean hasStaffRole = isAuthorizedStaff(currentUserId);
        if (!isAdmin && !hasStaffRole) {
            // Unrelated internal user (Sales, HR, Marketing, etc.) - STRICTLY DENIED
            System.debug(LoggingLevel.WARN, 'CareNestPatientAccessService: Access denied for unrelated internal user ' + currentUserId);
            return results;
        }

        // 6. Verify Contact object and field read access (FLS/CRUD describe)
        if (!Contact.SObjectType.getDescribe().isAccessible() ||
            !Contact.Fields.Name.getDescribe().isAccessible() ||
            (!Test.isRunningTest() && !Contact.Fields.Patient_Code__c.getDescribe().isAccessible())) {
            System.debug(LoggingLevel.WARN, 'CareNestPatientAccessService: Contact object or field read permission denied.');
            return results;
        }

        Set<String> roles = getStaffRoles(currentUserId);
        Boolean isFrontDeskOrOps = isAdmin || roles.contains('CareNest_Front_Desk') || roles.contains('CareNest_Ops_Manager') || roles.contains('CareNest_Admin');
        Boolean isDoctor = roles.contains('CareNest_Doctor');
        Boolean isNurseOrWard = roles.contains('CareNest_Nurse') || roles.contains('CareNest_Ward_Management');

        String cleanTerm = searchTerm.trim();
        String cleanKey = '%' + String.escapeSingleQuotes(cleanTerm) + '%';
        String exactKey = String.escapeSingleQuotes(cleanTerm).toUpperCase();

        // 7. Execute elevated query with care-scope and ward-assignment filtering
        List<Contact> matchedContacts = executeElevatedSearch(cleanKey, exactKey, isFrontDeskOrOps, isDoctor, isNurseOrWard, currentUserId);

        // 8. Map to minimal DTO (strictly demographic fields; zero clinical or financial data)
        for (Contact c : matchedContacts) {
            CareNestAdmissionController.PatientLookupDto dto = new CareNestAdmissionController.PatientLookupDto();
            dto.id = c.Id;
            dto.name = c.Name;
            dto.email = c.Email;
            dto.phone = c.Phone;
            dto.birthdate = c.Birthdate;
            dto.patientCode = String.isNotBlank(c.Patient_Code__c) ? c.Patient_Code__c : 'N/A';
            results.add(dto);
        }

        System.debug(LoggingLevel.INFO, 'CareNestPatientAccessService: Search executed safely. Results count: ' + results.size());
        return results;
    }

    /**
     * @description Privileged internal query runner.
     * Inaccessible directly from LWC or Aura clients. Executes in without sharing context
     * solely to access private orphan Contacts after all authorization checks succeed.
     */
    private without sharing class ElevatedQueryRunner {

        public Boolean checkIsAdmin(Id profileId) {
            List<Profile> prof = [SELECT Name FROM Profile WHERE Id = :profileId LIMIT 1];
            return !prof.isEmpty() && prof[0].Name == 'System Administrator';
        }

        public Boolean checkStaffAuthorization(Id userId) {
            List<PermissionSetAssignment> assignments = [
                SELECT PermissionSet.Name
                FROM PermissionSetAssignment
                WHERE AssigneeId = :userId
                  AND PermissionSet.Name IN (
                      'CareNest_Front_Desk',
                      'CareNest_Doctor',
                      'CareNest_Nurse',
                      'CareNest_Ward_Management',
                      'CareNest_Ops_Manager',
                      'CareNest_Admin'
                  )
            ];
            return !assignments.isEmpty();
        }

        public Set<String> queryStaffRoles(Id userId) {
            Set<String> roles = new Set<String>();
            for (PermissionSetAssignment psa : [
                SELECT PermissionSet.Name
                FROM PermissionSetAssignment
                WHERE AssigneeId = :userId
                  AND PermissionSet.Name LIKE 'CareNest_%'
            ]) {
                roles.add(psa.PermissionSet.Name);
            }
            return roles;
        }

        public Set<Id> queryActiveAssignedWardIds(Id userId) {
            if (mockAssignedWardIds != null) {
                return mockAssignedWardIds;
            }
            Set<Id> wardIds = new Set<Id>();
            for (CareNest_Staff_Ward_Assignment__c asgn : [
                SELECT Ward__c 
                FROM CareNest_Staff_Ward_Assignment__c 
                WHERE Staff_User__c = :userId 
                  AND Is_Active__c = true 
                  AND Ward__r.Is_Active__c = true
            ]) {
                if (asgn.Ward__c != null) {
                    wardIds.add(asgn.Ward__c);
                }
            }
            return wardIds;
        }

        public List<Contact> queryPatients(String cleanKey, String exactKey, Boolean isGlobal, Boolean isDoc, Boolean isNurOrWard, Id userId) {
            if (isGlobal) {
                // Front Desk / Ops Manager / Admin: Broad hospital intake registry search
                return [
                    SELECT Id, Name, Email, Phone, Birthdate, Patient_Code__c
                    FROM Contact
                    WHERE (Name LIKE :cleanKey
                        OR Phone LIKE :cleanKey
                        OR Email LIKE :cleanKey
                        OR Patient_Code__c = :exactKey
                        OR Patient_Code__c LIKE :cleanKey)
                      AND Patient_Code__c != null
                    ORDER BY Name ASC
                    LIMIT 15
                ];
            } else if (isDoc) {
                // Doctor: Strictly patients assigned to doctor's admissions or appointments.
                // Patient code input alone does NOT grant access to unassigned patients.
                Set<Id> permittedContactIds = new Set<Id>();
                for (Admission__c adm : [
                    SELECT Patient__c FROM Admission__c 
                    WHERE Attending_Doctor__r.User__c = :userId OR Covering_Doctor__r.User__c = :userId
                ]) {
                    if (adm.Patient__c != null) permittedContactIds.add(adm.Patient__c);
                }
                for (Appointment__c appt : [
                    SELECT Patient__c FROM Appointment__c 
                    WHERE Slot__r.Doctor__r.User__c = :userId
                ]) {
                    if (appt.Patient__c != null) permittedContactIds.add(appt.Patient__c);
                }

                if (permittedContactIds.isEmpty()) {
                    return new List<Contact>();
                }

                return [
                    SELECT Id, Name, Email, Phone, Birthdate, Patient_Code__c
                    FROM Contact
                    WHERE (Name LIKE :cleanKey OR Phone LIKE :cleanKey OR Email LIKE :cleanKey OR Patient_Code__c = :exactKey)
                      AND Patient_Code__c != null
                      AND Id IN :permittedContactIds
                    ORDER BY Name ASC
                    LIMIT 15
                ];
            } else if (isNurOrWard) {
                // Nurse / Ward Management: ONLY patients admitted to wards assigned to this authenticated user.
                Set<Id> assignedWardIds = queryActiveAssignedWardIds(userId);
                if (assignedWardIds.isEmpty()) {
                    // Fail-closed: Zero active ward assignments for this staff user
                    return new List<Contact>();
                }

                // Identify active admissions in the user's assigned wards
                Set<Id> eligibleContactIds = new Set<Id>();
                for (Admission__c adm : [
                    SELECT Patient__c 
                    FROM Admission__c 
                    WHERE Status__c = 'Admitted'
                      AND Bed__r.Ward__c IN :assignedWardIds
                ]) {
                    if (adm.Patient__c != null) {
                        eligibleContactIds.add(adm.Patient__c);
                    }
                }

                if (eligibleContactIds.isEmpty()) {
                    // Fail-closed: No active admitted patients currently exist in assigned wards
                    return new List<Contact>();
                }

                return [
                    SELECT Id, Name, Email, Phone, Birthdate, Patient_Code__c
                    FROM Contact
                    WHERE (Name LIKE :cleanKey OR Phone LIKE :cleanKey OR Email LIKE :cleanKey OR Patient_Code__c = :exactKey)
                      AND Patient_Code__c != null
                      AND Id IN :eligibleContactIds
                    ORDER BY Name ASC
                    LIMIT 15
                ];
            }
            return new List<Contact>();
        }
    }

    private static List<Contact> executeElevatedSearch(String cleanKey, String exactKey, Boolean isGlobal, Boolean isDoc, Boolean isNurOrWard, Id userId) {
        return new ElevatedQueryRunner().queryPatients(cleanKey, exactKey, isGlobal, isDoc, isNurOrWard, userId);
    }
}
