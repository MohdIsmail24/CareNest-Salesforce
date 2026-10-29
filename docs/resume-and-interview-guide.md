# CareNest — Resume Bullets & Technical Interview Guide

## 1. Resume Bullet Points

### Salesforce Developer Bullets (Advanced Apex & LWC)
1. **Architected and developed CareNest**, an enterprise-grade Hospital Management System on Salesforce Lightning, designing 13 custom objects, 1 custom metadata type, 1 platform event, 51 Apex classes, and 14 modular Lightning Web Components communicating via Lightning Message Service (LMS).
2. **Eliminated concurrent appointment and bed double-allocations** by implementing pessimistic row-level database locking (`SELECT ... FOR UPDATE`) across `AppointmentService.cls` and `CareNestAdmissionController.cls`, ensuring atomic capacity validation during peak clinic hours.
3. **Engineered an event-driven exception logging architecture** utilizing Platform Event `Error_Log_Event__e` (`PublishImmediately`), enabling diagnostic error publishing that survives caller savepoint rollbacks (`Database.rollback(sp)`) and processes via an asynchronous trigger handler.
4. **Developed a 6-step reactive admission intake wizard** in LWC enforcing mandatory Admission Type classification validation (`Emergency`, `Planned`, `Transfer`), dynamic ward capacity rollups, and zero-leak orphan contact intake.
5. **Achieved 100% test pass rate across 337 org regression tests** with 88% org-wide Apex code coverage and 226 automated local static AST checks, verified via Salesforce CLI (`sf`) and Playwright MCP.

### Salesforce Administrator Bullets (Governance, Security & Automation)
1. **Enforced a Zero-Trust security model** by configuring Private Organization-Wide Defaults across sensitive clinical objects (`Contact`, `Admission__c`, `Patient_Vital__c`, `Payment__c`), augmented by 9 project-managed Permission Sets (and 1 Permission Set Group) and programmatic Apex sharing services.
2. **Automated hospital operational governance** by deploying Record-Triggered Flows, hourly slot-reclamation scheduled batches (`PendingExpiryBatch`), and Custom Metadata Types (`Cancellation_Policy__mdt`) for dynamic, code-free refund policy administration.
3. **Designed and deployed a centralized Reports & Analytics Hub** mapping 16 certified CareNest Salesforce reports across dedicated folders, implementing server-side Role-Based Access Control to prevent non-administrative users from discovering or viewing sensitive financial telemetry.

### Agentforce AI Specialist Bullet
- **Integrated autonomous Agentforce AI capabilities** (`AgentforceEmployeeAgent` / InternalCopilot), developing four secure `@InvocableMethod` Apex actions for real-time doctor discovery and ward bed allocation, while implementing deterministic software guardrails that immediately refuse medical diagnostic liability and escalate emergencies to national and local hotlines (e.g., 112 in India, 911 / ext 4567 in standard demonstration fixtures).

---

## 2. Interview Elevator Pitch (Project Explanation)

> *"CareNest is an enterprise Hospital Management System I engineered natively on the Salesforce Lightning Platform. It coordinates the full end-to-end patient journey across outpatient consultations, inpatient ward and bed allocation, and bedside clinical telemetry.*
>
> *Technically, I focused heavily on concurrency safety, security, and enterprise architectural patterns. For example, to prevent race conditions during high-volume appointment bookings, I implemented pessimistic database row-locking using `SELECT ... FOR UPDATE` in our Apex domain services. I also established a Zero-Trust security framework with Private OWDs and programmatic Apex sharing, dynamically granting attending physicians and ward nurses row-level access during active admissions.*
>
> *For AI, I developed four governed Invocable Actions for Agentforce integration while building deterministic software guardrails to refuse diagnostic liability and escalate emergencies. Across the entire application, I maintained 100% test pass rates across 226 local static checks and our 337 org regression tests with 88% code coverage."*

---

## 3. Five Technical Interview Questions & Expert Answers

### Question 1: How did you prevent race conditions when multiple patients attempted to book the last available appointment slot simultaneously?
**Expert Answer:**
> *"In a multi-tenant cloud environment like Salesforce, two parallel execution threads reading an `Appointment_Slot__c` record at the same millisecond will both see available capacity before either commits, causing an overbooking defect.
> To prevent this, in `AppointmentService.cls` I executed a pessimistic database lock using `SELECT Id, Capacity__c, Booked_Count__c FROM Appointment_Slot__c WHERE Id = :slotId FOR UPDATE`.
> This places an exclusive database lock on the slot row. Any concurrent transaction attempting to access that record is placed into a queued wait state until the first transaction finishes its capacity validation, increments `Booked_Count__c`, and commits. If the slot reaches full capacity, the subsequent transaction immediately reads the updated state and throws a controlled `AppointmentException`, ensuring 100% concurrency safety without data corruption."*

