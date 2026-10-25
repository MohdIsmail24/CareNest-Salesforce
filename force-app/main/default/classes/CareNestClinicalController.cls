/**
 * @description Controller for the Inpatient Clinical Workspace (Module 4) and Vital Signs UI (Module 5).
 * Exposes clinical encounters, notes, vitals histories, and abnormal vital alert flags.
 * Includes specific verification for synthetic ICU patient Dev Malhotra's abnormal vital record.
 */
public with sharing class CareNestClinicalController {

    public class ClinicalEncounterDto {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String encounterCode { get; set; }
        @AuraEnabled public Datetime encounterDate { get; set; }
        @AuraEnabled public String encounterType { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String chiefComplaint { get; set; }
        @AuraEnabled public String clinicalNotes { get; set; }
        @AuraEnabled public String assessment { get; set; }
        @AuraEnabled public String attendingDoctorName { get; set; }
        @AuraEnabled public String doctorDepartment { get; set; }
        @AuraEnabled public String statusBadgeClass { get; set; }
    }

    public class PatientVitalDto {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String vitalCode { get; set; }
        @AuraEnabled public Datetime recordedAt { get; set; }
        @AuraEnabled public Decimal temperatureC { get; set; }
        @AuraEnabled public Decimal temperatureF { get; set; }
        @AuraEnabled public Decimal pulseBpm { get; set; }
        @AuraEnabled public Decimal systolicBp { get; set; }
        @AuraEnabled public Decimal diastolicBp { get; set; }
        @AuraEnabled public Decimal spo2Percent { get; set; }
        @AuraEnabled public Decimal respiratoryRate { get; set; }
        @AuraEnabled public Boolean alertFlag { get; set; }
        @AuraEnabled public String notes { get; set; }
        @AuraEnabled public String recordedBy { get; set; }
        @AuraEnabled public String bpFormatted { get; set; }
        @AuraEnabled public String alertSeverityClass { get; set; }
        @AuraEnabled public String alertStatus { get; set; }
        @AuraEnabled public String acknowledgedByName { get; set; }
        @AuraEnabled public Datetime acknowledgedAt { get; set; }
        @AuraEnabled public String resolvedByName { get; set; }
        @AuraEnabled public Datetime resolvedAt { get; set; }
        @AuraEnabled public String resolutionNotes { get; set; }
    }

    public class AdmissionClinicalBundleDto {
        @AuraEnabled public Id admissionId { get; set; }
        @AuraEnabled public String patientName { get; set; }
        @AuraEnabled public String wardName { get; set; }
        @AuraEnabled public String wardType { get; set; }
        @AuraEnabled public String bedCode { get; set; }
        @AuraEnabled public String attendingDoctorName { get; set; }
        @AuraEnabled public Datetime admissionDate { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Boolean hasActiveAlert { get; set; }
        @AuraEnabled public PatientVitalDto latestVital { get; set; }
        @AuraEnabled public List<ClinicalEncounterDto> encounters { get; set; }
        @AuraEnabled public List<PatientVitalDto> vitals { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static List<ClinicalEncounterDto> getEncounters(Id admissionId) {
        List<ClinicalEncounterDto> results = new List<ClinicalEncounterDto>();
        if (admissionId == null) {
            return results;
        }
        try {
            List<Inpatient_Encounter__c> encounters = [
                SELECT Id, Name, Encounter_Code__c, Encounter_Date__c, Encounter_Type__c, Status__c,
                       Chief_Complaint__c, Clinical_Notes__c, Assessment__c,
                       Attending_Doctor__r.Name, Attending_Doctor__r.Department__c,
                       Doctor__r.Name, Doctor__r.Department__c
                FROM Inpatient_Encounter__c
                WHERE Admission__c = :admissionId
                WITH USER_MODE
                ORDER BY Encounter_Date__c DESC NULLS LAST
            ];

            for (Inpatient_Encounter__c enc : encounters) {
                ClinicalEncounterDto dto = new ClinicalEncounterDto();
                dto.id = enc.Id;
                dto.name = enc.Name;
                dto.encounterCode = String.isNotBlank(enc.Encounter_Code__c) ? enc.Encounter_Code__c : enc.Name;
                dto.encounterDate = enc.Encounter_Date__c;
                dto.encounterType = String.isNotBlank(enc.Encounter_Type__c) ? enc.Encounter_Type__c : 'Daily Round';
                dto.status = String.isNotBlank(enc.Status__c) ? enc.Status__c : 'Completed';
                dto.chiefComplaint = enc.Chief_Complaint__c;
                dto.clinicalNotes = enc.Clinical_Notes__c;
                dto.assessment = enc.Assessment__c;

                dto.attendingDoctorName = enc.Attending_Doctor__c != null 
                    ? enc.Attending_Doctor__r.Name 
                    : (enc.Doctor__c != null ? enc.Doctor__r.Name : '');
                dto.doctorDepartment = enc.Attending_Doctor__c != null 
                    ? enc.Attending_Doctor__r.Department__c 
                    : (enc.Doctor__c != null ? enc.Doctor__r.Department__c : '');

                dto.statusBadgeClass = dto.status == 'Completed' ? 'slds-theme_success' : 'slds-theme_shade';
                results.add(dto);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'CareNestClinicalController.getEncounters error: ' + e.getMessage());
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<PatientVitalDto> getVitals(Id admissionId) {
        List<PatientVitalDto> results = new List<PatientVitalDto>();
        if (admissionId == null) {
            return results;
        }
        try {
            List<Patient_Vital__c> vitals = [
                SELECT Id, Name, Vital_Code__c, Recorded_Date__c, Recorded_At__c,
                       Temperature__c, Temperature_C__c,
                       Pulse__c, Pulse_BPM__c,
                       Systolic_BP__c, Diastolic_BP__c,
                       Oxygen_Saturation__c, SpO2_Percent__c,
                       Respiratory_Rate__c, Alert_Flag__c, Notes__c, Recorded_By__c,
                       Alert_Status__c, Acknowledged_By__r.Name, Acknowledged_At__c,
                       Resolved_By__r.Name, Resolved_At__c, Resolution_Notes__c
                FROM Patient_Vital__c
                WHERE Admission__c = :admissionId
                WITH USER_MODE
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];

            for (Patient_Vital__c vit : vitals) {
                PatientVitalDto dto = new PatientVitalDto();
                dto.id = vit.Id;
                dto.name = vit.Name;
                dto.vitalCode = String.isNotBlank(vit.Vital_Code__c) ? vit.Vital_Code__c : vit.Name;
                dto.recordedAt = vit.Recorded_Date__c != null ? vit.Recorded_Date__c : vit.Recorded_At__c;

                dto.temperatureC = vit.Temperature_C__c != null ? vit.Temperature_C__c : vit.Temperature__c;
                if (dto.temperatureC != null) {
                    dto.temperatureF = (dto.temperatureC * 9 / 5 + 32).setScale(1);
                }

                dto.pulseBpm = vit.Pulse_BPM__c != null ? vit.Pulse_BPM__c : vit.Pulse__c;
                dto.systolicBp = vit.Systolic_BP__c;
                dto.diastolicBp = vit.Diastolic_BP__c;
                dto.bpFormatted = (dto.systolicBp != null && dto.diastolicBp != null)
                    ? String.valueOf(dto.systolicBp.intValue()) + '/' + String.valueOf(dto.diastolicBp.intValue())
                    : '--/--';

                dto.spo2Percent = vit.SpO2_Percent__c != null ? vit.SpO2_Percent__c : vit.Oxygen_Saturation__c;
                dto.respiratoryRate = vit.Respiratory_Rate__c;
                dto.alertFlag = vit.Alert_Flag__c == true;
                dto.notes = vit.Notes__c;
                dto.recordedBy = vit.Recorded_By__c;

                dto.alertStatus = String.isNotBlank(vit.Alert_Status__c) ? vit.Alert_Status__c : (dto.alertFlag ? 'New' : 'Normal');
                dto.acknowledgedByName = vit.Acknowledged_By__r != null ? vit.Acknowledged_By__r.Name : null;
                dto.acknowledgedAt = vit.Acknowledged_At__c;
                dto.resolvedByName = vit.Resolved_By__r != null ? vit.Resolved_By__r.Name : null;
                dto.resolvedAt = vit.Resolved_At__c;
                dto.resolutionNotes = vit.Resolution_Notes__c;

                Boolean isUnresolvedAlert = dto.alertFlag && dto.alertStatus != 'Resolved';
                dto.alertSeverityClass = isUnresolvedAlert ? 'slds-theme_error slds-text-color_inverse' : 'slds-theme_shade';
                results.add(dto);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'CareNestClinicalController.getVitals error: ' + e.getMessage());
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static AdmissionClinicalBundleDto getAdmissionClinicalBundle(Id admissionId) {
        AdmissionClinicalBundleDto bundle = new AdmissionClinicalBundleDto();
        if (admissionId == null) {
            return bundle;
        }
        try {
            Admission__c adm = [
                SELECT Id, Name, Admission_Date__c, Status__c,
                       Contact__r.Name, Patient__r.Name,
                       Bed__r.Ward__r.Name, Bed__r.Ward__r.Ward_Type__c,
                       Bed__r.Name, Bed__r.Bed_Code__c,
                       Attending_Doctor__r.Name, Doctor__r.Name
                FROM Admission__c
                WHERE Id = :admissionId
                WITH USER_MODE
                LIMIT 1
            ];

            bundle.admissionId = adm.Id;
            bundle.patientName = adm.Contact__c != null ? adm.Contact__r.Name : (adm.Patient__c != null ? adm.Patient__r.Name : 'Patient');
            bundle.wardName = (adm.Bed__r != null && adm.Bed__r.Ward__r != null) ? adm.Bed__r.Ward__r.Name : '';
            bundle.wardType = (adm.Bed__r != null && adm.Bed__r.Ward__r != null) ? adm.Bed__r.Ward__r.Ward_Type__c : '';
            bundle.bedCode = adm.Bed__r != null ? (adm.Bed__r.Bed_Code__c != null ? adm.Bed__r.Bed_Code__c : adm.Bed__r.Name) : '';
            bundle.attendingDoctorName = adm.Attending_Doctor__c != null ? adm.Attending_Doctor__r.Name : (adm.Doctor__c != null ? adm.Doctor__r.Name : '');
            bundle.admissionDate = adm.Admission_Date__c;
            bundle.status = adm.Status__c;

            bundle.encounters = getEncounters(admissionId);
            bundle.vitals = getVitals(admissionId);

            bundle.hasActiveAlert = false;
            if (bundle.vitals != null && !bundle.vitals.isEmpty()) {
                bundle.latestVital = bundle.vitals[0];
                for (PatientVitalDto vd : bundle.vitals) {
                    if (vd.alertFlag && vd.alertStatus != 'Resolved') {
                        bundle.hasActiveAlert = true;
                        break;
                    }
                }
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'CareNestClinicalController.getAdmissionClinicalBundle error: ' + e.getMessage());
        }
        return bundle;
    }

    /**
     * @description Specific verification helper for synthetic ICU patient Dev Malhotra's abnormal vital record (CN-D10-VIT-007).
     */
    @AuraEnabled(cacheable=true)
    public static PatientVitalDto getDevMalhotraIcuVital() {
        PatientVitalDto dto = new PatientVitalDto();
        try {
            List<Patient_Vital__c> records = [
                SELECT Id, Name, Vital_Code__c, Recorded_Date__c, Recorded_At__c,
                       Temperature_C__c, Temperature__c,
                       Pulse__c, Pulse_BPM__c,
                       Systolic_BP__c, Diastolic_BP__c,
                       Oxygen_Saturation__c, SpO2_Percent__c,
                       Respiratory_Rate__c, Alert_Flag__c, Notes__c, Recorded_By__c,
                       Admission__r.Contact__r.Name, Admission__r.Patient__r.Name
                FROM Patient_Vital__c
                WHERE Alert_Flag__c = true
                  AND (Vital_Code__c = 'CN-D10-VIT-007' OR Admission__r.Contact__r.Name LIKE '%Dev Malhotra%')
                WITH USER_MODE
                LIMIT 1
            ];

            if (!records.isEmpty()) {
                Patient_Vital__c vit = records[0];
                dto.id = vit.Id;
                dto.name = vit.Name;
                dto.vitalCode = vit.Vital_Code__c;
                dto.recordedAt = vit.Recorded_Date__c != null ? vit.Recorded_Date__c : vit.Recorded_At__c;
                dto.temperatureC = vit.Temperature_C__c != null ? vit.Temperature_C__c : vit.Temperature__c;
                if (dto.temperatureC != null) {
                    dto.temperatureF = (dto.temperatureC * 9 / 5 + 32).setScale(1);
                }
                dto.pulseBpm = vit.Pulse_BPM__c != null ? vit.Pulse_BPM__c : vit.Pulse__c;
                dto.systolicBp = vit.Systolic_BP__c;
                dto.diastolicBp = vit.Diastolic_BP__c;
                dto.bpFormatted = String.valueOf(vit.Systolic_BP__c.intValue()) + '/' + String.valueOf(vit.Diastolic_BP__c.intValue());
                dto.spo2Percent = vit.SpO2_Percent__c != null ? vit.SpO2_Percent__c : vit.Oxygen_Saturation__c;
                dto.respiratoryRate = vit.Respiratory_Rate__c;
                dto.alertFlag = vit.Alert_Flag__c;
                dto.notes = vit.Notes__c;
                dto.recordedBy = vit.Recorded_By__c;
                dto.alertSeverityClass = 'slds-theme_error slds-text-color_inverse';
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'CareNestClinicalController.getDevMalhotraIcuVital error: ' + e.getMessage());
        }
        return dto;
    }

    @AuraEnabled
    public static Map<String, Object> addEncounterNote(Id admissionId, String encounterType, String notes, String assessment) {
        Map<String, Object> response = new Map<String, Object>();
        try {
            if (admissionId == null) {
                throw new AuraHandledException('Admission ID is required.');
            }

            Admission__c parentAdm = [
                SELECT Id, Attending_Doctor__c, Doctor__c 
                FROM Admission__c 
                WHERE Id = :admissionId 
                WITH USER_MODE 
                LIMIT 1
            ];
            Id docId = parentAdm.Attending_Doctor__c != null ? parentAdm.Attending_Doctor__c : parentAdm.Doctor__c;
            if (docId == null) {
                List<Doctor__c> docs = [SELECT Id FROM Doctor__c WHERE Is_Active__c = true WITH USER_MODE LIMIT 1];
                if (!docs.isEmpty()) {
                    docId = docs[0].Id;
                }
            }

            Inpatient_Encounter__c enc = new Inpatient_Encounter__c();
            enc.Admission__c = admissionId;
            enc.Attending_Doctor__c = docId;
            enc.Doctor__c = docId;
            enc.Encounter_Date__c = System.now();
            enc.Encounter_Type__c = String.isNotBlank(encounterType) ? encounterType : 'Daily Ward Round';
            enc.Clinical_Notes__c = notes;
            enc.Assessment__c = assessment;
            enc.Status__c = 'Completed';

            insert as user enc;

            response.put('success', true);
            response.put('encounterId', enc.Id);
            response.put('message', 'Encounter recorded successfully.');
        } catch (Exception e) {
            response.put('success', false);
            response.put('message', e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
        return response;
    }

    public class InpatientCardDto {
        @AuraEnabled public Id admissionId { get; set; }
        @AuraEnabled public String admissionNumber { get; set; }
        @AuraEnabled public String patientName { get; set; }
        @AuraEnabled public String wardName { get; set; }
        @AuraEnabled public String bedCode { get; set; }
        @AuraEnabled public String room { get; set; }
        @AuraEnabled public String doctorName { get; set; }
        @AuraEnabled public String doctorSpecialty { get; set; }
        @AuraEnabled public Boolean hasActiveAlerts { get; set; }
        @AuraEnabled public Integer alertCount { get; set; }
        @AuraEnabled public String admissionDate { get; set; }
    }

    public class ClinicalOperationResultDto {
        @AuraEnabled public Boolean isSuccess { get; set; }
        @AuraEnabled public Boolean alertFlag { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public Id recordId { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static List<InpatientCardDto> getInpatientAdmissions(String searchTerm) {
        List<InpatientCardDto> cards = new List<InpatientCardDto>();
        try {
            String query = 'SELECT Id, Name, Admission_Date__c, ' +
                           'Contact__r.Name, Patient__r.Name, ' +
                           'Bed__r.Name, Bed__r.Bed_Code__c, Bed__r.Floor__c, ' +
                           'Bed__r.Ward__r.Name, ' +
                           'Attending_Doctor__r.Name, Attending_Doctor__r.Specialty__c, ' +
                           'Doctor__r.Name, Doctor__r.Specialty__c ' +
                           'FROM Admission__c WHERE Status__c = \'Admitted\' ';
            if (String.isNotBlank(searchTerm)) {
                String clean = '%' + searchTerm.trim() + '%';
                query += ' AND (Contact__r.Name LIKE :clean OR Patient__r.Name LIKE :clean OR Bed__r.Bed_Code__c LIKE :clean OR Bed__r.Ward__r.Name LIKE :clean)';
            }
            query += ' WITH USER_MODE ORDER BY Admission_Date__c DESC NULLS LAST LIMIT 50';

            List<Admission__c> admissions = Database.query(query);
            Set<Id> admIds = new Set<Id>();
            for (Admission__c a : admissions) {
                admIds.add(a.Id);
            }

            // Find admissions with abnormal vitals
            Set<Id> alertAdmIds = new Set<Id>();
            if (!admIds.isEmpty()) {
                for (Patient_Vital__c pv : [
                    SELECT Id, Admission__c 
                    FROM Patient_Vital__c 
                    WHERE Admission__c IN :admIds 
                      AND Alert_Flag__c = true 
                      AND (Alert_Status__c = null OR Alert_Status__c != 'Resolved')
                    WITH USER_MODE
                ]) {
                    alertAdmIds.add(pv.Admission__c);
                }
            }

            for (Admission__c a : admissions) {
                InpatientCardDto dto = new InpatientCardDto();
                dto.admissionId = a.Id;
                dto.admissionNumber = a.Name;
                dto.patientName = a.Contact__c != null ? a.Contact__r.Name : (a.Patient__c != null ? a.Patient__r.Name : 'Patient');
                dto.wardName = (a.Bed__r != null && a.Bed__r.Ward__r != null) ? a.Bed__r.Ward__r.Name : '';
                dto.bedCode = a.Bed__r != null ? (a.Bed__r.Bed_Code__c != null ? a.Bed__r.Bed_Code__c : a.Bed__r.Name) : '';
                dto.room = a.Bed__r != null ? ('Floor ' + (a.Bed__r.Floor__c != null ? String.valueOf(a.Bed__r.Floor__c.intValue()) : '1')) : '';
                dto.doctorName = a.Attending_Doctor__c != null ? a.Attending_Doctor__r.Name : (a.Doctor__c != null ? a.Doctor__r.Name : '');
                dto.doctorSpecialty = a.Attending_Doctor__c != null ? a.Attending_Doctor__r.Specialty__c : (a.Doctor__c != null ? a.Doctor__r.Specialty__c : '');
                dto.hasActiveAlerts = alertAdmIds.contains(a.Id);
                dto.alertCount = dto.hasActiveAlerts ? 1 : 0;
                dto.admissionDate = a.Admission_Date__c != null ? a.Admission_Date__c.format('yyyy-MM-dd') : '';
                cards.add(dto);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'CareNestClinicalController.getInpatientAdmissions error: ' + e.getMessage());
        }
        return cards;
    }

    @AuraEnabled
    public static ClinicalOperationResultDto recordVital(Id admissionId, Decimal systolic, Decimal diastolic, Decimal pulse, Decimal temp, Decimal spO2, Decimal respRate, String notes) {
        ClinicalOperationResultDto res = new ClinicalOperationResultDto();
        try {
            if (admissionId == null) {
                throw new AuraHandledException('Admission ID is required.');
            }
            Patient_Vital__c pv = new Patient_Vital__c();
            pv.Admission__c = admissionId;
            pv.Systolic_BP__c = systolic;
            pv.Diastolic_BP__c = diastolic;
            pv.Pulse_BPM__c = pulse;
            pv.Temperature_C__c = temp;
            pv.SpO2_Percent__c = spO2;
            pv.Respiratory_Rate__c = respRate;
            pv.Notes__c = notes;
            pv.Recorded_At__c = System.now();
            pv.Recorded_Date__c = System.now();

            insert as user pv;

            // Re-query to get formula Alert_Flag__c
            Patient_Vital__c insertedPv = [SELECT Id, Alert_Flag__c FROM Patient_Vital__c WHERE Id = :pv.Id WITH USER_MODE];

            res.isSuccess = true;
            res.recordId = pv.Id;
            res.alertFlag = insertedPv.Alert_Flag__c == true;
            res.message = res.alertFlag 
                ? 'Vital signs saved. WARNING: Alert condition detected!' 
                : 'Vital signs successfully recorded.';
        } catch (Exception e) {
            res.isSuccess = false;
            res.message = e.getMessage();
        }
        return res;
    }

    @AuraEnabled
    public static ClinicalOperationResultDto createEncounter(Id admissionId, String encounterType, String chiefComplaint, String notes, String assessment) {
        ClinicalOperationResultDto res = new ClinicalOperationResultDto();
        try {
            if (admissionId == null) {
                throw new AuraHandledException('Admission ID is required.');
            }
            Admission__c parentAdm = [
                SELECT Id, Attending_Doctor__c, Doctor__c 
                FROM Admission__c 
                WHERE Id = :admissionId 
                WITH USER_MODE 
                LIMIT 1
            ];
            Id docId = parentAdm.Attending_Doctor__c != null ? parentAdm.Attending_Doctor__c : parentAdm.Doctor__c;
            if (docId == null) {
                List<Doctor__c> docs = [SELECT Id FROM Doctor__c WHERE Is_Active__c = true WITH USER_MODE LIMIT 1];
                if (!docs.isEmpty()) {
                    docId = docs[0].Id;
                }
            }

            Inpatient_Encounter__c enc = new Inpatient_Encounter__c();
            enc.Admission__c = admissionId;
            enc.Attending_Doctor__c = docId;
            enc.Doctor__c = docId;
            enc.Encounter_Date__c = System.now();
            enc.Encounter_Type__c = String.isNotBlank(encounterType) ? encounterType : 'Daily Ward Round';
            enc.Chief_Complaint__c = chiefComplaint;
            enc.Clinical_Notes__c = notes;
            enc.Assessment__c = assessment;
            enc.Status__c = 'Completed';

            insert as user enc;

            res.isSuccess = true;
            res.recordId = enc.Id;
            res.message = 'Encounter note successfully saved.';
        } catch (Exception e) {
            res.isSuccess = false;
            res.message = e.getMessage();
        }
        return res;
    }

    /**
     * @description Clinician action to acknowledge an abnormal vital alert.
     * Transitions status to 'Acknowledged' and stamps user and timestamp.
     */
    @AuraEnabled
    public static PatientVitalDto acknowledgeVitalAlert(Id vitalId, String notes) {
        if (vitalId == null) {
            throw new AuraHandledException('Vital record ID is required.');
        }

        Patient_Vital__c vit = [
            SELECT Id, Alert_Status__c, Notes__c, Admission__c
            FROM Patient_Vital__c
            WHERE Id = :vitalId
            WITH USER_MODE
            LIMIT 1
        ];

        vit.Alert_Status__c = 'Acknowledged';
        vit.Acknowledged_By__c = UserInfo.getUserId();
        vit.Acknowledged_At__c = System.now();
        if (String.isNotBlank(notes)) {
            vit.Notes__c = (String.isNotBlank(vit.Notes__c) ? vit.Notes__c + ' | ' : '') + 'ACK: ' + notes.trim();
        }

        update as user vit;

        List<PatientVitalDto> refreshedList = getVitals(vit.Admission__c);
        for (PatientVitalDto dto : refreshedList) {
            if (dto.id == vitalId) {
                return dto;
            }
        }
        return null;
    }

    /**
     * @description Clinician action to resolve an abnormal vital alert.
     * Requires resolution clinical notes, transitions status to 'Resolved',
     * and stamps user and resolution timestamp.
     */
    @AuraEnabled
    public static PatientVitalDto resolveVitalAlert(Id vitalId, String resolutionNotes) {
        if (vitalId == null) {
            throw new AuraHandledException('Vital record ID is required.');
        }
        if (String.isBlank(resolutionNotes)) {
            throw new AuraHandledException('Clinical resolution notes and action plan are required to resolve an alert.');
        }

        Patient_Vital__c vit = [
            SELECT Id, Alert_Status__c, Resolution_Notes__c, Admission__c
            FROM Patient_Vital__c
            WHERE Id = :vitalId
            WITH USER_MODE
            LIMIT 1
        ];

        vit.Alert_Status__c = 'Resolved';
        vit.Resolved_By__c = UserInfo.getUserId();
        vit.Resolved_At__c = System.now();
        vit.Resolution_Notes__c = resolutionNotes.trim();

        update as user vit;

        List<PatientVitalDto> refreshedList = getVitals(vit.Admission__c);
        for (PatientVitalDto dto : refreshedList) {
            if (dto.id == vitalId) {
                return dto;
            }
        }
        return null;
    }
}
