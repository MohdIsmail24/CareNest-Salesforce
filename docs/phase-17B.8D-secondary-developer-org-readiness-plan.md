# CareNest HMS — Phase 17B.8D Isolated Secondary Developer Edition Readiness Plan

**Document Date/Time:** 2026-10-17T03:38:00+05:30  
**Mode:** Strictly Read-Only Planning and Repository Inspection  
**Live Org Alias:** `carenest`  
**Live Org ID:** `00Dg700000Cpr9pEAB`  
**Project Workspace:** `C:\Users\hp\Downloads\carenest-salesforce-chunk1\carenest-salesforce`  
**Git Baseline Commit:** `249c65a665cb594c136d6f59f2986a012147409f` (Branch `main`)  

---

## 1. Executive Summary & Objective

This document establishes the readiness plan for conducting non-admin clinical security testing (**TC-01 through TC-08**) in a separate, isolated Salesforce Developer Edition org. 

The secondary org has **not yet been created or authenticated**. This phase prepares the exact metadata boundary, persona mapping, synthetic data inventory, and execution sequence required so that when an isolated org is authorized, testing can proceed with zero risk to the live `carenest` org baseline.

---

## 2. Live Baseline Invariant Verification

Before formulating this plan, a read-only audit verified all protected live-org invariants against `00Dg700000Cpr9pEAB`:

| Invariant Item | Target Identifier / Object | Expected Value | Actual Measured | Evidence / Query Source | Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Salesforce Org ID** | `Organization.Id` | `00Dg700000Cpr9pEAB` | `00Dg700000Cpr9pEAB` | `SELECT Id FROM Organization` | **PASS** |
| **Git Branch** | Active Branch | `main` | `main` | `git rev-parse --abbrev-ref HEAD` | **PASS** |
| **Git HEAD Commit** | Baseline Commit | `249c65a665cb...` | `249c65a665cb594c136d6f59f2986a012147409f` | `git rev-parse HEAD` | **PASS** |
| **Git Working Tree** | Tracked Modifications | Exactly 17 files | 17 files preserved | `git status --porcelain` | **PASS** |
| **Git Untracked Assets** | Untracked Files | 53 + 1 doc file | 53 assets + `phase-17B.8C` report preserved | `git status --porcelain` | **PASS** |
| **Billing Ledger** | `Payment__c` Total Count | Exactly `69` | `69` | `SELECT COUNT(Id) cnt FROM Payment__c` | **PASS** |
| **Inpatient Admissions**| `Admission__c` Count | Exactly `0` | `0` | `SELECT COUNT(Id) cnt FROM Admission__c` | **PASS** |
| **Clinical Encounters** | `Inpatient_Encounter__c` Count | Exactly `0` | `0` | `SELECT COUNT(Id) cnt FROM Inpatient_Encounter__c` | **PASS** |
| **Patient Vitals** | `Patient_Vital__c` Count | Exactly `0` | `0` | `SELECT COUNT(Id) cnt FROM Patient_Vital__c` | **PASS** |
| **Doctor Total Records**| `Doctor__c` Count | Exactly `12` | `12` | `SELECT COUNT(Id) cnt FROM Doctor__c` | **PASS** |
| **Doctor User Mappings**| `Doctor__c WHERE User__c != null` | Exactly `0` | `0` (All 12 unmapped) | `SELECT COUNT(Id) cnt FROM Doctor__c WHERE User__c != null` | **PASS** |
| **Experience Cloud** | Network `0DBg7000002IgpFGAS` | `UnderConstruction` | `UnderConstruction` | `SELECT Id, Status FROM Network` | **PASS** |
| **Appointment Scheduler**| CronTrigger `08eg700000NJ1JiAAL` | `WAITING` | `WAITING` (Next: 2026-10-17 15:00 UTC) | `SELECT Id, State FROM CronTrigger` | **PASS** |
| **Reconciliation Batch**| CronTrigger `CrossCover...` | Unscheduled (`0`) | `0` scheduled | `SELECT Id FROM CronTrigger WHERE CronJobDetail.Name...` | **PASS** |

---

