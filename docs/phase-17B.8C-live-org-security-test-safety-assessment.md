# CareNest HMS — Phase 17B.8C Live-Org Security Test Safety Assessment

**Assessment Date/Time:** 2026-10-17T03:34:00+05:30  
**Project Workspace:** `C:\Users\hp\Downloads\carenest-salesforce-chunk1\carenest-salesforce`  
**Target Org Alias:** `carenest`  
**Target Org ID:** `00Dg700000Cpr9pEAB`  
**Org Edition:** `Developer Edition`  
**Git Baseline Commit:** `249c65a665cb594c136d6f59f2986a012147409f` (Branch `main`)  

---

## 1. Executive Summary & Objective

The objective of this assessment is to determine whether and how test cases **TC-01 through TC-08** (established in `phase17b8a_non_admin_security_test_plan.md`) can be tested safely within the existing CareNest Salesforce org (`00Dg700000Cpr9pEAB`), without violating protected baseline invariants.

This is a **strictly read-only assessment**. No test cases were executed, no Apex or anonymous scripts were run, no records were created or altered, and no metadata or Git changes were introduced.

---

## 2. Baseline Snapshot & Invariant Verification

A complete read-only audit of org and repository state was executed before planning:

| Invariant Item | Target Identifier / Object | Expected Baseline Value | Actual Measured Value | Evidence Source | Baseline Status |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Salesforce Org ID** | `Organization.Id` | `00Dg700000Cpr9pEAB` | `00Dg700000Cpr9pEAB` | `sf data query -q "SELECT Id FROM Organization"` | **PASS** |
| **Git Branch** | Active Branch | `main` | `main` | `git rev-parse --abbrev-ref HEAD` | **PASS** |
| **Git HEAD Commit** | Baseline Commit | `249c65a665cb...` | `249c65a665cb594c136d6f59f2986a012147409f` | `git rev-parse HEAD` | **PASS** |
| **Git Working Tree** | Tracked / Untracked files | 17 modified, 53 untracked | 17 modified, 53 untracked preserved | `git status --porcelain` | **PASS** |
| **Billing Ledger** | `Payment__c` Total Count | Exactly `69` | `69` | `SELECT COUNT(Id) cnt FROM Payment__c` | **PASS** |
| **Inpatient Admissions**| `Admission__c` Total Count | Exactly `0` | `0` | `SELECT COUNT(Id) cnt FROM Admission__c` | **PASS** |
| **Clinical Encounters** | `Inpatient_Encounter__c` Count | Exactly `0` | `0` | `SELECT COUNT(Id) cnt FROM Inpatient_Encounter__c` | **PASS** |
| **Patient Vitals** | `Patient_Vital__c` Count | Exactly `0` | `0` | `SELECT COUNT(Id) cnt FROM Patient_Vital__c` | **PASS** |
| **Doctor Total Count** | `Doctor__c` Total Records | Exactly `12` | `12` | `SELECT COUNT(Id) cnt FROM Doctor__c` | **PASS** |
| **Doctor User Mappings**| `Doctor__c WHERE User__c != null` | Exactly `0` | `0` (All 12 unmapped) | `SELECT COUNT(Id) cnt FROM Doctor__c WHERE User__c != null`| **PASS** |
| **Experience Cloud** | Network `0DBg7000002IgpFGAS` | `UnderConstruction` | `UnderConstruction` | `SELECT Id, Status FROM Network` | **PASS** |
| **Appointment Scheduler**| CronTrigger `08eg700000NJ1JiAAL` | `WAITING` | `WAITING` (Next: 2026-10-17 15:00 UTC) | `SELECT Id, State FROM CronTrigger` | **PASS** |
| **Reconciliation Batch**| CronTrigger `CrossCover...` | Unscheduled (`0`) | `0` scheduled | `SELECT Id FROM CronTrigger WHERE CronJobDetail.Name...`| **PASS** |

All baseline checks passed. The environment is verified in its expected pristine pre-implementation state.

---

## 3. Authoritative Test Case Definitions (TC-01 through TC-08)

Extracted verbatim from `phase17b8a_non_admin_security_test_plan.md`:

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

## 4. Per-Test Live-Org Safety Classification & Technical Analysis

