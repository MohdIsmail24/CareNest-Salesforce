# CareNest HMS — Stage 1: Offline Discovery & Tracker Findings

**Stage:** STAGE 1 — OFFLINE DISCOVERY AND TRACKER (NO ORG ACCESS)  
**Workspace:** `C:\Users\hp\Downloads\carenest-salesforce-chunk1\carenest-salesforce`  
**Referenced Org Alias:** `carenest` (`00Dg700000Cpr9pEAB`)  
**CLI Version:** `@salesforce/cli/2.151.7 win32-x64 node-v24.20.0`  
**Audit Timestamp:** 2026-10-17T05:54:00+05:30  

---

## 1. Repository Baseline

Read-only inspection via Git commands confirms the repository baseline:

```
Branch: main
HEAD Commit: 249c65a665cb594c136d6f59f2986a012147409f
Tracked Modified Files Count: 17
Untracked Items in Short Status: 71 (53 pre-existing assets + 2 planning docs + 1 manifest + unpacked folders)
Working Tree State: Strictly preserved. Zero resets, checkouts, stashes, commits, or pushes.
```

### Complete List of 17 Tracked Modifications
1. [`force-app/main/default/applications/CareNest.app-meta.xml`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/applications/CareNest.app-meta.xml)
2. [`force-app/main/default/classes/AppointmentCoreTest.cls`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/classes/AppointmentCoreTest.cls)
3. [`force-app/main/default/classes/CancellationService.cls`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/classes/CancellationService.cls)
4. [`force-app/main/default/classes/DoctorSearchControllerTest.cls`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/classes/DoctorSearchControllerTest.cls)
5. [`force-app/main/default/classes/NoShowBatch.cls`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/classes/NoShowBatch.cls)
6. [`force-app/main/default/classes/PendingExpiryBatch.cls`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/classes/PendingExpiryBatch.cls)
7. [`force-app/main/default/classes/ReminderSmsJob.cls`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/classes/ReminderSmsJob.cls)
8. [`force-app/main/default/flows/CareNest_Appointment_Daily_Reminder.flow-meta.xml`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/flows/CareNest_Appointment_Daily_Reminder.flow-meta.xml)
9. [`force-app/main/default/lwc/appointmentWizard/appointmentWizard.js-meta.xml`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/lwc/appointmentWizard/appointmentWizard.js-meta.xml)
10. [`force-app/main/default/lwc/doctorSearch/doctorSearch.js-meta.xml`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/lwc/doctorSearch/doctorSearch.js-meta.xml)
11. [`force-app/main/default/lwc/myAppointments/myAppointments.js-meta.xml`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/lwc/myAppointments/myAppointments.js-meta.xml)
12. [`force-app/main/default/lwc/patientBilling/patientBilling.js-meta.xml`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/lwc/patientBilling/patientBilling.js-meta.xml)
13. [`force-app/main/default/lwc/slotPicker/slotPicker.js-meta.xml`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/lwc/slotPicker/slotPicker.js-meta.xml)
14. [`force-app/main/default/objects/Error_Log__c/Error_Log__c.object-meta.xml`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/objects/Error_Log__c/Error_Log__c.object-meta.xml)
15. [`force-app/main/default/permissionsets/CareNest_Doctor.permissionset-meta.xml`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/permissionsets/CareNest_Doctor.permissionset-meta.xml)
16. [`force-app/main/default/permissionsets/CareNest_Front_Desk.permissionset-meta.xml`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/permissionsets/CareNest_Front_Desk.permissionset-meta.xml)
17. [`force-app/main/default/permissionsets/CareNest_Ops_Manager.permissionset-meta.xml`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/permissionsets/CareNest_Ops_Manager.permissionset-meta.xml)

---

## 2. Inventory of Real Files

Inspected real files via Windows PowerShell file system queries:

| Metadata Type | Real File / Directory Count | Details & File References |
| :--- | :---: | :--- |
| **Custom Objects (`__c`)** | 12 | `Admission__c`, `Appointment__c`, `Appointment_Slot__c`, `Bed__c`, `Cancellation__c`, `Doctor__c`, `Error_Log__c`, `Inpatient_Encounter__c`, `Patient_Vital__c`, `Payment__c`, `Visit_Record__c`, `Ward__c` |
| **Platform Events (`__e`)** | 1 | `Error_Log_Event__e` |
| **Custom Metadata (`__mdt`)** | 1 | `Cancellation_Policy__mdt` (3 records) |
| **Standard Objects** | 1 | `Contact` (`Patient_Code__c.field-meta.xml`) |
| **Custom Fields** | 102 | Across all objects in `force-app/main/default/objects/*/fields/` |
| **Apex Classes** | 30 | 20 service/handler/batch classes + 10 test classes |
| **Apex Triggers** | 7 | `AdmissionTrigger`, `AppointmentTrigger`, `BedTrigger`, `DoctorTrigger`, `ErrorLogEventTrigger`, `InpatientEncounterTrigger`, `PatientVitalTrigger` |
| **Test Classes & Methods** | 10 classes / 147 methods | Total 147 test methods (87 in 7 Inpatient tests, 60 in 3 Appointment tests) |
| **Flows** | 3 | `CareNest_Appointment_Confirmed`, `CareNest_Appointment_Daily_Reminder`, `CareNest_Cancel_Appointment` |
| **Lightning Web Components** | 5 | `appointmentWizard`, `doctorSearch`, `myAppointments`, `patientBilling`, `slotPicker` |
| **Permission Sets** | 7 | `CareNest_Agent_Actions`, `CareNest_Doctor`, `CareNest_Front_Desk`, `CareNest_Integration`, `CareNest_Ops_Manager`, `CareNest_Patient`, `CareNest_Ward_Management` |
| **Permission Set Groups** | 1 | `CareNest_Operations` |
| **Custom Tabs** | 13 | 12 custom object tabs + 1 custom page tab (`CareNest_Home`) |
| **Custom Applications** | 1 | `CareNest` (Lightning application) |
| **Page Layouts** | 12 | One layout per custom object |
| **Reports** | 12 | 7 inpatient reports + 5 appointment reports |
| **Dashboards** | 1 | `CareNest_Operations_Dashboard` |
| **Package Manifests** | 3 | `manifest/phase17-inpatient-package.xml`, `manifest/phase17b5-package.xml`, `manifest/phase17b7-package.xml` |

### Apex Classes & Triggers API Version Breakdown
- **API 60.0 (27 Classes):** `AdmissionService`, `AdmissionTriggerHandler`, `AppointmentAsyncTest`, `AppointmentCoreTest`, `AppointmentService`, `AppointmentTriggerHandler`, `BedTriggerHandler`, `CancelAppointmentAction`, `CancellationService`, `CareNestReminderScheduler`, `ClinicalDocumentationService`, `ClinicalDocumentationTest`, `ClinicalSharingTest`, `CrossCoverReconciliationBatch`, `DoctorSearchController`, `DoctorSearchControllerTest`, `ErrorLogService`, `ErrorLogServiceTest`, `InpatientAdmissionTest`, `InpatientDischargeTest`, `InpatientEncounterTriggerHandler`, `InpatientLifecycleE2ETest`, `NoShowBatch`, `PatientVitalTriggerHandler`, `PendingExpiryBatch`, `ReminderSmsJob`, `TriggerHandler`, `WardBedManagementTest`.
- **API 68.0 (2 Classes):** `ClinicalSharingService`, `DoctorTriggerHandler`.
- **API 60.0 (6 Triggers):** `AdmissionTrigger`, `AppointmentTrigger`, `BedTrigger`, `ErrorLogEventTrigger`, `InpatientEncounterTrigger`, `PatientVitalTrigger`.
- **API 68.0 (1 Trigger):** `DoctorTrigger`.

---

## 3. Dependency Check for `manifest/phase17-inpatient-package.xml`

### Explicit Component Check