## 3. Authoritative Source Documents

The following documents were inspected to establish requirements:

1. **`phase17b8a_non_admin_security_test_plan.md`**  
   *Path:* `C:\Users\hp\.gemini\antigravity\brain\b22e34d2-c267-4528-b317-93fcab6fe14c\phase17b8a_non_admin_security_test_plan.md`  
   *Contribution:* Contains authoritative definitions, preconditions, steps, expected results, and evidence requirements for TC-01 through TC-08.
2. **`phase17b8b_isolated_test_environment_feasibility_report.md`**  
   *Path:* `C:\Users\hp\.gemini\antigravity\brain\b22e34d2-c267-4528-b317-93fcab6fe14c\phase17b8b_isolated_test_environment_feasibility_report.md`  
   *Contribution:* Establishes absence of Dev Hub in CLI and impossibility of sandboxes on Developer Edition orgs.
3. **`docs/phase-17B.8C-live-org-security-test-safety-assessment.md`**  
   *Path:* `C:\Users\hp\Downloads\carenest-salesforce-chunk1\carenest-salesforce\docs\phase-17B.8C-live-org-security-test-safety-assessment.md`  
   *Contribution:* Confirms that executing TC-01 to TC-06, TC-08 in the live org directly conflicts with baseline zero-record invariants.
4. **`manifest/phase17b5-package.xml` & `manifest/phase17b7-package.xml`**  
   *Paths:* `C:\Users\hp\Downloads\carenest-salesforce-chunk1\carenest-salesforce\manifest\*.xml`  
   *Contribution:* Authoritative manifests for the clinical sharing and security package.

---

## 4. Exact Authoritative Test Definitions (TC-01 to TC-08)

Copied verbatim from `phase17b8a_non_admin_security_test_plan.md`:

- **Scenario TC-01: Attending Clinician Authorized Record Access**
  - *Preconditions:* Test Patient, Ward, Bed, Admission linked to Doctor A (mapped to P-ATT). Inpatient Encounter & Vital created under Admission.
  - *Steps:* Log in / authenticate as P-ATT. Attempt SOQL/UI read on `Inpatient_Encounter__c` and `Patient_Vital__c`. Attempt note update.
  - *Expected Result:* P-ATT can view Admission, Encounter, and Vital. Can update clinical note.
  - *Evidence:* SOQL record IDs returned; successful DML response.
  - *Cleanup:* Delete synthetic Encounter, Vital, Admission, Patient.

- **Scenario TC-02: Unrelated Clinician Access Restriction**
  - *Preconditions:* Admission linked to Doctor A. Doctor C (mapped to P-URL) has no attending or cross-cover relationship.
  - *Steps:* Authenticate as P-URL. Attempt SOQL query: `SELECT Id FROM Inpatient_Encounter__c WHERE Id = :encId`.
  - *Expected Result:* Zero records returned (`INVALID_CROSS_REFERENCE_KEY` or empty result set). Private clinical sharing enforced.
  - *Evidence:* Query response showing `totalSize = 0`.
  - *Cleanup:* Managed in suite teardown.

- **Scenario TC-03: Covering Clinician Temporary Access (Active Window)**
  - *Preconditions:* Admission has `Covering_Doctor__c = Doctor B` (mapped to P-COV). `Covering_Start_Time__c <= NOW` and `Covering_End_Time__c >= NOW`.
  - *Steps:* Authenticate as P-COV. Query `Inpatient_Encounter__Share` and `Patient_Vital__Share`. Query Encounter and Vital records.
  - *Expected Result:* Shares exist with `RowCause = Care_Team__c` and `AccessLevel = Read`. P-COV can view Encounter and Vital records.
  - *Evidence:* Share query output showing `Care_Team__c`; record query returning encounter/vital data.
  - *Cleanup:* Managed in suite teardown.

