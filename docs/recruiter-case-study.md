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
- Architected the end-to-end data model comprising 16 custom objects, master-detail relationships, and 30 declarative validation rules.
- Engineered concurrency-safe slot allocation logic in `AppointmentService.cls` utilizing pessimistic row-level locks.
- Developed an asynchronous platform event logging service (`ErrorLogService.cls`) guaranteeing error persistence across rolled-back transactions.
- Implemented programmatic row-level sharing (`CareNestPatientAccessService.cls`) granting dynamic record access to attending physicians and assigned ward nurses.
- Designed and verified the **Module 9: Reports Hub**, securely mapping all 16 certified CareNest Salesforce reports with server-side RBAC and client-side instant search.

---

## 3. Key Engineering Challenges & Solutions

### Challenge 1: Eliminating Race Conditions in High-Volume Booking
- **Problem:** If two patients attempt to book the last available slot with a specialist at the exact same millisecond, standard SOQL queries read `Booked_Count < Capacity` in both execution threads, resulting in an overbooking defect.
- **Solution:** Enforced pessimistic database locking in `AppointmentService.cls` using `SELECT Id, Capacity__c, Booked_Count__c FROM Appointment_Slot__c WHERE Id = :slotId FOR UPDATE`. The first thread locks the database row; parallel threads are blocked until the lock is released, ensuring atomic capacity validation.

### Challenge 2: Decoupled Exception Logging Across Database Rollbacks
- **Problem:** When an Apex transaction catches an exception and rolls back the database state (`Database.rollback()`), standard log records inserted within the same context are erased from the database.
- **Solution:** Implemented event-driven exception logging via Platform Event `Error_Log_Event__e`. Because Platform Events published via `EventBus.publish()` execute in an autonomous queue outside the primary database transaction, diagnostic records remain permanently committed regardless of transaction rollbacks.

### Challenge 3: Enforcing Ethical AI Boundaries & Safety Guardrails
- **Problem:** Conversational AI models deployed in healthcare risk generating inaccurate medical diagnoses or offering treatment advice, introducing catastrophic liability.
- **Solution:** Hardcoded deterministic clinical safety filters in `CareNestAssistantUIController.cls`. Any prompt containing medical emergency keywords (e.g. "chest pain", "trouble breathing", "prescribe", "diagnosis") triggers an immediate refusal, displays prominent emergency hotline extensions (`911 / 4567`), and halts AI execution.

### Challenge 4: Protecting Financial Telemetry Without Disrupting Clinical Workflows
- **Problem:** Nurses and outpatient doctors require access to patient clinical charts and ward beds but must be strictly blocked from viewing hospital collections, doctor revenue shares, or outstanding receivables.
- **Solution:** Enforced server-side Role-Based Access Control in `CareNestDashboardController.cls`. The controller queries `isUserAuthorizedAdmin()`; non-admin users receive a payload completely stripped of financial KPIs and sensitive report links. Standard Salesforce report folder permissions reinforce this security at the platform level.

---

## 5. Quantitative Verification Evidence

| Quality Metric | Target Requirement | Measured Result | Verification Method |
|---|:---:|:---:|---|
| **Local Automated Suite** | 100% Pass | **205 / 205 PASSED (100%)** | `test_admin_analytics_local.js` (153) & `test_careNestDashboardV2_local.js` (52) |
| **Apex Unit Tests** | 100% Pass | **8 / 8 PASSED (100%)** | `CareNestDashboardControllerTest.cls` |
| **SFDX Validation Dry-Run** | Succeeded | **Succeeded (Job: 0Afg700000Gh1E9CAJ)** | `sf project deploy start --dry-run` |
| **Permanent Deployment** | Succeeded | **Succeeded (Job: 0Afg700000Gfz38CAB)** | `sf project deploy start` (checkOnly = false) |
| **Foreign Project Isolation**| 0 References | **0 MiniCare IDs Found** | Automated AST static scanner across all files |
| **Cross-Viewport Testing** | Desktop, Tablet, Mobile | **100% Responsive** | Genuine live Playwright screenshots (1920x1080, 820x1180, 390x844) |

---

## 6. Business Value & Impact

- **Operational Efficiency:** Consolidates 12 distinct clinic management touchpoints into a unified Lightning command center, reducing staff application switching.
- **Revenue Protection:** Reclaims abandoned appointment slots via automated hourly batches (`PendingExpiryBatch`), maintaining high outpatient chair utilization.
- **Clinical Governance:** Detects abnormal patient vitals in real time, alerting medical staff and enforcing documented physician review.
- **Audit Transparency:** Provides executive leadership with verified, audited accounting metrics distinguishing cleared collections, refund entitlements, and post-service open balances.

---

## 7. Portfolio Disclaimer

*CareNest is presented as a demonstration reference architecture showcasing advanced enterprise Salesforce engineering, data governance, and Agentforce capabilities. It operates on synthetic patient records and mock cashier desk flows, and is not certified for clinical diagnostic production use.*
