# CareNest — Phase 09 Lightning Web Components Documentation

## 1. Overview
Phase 09 delivers the presentation and interaction layer for CareNest using Lightning Web Components (LWC). It establishes a modern, responsive clinic booking and appointment management user experience while strictly adhering to enterprise Salesforce security standards, explicit identity boundaries, and transactional integrity.

---

## 2. Architecture & Component Interaction

```
┌────────────────────────────────────────────────────────────────────────┐
│                        Lightning Message Service                       │
│                        (Doctor_Selected channel)                       │
└─────────────────────────────────▲──────────────────────────────────────┘
                                  │ Publishes doctorId & department
┌─────────────────────────────┐   │
│        doctorSearch         ├───┘
│  - Department filter        │
│  - Doctor name live search  │
│  - Doctor selection cards   │
└─────────────────────────────┘
                                  │ Subscribes to doctorId
┌─────────────────────────────┐   │
│         slotPicker          ├───┘
│  - Date & Mode filters      │
│  - Real-time slot cards     │
│  - Select slot & proceed    │
└──────────────┬──────────────┘
               │ Emits 'slotselect' event
┌──────────────▼──────────────┐
│      appointmentWizard      │
│  - Step 1: Doctor & Slot    │
│  - Step 2: Patient Select   │
│  - Step 3: Review & Pricing │
│  - Step 4: Booking Summary  │
└──────────────┬──────────────┘
               │
               ▼
┌────────────────────────────────────────────────────────────────────────┐
│                      DoctorSearchController (Apex)                     │
│  - WITH USER_MODE enforcement                                          │
│  - Server-side ID validation (SObjectType verification)                │
│  - Enforces User.ContactId authorization                               │
│  - Delegates concurrency locking & capacity to AppointmentService      │
│  - Delegates cancellation policy & refund to CancellationService       │
└────────────────────────────────────────────────────────────────────────┘
                                  ▲
┌─────────────────────────────┐   │ Wire & Imperative Apex
│       myAppointments        ├───┘
│  - Authenticated patient    │
│  - Booking status badges    │
│  - Policy cancellation modal│
│  - Identity error boundary  │
└─────────────────────────────┘
```

---

## 3. Component Catalog

### 1. `Doctor_Selected` (Lightning Message Channel)
- **Path**: `force-app/main/default/messageChannels/Doctor_Selected.messageChannel-meta.xml`
- **Fields**:
  - `doctorId` (String): Salesforce Record ID of the selected `Doctor__c`.
  - `department` (String): Department of the selected doctor.
- **Role**: Decoupled, publish-subscribe communication allowing `doctorSearch` and `slotPicker` to be placed anywhere on an App Page, Record Page, or Home Page.

### 2. `DoctorSearchController` & `DoctorSearchControllerTest` (Apex Controller Layer)
- **Path**: `force-app/main/default/classes/DoctorSearchController.cls`
- **Security & Sharing**: `with sharing`, all SOQL queries and DML executed `WITH USER_MODE`.
- **Identity & Authorization Enforcement**:
  - `getUserContext`: Returns current user session context (`isPortalUser`, `contactId`, `contactName`).
  - `getDoctors`: Server-side filtered query returning active doctors.
  - `searchSlots` & `getDoctorSlots`: Dynamic SOQL with bind variables returning wrapped `SlotOption` DTOs.
  - `searchPatients`: Staff-only patient query (minimum 2 characters required; returns Contacts with `Patient_Code__c != null`).
  - `bookAppointment`: Validates `Appointment_Slot__c` and `Contact` IDs server-side. For portal patients, automatically binds `User.ContactId` to prevent impersonation. Pricing (fee, discount, totals) is not trusted from the client and is automatically managed by the Phase 07 `AppointmentService` domain layer.
  - `getMyAppointments`: Explicitly queries `User.ContactId`. If `ContactId` is null, throws an `AuraHandledException` to prevent unauthenticated record exposure.
  - `cancelAppointment`: Verifies patient record ownership for portal users. Returns a typed `CancelResultDto` wrapping `CancellationService.CancellationResult`.
- **Unit Test Coverage**: `DoctorSearchControllerTest` achieves 82% coverage with 10 passing tests across positive, negative, and permission-boundary scenarios.

### 3. `doctorSearch` (LWC)
- **Path**: `force-app/main/default/lwc/doctorSearch/`
- **Features**:
  - Dynamic department dropdown populated with validated picklist entries.
  - Live doctor name search input with debouncing.
  - Card-based doctor listing with specialty, department badge, and consultation fee.
  - Publishes doctor selection via LMS (`Doctor_Selected`).
  - Targets: App Page, Record Page, Home Page, Experience Cloud (`lightningCommunity__Page`, `lightningCommunity__Default`).

### 4. `slotPicker` (LWC)
- **Path**: `force-app/main/default/lwc/slotPicker/`
- **Features**:
  - Subscribes to LMS `Doctor_Selected`.
  - Filter by consultation mode (`All`, `OPD`, `Teleconsult`) and date.
  - Interactive slot grid with start/end time, mode badge, and remaining capacity counter.
  - Dispatches `slotselect` CustomEvent payload with full slot and doctor details.
  - Empty-state illustrations and loading indicators.