- **Scenario TC-04: Covering Clinician Expiry / Revocation**
  - *Preconditions:* Active covering window on Admission expires (`Covering_End_Time__c` set to past). Reconcile via trigger update or `CrossCoverReconciliationBatch`.
  - *Steps:* Authenticate as P-COV. Attempt query on Encounter and Vital records.
  - *Expected Result:* `Care_Team__c` shares for both `Inpatient_Encounter__Share` and `Patient_Vital__Share` are deleted. P-COV receives zero records.
  - *Evidence:* Share count = 0; SOQL result size = 0.
  - *Cleanup:* Managed in suite teardown.

- **Scenario TC-05: Patient Discharge Protection & Downgrade**
  - *Preconditions:* Admission with Attending Doctor A and Covering Doctor B. Encounter and Vitals exist.
  - *Steps:* Update `Admission__c.Status__c = 'Discharged'`. Authenticate as P-ATT, then P-COV.
  - *Expected Result:* P-ATT access downgraded from Read/Write to Read-Only (`RowCause = Manual` or updated Attending share). Vital insertions blocked post-discharge. P-COV `Care_Team__c` shares are revoked immediately.
  - *Evidence:* Share records for P-COV deleted; P-ATT write attempt rejected with trigger validation.
  - *Cleanup:* Managed in suite teardown.

- **Scenario TC-06: Front-Desk Restricted Access**
  - *Preconditions:* Inpatient Encounter and Patient Vital records exist.
  - *Steps:* Authenticate as P-FDK (`CareNest_Front_Desk`). Query `Inpatient_Encounter__c` and `Patient_Vital__c`.
  - *Expected Result:* Front-desk user receives query error or zero records. Clinical documentation is completely invisible.
  - *Evidence:* Object describe or SOQL exception indicating insufficient privileges.
  - *Cleanup:* Managed in suite teardown.

- **Scenario TC-07: Clinician Mapping Immutability under `CareNest_Doctor`**
  - *Preconditions:* P-ATT logged in under `CareNest_Doctor`.
  - *Steps:* P-ATT attempts to update `Doctor__c.User__c` on Doctor A or any other doctor record via UI or API.
  - *Expected Result:* Operation blocked with `FIELD_CUSTOM_VALIDATION_EXCEPTION` or `INSUFFICIENT_ACCESS_OR_READONLY`.
  - *Evidence:* API error response confirming field is not updateable.
  - *Cleanup:* None.

- **Scenario TC-08: Reconciliation Idempotency & Attending Share Preservation**
  - *Preconditions:* Admission with attending doctor and expired covering doctor. Attending share exists.
  - *Steps:* Run `ClinicalSharingService.reconcileCrossCoverShares` twice.
  - *Expected Result:* Expired `Care_Team__c` vital and encounter shares remain purged. Attending physician shares remain untouched with count = 1.
  - *Evidence:* Share query counts before and after second run.
  - *Cleanup:* Managed in suite teardown.

---

## 5. Metadata Dependency Map (Minimum Clinical-Security Package)

To ensure high deployability to a fresh, vanilla Developer Edition org, only the clinical security domain is included. Unrelated features (billing, scheduling, portal networks, Agentforce) are strictly excluded.

### A. Included Core Components

