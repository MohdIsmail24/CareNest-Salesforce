# CareNest — Enterprise Hospital Management System (HMS)

[![Salesforce Lightning](https://img.shields.io/badge/Salesforce-Lightning%20Platform-00A1E0?logo=salesforce&logoColor=white)](https://developer.salesforce.com/)
[![Apex & LWC](https://img.shields.io/badge/Stack-Apex%20%7C%20LWC%20%7C%20Flows-0176D3?logo=salesforce&logoColor=white)](https://developer.salesforce.com/)
[![Agentforce AI](https://img.shields.io/badge/Agentforce-AI%20Autonomous%20Actions-7F27FF?logo=salesforce&logoColor=white)](https://www.salesforce.com/agentforce/)
[![SFDX Architecture](https://img.shields.io/badge/Architecture-Enterprise%20SoC%20Patterns-0D9488)](docs/architecture.md)
[![Tests Passed](https://img.shields.io/badge/Automated%20Tests-205%20Passed%20(100%25)-10B981)](#testing--verification)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

**CareNest** is a full-featured, enterprise-grade Hospital Management System built natively on the **Salesforce Lightning Platform**. It unifies outpatient scheduling, inpatient bed allocation, bedside clinical telemetry, billing workflows, executive revenue analytics, and autonomous **Agentforce AI** agents into a centralized hospital command center.

---

## 🏛️ System Architecture

CareNest implements the **Separation of Concerns (SoC)** architectural pattern, cleanly isolating Presentation (LWC), Orchestration (Apex Controllers), Domain Services, Background Batches, and Database Security.

```mermaid
graph TD
    subgraph UI_Layer["Presentation Layer (Lightning Experience & LWCs)"]
        Nav["CareNest Master Command Center (careNestDashboardV2)"]
        M1["OPD Scheduling & Slot Picker"]
        M2["Inpatient Admissions & Discharges"]
        M3["Ward & Bed Capacity Manager"]
        M4["Clinical Charts & Vitals Telemetry"]
        M5["Agentforce AI Assistant Widget"]
        M6["Executive Revenue Analytics & Reports Hub"]
    end

    subgraph Service_Layer["Apex Domain & Application Services"]
        S_Appt["AppointmentService\n(Concurrency-Safe: SELECT ... FOR UPDATE)"]
        S_Canc["CancellationService\n(Custom Metadata Tiered Refund Engine)"]
        S_Adm["AdmissionService\n(Bed State Machine & Admission Tracking)"]
        S_Clin["ClinicalDocumentationService\n(Vitals Range Validation & Alert Engine)"]
        S_Share["CareNestPatientAccessService & ClinicalSharingService\n(Programmatic Apex Sharing)"]
        S_Log["ErrorLogService\n(Platform Event-Driven Decoupled Logging)"]
    end

    subgraph AI_Layer["Agentforce AI Engine"]
        Bot["CareNest Assistant Bot\n(AgentforceEmployeeAgent)"]
        Act1["DoctorSearchAction"]
        Act2["AppointmentStatusAction"]
        Act3["CancelAppointmentAction"]
        Act4["WardAvailabilityAction"]
    end

    subgraph DB_Layer["Salesforce Secure Database (Private OWD)"]
        Contact["Contact (Patient Master)"]
        Doctor["Doctor__c"]
        Slot["Appointment_Slot__c"]
        Appt["Appointment__c"]
        Payment["Payment__c"]
        Ward["Ward__c"]
        Bed["Bed__c"]
        Adm["Admission__c"]
        Vital["Patient_Vital__c"]
    end

    Nav --> M1 & M2 & M3 & M4 & M5 & M6
    M1 --> S_Appt & S_Canc
    M2 & M3 --> S_Adm
    M4 --> S_Clin
    M5 --> Bot
    Bot --> Act1 & Act2 & Act3 & Act4
    Act1 & Act2 & Act3 & Act4 --> S_Appt & S_Adm

    S_Appt & S_Canc --> Slot & Appt & Payment
    S_Adm --> Ward & Bed & Adm
    S_Clin --> Vital
    S_Share --> Contact & Adm
    S_Log --> DB_Layer
```

---

## 🏥 12 Integrated Operational Modules

CareNest provides a single, unified workspace for hospital leadership, clinicians, nurses, and administrative personnel:

| # | Module Name | Primary Responsibilities |
|---|---|---|
| **1** | **Hospital Command Center** | Real-time hospital telemetry, total bed occupancy (45.2% across 42 physical beds), inpatient census (19 active admissions), and live emergency hotline integration. |
| **2** | **Executive Revenue Analytics** | 7 financial metrics and visualizations: Recorded Successful Collections, Collections Less Refund Obligations, Refund Entitlements, Post-Service Open Balances, Accrued Inpatient Bed Charges, Department Revenue Distribution progress chart, and Post-Service Receivables Aging 4-bucket breakdown. |
| **3** | **Patient Registry Workspace** | Intake management, demographic lookup, duplicate prevention, and medical history navigation. |
| **4** | **Doctors & Staff Directory** | Physician rosters, clinical departments (General Medicine, Cardiology, Paediatrics, Orthopaedics, ENT, Dermatology), and fee schedules. |
| **5** | **Outpatient Appointments (OPD)** | 4-step guided booking wizard (`appointmentWizard`) with reactive date-filtered slot selection (`slotPicker`). |
| **6** | **Inpatient Admissions (IPD)** | Bed reservation, attending doctor assignment, clinical diagnosis capture, and length-of-stay tracking. |
| **7** | **Ward & Bed Capacity Manager** | Interactive floor plan managing ward capacities, bed statuses (`Available`, `Occupied`, `Maintenance`, `Cleaning`), and census rollups. |
| **8** | **Clinical Charts & Vitals** | Bedside vital signs entry, physiological range checks, abnormal alert flagging, and physician consultation documentation (`Inpatient_Encounter__c`). |
| **9** | **Reports & Analytics Hub** | Centralized access to **16 certified CareNest Salesforce Reports** across Financial Analytics, Hospital Operations, Clinical & Physician, and Additional Operations. |
| **10** | **Cashier Desk & Patient Billing** | POS desk modal supporting simulated Cash, Card, and UPI settlements, invoice receipt rendering, and balance reconciliation. |
| **11** | **Agentforce AI Assistant** | Autonomous AI copilot (`agentforceAssistantWidget`) executing governed Invocable Actions with hardcoded clinical emergency safety guardrails. |
| **12** | **System Health & RBAC Audit** | Administrative audit logs, platform event error feeds, and Zero-Trust Role-Based Access Control monitoring. |

---

## 💻 Technology Stack

- **Platform:** Salesforce Lightning Experience (API v61.0 / v68.0)
- **Backend Languages:** Apex (Domain Services, Triggers, Batch Apex, Queueable Apex, Schedulable Apex)
- **Frontend Framework:** Lightning Web Components (LWC), Shadow DOM, Lightning Message Service (LMS), SVG Data Visualizations
- **AI & Automation:** Salesforce Agentforce (`AgentforceEmployeeAgent`), Invocable Apex Actions, Record-Triggered Flows, Scheduled Flows, Screen Flows
- **Configuration & Rules:** Custom Metadata Types (`Cancellation_Policy__mdt`), 30 Declarative Validation Rules, Custom Permissions
- **Security & Data:** Organization-Wide Defaults (OWD), Programmatic Apex Sharing, 9 Permission Sets, Platform Events (`Error_Log_Event__e`)
- **Testing & Tooling:** Salesforce CLI (`sf`), Node.js Static AST Test Suites (205 tests), Playwright MCP for Cross-Viewport Verification

---

## 🔒 Security Architecture & Zero-Trust RBAC

CareNest strictly enforces the principle of least privilege:
- **Baseline Privacy:** Core healthcare objects (`Contact`, `Admission__c`, `Inpatient_Encounter__c`, `Patient_Vital__c`, `Payment__c`, `Appointment__c`) are configured with **Private** Organization-Wide Defaults.
- **Programmatic Apex Sharing:** Attending doctors and ward nurses are dynamically granted row-level access upon patient admission (`CareNestPatientAccessService` & `ClinicalSharingService`), automatically revoked upon discharge.
- **Server-Side Financial Security:** Non-admin users are strictly filtered on the server side in `CareNestDashboardController`. Sensitive revenue metrics and financial report links are excluded from Lightning payloads for non-administrative roles.
- **Data Isolation:** Cleanly isolated from legacy or external project data (e.g. MiniCare) with zero references to foreign report IDs or shared patient IDs.

---

## 📸 Authentic Application Screenshots

All screenshots are captured directly from live Salesforce execution (`/lightning/app/c__CareNest`):

| View | Screenshot Preview | Detailed Description |
|---|---|---|
| **Unified Command Center** | [![Command Center](docs/screenshots/01_unified_home.png)](docs/screenshots/01_unified_home.png) | High-level hospital operational telemetry, live bed count, and navigation. |
| **Executive Admin Overview** | [![Admin Overview](docs/screenshots/02_admin_overview.png)](docs/screenshots/02_admin_overview.png) | High-precision accounting KPIs and executive command center. |
| **Revenue Analytics Graphs** | [![Revenue Charts](docs/screenshots/03_revenue_analytics.png)](docs/screenshots/03_revenue_analytics.png) | Collections by department and post-service receivables aging breakdown. |
| **Reports & Analytics Hub** | [![Reports Hub](docs/screenshots/11_reports_hub.png)](docs/screenshots/11_reports_hub.png) | 16 certified Salesforce reports with search, category filtering, and direct links. |
| **Inpatient Admissions** | [![Admissions](docs/screenshots/08_inpatient_admissions.png)](docs/screenshots/08_inpatient_admissions.png) | Inpatient admission intake workspace, bed allocation, and attending clinician. |
| **Ward & Bed Manager** | [![Ward Bed Manager](docs/screenshots/07_ward_bed_management.png)](docs/screenshots/07_ward_bed_management.png) | Ward capacity distribution, bed state transitions, and vacancy tracking. |
| **Clinical Charts & Alerts** | [![Clinical Charts](docs/screenshots/09_clinical_charts_alerts.png)](docs/screenshots/09_clinical_charts_alerts.png) | Bedside vitals telemetry, physiological range checks, and active alert triage. |
| **Cashier & Billing Desk** | [![Billing](docs/screenshots/10_billing_and_payments.png)](docs/screenshots/10_billing_and_payments.png) | Outpatient payment settlement modal (Cash, Card, UPI) and receipt generation. |
| **Agentforce AI Assistant** | [![Agentforce](docs/screenshots/13_agentforce_assistant.png)](docs/screenshots/13_agentforce_assistant.png) | Autonomous copilot interface with safety guardrails and doctor discovery. |
| **Mobile Responsive Layout** | [![Mobile View](docs/screenshots/14_mobile_responsive_view.png)](docs/screenshots/14_mobile_responsive_view.png) | Fully responsive mobile navigation drawer and single-column cards (390x844). |

---

## 🧪 Testing & Verification

CareNest maintains 100% pass rates across local static analysis suites and cloud Apex unit tests:

```
=================================================================
 LOCAL AUTOMATED TEST SUITES (205 / 205 CHECKS PASSED - 100%)
=================================================================
 scripts/test_admin_analytics_local.js    : 153 / 153 PASSED (0 failures)
 scripts/test_careNestDashboardV2_local.js:  52 /  52 PASSED (0 failures)

=================================================================
 APEX UNIT TEST VERIFICATION (8 / 8 APEX TESTS PASSED - 100%)
=================================================================
 CareNestDashboardControllerTest.cls:
   - testFilterVariations                        [PASS] (1323 ms)
   - testGetAdminOverviewAnalytics_Authorized    [PASS] (497 ms)
   - testGetAdminOverviewAnalytics_NonAdminDenied[PASS] (110 ms)
   - testGetDashboardMetrics                     [PASS] (373 ms)
   - testGetRecentActivities                     [PASS] (269 ms)
   - testGetReportsHubReports_Admin              [PASS] (114 ms)
   - testGetReportsHubReports_NonAdmin           [PASS] (113 ms)
   - testGetWardSummaries                        [PASS] (153 ms)
```

- **Validation Dry-Run Job ID:** `0Afg700000Gh1E9CAJ` (`checkOnly = true`, Succeeded)
- **Permanent Deployment Job ID:** `0Afg700000Gfz38CAB` (`checkOnly = false`, Succeeded)

---

## 🚀 Setup & SFDX Deployment Instructions

### Prerequisites
- [Salesforce CLI (`sf`)](https://developer.salesforce.com/tools/salesforcecli) (v2.x or higher)
- A Salesforce Developer Edition, Scratch Org, or Sandbox

### 1. Authenticate Target Org
```powershell
sf org login web --alias carenest-dev --set-default
```

### 2. Deploy Metadata
Deploy the core metadata bundle using the tested manifest:
```powershell
sf project deploy start --manifest manifest/phase36-reports-hub-integration-package.xml --target-org carenest-dev --test-level RunSpecifiedTests --tests CareNestDashboardControllerTest --wait 60
```

### 3. Assign Permissions
Assign the Administrator permission set to your user:
```powershell
sf org assign permset --name CareNest_Admin --target-org carenest-dev
```

### 4. Open Application
```powershell
sf org open --path "/lightning/app/c__CareNest" --target-org carenest-dev
```

---

## 📚 Technical Documentation Index

Detailed engineering documentation is available in the [`docs/`](docs/) directory:
- [Architecture & Design Patterns](docs/architecture.md)
- [Data Model & ERD](docs/data-model.md)
- [Apex Development & Concurrency Control](docs/apex-development.md)
- [Lightning Web Components (LWC) Architecture](docs/lwc-components.md)
- [Automation, Flows & Event-Driven Engine](docs/automation.md)
- [Security Model & Zero-Trust RBAC](docs/security-model.md)
- [Agentforce AI Integration & Autonomous Actions](docs/agentforce.md)
- [Reports, Analytics & Financial Reconciliation](docs/reports-and-analytics.md)
- [Testing Strategy & CI/CD Lifecycle](docs/testing-and-deployment.md)
- [End-to-End Business Use Cases](docs/business-use-cases.md)
- [System Boundaries & Known Limitations](docs/known-limitations.md)
- [Recruiter Portfolio Case Study](docs/recruiter-case-study.md)
- [Resume Bullets & Interview Guide](docs/resume-and-interview-guide.md)

---

## ⚖️ Portfolio Disclaimer
CareNest is developed as an educational reference architecture demonstrating advanced Salesforce platform engineering, data governance, and Agentforce capabilities. It utilizes synthetic demonstration records and mock payment desk flows. It is not certified for clinical diagnostic production deployment.
