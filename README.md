# CareNest — Salesforce Healthcare Operations Platform

CareNest is a modular outpatient clinic management application built natively on the Salesforce Lightning Platform. It coordinates the end-to-end patient consultation lifecycle—from doctor discovery and concurrency-safe appointment booking to simulated patient billing, tiered cancellations, and clinical visit logging.

---

## Architecture & Technical Overview

CareNest follows enterprise Salesforce architecture patterns, separating concerns across a robust data model, domain services, asynchronous batch workers, reactive Lightning Web Components (LWCs), and declarative flows.

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Lightning Experience UI                         │
│  ┌────────────────┐ ┌───────────────────┐ ┌──────────────────────────┐ │
│  │ c:doctorSearch │ │ c:appointment-    │ │   c:patientBilling       │ │
│  │                │ │   Wizard          │ │   (Simulated Demo Flow)  │ │
│  │                │ │ ┌───────────────┐ │ │                          │ │
│  │                │ │ │ c:slotPicker  │ │ │                          │ │
│  └───────┬────────┘ └─┴───────┬───────┴─┘ └──────────────────────────┘ │
│          │ LMS Channel        │                                        │
│          ▼                    ▼                                        │
│  ┌──────────────────────────────────────┐                              │
│  │       DoctorSearchController         │                              │
│  └──────────────────┬───────────────────┘                              │
└─────────────────────┼──────────────────────────────────────────────────┘
                      ▼
┌────────────────────────────────────────────────────────────────────────┐
│                        Core Apex Domain Services                       │
│  ┌──────────────────────────────────────┐ ┌──────────────────────────┐ │
│  │          AppointmentService          │ │   CancellationService    │ │
│  │  • FOR UPDATE Slot Capacity Lock     │ │   • Tiered Policy Engine │ │
│  │  • Doctor Consultation Fee Sync      │ │   • Refund Calculations  │ │
│  │  • Governed Discount Approvals       │ │   • Capacity Restoration │ │
│  │  • Slot Booked_Count Maintenance     │ │                          │ │
│  └──────────────────────────────────────┘ └──────────────────────────┘ │
└─────────────────────┬──────────────────────────────────────────────────┘
                      ▼
┌────────────────────────────────────────────────────────────────────────┐
│                         Database & Data Model                          │
│   Doctor__c ──< Appointment_Slot__c ──< Appointment__c ──< Payment__c   │
│                                                │                       │
│                                                ├──< Cancellation__c    │
│                                                └──< Visit_Record__c    │
└────────────────────────────────────────────────────────────────────────┘
```

### 1. Data Model
- **`Doctor__c`**: Outpatient physicians, departments, specialties, active status, and consultation fees.
- **`Appointment_Slot__c`**: Bookable calendar slots (OPD and Teleconsult), total capacity, booked count, and calculated availability.
- **`Appointment__c`**: Core appointment transaction linking patient (`Contact`) and slot, managing approval status, discounts, fee amounts, and balance due.
- **`Payment__c`**: Simulated transaction records linked to appointments with payment method, gateway transaction IDs, and settlement dates.
- **`Cancellation__c`**: Detailed cancellation audit trail capturing notice hours before appointment, tiered cancellation fees, refund amounts, and reasons.
- **`Visit_Record__c`**: Post-consultation clinical encounter records capturing chief complaints, follow-up flags, and follow-up dates.
- **`Error_Log__c`**: Asynchronous error logging object utilized by Flows and Apex exception handlers.

### 2. Apex Domain Services & Concurrency Safety
- **`AppointmentService.cls`**: Enforces concurrency-safe slot capacity locking using row-level locks (`SELECT ... FOR UPDATE`), preventing overbooking across simultaneous transactions. Handles automatic fee population, discount threshold validation, and synchronization of `Booked_Count__c`.
- **`CancellationService.cls`**: Evaluates tiered cancellation policies configured in `Cancellation_Policy__mdt` based on hours remaining before slot start, computes fees and refunds, logs cancellation audit records, and decrements slot counts.
- **`CancelAppointmentAction.cls`**: Invocable action exposing cancellation logic to Screen Flows and Agentforce.
- **`DoctorSearchController.cls`**: Unified AuraEnabled controller powering doctor search, date-filtered slot retrieval, patient search for clinic staff, booking execution, and patient portal security scoping.

### 3. Asynchronous Apex
- **`NoShowBatch.cls`**: Daily scheduled batch identifying past confirmed appointments without visit records and transitioning them to `No Show`.
- **`PendingExpiryBatch.cls`**: Hourly batch auto-cancelling unpaid pending bookings older than the configured expiry threshold.
- **`CareNestReminderScheduler.cls`**: Schedulable coordinator dispatching automated reminder notifications.
- **`ReminderSmsJob.cls`**: Queueable SMS notification worker with idempotency safeguards and race condition protections.

### 4. Lightning Web Components & UI
- **`c:doctorSearch`**: Searchable doctor directory with department picklists, fee badges, and Lightning Message Service (LMS) publication.
- **`c:slotPicker`**: Reactive slot picker responding to LMS events with date filtering and empty-state handling.
- **`c:appointmentWizard`**: 4-step guided booking wizard (Doctor/Slot selection, Staff patient lookup, Pricing review, Confirmation).
- **`c:patientBilling`**: Demonstration billing modal allowing simulated UPI, Card, and Cash counter flows with instant receipt rendering.
- **`c:myAppointments`**: Secure appointment list for authenticated portal patients with self-service cancellation dialogs.

### 5. Automation & Security
- **Flows**: Record-triggered confirmation workflows (`CareNest_Appointment_Confirmed`), daily reminders (`CareNest_Appointment_Daily_Reminder`), and staff cancellation screen flow (`CareNest_Cancel_Appointment`).
- **Validation Rules**: Past slot creation prevention, positive capacity enforcement, patient presence requirement, unapproved discount limits, and follow-up date validation.
- **Security Model**: Private sharing model with 6 granular Permission Sets (`CareNest_Doctor`, `CareNest_Front_Desk`, `CareNest_Ops_Manager`, `CareNest_Patient`, `CareNest_Agent_Actions`, `CareNest_Integration`) and Custom Permission `Approve_Discount`.

---

## Getting Started: Setup & Deployment

### Prerequisites
- [Salesforce CLI (`sf`)](https://developer.salesforce.com/tools/salesforcecli) (v2.x or higher)
- A Salesforce Developer Edition org, Trailhead Playground, or Scratch Org

### Step 1: Authenticate Your Org
```bash
sf org login web --alias carenest-dev --set-default
```

### Step 2: Deploy Source Metadata
Deploy all custom objects, Apex classes, triggers, flows, LWCs, layouts, and permissions:
```bash
sf project deploy start --source-dir force-app --target-org carenest-dev
```

### Step 3: Seed Demonstration Data
Seed synthetic demo doctors, patient contacts, appointment slots, appointments, and payments:
```bash
# On Linux / macOS / Git Bash:
./scripts/02_load_data.sh demo carenest-dev