| Component Name | Metadata Type | Source Path | Required for TC-01–TC-08? | Deployable to DE Org? | Dependencies / Prerequisites |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `Doctor__c` | `CustomObject` | `objects/Doctor__c/Doctor__c.object-meta.xml` | **YES** | Yes | None |
| `Doctor__c.User__c` | `CustomField` | `objects/Doctor__c/fields/User__c.field-meta.xml` | **YES** | Yes | Lookup to `User` |
| `Doctor__c.User_Id_Unique__c` | `CustomField` | `objects/Doctor__c/fields/User_Id_Unique__c.field-meta.xml` | **YES** | Yes | None |
| `Ward__c` | `CustomObject` | `objects/Ward__c/Ward__c.object-meta.xml` | **YES** | Yes | None |
| `Bed__c` | `CustomObject` | `objects/Bed__c/Bed__c.object-meta.xml` | **YES** | Yes | Master-Detail to `Ward__c` |
| `Admission__c` | `CustomObject` | `objects/Admission__c/Admission__c.object-meta.xml` | **YES** | Yes | Lookups to `Doctor__c`, `Bed__c`, `Contact` |
| `Inpatient_Encounter__c` | `CustomObject` | `objects/Inpatient_Encounter__c/...` | **YES** | Yes | Lookup to `Admission__c` |
| `Inpatient_Encounter__c.Attending_Physician__c` | `SharingReason` | `objects/Inpatient_Encounter__c/sharingReasons/...` | **YES** | Yes | Requires `Inpatient_Encounter__c` OWD = Private |
| `Inpatient_Encounter__c.Care_Team__c` | `SharingReason` | `objects/Inpatient_Encounter__c/sharingReasons/...` | **YES** | Yes | Requires `Inpatient_Encounter__c` OWD = Private |
| `Patient_Vital__c` | `CustomObject` | `objects/Patient_Vital__c/...` | **YES** | Yes | Lookup to `Admission__c` |
| `Patient_Vital__c.Attending_Physician__c` | `SharingReason` | `objects/Patient_Vital__c/sharingReasons/...` | **YES** | Yes | Requires `Patient_Vital__c` OWD = Private |
| `Patient_Vital__c.Care_Team__c` | `SharingReason` | `objects/Patient_Vital__c/sharingReasons/...` | **YES** | Yes | Requires `Patient_Vital__c` OWD = Private |
| `Error_Log_Event__e` | `PlatformEvent` | `objects/Error_Log_Event__e/...` | **YES** | Yes | None |
| `Error_Log__c` | `CustomObject` | `objects/Error_Log__c/...` | **YES** | Yes | None |
| `ErrorLogService` | `ApexClass` | `classes/ErrorLogService.cls` | **YES** | Yes | Depends on `Error_Log_Event__e` |
| `ClinicalSharingService` | `ApexClass` | `classes/ClinicalSharingService.cls` | **YES** | Yes | Depends on Clinical objects & SharingReasons |
| `ClinicalSharingTest` | `ApexClass` | `classes/ClinicalSharingTest.cls` | **YES** | Yes | Test harness |
| `CrossCoverReconciliationBatch` | `ApexClass` | `classes/CrossCoverReconciliationBatch.cls`| **YES** | Yes | Depends on `ClinicalSharingService` |
| `AdmissionTriggerHandler` | `ApexClass` | `classes/AdmissionTriggerHandler.cls` | **YES** | Yes | Depends on `Admission__c` |
| `DoctorTriggerHandler` | `ApexClass` | `classes/DoctorTriggerHandler.cls` | **YES** | Yes | Depends on `Doctor__c` |
| `InpatientEncounterTriggerHandler` | `ApexClass` | `classes/InpatientEncounterTriggerHandler.cls` | **YES** | Yes | Depends on `Inpatient_Encounter__c` |
| `PatientVitalTriggerHandler` | `ApexClass` | `classes/PatientVitalTriggerHandler.cls` | **YES** | Yes | Depends on `Patient_Vital__c` |
| `BedTriggerHandler` | `ApexClass` | `classes/BedTriggerHandler.cls` | **YES** | Yes | Depends on `Bed__c` |
| `AdmissionTrigger` | `ApexTrigger` | `triggers/AdmissionTrigger.trigger` | **YES** | Yes | `AdmissionTriggerHandler` |
| `DoctorTrigger` | `ApexTrigger` | `triggers/DoctorTrigger.trigger` | **YES** | Yes | `DoctorTriggerHandler` |
| `InpatientEncounterTrigger` | `ApexTrigger` | `triggers/InpatientEncounterTrigger.trigger` | **YES** | Yes | `InpatientEncounterTriggerHandler` |
| `PatientVitalTrigger` | `ApexTrigger` | `triggers/PatientVitalTrigger.trigger` | **YES** | Yes | `PatientVitalTriggerHandler` |
| `BedTrigger` | `ApexTrigger` | `triggers/BedTrigger.trigger` | **YES** | Yes | `BedTriggerHandler` |
| `ErrorLogEventTrigger` | `ApexTrigger` | `triggers/ErrorLogEventTrigger.trigger` | **YES** | Yes | `ErrorLogService` |
| `CareNest_Doctor` | `PermissionSet` | `permissionsets/CareNest_Doctor...` | **YES** | Yes | License-agnostic |
| `CareNest_Front_Desk` | `PermissionSet` | `permissionsets/CareNest_Front_Desk...` | **YES** | Yes | License-agnostic |
| `CareNest_Ops_Manager` | `PermissionSet` | `permissionsets/CareNest_Ops_Manager...` | **YES** | Yes | License-agnostic |
| `CareNest_Ward_Management` | `PermissionSet` | `permissionsets/CareNest_Ward_Management...` | **YES** | Yes | License-agnostic |

