/**
 * @description Bulk-safe trigger handler for Admission__c.
 * Enforces business invariants: bed availability, active ward,
 * duplicate active admission prevention, terminal state protections,
 * and safe bed release.
 */
public inherited sharing class AdmissionTriggerHandler {

    /**
     * @description Flag set by AdmissionService when it manages bed locking & occupancy updates atomically.
     */
    public static Boolean isServiceManagingBedUpdate = false;

    /**
     * @description Global bypass flag for migrations/bulk admin scripts if needed.
     */
    public static Boolean bypassTrigger = false;

    private static final Set<String> ACTIVE_STATUSES = new Set<String>{
        'Admitted',
        'Discharge Pending'
    };

    public void beforeInsert(List<Admission__c> newList) {
        if (bypassTrigger) {
            return;
        }

        syncAliasesAndDefaults(newList);
        validateRequiredFields(newList);
        validateBatchUniqueness(newList);
        validateNoExistingActiveAdmissions(newList, null);

        if (!isServiceManagingBedUpdate) {
            validateBedAndWardPreconditions(newList);
        }
    }

    public void afterInsert(List<Admission__c> newList) {
        if (bypassTrigger || isServiceManagingBedUpdate) {
            return;
        }

        // Direct DML safety fallback: mark beds as Occupied for active admissions
        Set<Id> bedsToOccupy = new Set<Id>();
        for (Admission__c adm : newList) {
            if (ACTIVE_STATUSES.contains(adm.Status__c) && adm.Bed__c != null) {
                bedsToOccupy.add(adm.Bed__c);
            }
        }

        if (!bedsToOccupy.isEmpty()) {
            List<Bed__c> beds = new List<Bed__c>();
            for (Id bId : bedsToOccupy) {
                beds.add(new Bed__c(Id = bId, Status__c = 'Occupied'));
            }
            update beds;
        }
    }

    public void beforeUpdate(List<Admission__c> newList, Map<Id, Admission__c> oldMap) {
        if (bypassTrigger) {
            return;
        }

        syncAliasesAndDefaults(newList);
        validateRequiredFields(newList);
        validateBatchUniqueness(newList);
        validateNoExistingActiveAdmissions(newList, oldMap);
        validateStatusTransitionsAndDischarge(newList, oldMap);

        if (!isServiceManagingBedUpdate) {
            List<Admission__c> admsToCheck = new List<Admission__c>();
            for (Admission__c adm : newList) {
                Admission__c oldAdm = oldMap.get(adm.Id);
                Boolean bedChanged = adm.Bed__c != oldAdm.Bed__c;
                Boolean statusBecameActive = ACTIVE_STATUSES.contains(adm.Status__c) && !ACTIVE_STATUSES.contains(oldAdm.Status__c);
                if (bedChanged || statusBecameActive) {
                    admsToCheck.add(adm);
                }
            }
            if (!admsToCheck.isEmpty()) {
                validateBedAndWardPreconditions(admsToCheck);
            }
        }
    }

    public void afterUpdate(List<Admission__c> newList, Map<Id, Admission__c> oldMap) {
        if (bypassTrigger) {
            return;
        }

        if (!isServiceManagingBedUpdate) {
            Set<Id> bedsToFree = new Set<Id>();
            for (Admission__c adm : newList) {
                Admission__c oldAdm = oldMap.get(adm.Id);
                Boolean wasActive = ACTIVE_STATUSES.contains(oldAdm.Status__c);
                Boolean isNowInactive = (adm.Status__c == 'Discharged' || adm.Status__c == 'Cancelled');
                if (wasActive && isNowInactive && adm.Bed__c != null) {
                    bedsToFree.add(adm.Bed__c);
                }
            }

            if (!bedsToFree.isEmpty()) {
                // Confirm no other active admissions on these beds before freeing
                Map<Id, AggregateResult> activeCounts = new Map<Id, AggregateResult>([
                    SELECT Bed__c Id, COUNT(Id) cnt
                    FROM Admission__c
                    WHERE Bed__c IN :bedsToFree
                      AND Status__c IN :ACTIVE_STATUSES
                    GROUP BY Bed__c
                ]);

                List<Bed__c> beds = new List<Bed__c>();
                for (Id bId : bedsToFree) {
                    if (!activeCounts.containsKey(bId)) {
                        beds.add(new Bed__c(Id = bId, Status__c = 'Available'));
                    }
                }
                if (!beds.isEmpty()) {
                    update beds;
                }
            }
        }

        // Clinical Record Sharing Hooks
        Set<Id> dischargedIds = new Set<Id>();
        Map<Id, Id> admissionToNewDoctorMap = new Map<Id, Id>();
        Map<Id, Id> admissionToOldDoctorMap = new Map<Id, Id>();
        Set<Id> crossCoverAdmissionIds = new Set<Id>();

        for (Admission__c adm : newList) {
            Admission__c oldAdm = oldMap.get(adm.Id);
            if (oldAdm == null) {
                continue;
            }

            if (adm.Status__c == 'Discharged' && oldAdm.Status__c != 'Discharged') {
                dischargedIds.add(adm.Id);
            }

            if (adm.Attending_Doctor__c != oldAdm.Attending_Doctor__c) {
                admissionToNewDoctorMap.put(adm.Id, adm.Attending_Doctor__c);
                admissionToOldDoctorMap.put(adm.Id, oldAdm.Attending_Doctor__c);
            }

            if (adm.Covering_Doctor__c != oldAdm.Covering_Doctor__c ||
                adm.Covering_Start_Time__c != oldAdm.Covering_Start_Time__c ||
                adm.Covering_End_Time__c != oldAdm.Covering_End_Time__c) {
                crossCoverAdmissionIds.add(adm.Id);
            }
        }

        if (!dischargedIds.isEmpty()) {
            ClinicalSharingService.downgradeSharesOnDischarge(dischargedIds);
        }

        if (!admissionToNewDoctorMap.isEmpty()) {
            ClinicalSharingService.handleAttendingReassignment(admissionToNewDoctorMap, admissionToOldDoctorMap);
        }

        if (!crossCoverAdmissionIds.isEmpty()) {
            ClinicalSharingService.reconcileCrossCoverShares(crossCoverAdmissionIds);
        }
    }

    /**
     * Enforces valid lifecycle status transitions and protects terminal states (Discharged/Cancelled).
     */
    private void validateStatusTransitionsAndDischarge(List<Admission__c> records, Map<Id, Admission__c> oldMap) {
        for (Admission__c adm : records) {
            Admission__c oldAdm = oldMap.get(adm.Id);
            if (oldAdm == null) {
                continue;
            }

            // 1. Terminal state protection: Cannot transition out of Discharged or Cancelled
            if (oldAdm.Status__c == 'Discharged' && adm.Status__c != 'Discharged') {
                adm.addError('Cannot change status of an already discharged admission (' + adm.Name + '). Inpatient discharge is terminal.');
            } else if (oldAdm.Status__c == 'Cancelled' && adm.Status__c != 'Cancelled') {
                adm.addError('Cannot change status of a cancelled admission (' + adm.Name + '). Cancellation is terminal.');
            }

            // 2. Validate transition to Discharged
            if (adm.Status__c == 'Discharged' && oldAdm.Status__c != 'Discharged') {
                if (oldAdm.Status__c == 'Cancelled') {
                    adm.addError('Cannot discharge a cancelled admission (' + adm.Name + ').');
                } else if (oldAdm.Status__c != 'Admitted' && oldAdm.Status__c != 'Discharge Pending') {
                    adm.addError('Admission can only be discharged from Admitted or Discharge Pending status (Current: ' + oldAdm.Status__c + ').');
                }

                // Ensure discharge date defaults to now if omitted
                if (adm.Discharge_Date__c == null) {
                    adm.Discharge_Date__c = System.now();
                }

                // Ensure clinical documentation defaults
                if (String.isBlank(adm.Discharge_Summary__c)) {
                    adm.Discharge_Summary__c = String.isNotBlank(adm.Reason__c) ? adm.Reason__c : 'Clinical discharge completed.';
                }
                if (String.isBlank(adm.Discharge_Disposition__c)) {
                    adm.Discharge_Disposition__c = 'Home';
                }
                if (adm.Discharging_Doctor__c == null) {
                    adm.Discharging_Doctor__c = adm.Attending_Doctor__c != null ? adm.Attending_Doctor__c : adm.Doctor__c;
                }
            }
        }
    }

    /**
     * Synchronizes Contact__c/Patient__c and Attending_Doctor__c/Doctor__c aliases and defaults.
     */
    private void syncAliasesAndDefaults(List<Admission__c> records) {
        for (Admission__c adm : records) {
            if (adm.Contact__c != null && adm.Patient__c == null) {
                adm.Patient__c = adm.Contact__c;
            } else if (adm.Patient__c != null && adm.Contact__c == null) {
                adm.Contact__c = adm.Patient__c;
            }

            if (adm.Admitting_Doctor__c != null && adm.Attending_Doctor__c == null) {
                adm.Attending_Doctor__c = adm.Admitting_Doctor__c;
            } else if (adm.Attending_Doctor__c != null && adm.Admitting_Doctor__c == null) {
                adm.Admitting_Doctor__c = adm.Attending_Doctor__c;
            }

            if (adm.Attending_Doctor__c != null && adm.Doctor__c == null) {
                adm.Doctor__c = adm.Attending_Doctor__c;
            } else if (adm.Doctor__c != null && adm.Attending_Doctor__c == null) {
                adm.Attending_Doctor__c = adm.Doctor__c;
            }

            if (adm.Status__c == null) {
                adm.Status__c = 'Admitted';
            }

            if (adm.Admission_Date__c == null) {
                adm.Admission_Date__c = System.now();
            }
        }
    }

    /**
     * Validates that required clinical and bed identifiers are supplied.
     */
    private void validateRequiredFields(List<Admission__c> records) {
        for (Admission__c adm : records) {
            if (adm.Contact__c == null && adm.Patient__c == null) {
                adm.addError('A patient (Contact) is required for admission.');
            }
            if (adm.Bed__c == null) {
                adm.addError('A bed is required for admission.');
            }
            if (adm.Attending_Doctor__c == null && adm.Doctor__c == null && adm.Admitting_Doctor__c == null) {
                adm.addError('An attending doctor is required for admission.');
            }
            if (adm.Admission_Date__c == null) {
                adm.addError('Admission date and time is required.');
            }
        }
    }

    /**
     * Prevents multiple admissions in the same transaction from claiming the same bed.
     */
    private void validateBatchUniqueness(List<Admission__c> records) {
        Set<Id> activeBedsInBatch = new Set<Id>();
        for (Admission__c adm : records) {
            if (adm.Bed__c != null && ACTIVE_STATUSES.contains(adm.Status__c)) {
                if (activeBedsInBatch.contains(adm.Bed__c)) {
                    adm.addError('Duplicate active admission in batch: Cannot allocate Bed ' + adm.Bed__c + ' multiple times simultaneously.');
                } else {
                    activeBedsInBatch.add(adm.Bed__c);
                }
            }
        }
    }

    /**
     * Queries database to ensure no other active admission exists for the requested bed.
     */
    private void validateNoExistingActiveAdmissions(List<Admission__c> records, Map<Id, Admission__c> oldMap) {
        Set<Id> bedIds = new Set<Id>();
        for (Admission__c adm : records) {
            if (adm.Bed__c != null && ACTIVE_STATUSES.contains(adm.Status__c)) {
                bedIds.add(adm.Bed__c);
            }
        }

        if (bedIds.isEmpty()) {
            return;
        }

        Set<Id> recordIds = oldMap != null ? oldMap.keySet() : new Set<Id>();
        List<Admission__c> existingActive = [
            SELECT Id, Bed__c, Name
            FROM Admission__c
            WHERE Bed__c IN :bedIds
              AND Status__c IN :ACTIVE_STATUSES
              AND Id NOT IN :recordIds
        ];

        Map<Id, Admission__c> bedToActiveAdm = new Map<Id, Admission__c>();
        for (Admission__c act : existingActive) {
            bedToActiveAdm.put(act.Bed__c, act);
        }

        for (Admission__c adm : records) {
            if (adm.Bed__c != null && ACTIVE_STATUSES.contains(adm.Status__c) && bedToActiveAdm.containsKey(adm.Bed__c)) {
                adm.addError('This bed already has an active admission (' + bedToActiveAdm.get(adm.Bed__c).Name + '). Duplicate allocation rejected.');
            }
        }
    }

    /**
     * Direct DML verification: confirms bed is Available and Ward is active.
     */
    private void validateBedAndWardPreconditions(List<Admission__c> records) {
        Set<Id> bedIds = new Set<Id>();
        for (Admission__c adm : records) {
            if (adm.Bed__c != null && ACTIVE_STATUSES.contains(adm.Status__c)) {
                bedIds.add(adm.Bed__c);
            }
        }

        if (bedIds.isEmpty()) {
            return;
        }

        Map<Id, Bed__c> beds = new Map<Id, Bed__c>([
            SELECT Id, Name, Status__c, Ward__r.Name, Ward__r.Is_Active__c
            FROM Bed__c
            WHERE Id IN :bedIds
        ]);

        for (Admission__c adm : records) {
            if (adm.Bed__c != null && ACTIVE_STATUSES.contains(adm.Status__c)) {
                Bed__c bed = beds.get(adm.Bed__c);
                if (bed == null) {
                    adm.addError('Specified bed does not exist.');
                    continue;
                }
                if (bed.Status__c != 'Available') {
                    if (String.isNotBlank(adm.Admission_Code__c) && bed.Status__c == 'Occupied') {
                        // Permitted: Initial data migration / pre-seeded bed allocation matching external admission
                    } else {
                        adm.addError('Bed ' + bed.Name + ' is not available for admission. Current status: ' + bed.Status__c);
                    }
                }
                if (bed.Ward__r == null || !bed.Ward__r.Is_Active__c) {
                    adm.addError('Cannot admit patient: Ward for bed ' + bed.Name + ' is inactive.');
                }
            }
        }
    }
}
