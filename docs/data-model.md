# CareNest — Data Model & Entity Relationship Guide

## 1. Entity-Relationship Overview

The CareNest data model is structured around two interconnected operational lifecycles:
1. **Outpatient Consultation Lifecycle (OPD):** Patient (`Contact`) → `Doctor__c` → `Appointment_Slot__c` → `Appointment__c` → `Payment__c` / `Cancellation__c` / `Visit_Record__c`.
2. **Inpatient Admission & Clinical Lifecycle (IPD):** `Ward__c` → `Bed__c` → `Admission__c` → `Inpatient_Encounter__c` & `Patient_Vital__c`.

```mermaid
erDiagram
    CONTACT ||--o{ APPOINTMENT : "books (Patient__c)"
    CONTACT ||--o{ ADMISSION : "admitted as (Patient__c)"
    
    DOCTOR ||--o{ APPOINTMENT_SLOT : "allocates schedule"
    DOCTOR ||--o{ ADMISSION : "attending physician"
    DOCTOR ||--o{ INPATIENT_ENCOUNTER : "conducts rounds"
    
    APPOINTMENT_SLOT ||--o{ APPOINTMENT : "consumes capacity"
    
    APPOINTMENT ||--o{ PAYMENT : "settled via"
    APPOINTMENT ||--o{ CANCELLATION : "audited by"
    APPOINTMENT ||--o{ VISIT_RECORD : "documents consultation"
    
    WARD ||--o{ BED : "contains beds"
    WARD ||--o{ STAFF_WARD_ASSIGNMENT : "staffed by"
    
    BED ||--o{ ADMISSION : "assigned bed"
    
    ADMISSION ||--o{ INPATIENT_ENCOUNTER : "clinical rounds"
    ADMISSION ||--o{ PATIENT_VITAL : "recorded vitals"

    CONTACT {
        Id Id PK
        String FirstName
        String LastName
        String Email
        String Phone
        String Patient_Code__c "Unique (e.g. CN-P-001)"
    }

    DOCTOR {
        Id Id PK
        String Name "Dr. Full Name"
        String Department__c "General Medicine, Paediatrics, etc."
        String Specialty__c "Sub-specialty qualification"
        Decimal Consultation_Fee__c "Default consultation rate"
        Boolean Is_Active__c "Active practicing physician"
        Lookup User__c "Associated Salesforce User"
    }

    APPOINTMENT_SLOT {
        Id Id PK
        Lookup Doctor__c FK
        Datetime Slot_Start__c "Start time"
        Datetime Slot_End__c "End time"
        Decimal Capacity__c "Total patient slots (positive)"
        Decimal Booked_Count__c "Currently booked appointments"
        Decimal Available_Capacity__c "Formula (Capacity - Booked)"
        String Slot_Type__c "OPD or Teleconsult"
        String Status__c "Open, Full, Closed"
    }

    APPOINTMENT {
        Id Id PK
        Lookup Patient__c FK "Contact reference"
        Lookup Slot__c FK "Appointment_Slot__c reference"
        String Status__c "Scheduled, Completed, Cancelled, No-Show"
        Decimal Fee_Amount__c "Consultation fee billed"
        Decimal Discount_Percent__c "Approved discount (0-20%)"
        Decimal Total_Amount__c "Net fee after discount"
        Decimal Amount_Paid__c "Rollup/tracked collected fees"
        Decimal Balance_Due__c "Formula (Total_Amount - Amount_Paid)"
        Boolean Discount_Approved__c "Approval flag"
    }

    PAYMENT {
        Id Id PK
        Lookup Appointment__c FK
        Decimal Amount__c "Transaction currency amount"
        String Method__c "Cash, UPI, Card, Net Banking"
        String Status__c "Success, Pending, Refunded"
        String Transaction_Id__c "POS receipt or gateway ref"
        Datetime Payment_Date__c "Recorded timestamp"
    }

    CANCELLATION {
        Id Id PK
        Lookup Appointment__c FK
        Decimal Hours_Before__c "Notice period prior to slot start"
        Decimal Refund_Amount__c "Calculated refund payout"
        Decimal Cancellation_Fee__c "Retained hospital fee"
        String Reason__c "Patient cancelled, Doctor unavailable, etc."
        String Policy_Applied__c "Rule tier applied from metadata"
    }

    VISIT_RECORD {
        Id Id PK
        Lookup Appointment__c FK
        String Chief_Complaint__c "Presenting patient symptom"
        String Clinical_Notes__c "Physician diagnosis and notes"
        Boolean Follow_Up_Required__c "Flag for follow-up session"
        Date Follow_Up_Date__c "Scheduled follow-up date"
    }

    WARD {
        Id Id PK
        String Name "Ward Name (e.g. Ward A - ICU)"
        String Ward_Code__c "Unique identifier"
        String Ward_Type__c "General, Semi-Private, Private, ICU, Emergency"
        Decimal Total_Beds__c "Maximum bed capacity"
        Decimal Occupied_Beds__c "Rollup of occupied beds"
        Decimal Available_Beds__c "Formula (Total_Beds - Occupied_Beds)"
        Decimal Daily_Rate__c "Inpatient bed charge per day"
        Boolean Is_Active__c "Operational status"
    }

    BED {
        Id Id PK
        Lookup Ward__c FK
        String Bed_Number__c "Physical bed tag"
        String Bed_Code__c "Unique composite identifier"
        String Status__c "Available, Occupied, Maintenance, Cleaning"
        Boolean Is_Available__c "Formula boolean"
    }

    ADMISSION {
        Id Id PK
        Lookup Patient__c FK "Contact reference"
        Lookup Bed__c FK "Assigned Bed"
        Lookup Doctor__c FK "Attending Doctor"
        Datetime Admission_Date__c "Inpatient admission timestamp"
        Datetime Discharge_Date__c "Discharge timestamp"
        String Status__c "Admitted, Discharged, Transferred, Cancelled"
        String Diagnosis__c "Primary admitting diagnosis"
        Decimal Daily_Rate__c "Snapshot of bed daily rate"
        Decimal Length_Of_Stay_Days__c "Formula calculation"
        Decimal Accrued_Bed_Charges__c "Formula (Days * Daily_Rate)"
    }

    INPATIENT_ENCOUNTER {
        Id Id PK
        Lookup Admission__c FK
        Lookup Doctor__c FK
        Datetime Encounter_Date__c "Timestamp of clinical round"
        String Encounter_Type__c "Morning Rounds, Emergency Review, Routine"
        String Clinical_Summary__c "Detailed round observations"
        String Care_Plan_Modifications__c "Treatment adjustments"
    }

    PATIENT_VITAL {
        Id Id PK
        Lookup Admission__c FK
        Datetime Recorded_Date__c "Vitals capture timestamp"
        Decimal Systolic_BP__c "Systolic blood pressure (mmHg)"
        Decimal Diastolic_BP__c "Diastolic blood pressure (mmHg)"
        Decimal Heart_Rate__c "Pulse rate (bpm)"
        Decimal Respiratory_Rate__c "Breathing rate (breaths/min)"
        Decimal Temperature_Celsius__c "Body temperature"
        Decimal Oxygen_Saturation__c "SpO2 percentage (0-100)"
        Boolean Is_Abnormal__c "Formula/Trigger alert flag"
        String Clinical_Alert_Status__c "Active, Clinically Reviewed, Resolved"
    }

    STAFF_WARD_ASSIGNMENT {
        Id Id PK
        Lookup Ward__c FK
        Lookup User__c FK "Assigned Nurse or Physician"
        Date Start_Date__c "Effective assignment date"
        Date End_Date__c "Expiry date for cross-cover duty"
        String Role__c "Primary Nurse, Charge Nurse, Resident"
    }
```

