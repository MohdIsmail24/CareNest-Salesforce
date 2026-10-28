# CareNest HMS — Functional Modules & 15-Pillar Capability Matrix

**Project:** CareNest Hospital Management System  
**Version:** Phase 22 Final Production Handover  
**Target Organization:** `carenest` (`00Dg700000Cpr9pEAB`)  

---

## 1. 15-Pillar Healthcare Capability Architecture

CareNest is structured around 15 core architectural pillars that ensure complete, end-to-end hospital operational excellence:

| Pillar | Operational Capability | Primary Implementing Components | Verification Status |
| :---: | :--- | :--- | :---: |
| **Pillar 1** | **Executive Command Center** | `careNestDashboardV2`, `CareNestDashboardController` | **VERIFIED (Live UI)** |
| **Pillar 2** | **Patient Registry & Master Index** | `patientRegistrationModal`, `CareNestPatientAccessService` | **VERIFIED (Live UI)** |
| **Pillar 3** | **Credentialed Physician Roster** | `doctorSearch`, `CareNestDoctorController` | **VERIFIED (Live UI)** |
| **Pillar 4** | **Concurrency-Safe OPD Booking** | `appointmentWizard`, `slotPicker`, `AppointmentService` | **VERIFIED (Apex Test)** |
| **Pillar 5** | **Ward & Bed Inventory Matrix** | `wardBedManager`, `CareNestAdmissionController` | **VERIFIED (Live UI)** |
| **Pillar 6** | **6-Step Inpatient Admission Wizard** | `patientAdmissionWorkspace` (Step 1-6) | **VERIFIED (Live UI)** |
| **Pillar 7** | **Inpatient Discharge & Disposition** | `patientAdmissionWorkspace`, `AdmissionService` | **VERIFIED (Live UI)** |
| **Pillar 8** | **Clinical Telemetry & Rounds Charting** | `inpatientClinicalWorkspace`, `ClinicalDocumentationService` | **VERIFIED (Live UI)** |
| **Pillar 9** | **Urgent Clinical Alert Triage** | `inpatientClinicalWorkspace`, `Patient_Vital__c` Triggers | **VERIFIED (Live UI)** |
| **Pillar 10** | **Demonstration POS Billing & Ledger** | `patientBilling`, `BillingOperationsService` | **VERIFIED (Live UI)** |
| **Pillar 11** | **Hospital Reports Hub** | 16 Certified Salesforce Reports, Reports Hub Launcher | **VERIFIED (Live UI)** |
| **Pillar 12** | **Executive Financial Analytics** | `adminOverview`, `CareNestAdminAnalyticsController` | **VERIFIED (Live UI)** |
| **Pillar 13** | **Autonomous Agentforce AI Copilot** | 4 Invocable Actions, `agentforceAssistantWidget` | **VERIFIED (Live UI)** |
| **Pillar 14** | **Automated Maintenance Jobs** | `BedAutoCleanScheduler`, `SlotAutoReleaseBatch` | **VERIFIED (Apex Test)** |
| **Pillar 15** | **Zero-Trust RBAC & Managed Sharing** | Private OWD, `CareNestPatientSharingService` | **VERIFIED (Apex Test)** |

---

## 2. Detailed Module Breakdown

### Module 1: Executive Command Center (`overview`)
* **Role:** Real-time inpatient census, bed availability telemetry, and departmental KPI monitoring.
* **Key Metrics:** 12 live KPI cards (Inpatient Census: 20, Total Beds: 42, Available Beds: 19, Occupied Beds: 20, Active Doctors: 12, Clinical Alerts: 14, Collections: ₹42,475).
* **Live Synchronization:** Interactive `Sync Live Data` button triggers immediate wire cache invalidation.

### Module 2: Hospital Patient Registry & Intake (`patients`)
* **Role:** Searchable master patient index decoupled from admissions.
* **Features:**
  * Master index displaying all 50 most recently enrolled patients.
  * Instant reactive search by Patient Code (`CN-PAT-XXXXX`), Name, Contact Phone, or Email.
  * Direct action buttons on every outpatient: `Admit to Bed` (launches guided wizard) and `Book OPD`.
  * Integrated `+ Register Patient` modal with required Last Name validation and duplicate detection.