### Question 2: Why did you use Platform Events for exception logging instead of simply inserting an `Error_Log__c` record in an Apex `catch` block?
**Expert Answer:**
> *"In standard Apex transaction processing, if an error occurs within a complex operation involving multiple DML statements, best practice dictates rolling back the transaction using `Database.rollback(sp)` to prevent partial state corruption.
> However, if you insert an error log record synchronously into the database within that same execution thread, rolling back the savepoint also erases the inserted log record, leaving developers with zero diagnostic evidence in production.
> To address this, I implemented `ErrorLogService.cls` using Platform Event `Error_Log_Event__e` configured with `PublishImmediately`. Because events published with `PublishImmediately` dispatch to the Salesforce event bus immediately upon calling `EventBus.publish()`, they are not revoked if the calling transaction subsequently executes `Database.rollback(sp)`. An asynchronous subscriber trigger (`ErrorLogEventTrigger`) running under the Automated Process context consumes the event, sanitizes sensitive tokens, and inserts an `Error_Log__c` record out-of-transaction."*

### Question 3: How does CareNest enforce security and least privilege across clinical vs. administrative personnel?
**Expert Answer:**
> *"We implemented a defense-in-depth model starting with Organization-Wide Defaults set to Private on all core healthcare objects, including `Contact` (Patients), `Admission__c`, `Patient_Vital__c`, and `Payment__c`.
> Instead of using monolithic user profiles, we built 9 modular Permission Sets (`CareNest_Admin`, `CareNest_Doctor`, `CareNest_Nurse`, `CareNest_Front_Desk`, etc.).
> To handle dynamic clinical shifts, we built programmatic Apex sharing services (`CareNestPatientAccessService` and `ClinicalSharingService`) that dynamically insert row-level `Admission__Share` records for attending physicians and assigned ward nurses, automatically revoking access upon patient discharge or shift expiry via `CrossCoverReconciliationBatch`.
> Finally, in our `CareNestDashboardController`, we enforce server-side RBAC: non-admin users have all financial KPIs and revenue report links completely stripped from their Lightning payload before it leaves the server."*

### Question 4: How did you implement and safeguard Agentforce AI within a healthcare application?
**Expert Answer:**
> *"We configured a native Agentforce bot (`AgentforceEmployeeAgent`) connected to four typed `@InvocableMethod` Apex classes: `DoctorSearchAction`, `AppointmentStatusAction`, `CancelAppointmentAction`, and `WardAvailabilityAction`.
> The most critical requirement in healthcare AI is ethical and legal liability protection: an AI agent must never diagnose conditions, prescribe medications, or delay emergency care.
> To guarantee safety, we built deterministic guardrails in `CareNestAssistantUIController.cls`. Before any prompt reaches the AI reasoning engine, we evaluate it against keyword safety filters. If a user asks for medical advice or describes emergency symptoms (e.g. chest pain, breathing difficulty), the system immediately halts execution, returns a standard refusal, flags `isEmergency = true`, and renders direct emergency hotline escalation (directing users to 112 in India, 911 / ext 4567 in standard demo fixtures). This serves as a defensive software liability guardrail rather than clinical triage."*

### Question 5: How does CareNest ensure clean data isolation between different projects sharing the same Salesforce org?
**Expert Answer:**
> *"In complex Salesforce environments, legacy or parallel projects can inadvertently bleed data into reports or dashboards if filters rely merely on naming conventions.
> In CareNest, we established strict multi-tenant data governance:
> First, all CareNest patient records enforce unique patient codes (`CN-P-###`) and verified provenance tracking.
> Second, we conducted an automated AST scan across all Apex controllers, LWC templates, and JavaScript files to verify zero references to foreign or legacy report IDs (such as MiniCare).
> Third, in `CareNestDashboardController`, all report discovery queries execute through explicit, hardcoded compile-time allowlists of developer names. The controller accepts no dynamic report ID parameters from the client, preventing any possibility of arbitrary URL redirection or cross-project data leakage."*

---

## 4. Real-World Business Value & Impact Summary

- **Eliminated Overbooking:** Concurrency locking prevents double-bookings, protecting physician schedules and clinical patient trust.
- **Reclaimed Lost Revenue:** Automated background batches (`PendingExpiryBatch`) release abandoned appointment slots after 2 hours, keeping clinic appointment utilization high.
- **Improved Clinical Response:** Bedside vital signs entry triggers real-time visual alerts for abnormal physiological thresholds, enabling early clinical intervention.
- **Unified Single-Screen Operations:** Consolidates 12 operational departments onto a single, high-performance Lightning Home page, eliminating context switching across multiple disconnected applications.