# On Windows PowerShell:
sf data upsert bulk --sobject Doctor__c           --file data/demo/cli/doctors.csv           --external-id Registration_No__c --line-ending LF --target-org carenest-dev
sf data upsert bulk --sobject Contact             --file data/demo/cli/patients_contacts.csv --external-id Patient_Code__c    --line-ending LF --target-org carenest-dev
sf data upsert bulk --sobject Appointment_Slot__c --file data/demo/cli/appointment_slots.csv --external-id Slot_Code__c       --line-ending LF --target-org carenest-dev
sf data upsert bulk --sobject Appointment__c      --file data/demo/cli/appointments.csv      --external-id Appointment_Code__c --line-ending LF --target-org carenest-dev
sf data upsert bulk --sobject Payment__c          --file data/demo/cli/payments.csv          --external-id Gateway_Txn_Id__c  --line-ending LF --target-org carenest-dev
sf apex run --file scripts/apex/seed_cancellations_and_visits.apex --target-org carenest-dev
sf apex run --file scripts/apex/recalc_after_load.apex --target-org carenest-dev
```

### Step 4: Verify Deployment & Automated Tests
Execute the comprehensive Apex test suite:
```bash
sf apex run test --test-level RunLocalTests --wait 10 --result-format human --target-org carenest-dev
```
Expected result: **54 / 54 tests passing (100% pass rate, >90% code coverage)**.

---

## Demonstration Walkthrough

1. **Launch CareNest**: Open App Launcher (`9 dots`) and select **CareNest**. Navigate to the **CareNest Home** page.
2. **Select Doctor**: Under *Find a Doctor*, browse doctors by department (e.g. *Dr. Anil Mehta - Paediatrics*). Click **Select Doctor**.
3. **Choose Slot**: The *Book an Appointment* wizard receives the selection. Choose an available slot (e.g. *Oct 21, 2026, 10:00 AM*). Click **Next: Patient**.
4. **Search Patient**: In the staff patient search, enter a synthetic patient name (e.g., *Nazia Siddiqui* or code *CN-PAT-00001*). Click **Next: Review**.
5. **Confirm Booking**: Review doctor fee and discounts. Click **Confirm & Book Appointment**. Capacity is automatically decremented from the slot.
6. **Simulated Payment**: Click **Pay Bill (Demo Flow)**. Experience mock UPI, Card, or Cash flows.
7. **Cancel Appointment**: Open the created appointment record. Click the **Cancel Appointment** quick action to evaluate policy refund tiers and restore slot availability.

---

## Important Disclaimers

> [!WARNING]
> **Demonstration Flow — No Live Payments**  
> The payment interface in `c:patientBilling` is strictly an interactive simulation for testing and user-experience demonstration. No live payment gateway (Stripe, Razorpay, etc.) is connected, and no actual financial transactions or bank charges are processed. Never enter real credit cards, bank credentials, or UPI PINs.

> [!NOTE]
> **Synthetic Test Data Notice**  
> All records included in the `data/` directory—including patient names, email addresses, phone numbers, and addresses—are completely synthetic test fixtures. All email addresses utilize RFC 2606 reserved domains (e.g., `@example.com`). Any resemblance to real individuals or contact details is purely coincidental.

> [!IMPORTANT]
> **Compliance & Production Readiness**  
> CareNest is an architectural portfolio and proof-of-concept reference application. It is not certified for HIPAA, GDPR, or live clinical healthcare compliance, and is not intended for production healthcare use without comprehensive compliance audits, business associate agreements (BAAs), and healthcare infrastructure certification.

---

## License

This project is licensed under the MIT License - see the LICENSE file for details.