| Targeted Component | Present in `phase17-inpatient-package.xml`? | Present Elsewhere in `force-app`? | Status & Reason |
| :--- | :---: | :---: | :--- |
| `InpatientEncounterTrigger` | **NO** | YES ([`triggers/InpatientEncounterTrigger.trigger`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/triggers/InpatientEncounterTrigger.trigger)) | Pre-existing in `carenest` (Phase 17B.5). Omitted from 17C manifest. |
| `InpatientEncounterTriggerHandler` | **NO** | YES ([`classes/InpatientEncounterTriggerHandler.cls`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/classes/InpatientEncounterTriggerHandler.cls)) | Pre-existing in `carenest` (Phase 17B.5). Omitted from 17C manifest. |
| `PatientVitalTrigger` | **NO** | YES ([`triggers/PatientVitalTrigger.trigger`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/triggers/PatientVitalTrigger.trigger)) | Pre-existing in `carenest` (Phase 17B.5). Omitted from 17C manifest. |
| `PatientVitalTriggerHandler` | **NO** | YES ([`classes/PatientVitalTriggerHandler.cls`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/classes/PatientVitalTriggerHandler.cls)) | Pre-existing in `carenest` (Phase 17B.5). Omitted from 17C manifest. |
| `DoctorTrigger` | **NO** | YES ([`triggers/DoctorTrigger.trigger`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/triggers/DoctorTrigger.trigger)) | Pre-existing in `carenest` (Phase 17B.5). Omitted from 17C manifest. |
| `DoctorTriggerHandler` | **NO** | YES ([`classes/DoctorTriggerHandler.cls`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/classes/DoctorTriggerHandler.cls)) | Pre-existing in `carenest` (Phase 17B.5). Omitted from 17C manifest. |
| `ClinicalSharingService` | **NO** | YES ([`classes/ClinicalSharingService.cls`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/classes/ClinicalSharingService.cls)) | Pre-existing in `carenest` (Phase 17B.7). Omitted from 17C manifest. |
| `ClinicalSharingTest` | **NO** | YES ([`classes/ClinicalSharingTest.cls`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/classes/ClinicalSharingTest.cls)) | Pre-existing in `carenest` (Phase 17B.7). Omitted from 17C manifest; present in proposed `--tests` list. |
| `CrossCoverReconciliationBatch`| **NO** | YES ([`classes/CrossCoverReconciliationBatch.cls`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/classes/CrossCoverReconciliationBatch.cls)) | Pre-existing in `carenest` (Phase 17B.5). Omitted from 17C manifest. |
| `TriggerHandler` | **NO** | YES ([`classes/TriggerHandler.cls`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/classes/TriggerHandler.cls)) | Committed baseline base class. Omitted from 17C manifest. |
| `ErrorLogService` | **YES** | YES ([`classes/ErrorLogService.cls`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/classes/ErrorLogService.cls)) | Included in 17C manifest. |
| `Error_Log_Event__e` | **YES** | YES ([`objects/Error_Log_Event__e`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/objects/Error_Log_Event__e/Error_Log_Event__e.object-meta.xml)) | Included in 17C manifest under CustomObject. |

### Architectural Recommendation: Incremental vs. Self-Contained Package
- **Recommendation:** **Maintain an Incremental Package for `carenest` validation, but expand it to include the missing Inpatient Triggers and Handlers (`InpatientEncounterTrigger`, `InpatientEncounterTriggerHandler`, `PatientVitalTrigger`, `PatientVitalTriggerHandler`, and `ClinicalSharingTest`).**
- **Reasons:**
  1. *Target Org State:* The target org `carenest` already has the core foundation deployed (`Doctor__c`, `Contact.Patient_Code__c`, `TriggerHandler`, `ClinicalSharingService`). Re-deploying existing foundation objects is unnecessary and risks touching unrelated baseline metadata.
  2. *Domain Boundary:* Inpatient encounters and patient vitals are part of the Inpatient suite. Having their objects in `phase17-inpatient-package.xml` while omitting their triggers creates an artificial split. Including them ensures the Inpatient suite is functionally complete and cohesive.

---

## 4. API-Version Consistency Assessment