### B. Explicitly Excluded Components
- **Billing & Finance:** `Payment__c`, `patientBilling` LWC (Not relevant to TC-01–TC-08).
- **Appointment Lifecycle:** `Appointment__c`, `Appointment_Slot__c`, `Cancellation__c`, `CancellationService`, `AppointmentTrigger`, `appointmentWizard` LWC, `slotPicker` LWC, `myAppointments` LWC, `doctorSearch` LWC.
- **Batch Jobs for SMS/No-Show:** `ReminderSmsJob`, `NoShowBatch`, `PendingExpiryBatch`.
- **Experience Cloud:** `Network`, `CustomSite`, digital experience bundles.
- **Flows:** `CareNest_Appointment_Daily_Reminder.flow`, `CareNest_Appointment_Confirmed.flow`, `CareNest_Cancel_Appointment.flow`.
- **Agentforce:** `EinsteinServiceAgent User`, bot configurations.

---

## 6. Synthetic Persona and Licensing Feasibility

### A. Persona Matrix for Secondary Developer Edition Org

In a standard free Developer Edition org:
- **1 Admin User** is consumed upon org signup (`System Administrator`, Standard `Salesforce` license).
- **1 Standard `Salesforce` User License** remains available.
- **3 to 5 `Salesforce Platform` Licenses** are available.
- The CareNest permission sets (`CareNest_Doctor`, `CareNest_Front_Desk`, `CareNest_Ops_Manager`) are **license-agnostic** (contain no `<userLicense>` restriction), meaning they can be assigned to `Salesforce Platform` users!

| Persona ID | Role / Test Purpose | Required Permission Set | Recommended License | Distinct User Required? | Doctor Mapping Required? | Applicable Tests |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **P-ADM** | Org Admin / Deployment / Setup | System Administrator | Standard `Salesforce` (Signup User) | Yes | No | Pre/Post Setup, TC-08 |
| **P-ATT** | Attending Clinician | `CareNest_Doctor` | Standard `Salesforce` (or Platform) | Yes | **Doctor A** | TC-01, TC-05, TC-07 |
| **P-COV** | Covering Clinician | `CareNest_Doctor` | `Salesforce Platform` | Yes | **Doctor B** | TC-03, TC-04, TC-05 |
| **P-URL** | Unrelated Clinician | `CareNest_Doctor` | `Salesforce Platform` | Yes | **Doctor C** | TC-02 |
| **P-FDK** | Front-Desk Staff | `CareNest_Front_Desk` | `Salesforce Platform` | Yes | No | TC-06 |

### B. License Conservation & Concurrency Strategy
- **Option 1 (Concurrent Execution with Platform Licenses):** Provision P-ATT on the 1 remaining `Salesforce` license, and provision P-COV, P-URL, and P-FDK on `Salesforce Platform` licenses. All 4 non-admin personas can exist concurrently.
- **Option 2 (Sequential Execution on 1 Standard License):** If `Salesforce Platform` licenses are not desired, use 1 standard license sequentially: test P-ATT (TC-01, TC-05, TC-07), re-map username to Doctor B for P-COV (TC-03, TC-04), re-map to Doctor C for P-URL (TC-02), and assign `CareNest_Front_Desk` for P-FDK (TC-06).

---

## 7. Synthetic Data Plan (Isolated Environment Only)

All data is strictly fictional, synthetic, and prefixed with `TEST_SEC_`.