### 5. `appointmentWizard` (LWC)
- **Path**: `force-app/main/default/lwc/appointmentWizard/`
- **Architecture**: 4-step guided progression (`lightning-progress-indicator`):
  1. **Select Slot**: Integrates `doctorSearch` and `slotPicker` with live doctor and slot selection.
  2. **Select Patient**: Context-aware identity resolution. For portal users, locks patient to authenticated profile; for internal staff, provides debounced patient lookup by Patient Code, Name, or Phone.
  3. **Review & Confirm**: Displays doctor, specialty, time, mode, fee, and patient summary.
  4. **Confirmation**: Displays confirmed appointment number (`AP-XXXXX`), status badge, and one-click reset action.
- **Defensive Error Handling**: Catches slot concurrency collisions (`AuraHandledException`) and displays actionable user alerts.

### 6. `myAppointments` (LWC)
- **Path**: `force-app/main/default/lwc/myAppointments/`
- **Features**:
  - Card grid displaying patient appointments with status badges (`Confirmed`, `Pending`, `Cancelled`, `Completed`, `No Show`).
  - Formatted currency values for Total Fee, Amount Paid, and Balance Due.
  - One-click cancellation modal with mandatory cancellation reason entry.
  - Invokes `DoctorSearchController.cancelAppointment` and surfaces calculated cancellation fees and refunds.
  - Auto-refreshes using `refreshApex`.
- **Identity Dependency & Graceful Fallback**: If accessed by an internal user whose `User.ContactId` is null, displays an informative security notice: *"Patient Portal Access Required: Your current user account does not have an associated patient contact profile (ContactId)"*.

---

## 4. Security & Governance Review

| Security Principle | Implementation Detail | Status |
| :--- | :--- | :--- |
| **Enforce FLS & Object Permissions** | All Apex queries and DML use `WITH USER_MODE` / `AccessLevel.USER_MODE`. | **VERIFIED** |
| **Sharing Model** | `DoctorSearchController` declared `with sharing`. | **VERIFIED** |
| **ID Parameter Tampering** | Server-side validation checks `Id != null` and `id.getSObjectType() == ExpectedType.sObjectType`. | **VERIFIED** |
| **Impersonation Prevention** | If `User.ContactId != null`, `effectivePatientId` is strictly overridden to `User.ContactId`. | **VERIFIED** |
| **Financial Integrity** | No fees, discounts, or totals are accepted from LWC. Pricing is fetched from `Doctor__c` and calculated by `AppointmentService`. | **VERIFIED** |
| **Staff Authorization Guard** | `DoctorSearchController.searchPatients` verifies `User.ContactId == null`; throws error if portal user invokes it. | **VERIFIED** |
| **Experience Cloud Identity** | No guest or unauthenticated user can access arbitrary patient data. If `User.ContactId` is null, query aborts safely. | **BLOCKED / DEFERRED** (pending Experience Cloud setup) |

---

## 5. Phase 09.1 Corrective Patch
- **Fix 1 (Toast DTO Mapping)**: Updated `myAppointments.js` line 145 to map server DTO fields `result.fee` and `result.refund` (fixing previous `result.feeCharged` / `result.refundAmount` mismatch).
- **Fix 2 (Staff Patient Search Authorization)**: Integrated `getCurrentUserContactId()` check in `DoctorSearchController.searchPatients`. If `User.ContactId != null`, throws `AuraHandledException('Patient search is restricted to internal healthcare staff.')`.
- **Identity Harmonization**: `getCurrentUserContactId()` unified across all 5 controller entry points (`getUserContext`, `searchPatients`, `bookAppointment`, `getMyAppointments`, `cancelAppointment`).

---

## 6. Verification & Test Evidence

### Apex Test Results
- **Command**: `sf apex test run --tests DoctorSearchControllerTest,AppointmentCoreTest,AppointmentAsyncTest --target-org carenest --code-coverage`
- **Pass Rate**: 100% (35/35 tests passed)
- **DoctorSearchControllerTest**: 13/13 passed (including portal patient directory forbidden, portal context booking, and cross-patient cancel rejection)
- **AppointmentCoreTest**: 11/11 passed
- **AppointmentAsyncTest**: 11/11 passed
- **Org-Wide Code Coverage**: 90% (DoctorSearchController coverage: 87%)

### Phase 14 Data Integrity Regression
- **Script**: `scripts/03_verify.sh carenest`
- **Result**: ALL CHECKS PASSED (5/5)
  - `Doctor__c`: 12 / 12
  - `Contact` (Patient): 100 / 100
  - `Appointment_Slot__c`: 36 / 36
  - `Appointment__c`: 80 / 80
  - `Payment__c`: 60 / 60
  - `Cancellation_Policy__mdt`: 3 / 3