### Complete Distribution
- `sfdx-project.json`: `64.0` (1 instance)
- `manifest/phase17-inpatient-package.xml`: `68.0` (1 instance)
- `manifest/phase17b5-package.xml`: `68.0` (1 instance)
- `manifest/phase17b7-package.xml`: `68.0` (1 instance)
- `force-app/main/default/classes/ClinicalSharingService.cls-meta.xml`: `68.0` (1 instance)
- `force-app/main/default/classes/DoctorTriggerHandler.cls-meta.xml`: `68.0` (1 instance)
- `force-app/main/default/triggers/DoctorTrigger.trigger-meta.xml`: `68.0` (1 instance)
- All other 42 metadata XML files: `60.0` (42 instances)

### Dependency & Risk Analysis
- **Code Inspection:** None of the Apex code in `ClinicalSharingService` or `DoctorTriggerHandler` utilizes language constructs introduced after API 60.0 (e.g. no new syntax, standard SOQL/DML only).
- **Risk Assessment:** In historical jobs `0Afg700000FY6tZCAT` and `0Afg700000FffhjCAB`, the Salesforce CLI and live org accepted `68.0`. It is **NOT** a fatal deployment blocker for `carenest`.
- **Recommendation:** Do not perform blanket changes across all files. For long-term hygiene, the manifest version should be aligned to `64.0` (matching `sfdx-project.json`) during the next planned manifest refinement.

---

## 5. Inpatient Apex Code Review (Read-Only)