| Test Case | Safety Classification | Existing Apex Coverage | Live Mutation Required? | Conflicts with Protected Rules? | Isolated Org Recommended? |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TC-01** (Attending Access) | **REQUIRES LIVE USERS OR RECORDS** | `ClinicalSharingTest` (Scenarios 1 & 11) | Yes (User, Doctor map, Admission, Encounter, Vital) | **YES** (Breaks zero-clinical-record invariant) | **YES** |
| **TC-02** (Unrelated Clinician) | **REQUIRES LIVE USERS OR RECORDS** | `ClinicalSharingTest` (Scenario 2) | Yes (2 Users, Doctor maps, clinical records) | **YES** (Breaks zero-clinical-record invariant) | **YES** |
| **TC-03** (Covering Active Window) | **REQUIRES LIVE USERS OR RECORDS** | `ClinicalSharingTest` (Scenarios 3 & 22) | Yes (2 Users, Doctor maps, active admission) | **YES** (Breaks zero-clinical-record invariant) | **YES** |
| **TC-04** (Covering Expiry Revocation)| **REQUIRES LIVE USERS OR RECORDS** | `ClinicalSharingTest` (Scenarios 4 & 14) | Yes (Users, expired admission, batch trigger) | **YES** (Breaks clinical invariant & batch restriction) | **YES** |
| **TC-05** (Discharge Downgrade) | **REQUIRES LIVE USERS OR RECORDS** | `ClinicalSharingTest` (Scenarios 5 & 10) | Yes (Users, admission status change to Discharged) | **YES** (Breaks zero-clinical-record invariant) | **YES** |
| **TC-06** (Front-Desk Restriction) | **REQUIRES LIVE USERS OR RECORDS** | `ClinicalSharingTest` (Scenario 6) | Yes (Front-desk user, clinical records) | **YES** (Breaks zero-clinical-record invariant) | **YES** |
| **TC-07** (Doctor User Immutability)| **SAFE TO PLAN / SYSTEM.RUNAS ONLY**| `ClinicalSharingTest` (Scenario 24) | No (Verified live via FLS query on PermissionSet)| **NO** (Can be confirmed via metadata query) | Optional |
| **TC-08** (Reconciliation Idempotency)| **REQUIRES LIVE USERS OR RECORDS** | `ClinicalSharingTest` (Scenario 23) | Yes (Requires synthetic shares & admissions) | **YES** (Breaks zero-clinical-record invariant) | **YES** |

### Detailed Rationale by Test:
1. **TC-01, TC-02, TC-03, TC-05, TC-06, TC-08:**
   - Proves record-level sharing and row-cause security.
   - Fully validated in Apex test execution under validation job `0Afg700000FfPgBCAV` using `System.runAs()`.
   - Running live in `carenest` requires creating synthetic User accounts (which cannot be deleted in Salesforce, only deactivated) and creating Admissions/Encounters/Vitals (violating the pristine zero-record baseline).
2. **TC-04:**
   - Proves batch cleanup of expired shares.
   - Conflicts not only with data invariants but also with the explicit operating rule: *Do not schedule or execute `CrossCoverReconciliationBatch`*.
3. **TC-07:**
   - Proves field-level immutability of `Doctor__c.User__c` for clinicians.
   - Deployed metadata and live org SOQL on `FieldPermissions` (`01kg70000SIGetQAQT`) already prove that `CareNest_Doctor` has `PermissionsRead = true` and `PermissionsEdit = false`. `ClinicalSharingTest.testCareNestDoctor_CannotEditDoctorUserMapping` confirms this via `Schema.sObjectType.Doctor__c.fields.User__c.isUpdateable() == false`.

---

## 5. Limits of `System.runAs` Versus Interactive Non-Admin Login Verification

| Dimension | `System.runAs()` Test Execution | Interactive End-User Session / UI Login |
| :--- | :--- | :--- |
| **Record-Level Sharing (SOQL)** | **Proven** (Enforces record sharing and RowCause) | Proven (Identical platform security enforcement) |
| **DML Access & Triggers** | **Proven** (Executes trigger logic under user context) | Proven (Executes trigger logic) |
| **Field-Level Security (FLS) in Apex** | **Not Enforced** unless using `WITH SECURITY_ENFORCED` or `isUpdateable()` | **Enforced** natively across all UI components |
| **Lightning Record Page Layouts** | **Not Tested** | **Tested** (Verifies read-only widget rendering) |
| **List Views & Search Filtering** | **Not Tested** | **Tested** (Verifies records are hidden in SOSL/List Views) |
| **Org Baseline Impact** | **Zero Impact** (All data automatically rolled back) | **Permanent Mutation** (Records persist unless deleted) |
| **User License Consumption** | **Zero Impact** (Simulated in test execution context) | **Exhausts Licenses** (Requires active User records) |

