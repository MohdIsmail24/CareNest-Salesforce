/**
 * @description Enterprise inpatient admission and discharge service.
 * Implements bulk-safe, concurrency-controlled bed allocation and release with pessimistic
 * row locking (FOR UPDATE), atomic transaction boundaries, and automatic rollback on failure.
 */
public inherited sharing class AdmissionService {

    public class AdmissionException extends Exception {}

    /**
     * @description Data transfer object representing an inpatient admission request.
     */
    public class AdmissionRequest {
        @AuraEnabled public Id patientId { get; set; }
        @AuraEnabled public Id bedId { get; set; }
        @AuraEnabled public Id doctorId { get; set; }
        @AuraEnabled public Datetime admissionDate { get; set; }
        @AuraEnabled public String reason { get; set; }
        @AuraEnabled public Id appointmentId { get; set; }

        public AdmissionRequest() {}

        public AdmissionRequest(Id patientId, Id bedId, Id doctorId, Datetime admissionDate, String reason, Id appointmentId) {
            this.patientId = patientId;
            this.bedId = bedId;
            this.doctorId = doctorId;
            this.admissionDate = admissionDate != null ? admissionDate : System.now();
            this.reason = reason;
            this.appointmentId = appointmentId;
        }
    }

    /**
     * @description Data transfer object representing an inpatient discharge request.
     */
    public class DischargeRequest {
        @AuraEnabled public Id admissionId { get; set; }
        @AuraEnabled public Datetime dischargeDate { get; set; }
        @AuraEnabled public String dischargeSummary { get; set; }
        @AuraEnabled public String dischargeDisposition { get; set; }
        @AuraEnabled public Id dischargingDoctorId { get; set; }

        public DischargeRequest() {}

        public DischargeRequest(Id admissionId, Datetime dischargeDate, String dischargeSummary, String dischargeDisposition, Id dischargingDoctorId) {
            this.admissionId = admissionId;
            this.dischargeDate = dischargeDate != null ? dischargeDate : System.now();
            this.dischargeSummary = dischargeSummary;
            this.dischargeDisposition = String.isNotBlank(dischargeDisposition) ? dischargeDisposition : 'Home';
            this.dischargingDoctorId = dischargingDoctorId;
        }

        public DischargeRequest(Id admissionId, String dischargeSummary) {
            this(admissionId, System.now(), dischargeSummary, 'Home', null);
        }
    }

    /**
     * @description Admits a single patient to an available bed.
     * @param req AdmissionRequest DTO
     * @return Created Admission__c record
     */
    public static Admission__c admitPatient(AdmissionRequest req) {
        if (req == null) {
            throw new AdmissionException('Admission request cannot be null.');
        }
        List<Admission__c> results = admitPatients(new List<AdmissionRequest>{ req });
        return results[0];
    }

    /**
     * @description Convenience overload for admitting a single patient.
     */
    public static Admission__c admitPatient(Id patientId, Id bedId, Id doctorId, Datetime admissionDate, String reason, Id appointmentId) {
        return admitPatient(new AdmissionRequest(patientId, bedId, doctorId, admissionDate, reason, appointmentId));
    }

    /**
     * @description SObject-level overload for admitting patients.
     * @param rawAdmissions List of Admission__c records with populated patient, bed, doctor, and date.
     * @return List of created Admission__c records
     */
    public static List<Admission__c> admitPatients(List<Admission__c> rawAdmissions) {
        if (rawAdmissions == null || rawAdmissions.isEmpty()) {
            throw new AdmissionException('Admission records list cannot be null or empty.');
        }

        List<AdmissionRequest> requests = new List<AdmissionRequest>();
        for (Admission__c adm : rawAdmissions) {
            if (adm == null) {
                throw new AdmissionException('Admission record element cannot be null.');
            }
            Id patId = adm.Contact__c != null ? adm.Contact__c : adm.Patient__c;
            Id docId = adm.Attending_Doctor__c != null ? adm.Attending_Doctor__c : adm.Doctor__c;
            requests.add(new AdmissionRequest(patId, adm.Bed__c, docId, adm.Admission_Date__c, adm.Reason__c, adm.Appointment__c));
        }
        return admitPatients(requests);
    }

    /**
     * @description Bulk-safe, atomic inpatient admission processor.
     * Acquires pessimistic row locks on Bed__c records (FOR UPDATE) to prevent concurrency races.
     * Validates bed availability, active ward status, and ensures no duplicate active admissions.
     * Updates Bed status to Occupied and inserts Admission__c records atomically; rolls back on any error.
     * @param requests List of AdmissionRequest DTOs
     * @return List of created Admission__c records
     */
    public static List<Admission__c> admitPatients(List<AdmissionRequest> requests) {
        if (requests == null || requests.isEmpty()) {
            throw new AdmissionException('Admission requests list cannot be null or empty.');
        }

        validatePermissions();

        // Validate individual requests and detect duplicate beds in the current batch
        Set<Id> requestedBedIds = new Set<Id>();
        for (AdmissionRequest req : requests) {
            if (req == null) {
                throw new AdmissionException('Admission request element cannot be null.');
            }
            if (req.patientId == null) {
                throw new AdmissionException('Patient ID is required for admission.');
            }
            if (req.bedId == null) {
                throw new AdmissionException('Bed ID is required for admission.');
            }
            if (req.doctorId == null) {
                throw new AdmissionException('Attending Doctor ID is required for admission.');
            }
            if (requestedBedIds.contains(req.bedId)) {
                throw new AdmissionException('Duplicate bed allocation in request batch: Bed ' + req.bedId + ' is requested more than once in the same transaction.');
            }
            requestedBedIds.add(req.bedId);
        }

        // Establish transaction boundary savepoint for atomic rollback
        Savepoint sp = Database.setSavepoint();

        try {
            // 1. Acquire pessimistic row locks on Bed__c records to serialize concurrent allocation requests
            Map<Id, Bed__c> lockedBeds = new Map<Id, Bed__c>([
                SELECT Id, Name, Status__c, Ward__c, Ward__r.Name, Ward__r.Is_Active__c
                FROM Bed__c
                WHERE Id IN :requestedBedIds
                FOR UPDATE
            ]);

            // 2. Validate bed existence, operational status, and parent ward active status
            for (AdmissionRequest req : requests) {
                Bed__c bed = lockedBeds.get(req.bedId);
                if (bed == null) {
                    throw new AdmissionException('Bed with ID ' + req.bedId + ' was not found.');
                }
                if (bed.Status__c != 'Available') {
                    throw new AdmissionException('Bed ' + bed.Name + ' is not available for admission (Current status: ' + bed.Status__c + ').');
                }
                if (bed.Ward__r == null || !bed.Ward__r.Is_Active__c) {
                    throw new AdmissionException('Cannot admit patient: Ward for bed ' + bed.Name + ' is inactive.');
                }
            }

            // 3. Verify no concurrent active admission already exists in database for these beds
            List<Admission__c> existingActiveAdmissions = [
                SELECT Id, Name, Bed__c, Status__c
                FROM Admission__c
                WHERE Bed__c IN :requestedBedIds
                  AND Status__c IN ('Admitted', 'Discharge Pending')
            ];
            if (!existingActiveAdmissions.isEmpty()) {
                throw new AdmissionException('Bed already has an active admission (' + existingActiveAdmissions[0].Name + '). Duplicate allocation rejected.');
            }

            // 4. Construct bed status updates (Available -> Occupied)
            List<Bed__c> bedsToUpdate = new List<Bed__c>();
            for (Id bId : requestedBedIds) {
                bedsToUpdate.add(new Bed__c(
                    Id = bId,
                    Status__c = 'Occupied'
                ));
            }

            // 5. Construct Admission__c records
            List<Admission__c> admissionsToInsert = new List<Admission__c>();
            for (AdmissionRequest req : requests) {
                Admission__c adm = new Admission__c(
                    Contact__c = req.patientId,
                    Patient__c = req.patientId,
                    Bed__c = req.bedId,
                    Attending_Doctor__c = req.doctorId,
                    Doctor__c = req.doctorId,
                    Admission_Date__c = req.admissionDate != null ? req.admissionDate : System.now(),
                    Reason__c = req.reason,
                    Appointment__c = req.appointmentId,
                    Status__c = 'Admitted'
                );
                admissionsToInsert.add(adm);
            }

            // 6. Execute atomic updates
            AdmissionTriggerHandler.isServiceManagingBedUpdate = true;
            try {
                update bedsToUpdate;
                insert admissionsToInsert;
            } finally {
                AdmissionTriggerHandler.isServiceManagingBedUpdate = false;
            }

            return admissionsToInsert;

        } catch (Exception ex) {
            Database.rollback(sp);
            ErrorLogService.log('AdmissionService.admitPatients', ex, null);
            if (ex instanceof AdmissionException) {
                throw (AdmissionException) ex;
            }
            throw new AdmissionException('Admission transaction failed: ' + ex.getMessage(), ex);
        }
    }

    /**
     * @description Authoritative method to discharge a single patient using a DischargeRequest DTO.
     * @param req DischargeRequest DTO
     * @return Updated Admission__c record
     */
    public static Admission__c dischargePatient(DischargeRequest req) {
        if (req == null) {
            throw new AdmissionException('Discharge request cannot be null.');
        }
        List<Admission__c> results = dischargePatients(new List<DischargeRequest>{ req });
        return results[0];
    }

    /**
     * @description Backward-compatible convenience overload for single patient discharge.
     * @param admissionId ID of the Admission__c record
     * @param dischargeDate Optional discharge timestamp
     * @return Updated Admission__c record
     */
    public static Admission__c dischargePatient(Id admissionId, Datetime dischargeDate) {
        if (admissionId == null) {
            throw new AdmissionException('Admission ID cannot be null.');
        }
        return dischargePatient(new DischargeRequest(admissionId, dischargeDate, 'Patient discharged in stable condition.', 'Home', null));
    }

    /**
     * @description Convenience overload accepting full parameters.
     */
    public static Admission__c dischargePatient(Id admissionId, Datetime dischargeDate, String dischargeSummary, String dischargeDisposition, Id dischargingDoctorId) {
        return dischargePatient(new DischargeRequest(admissionId, dischargeDate, dischargeSummary, dischargeDisposition, dischargingDoctorId));
    }

    /**
     * @description Transitions an admission to 'Discharge Pending'.
     * @param admissionId ID of the Admission__c record
     * @return Updated Admission__c record
     */
    public static Admission__c markDischargePending(Id admissionId) {
        if (admissionId == null) {
            throw new AdmissionException('Admission ID cannot be null.');
        }

        validateDischargePendingPermissions();
        Savepoint sp = Database.setSavepoint();
        try {
            Admission__c adm = [
                SELECT Id, Name, Status__c
                FROM Admission__c
                WHERE Id = :admissionId
                FOR UPDATE
            ];

            if (adm.Status__c != 'Admitted') {
                throw new AdmissionException('Only active Admitted patients can be placed in Discharge Pending (Current status: ' + adm.Status__c + ').');
            }

            adm.Status__c = 'Discharge Pending';
            new DischargeDmlHelper().executePendingDml(adm);
            return adm;
        } catch (Exception ex) {
            Database.rollback(sp);
            ErrorLogService.log('AdmissionService.requestDischarge', ex, admissionId);
            if (ex instanceof AdmissionException) {
                throw (AdmissionException) ex;
            }
            throw new AdmissionException('Failed to set Discharge Pending: ' + ex.getMessage(), ex);
        }
    }

    /**
     * @description Authoritative, bulk-safe, concurrency-controlled inpatient discharge processor.
     * Acquires pessimistic row locks on Admission__c and Bed__c records (FOR UPDATE).
     * Validates active status (Admitted or Discharge Pending), prevents duplicate/repeated discharge,
     * requires valid discharge date and summary/reason, detects bed inconsistencies, ensures no other
     * active admission holds the bed, and atomically releases the bed to Available.
     * Rolls back all changes if any operation fails.
     * @param requests List of DischargeRequest DTOs
     * @return List of updated Admission__c records
     */
    public static List<Admission__c> dischargePatients(List<DischargeRequest> requests) {
        if (requests == null || requests.isEmpty()) {
            throw new AdmissionException('Discharge requests list cannot be null or empty.');
        }

        validateDischargePermissions();

        // 1. Validate individual requests and detect duplicate admissions in batch
        Set<Id> requestedAdmissionIds = new Set<Id>();
        for (DischargeRequest req : requests) {
            if (req == null) {
                throw new AdmissionException('Discharge request element cannot be null.');
            }
            if (req.admissionId == null) {
                throw new AdmissionException('Admission ID is required for discharge.');
            }
            if (requestedAdmissionIds.contains(req.admissionId)) {
                throw new AdmissionException('Duplicate discharge request in batch: Admission ' + req.admissionId + ' is requested more than once in the same transaction.');
            }
            requestedAdmissionIds.add(req.admissionId);
        }

        Savepoint sp = Database.setSavepoint();

        try {
            // 2. Lock Admission records (FOR UPDATE)
            Map<Id, Admission__c> lockedAdmissions = new Map<Id, Admission__c>([
                SELECT Id, Name, Bed__c, Status__c, Admission_Date__c, Discharge_Date__c,
                       Reason__c, Contact__c, Patient__c, Attending_Doctor__c, Doctor__c
                FROM Admission__c
                WHERE Id IN :requestedAdmissionIds
                FOR UPDATE
            ]);

            // 3. Validate admission existence and lifecycle states
            Set<Id> bedIdsToLock = new Set<Id>();
            for (DischargeRequest req : requests) {
                Admission__c adm = lockedAdmissions.get(req.admissionId);
                if (adm == null) {
                    throw new AdmissionException('Admission with ID ' + req.admissionId + ' was not found.');
                }
                if (adm.Status__c == 'Discharged') {
                    throw new AdmissionException('Admission ' + adm.Name + ' is already discharged. Repeated discharge processing rejected.');
                }
                if (adm.Status__c == 'Cancelled') {
                    throw new AdmissionException('Cannot discharge cancelled admission ' + adm.Name + '.');
                }
                if (adm.Status__c != 'Admitted' && adm.Status__c != 'Discharge Pending') {
                    throw new AdmissionException('Invalid admission status for discharge on ' + adm.Name + ' (Status: ' + adm.Status__c + ').');
                }

                Datetime effDischarge = req.dischargeDate != null ? req.dischargeDate : System.now();
                if (adm.Admission_Date__c != null && effDischarge < adm.Admission_Date__c) {
                    throw new AdmissionException('Discharge date cannot be earlier than admission date for admission ' + adm.Name + '.');
                }

                String effSummary = String.isNotBlank(req.dischargeSummary) ? req.dischargeSummary : adm.Reason__c;
                if (String.isBlank(effSummary)) {
                    throw new AdmissionException('Discharge summary or documented discharge reason is required for admission ' + adm.Name + '.');
                }

                if (adm.Bed__c == null) {
                    throw new AdmissionException('Inconsistent record state: Admission ' + adm.Name + ' has no assigned bed.');
                }
                bedIdsToLock.add(adm.Bed__c);
            }

            // 4. Lock Bed records (FOR UPDATE)
            Map<Id, Bed__c> lockedBeds = new Map<Id, Bed__c>([
                SELECT Id, Name, Status__c, Ward__c
                FROM Bed__c
                WHERE Id IN :bedIdsToLock
                FOR UPDATE
            ]);

            // 5. Verify bed status: Bed MUST be Occupied by this admission
            for (DischargeRequest req : requests) {
                Admission__c adm = lockedAdmissions.get(req.admissionId);
                Bed__c bed = lockedBeds.get(adm.Bed__c);
                if (bed == null) {
                    throw new AdmissionException('Assigned Bed with ID ' + adm.Bed__c + ' was not found for admission ' + adm.Name + '.');
                }
                if (bed.Status__c != 'Occupied') {
                    throw new AdmissionException('Inconsistent record state: Assigned Bed ' + bed.Name + ' is not currently Occupied (Current status: ' + bed.Status__c + '). Discharge cannot safely release bed.');
                }
            }

            // 6. Verify that NO OTHER active admission is assigned to any of these beds
            List<Admission__c> otherActiveAdmissions = [
                SELECT Id, Name, Bed__c
                FROM Admission__c
                WHERE Bed__c IN :bedIdsToLock
                  AND Status__c IN ('Admitted', 'Discharge Pending')
                  AND Id NOT IN :requestedAdmissionIds
            ];
            if (!otherActiveAdmissions.isEmpty()) {
                Admission__c other = otherActiveAdmissions[0];
                Bed__c confBed = lockedBeds.get(other.Bed__c);
                String bedName = confBed != null ? confBed.Name : String.valueOf(other.Bed__c);
                throw new AdmissionException('Bed conflict: Bed ' + bedName + ' is also associated with another active admission (' + other.Name + '). Discharge aborted to protect bed state.');
            }

            // 7. Prepare atomic updates
            List<Admission__c> admissionsToUpdate = new List<Admission__c>();
            Map<Id, Bed__c> bedsToUpdateMap = new Map<Id, Bed__c>();

            for (DischargeRequest req : requests) {
                Admission__c adm = lockedAdmissions.get(req.admissionId);
                Datetime effDischarge = req.dischargeDate != null ? req.dischargeDate : System.now();
                String effSummary = String.isNotBlank(req.dischargeSummary) ? req.dischargeSummary : adm.Reason__c;
                Id effDoctor = req.dischargingDoctorId != null ? req.dischargingDoctorId
                    : (adm.Attending_Doctor__c != null ? adm.Attending_Doctor__c : adm.Doctor__c);

                adm.Status__c = 'Discharged';
                adm.Discharge_Date__c = effDischarge;
                adm.Discharge_Summary__c = effSummary;
                adm.Discharge_Disposition__c = String.isNotBlank(req.dischargeDisposition) ? req.dischargeDisposition : 'Home';
                adm.Discharging_Doctor__c = effDoctor;

                admissionsToUpdate.add(adm);

                Bed__c bed = lockedBeds.get(adm.Bed__c);
                bed.Status__c = 'Available';
                bedsToUpdateMap.put(bed.Id, bed);
            }

            // 8. Commit atomic changes
            AdmissionTriggerHandler.isServiceManagingBedUpdate = true;
            try {
                new DischargeDmlHelper().executeDischargeDml(admissionsToUpdate, bedsToUpdateMap.values());
            } finally {
                AdmissionTriggerHandler.isServiceManagingBedUpdate = false;
            }

            return admissionsToUpdate;

        } catch (Exception ex) {
            Database.rollback(sp);
            ErrorLogService.log('AdmissionService.dischargePatients', ex, null);
            if (ex instanceof AdmissionException) {
                throw (AdmissionException) ex;
            }
            throw new AdmissionException('Discharge transaction failed: ' + ex.getMessage(), ex);
        }
    }

    /**
     * @description Enforces CRUD authorizations for admission.
     */
    private static void validatePermissions() {
        if (!Schema.sObjectType.Admission__c.isCreateable()) {
            throw new AdmissionException('Insufficient permissions: User cannot create Admission records.');
        }
        if (!Schema.sObjectType.Bed__c.isUpdateable()) {
            throw new AdmissionException('Insufficient permissions: User cannot update Bed records.');
        }
    }

    /**
     * @description Enforces authorizations for clinical discharge.
     * Verifies that the user has update permissions on Admission__c as well as
     * field-level security on all clinical discharge fields.
     * Does NOT require general Bed__c edit permission, as bed release is managed
     * as an authorized system side-effect by DischargeDmlHelper.
     */
    private static void validateDischargePermissions() {
        if (!Schema.sObjectType.Admission__c.isUpdateable()) {
            throw new AdmissionException('Insufficient permissions: User cannot update Admission records.');
        }
        if (!Schema.sObjectType.Admission__c.fields.Discharge_Date__c.isUpdateable() ||
            !Schema.sObjectType.Admission__c.fields.Discharge_Summary__c.isUpdateable() ||
            !Schema.sObjectType.Admission__c.fields.Discharge_Disposition__c.isUpdateable() ||
            !Schema.sObjectType.Admission__c.fields.Discharging_Doctor__c.isUpdateable() ||
            !Schema.sObjectType.Admission__c.fields.Status__c.isUpdateable()) {
            throw new AdmissionException('Insufficient permissions: User lacks required field-level security on discharge fields.');
        }
    }

    /**
     * @description Enforces authorizations for setting Discharge Pending status.
     */
    private static void validateDischargePendingPermissions() {
        if (!Schema.sObjectType.Admission__c.isUpdateable() ||
            !Schema.sObjectType.Admission__c.fields.Status__c.isUpdateable()) {
            throw new AdmissionException('Insufficient permissions: User cannot update Admission status.');
        }
    }

    /**
     * @description Elevated system context helper to execute discharge DML atomically.
     * Discharge authorization and FLS are enforced prior to invocation.
     * Encapsulating updates in system context ensures that:
     * 1. Public Read-Only OWD on Admission__c does not prevent authorized clinicians from updating admissions created by other staff.
     * 2. ControlledByParent OWD on Bed__c does not require granting clinicians general Bed Edit permissions.
     */
    private without sharing class DischargeDmlHelper {
        private void executeDischargeDml(List<Admission__c> admissions, List<Bed__c> beds) {
            update admissions;
            update beds;
        }

        private void executePendingDml(Admission__c adm) {
            update adm;
        }
    }
}
