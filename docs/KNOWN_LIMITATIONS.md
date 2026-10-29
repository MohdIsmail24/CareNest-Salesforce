# CareNest HMS — System Boundaries, Design Trade-Offs & Known Limitations

**Project:** CareNest Hospital Management System  
**Audience:** Technical Reviewers, Auditors & Hiring Managers  

---

## 1. Portfolio Demonstration Scope

CareNest is engineered as an enterprise-grade reference architecture demonstrating advanced Salesforce Developer, Administrator, and Agentforce capabilities. 

To maintain strict ethical, legal, and security boundaries, CareNest is presented as a demonstration and educational reference implementation, not as a certified commercial Medical Device or live Electronic Health Record (EHR) software.

---

## 2. Key System Boundaries & Limitations

### 2.1 Simulated In-Clinic Cashier POS Desk
* **Current Behavior:** The `patientBilling` component and `Payment__c` object simulate counter collections (Cash, UPI, Card, Net Banking) directly in Salesforce with cashier receipt references.
* **Scope Boundary:** Live external payment gateway callouts (e.g., Stripe, Razorpay, or Authorize.net webhook integrations) are explicitly out of scope.
* **Rationale:** Prevents exposure of live merchant API keys and eliminates PCI-DSS compliance liabilities in demonstration environments.

### 2.2 Synthetic Demonstration Data
* **Current Population:** CareNest contains synthetic demonstration records (114 enrolled synthetic patient contacts, 12 credentialed physicians, 42 physical beds across 5 wards with 20 active admissions, 19 available, 2 cleaning, and 1 maintenance).
* **Compliance & Privacy:** All patient email addresses utilize reserved domain names (`*.example.com`, `*.example.org`, `*.example.net`) in strict compliance with IETF RFC 2606. Patient names, phone numbers, addresses, and clinical telemetry are entirely synthetic, fictional records generated solely for software testing and demonstration purposes. Zero real patient Personally Identifiable Information (PII) or Protected Health Information (PHI) exists in this repository.

### 2.3 Regulatory Compliance Patterns vs. Formal Certification
* **Architectural Patterns Implemented:**
  * Zero-Trust Stage 2 RBAC.
  * Organization-Wide Defaults set to Private.
  * Programmatic row-level sharing for attending clinicians.
  * Platform event-driven audit logging for errors and record updates.
  * Agentforce deterministic safety guardrails and emergency escalation guidance.
* **Limitation:** While CareNest incorporates architectural patterns required by HIPAA (United States) and DISHA (Digital Information Security in Healthcare Act - India), it has not undergone formal third-party SOC 2 Type II or FDA medical software certification audits.

### 2.4 Multi-Tenant Governor Limits & Volume Boundaries
* **SOQL / DML Design:** All trigger handlers and domain services are bulkified to handle standard Salesforce execution limits (up to 200 records per trigger execution, 50,000 query rows, and 10,000 DML rows).
* **Large Data Volume (LDV) Scaling:** If hospital patient populations scale beyond 5,000,000 records, future architectural evolutions would require Salesforce Big Objects or Data Cloud archival strategies for historical vital sign telemetry.

### 2.5 Agentforce LLM Model Dependencies
* **Current Configuration:** Invocable actions operate deterministically with explicit validation filters and rule-based safety triage.
* **Limitation:** In organizations where generative Agentforce LLMs are connected, prompt responses are subject to standard large language model nondeterminism. CareNest mitigates this by requiring all transactional changes (cancellations, doctor bookings) to execute through typed Invocable Actions rather than unconstrained generative SQL.
