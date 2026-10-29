# CareNest — Technical Recruiter Case Study

**Project Name:** CareNest Hospital Management System (HMS)  
**Target Platform:** Salesforce Lightning Platform (Enterprise Edition)  
**Role:** Senior Salesforce Developer / Solution Architect  
**Key Competencies:** Advanced Apex, Concurrency Locking, LWC Architecture, Agentforce AI, Zero-Trust RBAC, Platform Events, Financial Reconciliation.

---

## 1. Executive Summary & Business Problem

Healthcare organizations frequently struggle with fragmented software stacks: outpatient scheduling systems operate in silos away from inpatient bed registries, bedside clinical telemetry is documented on paper or disconnected apps, and financial billing reconciliation requires tedious manual spreadsheet calculations.

Furthermore, high-volume clinic booking portals frequently suffer from **concurrency race conditions**, leading to embarrassing and legally fraught double-bookings where multiple patients schedule the same physician consultation slot.

### The Objective:
Design, develop, and deploy an enterprise-grade, native Salesforce healthcare solution that:
1. Coordinates the complete patient consultation lifecycle across outpatient (OPD) and inpatient (IPD) departments.
2. Guarantees concurrency safety during peak booking hours using database-level locking.
3. Protects sensitive Patient Health Information (PHI) through a Zero-Trust security model with programmatic row-level sharing.
4. Integrates autonomous **Agentforce AI** agents with strict ethical and medical safety guardrails.
5. Provides executive leadership with auditable financial analytics and a centralized hub of 16 certified Salesforce reports.

---

## 2. Technical Stack & Key Responsibilities

### Technologies Used:
- **Salesforce Platform:** Lightning Experience, Custom Objects, Record-Triggered & Screen Flows, Custom Metadata Types (`Cancellation_Policy__mdt`), Platform Events (`Error_Log_Event__e`).
- **Apex Development:** Domain Services, `TriggerHandler` Framework, Pessimistic Database Locking (`SELECT ... FOR UPDATE`), Batch Apex, Queueable Apex, Invocable Actions, Dynamic SOQL allowlists.
- **Frontend Architecture:** Lightning Web Components (14 LWCs), Shadow DOM, Lightning Message Service (`CareNestMessageChannel`), CustomEvents, SVG Data Visualizations, Responsive CSS Grid.
- **AI & Automation:** Salesforce Agentforce (`AgentforceEmployeeAgent`), Invocable Actions, Rule-Based Ethical Guardrails.
- **Quality Assurance & DevOps:** Salesforce CLI (`sf`), Node.js static AST test suites (205 tests), Playwright cross-viewport verification, SFDX manifest packaging.

### Core Architecture Responsibilities:
- Architected the end-to-end data model comprising 13 custom objects, 1 custom metadata type, 1 platform event, custom extensions on standard Contact, and 30 declarative validation rules.
- Engineered concurrency-safe slot and bed allocation logic in `AppointmentService.cls` and `CareNestAdmissionController.cls` utilizing pessimistic row-level locks (`SELECT ... FOR UPDATE`).
- Developed an asynchronous platform event logging service (`ErrorLogService.cls`) utilizing `PublishImmediately` events to capture errors outside standard DML transaction rollbacks.
- Implemented programmatic access delegation (`CareNestPatientAccessService.cls`) and custom object sharing (`ClinicalSharingService.cls`) granting dynamic record access to attending physicians and assigned ward nurses.
- Designed and verified the **Module 9: Reports Hub**, securely mapping all 16 certified CareNest Salesforce reports with server-side RBAC and client-side instant search.

---

## 3. Key Engineering Challenges & Solutions

### Challenge 1: Eliminating Race Conditions in High-Volume Booking
- **Problem:** If two patients attempt to book the last available slot with a specialist at the exact same millisecond, standard SOQL queries read `Booked_Count < Capacity` in both execution threads, resulting in an overbooking defect.
- **Solution:** Enforced pessimistic database locking in `AppointmentService.cls` using `SELECT Id, Capacity__c, Booked_Count__c FROM Appointment_Slot__c WHERE Id = :slotId FOR UPDATE`. The first thread locks the database row; parallel threads are blocked until the lock is released, ensuring atomic capacity validation.