### Module 3: Doctors Directory & Specialties (`doctors`)
* **Role:** Directory of 12 credentialed medical staff across Paediatrics, Cardiology, Orthopaedics, General Medicine, ENT, Dermatology, Neurology, General Surgery, Pulmonology, and OB/GYN.
* **Indicators:** Accurately distinguishes confirmed open OPD appointment slots from inpatient on-call ward duties.

### Module 4: Outpatient Appointments & OPD Booking (`appointments`)
* **Role:** 4-step scheduling wizard with calendar date picker, department filter, slot reservation, and real-time concurrency locking.

### Module 5: Inpatient Admissions & Discharge (`admissions`)
* **Role:** Comprehensive inpatient management with guided 6-step intake wizard:
  1. Patient Selection
  2. Ward Selection (real-time bed capacity and occupancy rollups)
  3. Available Bed Selection (strictly excludes occupied and maintenance beds)
  4. Attending Physician Selection
  5. Clinical Details (explicit operator selection of Admission Type: Emergency, Planned, Transfer)
  6. Review & Confirm Summary with concurrency lock
* **Discharge Flow:** Routine Discharge Home, Transferred, or Home Health Care with clinical summary tracking.

### Module 6: Ward & Bed Capacity Management (`wards`)
* **Role:** Interactive bed grid across 5 hospital wards:
  * General Ward: Floor 1, 16 Installed Beds (8 Available, 8 Occupied — 50% Occupancy)
  * ICU: Floor 2, 6 Installed Beds (3 Available, 3 Occupied — 50% Occupancy)
  * Semi-Private: Floor 2, 8 Installed Beds (4 Available, 3 Occupied, 1 Cleaning — 37.5% Occupancy)
  * Private Room: Floor 3, 8 Installed Beds (4 Available, 3 Occupied, 1 Cleaning — 37.5% Occupancy)
  * Paediatric Ward: Floor 4, 4 Installed Beds (0 Available, 3 Occupied, 1 Cleaning — 75% Occupancy)
* **Total Capacity:** 42 physical beds across 5 wards (19 available).

### Module 7: Inpatient Clinical Operations & Telemetry (`clinical`)
* **Role:** Bedside vital signs monitoring, clinical encounter charting, and urgent clinical alert triage.
* **Range Validation:** Normal physiological ranges for Temperature ($97.0^\circ\text{F} - 99.0^\circ\text{F}$), Blood Pressure ($120/80\text{ mmHg}$), Heart Rate ($60 - 100\text{ bpm}$), Respiration Rate ($12 - 20\text{ bpm}$), and $\text{SpO}_2$ ($\ge 95\%$).

### Module 8: Patient Billing & Payment Ledger (`billing`)
* **Role:** Demonstration cashier desk for settlement simulation (Cash, UPI, Card, Net Banking). Clearly labeled with prominent universal demonstration disclaimers.

### Module 9: Certified Reports Hub (`reports`)
* **Role:** 16 certified native Salesforce Lightning reports categorized into Financial Analytics (4), Ward Capacity (3), Patient Volume (3), Clinical Audit (3), and Doctor Performance (3).

### Module 10: Executive Analytics & Revenue Engine (`adminOverview`)
* **Role:** Period-filtered hospital governance analytics (Today, Last 7 Days, Last 30 Days, This Month, Last Month, This Quarter, This Year, Custom Date Range).
* **Visualizations:** 2 inline SVG analytical charts (Monthly Revenue Trend, Department Revenue Distribution) and 5 financial KPI cards.

### Module 11: Agentforce AI Clinical Copilot (`assistant`)
* **Role:** Enterprise conversational assistant powered by 4 typed Invocable Actions:
  1. `DoctorSearchAction`: Look up doctors by specialty or department.
  2. `WardAvailabilityAction`: Query real-time bed availability across hospital wards.
  3. `AppointmentStatusAction`: Check outpatient booking status.
  4. `CancelAppointmentAction`: Execute policy-compliant appointment cancellation.

### Module 12: Automation & Scheduled Jobs (`automation`)
* **Role:** Apex Scheduled Jobs and Batch monitor tracking `BedAutoCleanScheduler`, `SlotAutoReleaseBatch`, and asynchronous background cleanup jobs.
