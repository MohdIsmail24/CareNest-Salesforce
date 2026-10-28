# CareNest HMS — Recruiter & Interview Showcase Guide

**Project:** CareNest Hospital Management System  
**Audience:** Technical Recruiters, Salesforce Hiring Managers, Solution Architects  
**Application URL:** `/lightning/app/c__CareNest`  

---

## 1. 5-Minute Executive Walkthrough

This demo script is tailored to showcase advanced Salesforce Development (LWC, Apex SoC, Concurrency, Dynamic SOQL), System Administration (Private OWD, RBAC, Reports), and Agentforce AI in an interview setting.

---

### Step 1: The Executive Command Center (`overview`)
* **What to Show:** Open `/lightning/app/c__CareNest`. Highlight the horizontal responsive navigation pills, sticky utility ribbon with real-time indicators, and 12 live KPI cards.
* **Key Talking Point:**  
  *"CareNest is a native Salesforce application built with clean Separation of Concerns. Notice the live Inpatient Census (20), Total Bed Inventory (42 across 5 wards), and 100% Passing Apex test gate. When clinical data changes anywhere in the hospital, the dashboard synchronizes instantly using reactive wire adapters."*

---

### Step 2: Patient Registration & Master Patient Index (`patients`)
* **What to Show:** Click `+ Register Patient` in the header.
* **Actions:**
  1. Show that the `Register & Save Patient` button is disabled until a valid Last Name is entered.
  2. Enter a fictional patient name (e.g., `Test_Recruiter Priya_Sharma`, phone `9876543210`).
  3. Click `Register & Save Patient`.
  4. Point out the toast: *"Successfully created patient (CN-PAT-00107)"*.
  5. Show that the patient immediately appears at the top of the Patient Registry with action buttons `Admit to Bed` and `Book OPD`.
* **Key Talking Point:**  
  *"Notice our Zero-Trust architecture: patient Contacts are created with AccountId set to null. This prevents commercial CRM account sharing rules from exposing protected health information. Access is managed exclusively through programmatic Apex sharing."*

---

### Step 3: Guided 6-Step Inpatient Admission Wizard (`admissions`)
* **What to Show:** Click `Admit to Bed` on the newly registered patient.
* **Actions:**
  1. **Step 1 (Patient):** Already complete with verified profile badge.
  2. **Step 2 (Ward):** Select **General Ward** (point out live occupancy and bed rollups).
  3. **Step 3 (Bed):** Point out that only available beds are listed (occupied and cleaning beds are strictly excluded). Select an available bed.
  4. **Step 4 (Doctor):** Select an attending physician (point out fee and verified schedule badge).
  5. **Step 5 (Clinical Details):** Point out the operator requirement to explicitly select an Admission Type (`Emergency`, `Planned`, or `Transfer`) and input a clinical reason.
  6. **Step 6 (Review & Confirm):** Review the 100% complete summary card and click `Confirm & Admit Patient`.
* **Key Talking Point:**  
  *"Under the hood, admission creation uses pessimistic locking (`SELECT ... FOR UPDATE`) to prevent bed double-allocation. The bed automatically transitions from Available to Occupied, and all ward rollups recalculate in real time."*

---

### Step 4: Bedside Clinical Operations & Urgent Vitals (`clinical`)
* **What to Show:** Click `Clinical Charts & Vitals`.
* **Actions:**
  1. Show the telemetry feed for admitted inpatients.
  2. Demonstrate how temperature, heart rate, blood pressure, and $\text{SpO}_2$ are flagged with Warning or Critical badges if they fall outside clinical thresholds.
* **Key Talking Point:**  
  *"Clinical telemetry includes automated threshold validation. Critical alerts dispatch platform events and automatically notify on-call ward nurses."*

---

### Step 5: Agentforce AI Clinical Copilot (`assistant`)
* **What to Show:** Click `Agentforce AI`.
* **Actions:**
  1. Click quick suggestion chip: `Check ICU Beds`.
  2. Notice the response: *"ICU currently has 3 available beds out of 6 total (50% occupancy)."*
  3. Click quick suggestion chip: `Find Cardiologists`.
* **Key Talking Point:**  
  *"CareNest integrates Salesforce Agentforce with 4 typed Invocable Actions (`DoctorSearchAction`, `WardAvailabilityAction`, `AppointmentStatusAction`, `CancelAppointmentAction`). These actions operate deterministically with strict clinical refusal guardrails."*

---

### Step 6: Certified Reports Hub & Executive Analytics (`reports` / `adminOverview`)
* **What to Show:** Click `Reports Hub` and `Executive Analytics`.
* **Actions:**
  1. Show the 16 native certified Salesforce reports organized into 4 distinct categories.
  2. In Executive Analytics, toggle between `Today`, `Last 7 Days`, and `This Month` to demonstrate instant SVG revenue trend adjustments.
* **Key Talking Point:**  
  *"Unlike mock portfolios, all 16 reports exist permanently in the Salesforce org, giving hospital executives verified visibility into financial, capacity, and clinical audit records."*