| Synthetic Record Type | Minimum Count | Purpose / Scenario Mapping | Relationships / Attributes |
| :--- | :--- | :--- | :--- |
| **`Contact` (Patient)** | 1 | Patient record for admission (`Pat_SecTest_01`) | Standard Patient contact |
| **`Ward__c`** | 1 | Ward container (`Ward_SecTest_01`) | Active = true |
| **`Bed__c`** | 1 | Bed container (`Bed_SecTest_01`) | Master-Detail to `Ward__c` |
| **`Doctor__c`** | 3 | Clinician placeholders: Doctor A (`Dr. Alpha`), Doctor B (`Dr. Beta`), Doctor C (`Dr. Gamma`) | Linked to `P-ATT`, `P-COV`, `P-URL` |
| **`Admission__c`** | 2 | Admission 1: Active cross-cover (TC-01, TC-03, TC-05, TC-08)<br>Admission 2: Expired cross-cover (TC-04) | Linked to Patient, Bed, Doctor A & Doctor B |
| **`Inpatient_Encounter__c`** | 2 | Encounter records under Admission 1 and 2 | Linked to Admission, Attending Doctor |
| **`Patient_Vital__c`** | 2 | Vital records linked to Encounter 1 and 2 | Linked to Admission, Encounter |

---

## 8. Proposed Setup & Deployment Sequence

Every step is assigned an explicit governance classification:

```
[Phase 17B.8D Approved]
          │
          ▼
Step 1: Human signs up for new DE org at developer.salesforce.com [HUMAN ACTION REQUIRED]
          │
          ▼
Step 2: Human verifies email and sets password [HUMAN ACTION REQUIRED]
          │
          ▼
Step 3: Human authorizes CLI connection: `sf org login web -a carenest-sec-test` [HUMAN ACTION REQUIRED]
          │
          ▼
Step 4: Verify secondary org ID != 00Dg700000Cpr9pEAB [READ-ONLY SAFE]
          │
          ▼
Step 5: Query UserLicense in new org to confirm license counts [READ-ONLY SAFE]
          │
          ▼
Step 6: User explicitly approves clinical-security package deployment [EXPLICIT APPROVAL REQUIRED]
          │
          ▼
Step 7: Deploy package to secondary org only: `sf project deploy start --target-org carenest-sec-test` [MUTATING - SECONDARY ORG ONLY]
          │
          ▼
Step 8: Run `ClinicalSharingTest` in secondary org to verify baseline health [MUTATING - SECONDARY ORG ONLY]
          │
          ▼
Step 9: User approves synthetic user and record provisioning [EXPLICIT APPROVAL REQUIRED]
          │
          ▼
Step 10: Provision P-ATT, P-COV, P-URL, P-FDK & synthetic records [MUTATING - SECONDARY ORG ONLY]
          │
          ▼
Step 11: Execute TC-01 through TC-08 & save evidence logs [MUTATING - SECONDARY ORG ONLY]
          │
          ▼
Step 12: Verify test pass/fail results & capture evidence artifacts [READ-ONLY SAFE]
          │
          ▼
Step 13: Execute teardown script or decommission secondary org [EXPLICIT APPROVAL REQUIRED]
```

---

## 9. Test Execution & Evidence Matrix (TC-01 through TC-08)

