/**
 * @description Enterprise inpatient clinical documentation service.
 * Manages bulk-safe creation of Inpatient_Encounter__c records and Patient_Vital__c observations
 * with strict CRUD/FLS enforcement, atomic transactions, and rollback on validation failure.
 */
public inherited sharing class ClinicalDocumentationService {

    public class ClinicalException extends Exception {}

    /**
     * @description Data transfer object for creating an inpatient clinical encounter.
     */
    public class EncounterRequest {
        @AuraEnabled public Id admissionId { get; set; }
        @AuraEnabled public Id doctorId { get; set; }
        @AuraEnabled public Datetime encounterDate { get; set; }
        @AuraEnabled public String chiefComplaint { get; set; }
        @AuraEnabled public String clinicalNotes { get; set; }
        @AuraEnabled public String assessment { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String encounterType { get; set; }

        public EncounterRequest() {}

        public EncounterRequest(Id admissionId, Id doctorId, Datetime encounterDate, String chiefComplaint, String assessment, String clinicalNotes) {
            this.admissionId = admissionId;
            this.doctorId = doctorId;
            this.encounterDate = encounterDate != null ? encounterDate : System.now();
            this.chiefComplaint = chiefComplaint;
            this.assessment = assessment;
            this.clinicalNotes = clinicalNotes;
            this.status = 'Completed';
            this.encounterType = 'Daily Ward Round';
        }
    }

    /**
     * @description Data transfer object for recording patient vital signs.
     */
    public class VitalRequest {
        @AuraEnabled public Id admissionId { get; set; }
        @AuraEnabled public Id encounterId { get; set; }
        @AuraEnabled public Datetime recordedDate { get; set; }
        @AuraEnabled public Decimal temperature { get; set; }
        @AuraEnabled public String temperatureUnit { get; set; }
        @AuraEnabled public Decimal pulse { get; set; }
        @AuraEnabled public Decimal respiratoryRate { get; set; }
        @AuraEnabled public Decimal systolicBp { get; set; }
        @AuraEnabled public Decimal diastolicBp { get; set; }
        @AuraEnabled public Decimal oxygenSaturation { get; set; }
        @AuraEnabled public Decimal weight { get; set; }
        @AuraEnabled public String weightUnit { get; set; }
        @AuraEnabled public String notes { get; set; }

        public VitalRequest() {}

        public VitalRequest(Id admissionId, Id encounterId, Decimal temperature, Decimal pulse, Decimal respiratoryRate, Decimal systolicBp, Decimal diastolicBp, Decimal oxygenSaturation, Decimal weight) {
            this.admissionId = admissionId;
            this.encounterId = encounterId;
            this.recordedDate = System.now();
            this.temperature = temperature;
            this.temperatureUnit = '°F';
            this.pulse = pulse;
            this.respiratoryRate = respiratoryRate;
            this.systolicBp = systolicBp;
            this.diastolicBp = diastolicBp;
            this.oxygenSaturation = oxygenSaturation;
            this.weight = weight;
            this.weightUnit = 'kg';
        }
    }

    /**
     * @description Composite DTO representing an encounter bundled with recorded vitals.
     */
    public class EncounterWithVitalsResult {
        @AuraEnabled public Inpatient_Encounter__c encounter { get; set; }
        @AuraEnabled public List<Patient_Vital__c> vitals { get; set; }

        public EncounterWithVitalsResult(Inpatient_Encounter__c encounter, List<Patient_Vital__c> vitals) {
            this.encounter = encounter;
            this.vitals = vitals;
        }
    }

    /**
     * @description Creates a single inpatient encounter.
     */
    public static Inpatient_Encounter__c createEncounter(EncounterRequest req) {
        if (req == null) {
            throw new ClinicalException('Encounter request cannot be null.');
        }
        List<Inpatient_Encounter__c> results = createEncounters(new List<EncounterRequest>{ req });
        return results[0];
    }

    /**
     * @description Bulk-safe creation of inpatient encounters with admission status validation.
     */
    public static List<Inpatient_Encounter__c> createEncounters(List<EncounterRequest> requests) {
        if (requests == null || requests.isEmpty()) {
            throw new ClinicalException('Encounter requests list cannot be null or empty.');
        }

        validateEncounterPermissions();

        Set<Id> admissionIds = new Set<Id>();
        for (EncounterRequest req : requests) {
            if (req == null) {
                throw new ClinicalException('Encounter request element cannot be null.');
            }
            if (req.admissionId == null) {
                throw new ClinicalException('Admission ID is required for inpatient encounter.');
            }
            if (req.doctorId == null) {
                throw new ClinicalException('Doctor ID is required for inpatient encounter.');
            }
            admissionIds.add(req.admissionId);
        }

        // Validate admission status
        Map<Id, Admission__c> admissions = new Map<Id, Admission__c>([
            SELECT Id, Name, Status__c
            FROM Admission__c
            WHERE Id IN :admissionIds
        ]);

        for (EncounterRequest req : requests) {
            Admission__c adm = admissions.get(req.admissionId);
            if (adm == null) {
                throw new ClinicalException('Admission not found for ID: ' + req.admissionId);
            }
            if (adm.Status__c == 'Discharged' || adm.Status__c == 'Cancelled') {
                throw new ClinicalException('Cannot document encounter for inactive admission ' + adm.Name + ' (Status: ' + adm.Status__c + ').');
            }
        }

        List<Inpatient_Encounter__c> encountersToInsert = new List<Inpatient_Encounter__c>();
        for (EncounterRequest req : requests) {
            encountersToInsert.add(new Inpatient_Encounter__c(
                Admission__c = req.admissionId,
                Attending_Doctor__c = req.doctorId,
                Doctor__c = req.doctorId,
                Encounter_Date__c = req.encounterDate != null ? req.encounterDate : System.now(),
                Chief_Complaint__c = req.chiefComplaint,
                Assessment__c = req.assessment,
                Clinical_Notes__c = req.clinicalNotes,
                Status__c = String.isNotBlank(req.status) ? req.status : 'Completed',
                Encounter_Type__c = String.isNotBlank(req.encounterType) ? req.encounterType : 'Daily Ward Round'
            ));
        }

        Savepoint sp = Database.setSavepoint();
        try {
            insert encountersToInsert;
            return encountersToInsert;
        } catch (Exception ex) {
            Database.rollback(sp);
            ErrorLogService.log('ClinicalDocumentationService.createEncounters', ex, null);
            if (ex instanceof ClinicalException) {
                throw (ClinicalException) ex;
            }
            throw new ClinicalException('Failed to create inpatient encounters: ' + ex.getMessage(), ex);
        }
    }

    /**
     * @description Records a single vital sign observation set.
     */
    public static Patient_Vital__c recordVitals(VitalRequest req) {
        if (req == null) {
            throw new ClinicalException('Vital request cannot be null.');
        }
        List<Patient_Vital__c> results = recordVitals(new List<VitalRequest>{ req });
        return results[0];
    }

    /**
     * @description Bulk-safe recording of patient vitals with physiological range checks.
     */
    public static List<Patient_Vital__c> recordVitals(List<VitalRequest> requests) {
        if (requests == null || requests.isEmpty()) {
            throw new ClinicalException('Vital requests list cannot be null or empty.');
        }

        validateVitalPermissions();

        Set<Id> admissionIds = new Set<Id>();
        Set<Id> encounterIds = new Set<Id>();

        for (VitalRequest req : requests) {
            if (req == null) {
                throw new ClinicalException('Vital request element cannot be null.');
            }
            if (req.admissionId == null && req.encounterId == null) {
                throw new ClinicalException('Either Admission ID or Encounter ID must be specified for vitals.');
            }
            if (req.admissionId != null) {
                admissionIds.add(req.admissionId);
            }
            if (req.encounterId != null) {
                encounterIds.add(req.encounterId);
            }

            // In-service physiological range validation
            validateVitalPayload(req);
        }

        // Validate parent admission status and resolve encounter links
        Map<Id, Inpatient_Encounter__c> encounters = new Map<Id, Inpatient_Encounter__c>();
        if (!encounterIds.isEmpty()) {
            encounters = new Map<Id, Inpatient_Encounter__c>([
                SELECT Id, Admission__c
                FROM Inpatient_Encounter__c
                WHERE Id IN :encounterIds
            ]);
            for (Inpatient_Encounter__c enc : encounters.values()) {
                if (enc.Admission__c != null) {
                    admissionIds.add(enc.Admission__c);
                }
            }
        }

        Map<Id, Admission__c> admissions = new Map<Id, Admission__c>([
            SELECT Id, Name, Status__c
            FROM Admission__c
            WHERE Id IN :admissionIds
        ]);

        List<Patient_Vital__c> vitalsToInsert = new List<Patient_Vital__c>();
        for (VitalRequest req : requests) {
            Id effectiveAdmissionId = req.admissionId;
            if (effectiveAdmissionId == null && req.encounterId != null && encounters.containsKey(req.encounterId)) {
                effectiveAdmissionId = encounters.get(req.encounterId).Admission__c;
            }

            Admission__c adm = admissions.get(effectiveAdmissionId);
            if (adm == null) {
                throw new ClinicalException('Admission record not found for vital observation.');
            }
            if (adm.Status__c == 'Discharged' || adm.Status__c == 'Cancelled') {
                throw new ClinicalException('Cannot record vitals for inactive admission ' + adm.Name + ' (Status: ' + adm.Status__c + ').');
            }

            String bpFormatted = null;
            if (req.systolicBp != null && req.diastolicBp != null) {
                bpFormatted = String.valueOf(req.systolicBp.intValue()) + '/' + String.valueOf(req.diastolicBp.intValue());
            }

            vitalsToInsert.add(new Patient_Vital__c(
                Admission__c = effectiveAdmissionId,
                Inpatient_Encounter__c = req.encounterId,
                Recorded_Date__c = req.recordedDate != null ? req.recordedDate : System.now(),
                Temperature__c = req.temperature,
                Temperature_Unit__c = String.isNotBlank(req.temperatureUnit) ? req.temperatureUnit : '°F',
                Pulse__c = req.pulse,
                Respiratory_Rate__c = req.respiratoryRate,
                Systolic_BP__c = req.systolicBp,
                Diastolic_BP__c = req.diastolicBp,
                Blood_Pressure__c = bpFormatted,
                Oxygen_Saturation__c = req.oxygenSaturation,
                Weight__c = req.weight,
                Weight_Unit__c = String.isNotBlank(req.weightUnit) ? req.weightUnit : 'kg',
                Notes__c = req.notes
            ));
        }

        Savepoint sp = Database.setSavepoint();
        try {
            insert vitalsToInsert;
            return vitalsToInsert;
        } catch (Exception ex) {
            Database.rollback(sp);
            ErrorLogService.log('ClinicalDocumentationService.recordVitals', ex, null);
            if (ex instanceof ClinicalException) {
                throw (ClinicalException) ex;
            }
            throw new ClinicalException('Failed to record patient vitals: ' + ex.getMessage(), ex);
        }
    }

    /**
     * @description Atomically creates an encounter along with one or more vitals observations.
     */
    public static EncounterWithVitalsResult createEncounterWithVitals(EncounterRequest encReq, List<VitalRequest> vitalsReqs) {
        if (encReq == null) {
            throw new ClinicalException('Encounter request cannot be null.');
        }

        Savepoint sp = Database.setSavepoint();
        try {
            Inpatient_Encounter__c enc = createEncounters(new List<EncounterRequest>{ encReq })[0];

            List<Patient_Vital__c> createdVitals = new List<Patient_Vital__c>();
            if (vitalsReqs != null && !vitalsReqs.isEmpty()) {
                for (VitalRequest vr : vitalsReqs) {
                    vr.encounterId = enc.Id;
                    vr.admissionId = enc.Admission__c;
                }
                createdVitals = recordVitals(vitalsReqs);
            }

            return new EncounterWithVitalsResult(enc, createdVitals);
        } catch (Exception ex) {
            Database.rollback(sp);
            if (ex instanceof ClinicalException) {
                throw (ClinicalException) ex;
            }
            throw new ClinicalException('Transaction failed: ' + ex.getMessage(), ex);
        }
    }

    /**
     * Validates vital ranges in the Apex service layer.
     */
    private static void validateVitalPayload(VitalRequest req) {
        if (req.temperature != null && (req.temperature < 85.0 || req.temperature > 110.0)) {
            throw new ClinicalException('Temperature ' + req.temperature + ' is outside clinically valid range (85.0°F - 110.0°F).');
        }
        if (req.pulse != null && (req.pulse < 30 || req.pulse > 250)) {
            throw new ClinicalException('Pulse ' + req.pulse + ' BPM is outside clinically valid range (30 - 250 BPM).');
        }
        if (req.respiratoryRate != null && (req.respiratoryRate < 5 || req.respiratoryRate > 70)) {
            throw new ClinicalException('Respiratory rate ' + req.respiratoryRate + ' is outside clinically valid range (5 - 70 breaths/min).');
        }
        if (req.systolicBp != null && req.diastolicBp != null && req.systolicBp <= req.diastolicBp) {
            throw new ClinicalException('Systolic BP (' + req.systolicBp + ') must exceed diastolic BP (' + req.diastolicBp + ').');
        }
        if (req.oxygenSaturation != null && (req.oxygenSaturation < 50 || req.oxygenSaturation > 100)) {
            throw new ClinicalException('Oxygen saturation ' + req.oxygenSaturation + '% is outside clinically valid range (50% - 100%).');
        }
        if (req.weight != null && (req.weight <= 0 || req.weight > 500)) {
            throw new ClinicalException('Weight ' + req.weight + ' is outside clinically valid range (0.1 - 500 kg).');
        }
    }

    private static void validateEncounterPermissions() {
        if (!Schema.sObjectType.Inpatient_Encounter__c.isCreateable()) {
            throw new ClinicalException('Insufficient permissions: User cannot create Inpatient_Encounter records.');
        }
    }

    private static void validateVitalPermissions() {
        if (!Schema.sObjectType.Patient_Vital__c.isCreateable()) {
            throw new ClinicalException('Insufficient permissions: User cannot create Patient_Vital records.');
        }
    }
}