`System.runAs` provides rigorous, mathematically sound proof of database sharing calculations, trigger behavior, and programmatic access control. However, it does not evaluate UI rendering, browser session management, or page layout field accessibility.

---

## 6. Comparison of Verification Approaches

- **Approach A — Read-Only Inspection of Live Metadata & Field Permissions:**
  - *Pros:* Zero risk, zero mutations, instant verification.
  - *Cons:* Limited to metadata and schema inspection (covers TC-07 directly, but cannot prove dynamic runtime sharing for TC-01–TC-06 without records).
- **Approach B — Review of Existing Apex Test Source:**
  - *Pros:* Verifies logic assertions and test coverage.
  - *Cons:* Does not execute tests or prove live runtime behavior.
- **Approach C — Deployed Test Results from Validation Job `0Afg700000FfPgBCAV`:**
  - *Pros:* Fully executed in org `00Dg700000Cpr9pEAB`; 24/24 tests passed in 67.79s with 0 failures; verifies sharing recalculations, idempotency, batch execution, and FLS checks with 100% rollback.
  - *Cons:* Does not provide human interactive UI screenshots.
- **Approach D — Live-Org Non-Admin Testing in `carenest`:**
  - *Pros:* Exercises true end-user HTTP sessions.
  - *Cons:* **High Risk**; violates protected baseline invariants (Admissions = 0, Encounters = 0, Vitals = 0, Mapped Doctors = 0); exhausts standard user licenses (only 2 available); leaves permanent inactive user debris in production.

---

## 7. Recommended Test Strategy

### **RECOMMENDED: PRESERVE BASELINE VIA APPROACH C + DEFER LIVE INTERACTION TO ISOLATED ORG**

1. **Current Acceptance Baseline (Immediate):**
   - Accept the certified test results of **Job `0Afg700000FfPgBCAV`** (which validated all 24 scenarios of `ClinicalSharingTest`) together with the live **`FieldPermissions` SOQL audit** (`01kg70000SIGetQAQT`) as conclusive evidence that the clinical security architecture is correct, functional, and active in org `00Dg700000Cpr9pEAB`.
   - This maintains 100% compliance with all protected live-org invariants.
2. **Interactive UI Verification (Future Authorized Phase):**
   - Defer live-user interactive testing (TC-01 through TC-06, TC-08) until an isolated environment (such as a Developer Scratch Org spawned from an authenticated Dev Hub, or a dedicated secondary Developer Edition org) is provisioned.
3. **Contingency (If In-Org Live Testing is Explicitly Mandated by User):**
   - If the user explicitly directs live testing in `carenest`, require a dedicated **Phase 17B.8D Atomic Synthetic Fixture Protocol**:
     - Explicit approval to consume standard licenses or use `Force.com` licenses for test users.
     - Synthetic test data prefixed with `TEST_SEC_` and isolated within a single transaction.
     - Automated teardown script that hard-deletes synthetic clinical records and deactivates test users immediately upon test completion.

---

## 8. Live-Org Changes Requiring Separate Explicit Approval

Before any live-user test could execute in `carenest`, the following explicit approvals would be required:
1. **User Creation:** Approval to insert up to 3 non-admin test User records (consuming available licenses).
2. **Doctor User Mapping:** Approval to update `Doctor__c.User__c` on test doctor records.
3. **Clinical Record Mutation:** Approval to insert synthetic `Contact`, `Ward__c`, `Bed__c`, `Admission__c`, `Inpatient_Encounter__c`, and `Patient_Vital__c` records.
4. **Batch Scheduling:** Approval to run or schedule `CrossCoverReconciliationBatch`.

---

## 9. Risks, Open Questions, & Stop Certification

### Risks & Open Questions:
- **User License Starvation:** Only 2 standard Salesforce licenses remain unallocated in `carenest`. Full multi-persona testing requires Platform/Force.com licenses or user deactivation.
- **Orphaned User Records:** Salesforce users cannot be deleted once created; they can only be deactivated, permanently altering the user table.
- **Orchestration Triggers:** Inserting Admissions could interact with downstream bed or notification automations if synthetic data is improperly flagged.

### Safety Certification:
- Zero Apex tests, anonymous Apex, or unit tests were executed during this assessment.
- Zero records were created, updated, or deleted.
- Zero metadata components were modified or pushed.
- All 13 live-org invariants and Git baselines remain strictly verified and intact.
- Phase 17B.9 has **NOT** been started.