| Test ID & Title | Persona(s) | Records Required | Preconditions & Steps | Expected Result | Evidence & Suggested Artifact |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-01: Attending Clinician Access** | `P-ATT` (`CareNest_Doctor`) | Doctor A, Admission 1, Encounter 1, Vital 1 | Log in as P-ATT. Query Encounter & Vital; update Clinical Note. | Record returned; update succeeds. | CLI output: `tc01_attending_access_success.json` |
| **TC-02: Unrelated Clinician Restriction** | `P-URL` (`CareNest_Doctor`) | Doctor C, Admission 1, Encounter 1 | Log in as P-URL. Query Encounter 1. | 0 records returned (`INVALID_CROSS_REFERENCE_KEY`). | CLI output: `tc02_unrelated_zero_records.json` |
| **TC-03: Covering Clinician Active Access** | `P-COV` (`CareNest_Doctor`) | Doctor B, Admission 1 (active cover window) | Log in as P-COV. Query `Inpatient_Encounter__Share` & `Patient_Vital__Share`. | Shares exist (`RowCause = Care_Team__c`, `Read`); records readable. | CLI output: `tc03_covering_active_shares.json` |
| **TC-04: Covering Expiry Revocation** | `P-COV` (`CareNest_Doctor`) | Doctor B, Admission 2 (expired cover window) | Run reconciliation. Log in as P-COV; query Encounter 2 & Vital 2. | `Care_Team__c` shares deleted; 0 records returned. | CLI output: `tc04_covering_expired_purged.json` |
| **TC-05: Discharge Protection & Downgrade** | `P-ATT`, `P-COV` | Doctor A, B, Admission 1 | Set `Status__c = 'Discharged'`. Attempt vital insert as P-ATT; query as P-COV. | Vital insert blocked; P-ATT read-only; P-COV shares deleted. | CLI output: `tc05_discharge_protection.json` |
| **TC-06: Front-Desk Clinical Restriction** | `P-FDK` (`CareNest_Front_Desk`)| Encounter 1, Vital 1 | Log in as P-FDK. Query Encounter & Vital. | Zero records returned / insufficient privileges. | CLI output: `tc06_frontdesk_restricted.json` |
| **TC-07: Doctor Mapping Immutability** | `P-ATT` (`CareNest_Doctor`) | Doctor A | Attempt update on `Doctor__c.User__c` under P-ATT session. | Blocked with `INSUFFICIENT_ACCESS_OR_READONLY`. | CLI output: `tc07_mapping_immutable.json` |
| **TC-08: Reconciliation Idempotency** | `P-ADM` / System | Admission 2 (expired cover) | Execute `reconcileCrossCoverShares` twice. Query shares. | Attending shares = 1; expired shares = 0 across runs. | CLI output: `tc08_reconciliation_idempotent.json` |

---

## 10. Technical Risks, Limitations, & Open Questions

1. **User License Limitations in Developer Edition:**
   - *Risk:* If the newly signed-up Developer Edition org restricts `Salesforce Platform` licenses from accessing custom objects with Apex Sharing reasons, sequential testing on the single remaining `Salesforce` license will be required.
   - *Mitigation:* Step 5 verifies available licenses immediately after org authentication.
2. **Standard Object Dependencies:**
   - *Risk:* `Admission__c` has a lookup to `Contact`. In vanilla DE orgs, `Contact` is present by default, but any custom fields on `Contact` referenced in CareNest code must be deployed.
3. **Session Management for CLI Non-Admin Testing:**
   - *Risk:* Testing as distinct non-admin users via CLI requires either authenticating each user alias via web login (`sf org login web -a carenest-attending`) or generating front-door login URLs via `sf org generate password` / `sf org open`.
4. **Clean Org Boundary Guarantee:**
   - Because all mutating actions target `carenest-sec-test`, the live `carenest` org (`00Dg700000Cpr9pEAB`) remains 100% isolated and protected.

---

## 11. Exact Approvals Required Before Any Execution

No setup or mutating action may begin without the following explicit approvals:
1. **Approval of this Readiness Plan:** Formal approval of the metadata scope, persona strategy, and setup sequence.
2. **Approval of Human Signup:** User authorization to sign up for a free Developer Edition org at developer.salesforce.com.
3. **Approval to Authenticate:** User authorization to connect the new org to the CLI under alias `carenest-sec-test`.
4. **Approval to Deploy:** User authorization to deploy the clinical-security package to `carenest-sec-test`.

---

## 12. Safety & Integrity Statement

**I confirm that:**
- Zero Salesforce orgs were created, registered, authorized, or authenticated during this phase.
- Zero metadata was deployed, pushed, validated, or retrieved.
- Zero Apex tests, batch jobs, or data mutations were executed.
- The live Salesforce org `00Dg700000Cpr9pEAB` remains completely untouched.
- Git baseline `249c65a665cb594c136d6f59f2986a012147409f` and all pre-existing files are preserved.
- This deliverable was created as an uncommitted file: `docs/phase-17B.8D-secondary-developer-org-readiness-plan.md`.