---

## 2. Custom Object Dictionary

| Object API Name | Standard / Custom | Description | Sharing Model | Key Relationships |
|---|---|---|---|---|
| `Contact` | Standard | Hospital Patient Master Record | Private | Child of Account (or Individual) |
| `Doctor__c` | Custom | Outpatient and Inpatient Physicians | Public Read/Write | Master to Appointment Slots |
| `Appointment_Slot__c` | Custom | Time slots allocated by doctor schedule | ControlledByParent | Master-Detail (`Doctor__c`) |
| `Appointment__c` | Custom | Consultation bookings and billing summary | Private | Lookup (`Contact`), Lookup (`Appointment_Slot__c`) |
| `Payment__c` | Custom | Cash, Card, UPI payment records | ControlledByParent | Master-Detail (`Appointment__c`) |
| `Cancellation__c` | Custom | Audit log for cancelled appointments & refunds | ControlledByParent | Master-Detail (`Appointment__c`) |
| `Visit_Record__c` | Custom | Post-consultation clinical encounter note | ControlledByParent | Master-Detail (`Appointment__c`) |
| `Ward__c` | Custom | Hospital wards (ICU, General, etc.) | Public Read Only | Master to Beds |
| `Bed__c` | Custom | Individual hospital beds within a ward | ControlledByParent | Master-Detail (`Ward__c`) |
| `Admission__c` | Custom | Inpatient admission records & census | Private | Lookup (`Contact`), Lookup (`Bed__c`), Lookup (`Doctor__c`) |
| `Inpatient_Encounter__c` | Custom | Daily physician ward rounds & progress notes | ControlledByParent | Master-Detail (`Admission__c`), Lookup (`Doctor__c`) |
| `Patient_Vital__c` | Custom | Physiological bedside vital signs & alert telemetry | ControlledByParent | Master-Detail (`Admission__c`) |
| `CareNest_Staff_Ward_Assignment__c` | Custom | Staff cross-cover ward assignments for Apex sharing | Private | Lookup (`Ward__c`), Lookup (`User`) |
| `Error_Log__c` | Custom | Persistent exception and transactional error log | Private | Standalone |
| `Error_Log_Event__e` | Platform Event | High-volume platform event for decoupled logging | N/A | Standalone event payload |
| `Cancellation_Policy__mdt` | Custom Metadata | Governed tiers for notice hours, refund %, and fee % | Public Read | Standalone metadata |

