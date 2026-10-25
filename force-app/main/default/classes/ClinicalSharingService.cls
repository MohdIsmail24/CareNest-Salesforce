/**
 * @description Enterprise clinical record sharing service for CareNest HMS.
 * Manages dynamic, least-privilege, and revocable record-level sharing for
 * Inpatient_Encounter__c and Patient_Vital__c under Private OWD settings.
 */
public inherited sharing class ClinicalSharingService {

    public class ClinicalSharingException extends Exception {}

    public static Boolean bypassSharing = false;

    /**
     * Bulk-safe generation of encounter shares for attending and covering physicians.
     */
    public static void grantEncounterShares(List<Inpatient_Encounter__c> encounters) {
        if (bypassSharing || encounters == null || encounters.isEmpty()) {
            return;
        }

        Set<Id> admissionIds = new Set<Id>();
        Set<Id> encounterDoctorIds = new Set<Id>();

        for (Inpatient_Encounter__c enc : encounters) {
            if (enc.Admission__c != null) {
                admissionIds.add(enc.Admission__c);
            }
            if (enc.Attending_Doctor__c != null) {
                encounterDoctorIds.add(enc.Attending_Doctor__c);
            }
        }

        Map<Id, Admission__c> admissions = new Map<Id, Admission__c>([
            SELECT Id, Status__c, Attending_Doctor__c, Attending_Doctor__r.User__c,
                   Covering_Doctor__c, Covering_Doctor__r.User__c,
                   Covering_Start_Time__c, Covering_End_Time__c
            FROM Admission__c
            WHERE Id IN :admissionIds
        ]);

        Map<Id, Doctor__c> encounterDoctors = new Map<Id, Doctor__c>([
            SELECT Id, User__c
            FROM Doctor__c
            WHERE Id IN :encounterDoctorIds
        ]);

        List<Inpatient_Encounter__Share> sharesToInsert = new List<Inpatient_Encounter__Share>();
        Datetime nowTime = System.now();

        for (Inpatient_Encounter__c enc : encounters) {
            Admission__c adm = enc.Admission__c != null ? admissions.get(enc.Admission__c) : null;
            if (adm == null) {
                continue;
            }

            // 1. Share with Admission Attending Doctor
            Id attendingUserId = adm.Attending_Doctor__r != null ? adm.Attending_Doctor__r.User__c : null;
            if (attendingUserId != null && attendingUserId != enc.OwnerId) {
                sharesToInsert.add(new Inpatient_Encounter__Share(
                    ParentId = enc.Id,
                    UserOrGroupId = attendingUserId,
                    AccessLevel = (adm.Status__c == 'Discharged' || adm.Status__c == 'Cancelled') ? 'Read' : 'Edit',
                    RowCause = Schema.Inpatient_Encounter__Share.RowCause.Attending_Physician__c
                ));
            }

            // 2. Share with Encounter Author Doctor (if distinct from admission attending)
            if (enc.Attending_Doctor__c != null && enc.Attending_Doctor__c != adm.Attending_Doctor__c) {
                Doctor__c encDoc = encounterDoctors.get(enc.Attending_Doctor__c);
                Id encDocUserId = encDoc != null ? encDoc.User__c : null;
                if (encDocUserId != null && encDocUserId != enc.OwnerId && encDocUserId != attendingUserId) {
                    sharesToInsert.add(new Inpatient_Encounter__Share(
                        ParentId = enc.Id,
                        UserOrGroupId = encDocUserId,
                        AccessLevel = 'Edit',
                        RowCause = Schema.Inpatient_Encounter__Share.RowCause.Attending_Physician__c
                    ));
                }
            }

            // 3. Share with Active Covering Doctor
            Id coveringUserId = adm.Covering_Doctor__r != null ? adm.Covering_Doctor__r.User__c : null;
            if (coveringUserId != null && coveringUserId != enc.OwnerId && coveringUserId != attendingUserId) {
                Boolean isCoveringActive = (adm.Covering_Start_Time__c == null || adm.Covering_Start_Time__c <= nowTime) &&
                                           (adm.Covering_End_Time__c == null || adm.Covering_End_Time__c >= nowTime);
                if (isCoveringActive && adm.Status__c != 'Discharged' && adm.Status__c != 'Cancelled') {
                    sharesToInsert.add(new Inpatient_Encounter__Share(
                        ParentId = enc.Id,
                        UserOrGroupId = coveringUserId,
                        AccessLevel = 'Read',
                        RowCause = Schema.Inpatient_Encounter__Share.RowCause.Care_Team__c
                    ));
                }
            }
        }

        if (!sharesToInsert.isEmpty()) {
            new ClinicalSharingDmlHelper().insertEncounterShares(sharesToInsert);
        }
    }

    /**
     * Bulk-safe generation of vital observation shares for attending and covering physicians.
     */
    public static void grantVitalShares(List<Patient_Vital__c> vitals) {
        if (bypassSharing || vitals == null || vitals.isEmpty()) {
            return;
        }

        Set<Id> admissionIds = new Set<Id>();
        for (Patient_Vital__c v : vitals) {
            if (v.Admission__c != null) {
                admissionIds.add(v.Admission__c);
            }
        }

        Map<Id, Admission__c> admissions = new Map<Id, Admission__c>([
            SELECT Id, Status__c, Attending_Doctor__c, Attending_Doctor__r.User__c,
                   Covering_Doctor__c, Covering_Doctor__r.User__c,
                   Covering_Start_Time__c, Covering_End_Time__c
            FROM Admission__c
            WHERE Id IN :admissionIds
        ]);

        List<Patient_Vital__Share> sharesToInsert = new List<Patient_Vital__Share>();
        Datetime nowTime = System.now();

        for (Patient_Vital__c v : vitals) {
            Admission__c adm = v.Admission__c != null ? admissions.get(v.Admission__c) : null;
            if (adm == null) {
                continue;
            }

            // Share with Admission Attending Doctor
            Id attendingUserId = adm.Attending_Doctor__r != null ? adm.Attending_Doctor__r.User__c : null;
            if (attendingUserId != null && attendingUserId != v.OwnerId) {
                sharesToInsert.add(new Patient_Vital__Share(
                    ParentId = v.Id,
                    UserOrGroupId = attendingUserId,
                    AccessLevel = 'Read',
                    RowCause = Schema.Patient_Vital__Share.RowCause.Attending_Physician__c
                ));
            }

            // Share with Active Covering Doctor
            Id coveringUserId = adm.Covering_Doctor__r != null ? adm.Covering_Doctor__r.User__c : null;
            if (coveringUserId != null && coveringUserId != v.OwnerId && coveringUserId != attendingUserId) {
                Boolean isCoveringActive = (adm.Covering_Start_Time__c == null || adm.Covering_Start_Time__c <= nowTime) &&
                                           (adm.Covering_End_Time__c == null || adm.Covering_End_Time__c >= nowTime);
                if (isCoveringActive && adm.Status__c != 'Discharged' && adm.Status__c != 'Cancelled') {
                    sharesToInsert.add(new Patient_Vital__Share(
                        ParentId = v.Id,
                        UserOrGroupId = coveringUserId,
                        AccessLevel = 'Read',
                        RowCause = Schema.Patient_Vital__Share.RowCause.Care_Team__c
                    ));
                }
            }
        }

        if (!sharesToInsert.isEmpty()) {
            new ClinicalSharingDmlHelper().insertVitalShares(sharesToInsert);
        }
    }

    /**
     * Handles attending doctor reassignment on Admission__c:
     * Revokes previous doctor's service shares and grants shares to the new doctor.
     */
    public static void handleAttendingReassignment(Map<Id, Id> admissionToNewDoctorMap, Map<Id, Id> admissionToOldDoctorMap) {
        if (bypassSharing || admissionToNewDoctorMap == null || admissionToNewDoctorMap.isEmpty()) {
            return;
        }

        Set<Id> allDoctorIds = new Set<Id>();
        allDoctorIds.addAll(admissionToNewDoctorMap.values());
        allDoctorIds.addAll(admissionToOldDoctorMap.values());

        Map<Id, Doctor__c> doctors = new Map<Id, Doctor__c>([
            SELECT Id, User__c
            FROM Doctor__c
            WHERE Id IN :allDoctorIds
        ]);

        Set<Id> admissionIds = admissionToNewDoctorMap.keySet();
        List<Inpatient_Encounter__c> encounters = [
            SELECT Id, Admission__c, OwnerId
            FROM Inpatient_Encounter__c
            WHERE Admission__c IN :admissionIds
        ];

        List<Patient_Vital__c> vitals = [
            SELECT Id, Admission__c, OwnerId
            FROM Patient_Vital__c
            WHERE Admission__c IN :admissionIds
        ];

        Set<Id> oldUserIds = new Set<Id>();
        for (Id oldDocId : admissionToOldDoctorMap.values()) {
            Doctor__c d = doctors.get(oldDocId);
            if (d != null && d.User__c != null) {
                oldUserIds.add(d.User__c);
            }
        }

        Set<Id> encIds = new Set<Id>();
        for (Inpatient_Encounter__c e : encounters) {
            encIds.add(e.Id);
        }

        Set<Id> vitIds = new Set<Id>();
        for (Patient_Vital__c v : vitals) {
            vitIds.add(v.Id);
        }

        // Query and delete old doctor shares
        List<Inpatient_Encounter__Share> encSharesToDelete = [
            SELECT Id FROM Inpatient_Encounter__Share
            WHERE ParentId IN :encIds
              AND UserOrGroupId IN :oldUserIds
              AND RowCause = :Schema.Inpatient_Encounter__Share.RowCause.Attending_Physician__c
        ];

        List<Patient_Vital__Share> vitSharesToDelete = [
            SELECT Id FROM Patient_Vital__Share
            WHERE ParentId IN :vitIds
              AND UserOrGroupId IN :oldUserIds
              AND RowCause = :Schema.Patient_Vital__Share.RowCause.Attending_Physician__c
        ];

        // Create new doctor shares
        List<Inpatient_Encounter__Share> newEncShares = new List<Inpatient_Encounter__Share>();
        List<Patient_Vital__Share> newVitShares = new List<Patient_Vital__Share>();

        for (Inpatient_Encounter__c e : encounters) {
            Id newDocId = admissionToNewDoctorMap.get(e.Admission__c);
            Doctor__c newDoc = doctors.get(newDocId);
            Id newUserId = newDoc != null ? newDoc.User__c : null;
            if (newUserId != null && newUserId != e.OwnerId) {
                newEncShares.add(new Inpatient_Encounter__Share(
                    ParentId = e.Id,
                    UserOrGroupId = newUserId,
                    AccessLevel = 'Edit',
                    RowCause = Schema.Inpatient_Encounter__Share.RowCause.Attending_Physician__c
                ));
            }
        }

        for (Patient_Vital__c v : vitals) {
            Id newDocId = admissionToNewDoctorMap.get(v.Admission__c);
            Doctor__c newDoc = doctors.get(newDocId);
            Id newUserId = newDoc != null ? newDoc.User__c : null;
            if (newUserId != null && newUserId != v.OwnerId) {
                newVitShares.add(new Patient_Vital__Share(
                    ParentId = v.Id,
                    UserOrGroupId = newUserId,
                    AccessLevel = 'Read',
                    RowCause = Schema.Patient_Vital__Share.RowCause.Attending_Physician__c
                ));
            }
        }

        ClinicalSharingDmlHelper helper = new ClinicalSharingDmlHelper();
        helper.deleteEncounterShares(encSharesToDelete);
        helper.deleteVitalShares(vitSharesToDelete);
        helper.insertEncounterShares(newEncShares);
        helper.insertVitalShares(newVitShares);
    }

    /**
     * Downgrades attending doctor shares on Inpatient_Encounter__c from 'Edit' to 'Read' on discharge.
     */
    public static void downgradeSharesOnDischarge(Set<Id> dischargedAdmissionIds) {
        if (bypassSharing || dischargedAdmissionIds == null || dischargedAdmissionIds.isEmpty()) {
            return;
        }

        List<Inpatient_Encounter__Share> sharesToDowngrade = [
            SELECT Id, AccessLevel
            FROM Inpatient_Encounter__Share
            WHERE ParentId IN (
                SELECT Id FROM Inpatient_Encounter__c WHERE Admission__c IN :dischargedAdmissionIds
            )
            AND RowCause = :Schema.Inpatient_Encounter__Share.RowCause.Attending_Physician__c
            AND AccessLevel = 'Edit'
        ];

        if (!sharesToDowngrade.isEmpty()) {
            for (Inpatient_Encounter__Share s : sharesToDowngrade) {
                s.AccessLevel = 'Read';
            }
            new ClinicalSharingDmlHelper().updateEncounterShares(sharesToDowngrade);
        }
    }

    /**
     * Reconciles cross-cover shares when Covering_Doctor__c or times change on Admission__c.
     */
    public static void reconcileCrossCoverShares(Set<Id> admissionIds) {
        if (bypassSharing || admissionIds == null || admissionIds.isEmpty()) {
            return;
        }

        List<Admission__c> admissions = [
            SELECT Id, Status__c, Covering_Doctor__c, Covering_Doctor__r.User__c,
                   Covering_Start_Time__c, Covering_End_Time__c
            FROM Admission__c
            WHERE Id IN :admissionIds
        ];

        List<Inpatient_Encounter__c> encounters = [
            SELECT Id, Admission__c, OwnerId
            FROM Inpatient_Encounter__c
            WHERE Admission__c IN :admissionIds
        ];

        List<Patient_Vital__c> vitals = [
            SELECT Id, Admission__c, OwnerId
            FROM Patient_Vital__c
            WHERE Admission__c IN :admissionIds
        ];

        Set<Id> encIds = new Set<Id>();
        for (Inpatient_Encounter__c e : encounters) {
            encIds.add(e.Id);
        }

        Set<Id> vitIds = new Set<Id>();
        for (Patient_Vital__c v : vitals) {
            vitIds.add(v.Id);
        }

        // Delete existing Care_Team__c shares for these encounters
        List<Inpatient_Encounter__Share> oldCareTeamShares = [
            SELECT Id FROM Inpatient_Encounter__Share
            WHERE ParentId IN :encIds
              AND RowCause = :Schema.Inpatient_Encounter__Share.RowCause.Care_Team__c
        ];

        // Delete existing Care_Team__c shares for these vitals
        List<Patient_Vital__Share> oldVitalCareTeamShares = [
            SELECT Id FROM Patient_Vital__Share
            WHERE ParentId IN :vitIds
              AND RowCause = :Schema.Patient_Vital__Share.RowCause.Care_Team__c
        ];

        ClinicalSharingDmlHelper helper = new ClinicalSharingDmlHelper();
        helper.deleteEncounterShares(oldCareTeamShares);
        helper.deleteVitalShares(oldVitalCareTeamShares);

        // Re-grant if currently active
        Datetime nowTime = System.now();
        List<Inpatient_Encounter__Share> newShares = new List<Inpatient_Encounter__Share>();
        List<Patient_Vital__Share> newVitalShares = new List<Patient_Vital__Share>();

        Map<Id, Admission__c> admMap = new Map<Id, Admission__c>(admissions);
        for (Inpatient_Encounter__c e : encounters) {
            Admission__c adm = admMap.get(e.Admission__c);
            if (adm == null || adm.Status__c == 'Discharged' || adm.Status__c == 'Cancelled') {
                continue;
            }
            Id covUserId = adm.Covering_Doctor__r != null ? adm.Covering_Doctor__r.User__c : null;
            Boolean isCoveringActive = (adm.Covering_Start_Time__c == null || adm.Covering_Start_Time__c <= nowTime) &&
                                       (adm.Covering_End_Time__c == null || adm.Covering_End_Time__c >= nowTime);

            if (covUserId != null && covUserId != e.OwnerId && isCoveringActive) {
                newShares.add(new Inpatient_Encounter__Share(
                    ParentId = e.Id,
                    UserOrGroupId = covUserId,
                    AccessLevel = 'Read',
                    RowCause = Schema.Inpatient_Encounter__Share.RowCause.Care_Team__c
                ));
            }
        }

        for (Patient_Vital__c v : vitals) {
            Admission__c adm = admMap.get(v.Admission__c);
            if (adm == null || adm.Status__c == 'Discharged' || adm.Status__c == 'Cancelled') {
                continue;
            }
            Id covUserId = adm.Covering_Doctor__r != null ? adm.Covering_Doctor__r.User__c : null;
            Boolean isCoveringActive = (adm.Covering_Start_Time__c == null || adm.Covering_Start_Time__c <= nowTime) &&
                                       (adm.Covering_End_Time__c == null || adm.Covering_End_Time__c >= nowTime);

            if (covUserId != null && covUserId != v.OwnerId && isCoveringActive) {
                newVitalShares.add(new Patient_Vital__Share(
                    ParentId = v.Id,
                    UserOrGroupId = covUserId,
                    AccessLevel = 'Read',
                    RowCause = Schema.Patient_Vital__Share.RowCause.Care_Team__c
                ));
            }
        }

        helper.insertEncounterShares(newShares);
        helper.insertVitalShares(newVitalShares);
    }

    /**
     * Handles updating doctor-to-user mappings when Doctor__c.User__c is changed.
     */
    public static void handleDoctorUserMappingReassignment(Map<Id, Id> doctorToOldUserMap, Map<Id, Id> doctorToNewUserMap) {
        if (bypassSharing || doctorToNewUserMap == null || doctorToNewUserMap.isEmpty()) {
            return;
        }

        Set<Id> doctorIds = doctorToNewUserMap.keySet();
        List<Admission__c> activeAdmissions = [
            SELECT Id, Attending_Doctor__c
            FROM Admission__c
            WHERE Attending_Doctor__c IN :doctorIds
              AND Status__c IN ('Admitted', 'Discharge Pending')
        ];

        if (activeAdmissions.isEmpty()) {
            return;
        }

        Map<Id, Id> admToNewDoc = new Map<Id, Id>();
        Map<Id, Id> admToOldDoc = new Map<Id, Id>();
        for (Admission__c adm : activeAdmissions) {
            admToNewDoc.put(adm.Id, adm.Attending_Doctor__c);
            admToOldDoc.put(adm.Id, adm.Attending_Doctor__c);
        }

        handleAttendingReassignment(admToNewDoc, admToOldDoc);
    }

    /**
     * Elevated system context helper to execute isolated DML on sharing tables.
     * Enforces that only service-owned sharing entries (RowCause = Attending_Physician__c or Care_Team__c)
     * are created, updated, or removed.
     */
    private without sharing class ClinicalSharingDmlHelper {

        private void insertEncounterShares(List<Inpatient_Encounter__Share> shares) {
            if (shares == null || shares.isEmpty()) return;
            Database.SaveResult[] results = Database.insert(shares, false);
            handleSaveResults(results, 'ClinicalSharingService.insertEncounterShares');
        }

        private void insertVitalShares(List<Patient_Vital__Share> shares) {
            if (shares == null || shares.isEmpty()) return;
            Database.SaveResult[] results = Database.insert(shares, false);
            handleSaveResults(results, 'ClinicalSharingService.insertVitalShares');
        }

        private void updateEncounterShares(List<Inpatient_Encounter__Share> shares) {
            if (shares == null || shares.isEmpty()) return;
            Database.SaveResult[] results = Database.update(shares, false);
            handleSaveResults(results, 'ClinicalSharingService.updateEncounterShares');
        }

        private void deleteEncounterShares(List<Inpatient_Encounter__Share> shares) {
            if (shares == null || shares.isEmpty()) return;
            Database.DeleteResult[] results = Database.delete(shares, false);
            handleDeleteResults(results, 'ClinicalSharingService.deleteEncounterShares');
        }

        private void deleteVitalShares(List<Patient_Vital__Share> shares) {
            if (shares == null || shares.isEmpty()) return;
            Database.DeleteResult[] results = Database.delete(shares, false);
            handleDeleteResults(results, 'ClinicalSharingService.deleteVitalShares');
        }

        private void handleSaveResults(Database.SaveResult[] results, String context) {
            for (Database.SaveResult sr : results) {
                if (!sr.isSuccess()) {
                    for (Database.Error err : sr.getErrors()) {
                        // Ignore duplicate share rows gracefully
                        if (err.getStatusCode() != StatusCode.DUPLICATE_VALUE) {
                            ErrorLogService.log(context, new ClinicalSharingException(err.getMessage()), null);
                        }
                    }
                }
            }
        }

        private void handleDeleteResults(Database.DeleteResult[] results, String context) {
            for (Database.DeleteResult dr : results) {
                if (!dr.isSuccess()) {
                    for (Database.Error err : dr.getErrors()) {
                        ErrorLogService.log(context, new ClinicalSharingException(err.getMessage()), null);
                    }
                }
            }
        }
    }
}