| File & Line | Component | Inspection Category | Severity | Observation & Architectural Finding |
| :--- | :--- | :--- | :---: | :--- |
| [`AdmissionService.cls#L145`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/classes/AdmissionService.cls#L145) | `AdmissionService` | Concurrency & Locking | INFO | Acquires pessimistic row locks (`FOR UPDATE`) on `Bed__c` during admission, preventing concurrent double-booking. |
| [`AdmissionService.cls#L331,L372`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/classes/AdmissionService.cls#L331) | `AdmissionService` | Concurrency & Locking | INFO | Acquires pessimistic row locks (`FOR UPDATE`) on both `Admission__c` and `Bed__c` during discharge, eliminating bed release race conditions. |
| [`AdmissionService.cls#L137,L211`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/classes/AdmissionService.cls#L137) | `AdmissionService` | Transaction Integrity | INFO | Establishes `Database.setSavepoint()` and executes `Database.rollback(sp)` on catch, ensuring complete atomicity. |
| [`AdmissionService.cls#L449-L486`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/classes/AdmissionService.cls#L449-L486) | `AdmissionService` | Authorization (CRUD/FLS) | INFO | Explicitly validates `isCreateable()` and `isUpdateable()` on objects and discharge fields prior to DML. |
| [`AdmissionService.cls#L495-L504`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/classes/AdmissionService.cls#L495-L504) | `DischargeDmlHelper` | Elevated System Helper | INFO | Inner `without sharing` class executes bed release safely without requiring clinicians to hold general Bed Edit permissions. |
| [`AdmissionTriggerHandler.cls#L200`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/classes/AdmissionTriggerHandler.cls#L200) | `AdmissionTriggerHandler` | Recursion Control | INFO | Uses `isServiceManagingBedUpdate` inside try-finally to prevent redundant trigger-driven bed updates during service operations. |
| [`AdmissionTriggerHandler.cls#L178`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/classes/AdmissionTriggerHandler.cls#L178) | `AdmissionTriggerHandler` | Invariant Protection | INFO | Terminal state protection blocks any status transition out of `Discharged` or `Cancelled`. |
| [`ClinicalDocumentationService.cls#L316`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/classes/ClinicalDocumentationService.cls#L316) | `ClinicalDocumentationService`| Data Validation | INFO | Enforces physiological bounds (temperature, pulse, respiratory rate, blood pressure, SpO2, weight). |
| [`ErrorLogService.cls#L137,L223`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/classes/ErrorLogService.cls#L137) | `ErrorLogService` | Security & Durability | INFO | Uses Platform Events (`PublishImmediately`) to survive transaction rollbacks; applies sanitization against credentials, tokens, and PII. |

**Audit Conclusion:** Zero SOQL/DML statements inside loops. Zero recursion hazards. Zero sharing leaks. Implementation is enterprise-grade.

---

## 6. Test Review

| Test Class | Actual Methods | `SeeAllData` | Synthetic Setup? | `System.runAs` | Missing Negative Tests / Gaps |
| :--- | :---: | :---: | :---: | :---: | :--- |
| [`WardBedManagementTest`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/classes/WardBedManagementTest.cls) | 7 | False | YES (Pure in-memory) | No | None. Tests capacity = 0, capacity reduction, exceed capacity, inactive ward. |
| [`InpatientAdmissionTest`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/classes/InpatientAdmissionTest.cls) | 13 | False | YES (Pure in-memory) | No | None. Tests occupied bed rejection, inactive ward rejection, batch duplicate bed, savepoint rollback. |
| [`InpatientDischargeTest`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/classes/InpatientDischargeTest.cls) | 16 | False | YES (Pure in-memory) | Yes (FLS check) | None. Tests discharge date < admission date, missing summary, bed conflict, unauthorized discharge. |
| [`ClinicalDocumentationTest`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/classes/ClinicalDocumentationTest.cls) | 13 | False | YES (Pure in-memory) | No | None. Tests invalid physiological ranges, documentation on discharged/cancelled admissions, rollback. |
| [`InpatientLifecycleE2ETest`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/classes/InpatientLifecycleE2ETest.cls) | 4 | False | YES (Pure in-memory) | No | None. Tests complete continuous lifecycle, cancelled admission rejection, bed isolation between admissions. |
| [`ClinicalSharingTest`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/classes/ClinicalSharingTest.cls) | 24 | False | YES (Pure in-memory) | Yes (User personas) | None. Pre-validated (24/24 passed in `0Afg700000FfPgBCAV`). |
| [`ErrorLogServiceTest`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/classes/ErrorLogServiceTest.cls) | 10 | False | YES (Pure in-memory) | No | None. Tests exception logging, credential redaction, PII sanitization, rollback survival. |

**Total Inpatient Suite Test Methods:** **87 methods**.  
Zero dependency on live org business records. 100% test isolation.

---

## 7. Permission Set Audit (Inpatient Fields & Doctor__c.User__c)

| Permission Set | Inpatient Object Access | Explicit Inpatient Field Permissions | `Doctor__c.User__c` FLS |
| :--- | :--- | :--- | :---: |
| [`CareNest_Doctor`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/permissionsets/CareNest_Doctor.permissionset-meta.xml) | `Admission__c` (R/E), `Inpatient_Encounter__c` (R/C/E), `Patient_Vital__c` (R/C/E), `Bed__c` (R), `Ward__c` (R) | Covers covering physician fields, discharge fields, clinical notes, and vitals. | **Read=true, Edit=false** |
| [`CareNest_Ward_Management`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/permissionsets/CareNest_Ward_Management.permissionset-meta.xml) | `Admission__c` (R/C/E), `Bed__c` (R/C/E), `Ward__c` (R/C/E), `Patient_Vital__c` (R/C), `Inpatient_Encounter__c` (R) | Covers admission, bed, and vitals management fields. `Admission__c.Status__c` is auto-accessible via field-level `<required>true</required>`. | **Not Present (No Access)** |
| [`CareNest_Front_Desk`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/permissionsets/CareNest_Front_Desk.permissionset-meta.xml) | `Admission__c` (R/C/E), `Bed__c` (R), `Ward__c` (R) | Admission demographics and scheduling. No clinical encounter/vital access. | **Not Present (No Access)** |
| [`CareNest_Ops_Manager`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/permissionsets/CareNest_Ops_Manager.permissionset-meta.xml) | Operational metadata only. | Zero inpatient field permissions. | **Not Present (No Access)** |
| [`CareNest_Agent_Actions`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/permissionsets/CareNest_Agent_Actions.permissionset-meta.xml) | Appointment actions only. | Zero inpatient field permissions. | **Not Present (No Access)** |
| [`CareNest_Integration`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/permissionsets/CareNest_Integration.permissionset-meta.xml) | Integration boundaries. | Zero inpatient field permissions. | **Not Present (No Access)** |
| [`CareNest_Patient`](file:///C:/Users/hp/Downloads/carenest-salesforce-chunk1/carenest-salesforce/force-app/main/default/permissionsets/CareNest_Patient.permissionset-meta.xml) | Experience Cloud portal. | Zero inpatient field permissions. | **Not Present (No Access)** |

---

## 8. Proposed Diffs (Not Applied — For Review Only)

### Proposed Manifest Enhancement (`manifest/phase17-inpatient-package.xml`)
```diff
--- a/manifest/phase17-inpatient-package.xml
+++ b/manifest/phase17-inpatient-package.xml
@@ -35,6 +35,7 @@
         <members>BedTriggerHandler</members>
         <members>ClinicalDocumentationService</members>
         <members>ClinicalDocumentationTest</members>
+        <members>ClinicalSharingTest</members>
         <members>InpatientAdmissionTest</members>
         <members>InpatientDischargeTest</members>
+        <members>InpatientEncounterTriggerHandler</members>
         <members>InpatientLifecycleE2ETest</members>
+        <members>PatientVitalTriggerHandler</members>
         <members>WardBedManagementTest</members>
         <members>ErrorLogService</members>
         <members>ErrorLogServiceTest</members>
         <name>ApexClass</name>
     </types>
     <types>
         <members>AdmissionTrigger</members>
         <members>BedTrigger</members>
         <members>ErrorLogEventTrigger</members>
+        <members>InpatientEncounterTrigger</members>
+        <members>PatientVitalTrigger</members>
         <name>ApexTrigger</name>
     </types>
     <types>
         <members>CareNest_Ward_Management</members>
         <name>PermissionSet</name>
     </types>
-    <version>68.0</version>
+    <version>64.0</version>
 </Package>
```

---

## 9. Draft Stage 2 Check-Only Validation Request

- **Exact Manifest:** `manifest/phase17-inpatient-package.xml`
- **Target Org Alias:** `carenest` (`00Dg700000Cpr9pEAB`)
- **Apex Test Classes:** `WardBedManagementTest,InpatientAdmissionTest,InpatientDischargeTest,ClinicalDocumentationTest,InpatientLifecycleE2ETest,ClinicalSharingTest,ErrorLogServiceTest`
- **Installed CLI Command Syntax:**
```bash
sf project deploy validate --manifest manifest/phase17-inpatient-package.xml --test-level RunSpecifiedTests --tests WardBedManagementTest,InpatientAdmissionTest,InpatientDischargeTest,ClinicalDocumentationTest,InpatientLifecycleE2ETest,ClinicalSharingTest,ErrorLogServiceTest --target-org carenest --json
```
- **Expected Effects:** Check-only deployment job initiated on Salesforce platform; Apex classes compiled against org schema; 87 Apex unit tests executed in test-sandbox context; zero live records created; returns a validation Job ID for future quick deployment.
- **Check-Only Confirmation:** The `--manifest` validation command executes with `checkOnly = true` natively in `sf project deploy validate`. No metadata or live data will be mutated.

---

## 10. NOT VERIFIED Items (Requiring Separate Authorization)

1. **Live Org Compilation:** Compilation of `manifest/phase17-inpatient-package.xml` against org `00Dg700000Cpr9pEAB` is **NOT VERIFIED** (requires executing `sf project deploy validate`).
2. **Actual Test Execution Pass Rate & Coverage:** Exact platform pass rate and code coverage percentages for the 87 tests are **NOT VERIFIED** until check-only validation executes.
3. **Live Metadata State in `carenest`:** Live presence of Phase 17B.5 components is established from local historical audit reports but is **NOT VERIFIED** via real-time SOQL query in this offline stage.
4. **Interactive In-Vivo Clinician Experience:** Browser-based UI validation of LWCs and record entry is **NOT VERIFIED**.