---

## 3. Data Integrity & Validation Rules

CareNest enforces 30 declarative validation rules directly on the database engine to guarantee medical, operational, and financial data consistency:

### 3.1 Admission & Bed Rules
1. `Admission__c.Patient_Required`: Prevents admissions without a linked Patient (`Contact`).
2. `Admission__c.Doctor_Required`: Requires an attending physician on all inpatient admissions.
3. `Admission__c.Bed_Required`: Ensures an admission is physically allocated to a valid `Bed__c`.
4. `Admission__c.Discharge_After_Admission`: Disallows discharge dates that precede admission dates.
5. `Bed__c.Ward_Required`: Enforces that beds must belong to an active parent ward.
6. `Bed__c.Bed_Number_Required`: Mandates physical bed identification tags.
7. `Bed__c.Bed_Code_Required`: Requires unique composite bed identifiers.
8. `Bed__c.Cannot_Add_Bed_To_Inactive_Ward`: Prevents adding beds to decommissioned wards.
9. `Ward__c.Ward_Code_Required`: Mandates unique clinical ward codes.
10. `Ward__c.Capacity_Must_Be_Positive`: Restricts ward bed capacity to positive integers.
11. `Ward__c.Capacity_Cannot_Be_Less_Than_Bed_Count`: Prevents reducing capacity below existing bed counts.

### 3.2 Outpatient & Appointment Rules
12. `Appointment__c.Patient_Required`: Enforces patient contact link on all bookings.
13. `Appointment__c.Unapproved_Discount_Not_Allowed`: Rejects discounts greater than 0% without approval flag.
14. `Appointment__c.Discount_Above_20_Not_Allowed`: Restricts max discount to 20% even with approval.
15. `Appointment_Slot__c.Capacity_Must_Be_Positive`: Ensures slot capacity is at least 1.
16. `Appointment_Slot__c.Slot_Must_Be_Future`: Prevents scheduling slots in the past.
17. `Visit_Record__c.Follow_Up_Date_Required`: Requires a date if follow-up flag is checked.

### 3.3 Clinical Documentation & Vitals Range Checks
18. `Inpatient_Encounter__c.Admission_Required`: Requires active admission link.
19. `Inpatient_Encounter__c.Doctor_Required`: Mandates clinician attribution on rounds.
20. `Inpatient_Encounter__c.Encounter_Date_Required`: Enforces encounter timestamp.
21. `Inpatient_Encounter__c.Prevent_Encounter_On_Inactive_Admission`: Rejects rounds on discharged patients.
22. `Patient_Vital__c.Admission_Required`: Mandates admission parent link.
23. `Patient_Vital__c.Prevent_Vitals_On_Inactive_Admission`: Disallows vitals logging post-discharge.
24. `Patient_Vital__c.Recorded_Date_Required`: Requires explicit timestamp.
25. `Patient_Vital__c.Valid_Blood_Pressure`: Checks systolic (50-250 mmHg) and diastolic (30-150 mmHg).
26. `Patient_Vital__c.Valid_Pulse_Range`: Restricts heart rate between 30 and 220 bpm.
27. `Patient_Vital__c.Valid_Respiratory_Rate_Range`: Validates respiration between 6 and 60 breaths/min.
28. `Patient_Vital__c.Valid_Temperature_Range`: Enforces human temperature range (34.0°C to 43.0°C).
29. `Patient_Vital__c.Valid_Oxygen_Saturation_Range`: Validates SpO2 percentage between 50% and 100%.
30. `Patient_Vital__c.Valid_Weight_Range`: Restricts weight between 1.0 kg and 400.0 kg.
