/**
 * @description Bulk-safe trigger handler for Patient_Vital__c.
 * Enforces clinical range validations, relationship integrity with Admission and Encounter,
 * automatic Blood Pressure formatting, and inactive admission protection.
 */
public inherited sharing class PatientVitalTriggerHandler {

    public static Boolean bypassTrigger = false;

    private static final Set<String> INACTIVE_ADMISSION_STATUSES = new Set<String>{
        'Discharged',
        'Cancelled'
    };

    public void beforeInsert(List<Patient_Vital__c> newList) {
        if (bypassTrigger) {
            return;
        }

        applyDefaultsAndDerivations(newList);
        validateRelationshipsAndStatus(newList);
        validateClinicalRanges(newList);
    }

    public void beforeUpdate(List<Patient_Vital__c> newList, Map<Id, Patient_Vital__c> oldMap) {
        if (bypassTrigger) {
            return;
        }

        applyDefaultsAndDerivations(newList);
        validateRelationshipsAndStatus(newList);
        validateClinicalRanges(newList);
    }

    public void afterInsert(List<Patient_Vital__c> newList) {
        if (bypassTrigger) {
            return;
        }

        ClinicalSharingService.grantVitalShares(newList);
    }

    /**
     * Applies defaults and populates Admission__c from Inpatient_Encounter__c if omitted.
     */
    private void applyDefaultsAndDerivations(List<Patient_Vital__c> records) {
        Set<Id> encounterIdsToQuery = new Set<Id>();
        for (Patient_Vital__c v : records) {
            // Synchronize Encounter lookups
            if (v.Inpatient_Encounter__c == null && v.Encounter__c != null) {
                v.Inpatient_Encounter__c = v.Encounter__c;
            } else if (v.Encounter__c == null && v.Inpatient_Encounter__c != null) {
                v.Encounter__c = v.Inpatient_Encounter__c;
            }

            // Synchronize Date/Time
            if (v.Recorded_Date__c == null && v.Recorded_At__c != null) {
                v.Recorded_Date__c = v.Recorded_At__c;
            } else if (v.Recorded_At__c == null && v.Recorded_Date__c != null) {
                v.Recorded_At__c = v.Recorded_Date__c;
            } else if (v.Recorded_Date__c == null && v.Recorded_At__c == null) {
                v.Recorded_Date__c = System.now();
                v.Recorded_At__c = v.Recorded_Date__c;
            }

            // Synchronize Pulse
            if (v.Pulse__c == null && v.Pulse_BPM__c != null) {
                v.Pulse__c = v.Pulse_BPM__c;
            } else if (v.Pulse_BPM__c == null && v.Pulse__c != null) {
                v.Pulse_BPM__c = v.Pulse__c;
            }

            // Synchronize SpO2
            if (v.Oxygen_Saturation__c == null && v.SpO2_Percent__c != null) {
                v.Oxygen_Saturation__c = v.SpO2_Percent__c;
            } else if (v.SpO2_Percent__c == null && v.Oxygen_Saturation__c != null) {
                v.SpO2_Percent__c = v.Oxygen_Saturation__c;
            }

            // Synchronize Temperature
            if (v.Temperature__c == null && v.Temperature_C__c != null) {
                v.Temperature__c = Decimal.valueOf(Math.round((((Double)v.Temperature_C__c * 9.0 / 5.0) + 32.0) * 10.0)) / 10.0;
                v.Temperature_Unit__c = '°F';
            } else if (v.Temperature_C__c == null && v.Temperature__c != null) {
                if (v.Temperature_Unit__c == '°C' || (v.Temperature__c >= 25.0 && v.Temperature__c <= 45.0)) {
                    v.Temperature_C__c = v.Temperature__c;
                    v.Temperature__c = Decimal.valueOf(Math.round((((Double)v.Temperature__c * 9.0 / 5.0) + 32.0) * 10.0)) / 10.0;
                    v.Temperature_Unit__c = '°F';
                } else {
                    v.Temperature_C__c = Decimal.valueOf(Math.round((((Double)(v.Temperature__c - 32.0) * 5.0 / 9.0)) * 10.0)) / 10.0;
                }
            }

            if (String.isBlank(v.Temperature_Unit__c)) {
                v.Temperature_Unit__c = '°F';
            }
            if (String.isBlank(v.Weight_Unit__c)) {
                v.Weight_Unit__c = 'kg';
            }

            // Format Blood Pressure string if components present
            if (v.Systolic_BP__c != null && v.Diastolic_BP__c != null && String.isBlank(v.Blood_Pressure__c)) {
                v.Blood_Pressure__c = String.valueOf(v.Systolic_BP__c.intValue()) + '/' + String.valueOf(v.Diastolic_BP__c.intValue());
            }

            // Derive Admission__c from Encounter if needed
            if (v.Admission__c == null && v.Inpatient_Encounter__c != null) {
                encounterIdsToQuery.add(v.Inpatient_Encounter__c);
            }
        }

        if (!encounterIdsToQuery.isEmpty()) {
            Map<Id, Inpatient_Encounter__c> encounters = new Map<Id, Inpatient_Encounter__c>([
                SELECT Id, Admission__c
                FROM Inpatient_Encounter__c
                WHERE Id IN :encounterIdsToQuery
            ]);

            for (Patient_Vital__c v : records) {
                if (v.Admission__c == null && v.Inpatient_Encounter__c != null && encounters.containsKey(v.Inpatient_Encounter__c)) {
                    v.Admission__c = encounters.get(v.Inpatient_Encounter__c).Admission__c;
                }
            }
        }
    }

    /**
     * Validates relationship consistency between vital, encounter, and admission.
     * Prevents recording vitals against discharged or cancelled admissions.
     */
    private void validateRelationshipsAndStatus(List<Patient_Vital__c> records) {
        Set<Id> admissionIds = new Set<Id>();
        Set<Id> encounterIds = new Set<Id>();

        for (Patient_Vital__c v : records) {
            if (v.Admission__c != null) {
                admissionIds.add(v.Admission__c);
            }
            if (v.Inpatient_Encounter__c != null) {
                encounterIds.add(v.Inpatient_Encounter__c);
            }
        }

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

        if (admissionIds.isEmpty()) {
            return;
        }

        Map<Id, Admission__c> admissions = new Map<Id, Admission__c>([
            SELECT Id, Name, Status__c
            FROM Admission__c
            WHERE Id IN :admissionIds
        ]);

        for (Patient_Vital__c v : records) {
            // Verify encounter matches vital admission
            if (v.Inpatient_Encounter__c != null && encounters.containsKey(v.Inpatient_Encounter__c)) {
                Inpatient_Encounter__c enc = encounters.get(v.Inpatient_Encounter__c);
                if (v.Admission__c != null && enc.Admission__c != null && v.Admission__c != enc.Admission__c) {
                    v.addError('Mismatched relationship: Inpatient encounter belongs to a different admission than specified for this vital.');
                    continue;
                }
            }

            if (v.Admission__c != null) {
                Admission__c adm = admissions.get(v.Admission__c);
                if (adm == null) {
                    v.addError('Specified Admission record was not found.');
                } else if (String.isBlank(v.Vital_Code__c) && INACTIVE_ADMISSION_STATUSES.contains(adm.Status__c)) {
                    v.addError('Cannot record or update vitals for discharged or cancelled admissions (Admission status: ' + adm.Status__c + ').');
                }
            }
        }
    }

    /**
     * Enforces physiological boundaries on vital sign inputs.
     */
    private void validateClinicalRanges(List<Patient_Vital__c> records) {
        for (Patient_Vital__c v : records) {
            // Temperature (85.0°F to 110.0°F)
            if (v.Temperature__c != null) {
                if (v.Temperature__c < 85.0 || v.Temperature__c > 110.0) {
                    v.addError('Temperature (' + v.Temperature__c + '°F) is outside the clinically plausible range of 85.0°F to 110.0°F.');
                }
            }

            // Pulse (30 to 250 BPM)
            if (v.Pulse__c != null) {
                if (v.Pulse__c < 30 || v.Pulse__c > 250) {
                    v.addError('Pulse (' + v.Pulse__c + ' BPM) is outside the clinically plausible range of 30 to 250 BPM.');
                }
            }

            // Respiratory Rate (5 to 70 breaths/min)
            if (v.Respiratory_Rate__c != null) {
                if (v.Respiratory_Rate__c < 5 || v.Respiratory_Rate__c > 70) {
                    v.addError('Respiratory rate (' + v.Respiratory_Rate__c + ' breaths/min) is outside the clinically plausible range of 5 to 70 breaths/min.');
                }
            }

            // Blood Pressure (Systolic 50-260, Diastolic 30-150, Systolic > Diastolic)
            if (v.Systolic_BP__c != null && v.Diastolic_BP__c != null) {
                if (v.Systolic_BP__c <= v.Diastolic_BP__c) {
                    v.addError('Systolic blood pressure (' + v.Systolic_BP__c + ') must strictly exceed diastolic pressure (' + v.Diastolic_BP__c + ').');
                }
                if (v.Systolic_BP__c < 50 || v.Systolic_BP__c > 260) {
                    v.addError('Systolic blood pressure (' + v.Systolic_BP__c + ' mmHg) is outside plausible range (50-260 mmHg).');
                }
                if (v.Diastolic_BP__c < 30 || v.Diastolic_BP__c > 150) {
                    v.addError('Diastolic blood pressure (' + v.Diastolic_BP__c + ' mmHg) is outside plausible range (30-150 mmHg).');
                }
            } else if (v.Systolic_BP__c != null && (v.Systolic_BP__c < 50 || v.Systolic_BP__c > 260)) {
                v.addError('Systolic blood pressure is outside plausible range (50-260 mmHg).');
            } else if (v.Diastolic_BP__c != null && (v.Diastolic_BP__c < 30 || v.Diastolic_BP__c > 150)) {
                v.addError('Diastolic blood pressure is outside plausible range (30-150 mmHg).');
            }

            // Oxygen Saturation (50% to 100%)
            if (v.Oxygen_Saturation__c != null) {
                if (v.Oxygen_Saturation__c < 50 || v.Oxygen_Saturation__c > 100) {
                    v.addError('Oxygen saturation (' + v.Oxygen_Saturation__c + '%) must be between 50% and 100%.');
                }
            }

            // Weight (0 < weight <= 500)
            if (v.Weight__c != null) {
                if (v.Weight__c <= 0 || v.Weight__c > 500) {
                    v.addError('Weight (' + v.Weight__c + ' kg) must be positive and not exceed 500 kg.');
                }
            }
        }
    }
}