### Challenge 2: Decoupled Exception Logging Across Database Rollbacks
- **Problem:** When an Apex transaction catches an exception and rolls back state (`Database.rollback(sp)`), synchronous database log records inserted within that same execution context are undone, losing diagnostic evidence.
- **Solution:** Implemented event-driven exception logging via Platform Event `Error_Log_Event__e` configured with `PublishImmediately` publish behavior. When `EventBus.publish()` executes prior to transaction rollback, the event message is dispatched to the Salesforce event bus independently of caller savepoints. An asynchronous subscriber trigger (`ErrorLogEventTrigger`) running under the Automated Process context sanitizes credentials and inserts `Error_Log__c` records out-of-transaction (subject to standard platform event delivery and trigger execution boundaries).

### Challenge 3: Enforcing Defensive AI Guardrails & Distinguishing Runtime Architecture
- **Problem:** Conversational AI models deployed in healthcare risk generating inaccurate medical diagnoses or offering treatment advice, introducing catastrophic liability.
- **Solution:** Developed 4 governed `@InvocableMethod` Apex actions (`DoctorSearchAction`, `WardAvailabilityAction`, `AppointmentStatusAction`, `CancelAppointmentAction`) for integration with Salesforce Agentforce. To provide a predictable, reproducible in-app demonstration within Lightning Experience, the `agentforceAssistantWidget` executes via `CareNestAssistantUIController.cls`, which evaluates deterministic keyword safety filters before invoking the action classes directly. Prompts containing clinical emergency terms (e.g. "chest pain", "trouble breathing", "prescribe", "diagnosis") trigger an immediate refusal, flag emergency status, and render national/local hotline escalation guidance (e.g., 112 in India, 911 / ext 4567 in standard demo fixtures).

### Challenge 4: Protecting Financial Telemetry Without Disrupting Clinical Workflows
- **Problem:** Nurses and outpatient doctors require access to patient clinical charts and ward beds but must be strictly blocked from viewing hospital collections, doctor revenue shares, or outstanding receivables.
- **Solution:** Enforced server-side Role-Based Access Control in `CareNestDashboardController.cls`. The controller queries `isUserAuthorizedAdmin()`; non-admin users receive a payload completely stripped of financial KPIs and sensitive report links. Standard Salesforce report folder permissions reinforce this security at the platform level. Governance is established across 9 project-managed Permission Sets (with a 10th system PermissionSet generated by the platform to back the `CareNest_Operations` Permission Set Group).

---

## 5. Quantitative Verification Evidence

| Quality Metric | Target Requirement | Measured Result | Verification Method |
|---|:---:|:---:|---|
| **Local Automated Suite** | 100% Pass | **226 / 226 PASSED (100%)** | `test_admin_analytics_local.js` (153), `test_careNestDashboardV2_local.js` (52), `test_phase23_local.js` (21) |
| **Org-Wide Apex Unit Tests** | >= 75% Coverage | **337 / 337 PASSED (88% Coverage)** | Org-wide Apex regression test run in target org `00Dg700000Cpr9pEAB` |
| **Targeted Admission Gate** | 100% Pass | **42 / 42 PASSED (100%)** | `CareNestAdmissionControllerTest`, `CareNestPatientSharingTest`, `CareNestDashboardControllerTest` |
| **Phase 23 Live Deployment** | Succeeded | **Succeeded (Job: 0Afg700000HFsUZCA1)** | `sf project deploy start` (2/2 components deployed, 0 errors) |
| **Check-Only Validation** | Succeeded | **Succeeded (Job: 0Afg700000HEGHfCAP)** | `sf project deploy validate` (dry run) |
| **Foreign Project Isolation**| 0 References | **0 MiniCare References** | Automated AST static scanner across all controllers and components |
| **Live UI & Usability Verification** | 0 Console Errors | **0 Errors (100% Responsive)** | Genuine live Playwright browser verification across desktop & mobile (390x844) |

---

## 6. Business Value & Impact

- **Operational Efficiency:** Consolidates 12 distinct clinic management touchpoints into a unified Lightning command center, reducing staff application switching.
- **Revenue Protection:** Reclaims abandoned appointment slots via automated hourly batches (`PendingExpiryBatch`), maintaining high outpatient chair utilization.
- **Clinical Governance:** Detects abnormal patient vitals in real time, alerting medical staff and enforcing documented physician review.
- **Audit Transparency:** Provides executive leadership with verified, audited accounting metrics distinguishing cleared collections, refund entitlements, and post-service open balances.

---

## 7. Portfolio Disclaimer

*CareNest is presented as a demonstration reference architecture showcasing advanced enterprise Salesforce engineering, data governance, and Agentforce capabilities. It operates on synthetic patient records and mock cashier desk flows, and is not certified for clinical diagnostic production use.*
