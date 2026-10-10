# CareNest — Phase 06 Automation Documentation

## 1. Overview
Phase 06 establishes the declarative business process automation layer for CareNest, enforcing data integrity at the database boundary, guiding users through critical actions, coordinating lifecycle milestones, and establishing governed discount approval flows.

---

## 2. Automation Inventory

### A. Validation Rules
| Object | Rule API Name | Active | Error Condition Formula | Error Display Field | Business Purpose |
|---|---|---|---|---|---|
| `Appointment_Slot__c` | `Slot_Must_Be_Future` | True | `AND(ISNEW(), Slot_Start__c <= NOW())` | `Slot_Start__c` | Prevents creation of past appointment slots. |
| `Appointment_Slot__c` | `Capacity_Must_Be_Positive` | True | `Total_Capacity__c <= 0` | `Total_Capacity__c` | Guarantees that bookable slot capacity is strictly greater than 0. |
| `Appointment__c` | `Patient_Required` | True | `ISBLANK(Patient__c)` | `Patient__c` | Enforces that an appointment record must reference a patient Contact. |
| `Appointment__c` | `Discount_Above_20_Not_Allowed` | True | `AND(Discount_Percent__c > 0.20, NOT($Permission.Approve_Discount))` | `Discount_Percent__c` | Blocks discounts > 20% unless user has the `Approve_Discount` custom permission. |
| `Visit_Record__c` | `Follow_Up_Date_Required` | True | `AND(Follow_Up_Required__c, ISBLANK(Follow_Up_Date__c))` | `Follow_Up_Date__c` | Ensures follow-up date is provided when follow-up is marked as required. |

### B. Flows
| Flow API Name | Type | Trigger / Schedule | Active | Business Purpose | Fault Handling |
|---|---|---|---|---|---|
| `CareNest_Appointment_Confirmed` | Record-Triggered (After-Save) | `Appointment__c` status changed to `Confirmed` | True | Creates task for appointment owner; triggers confirmation email alert if patient email is present. | Fault paths on Task creation and email action write to `Error_Log__c`. |
| `CareNest_Appointment_Daily_Reminder` | Schedule-Triggered (Daily) | Daily at 08:00 UTC on `Appointment__c` | True | Identifies confirmed appointments with slot starting in the next 24h and marks `Reminder_Sent__c = true`. | Fault connector on update writes to `Error_Log__c`. |
| `CareNest_Cancel_Appointment` | Screen Flow | Invoked from Appointment record page / quick action | True | Guides user through appointment cancellation, collects reason, validates status, updates appointment to `Cancelled`, and creates `Cancellation__c` record. | Fault paths on Get, Update, and Create log to `Error_Log__c` and present guided error screens. |

### C. Approval Process
- **Process Name**: `Appointment_Discount_Approval`
- **Object**: `Appointment__c`
- **Active**: True
- **Entry Criteria**: `Discount_Percent__c > 0.10` (Formula: `Discount_Percent__c > 0.10`)
- **Approver Routing**: Submitter's Manager (`userHierarchyField: Manager`)
- **Record Editability**: Administrator Only (`AdminOnly`)
- **Initial Submission Action**:
  - Field Update: `Set_Approval_Pending` (`Approval_Status__c = 'Pending'`)
  - Automatic record lock.
- **Final Approval Action**:
  - Field Update: `Set_Approval_Approved` (`Approval_Status__c = 'Approved'`)
  - Record unlock.
- **Final Rejection Action**:
  - Field Update: `Set_Approval_Rejected` (`Approval_Status__c = 'Rejected'`)
  - Field Update: `Reset_Discount_Percent` (`Discount_Percent__c = 0`)
  - Record unlock.

---

## 3. Security & Permission Integration
- Custom Permission: `Approve_Discount`
- Granted to: `CareNest_Ops_Manager` permission set
- Unassigned Users: Front desk staff and regular users cannot exceed 20% discount without manager intervention.

---

## 4. Verification & Testing Summary
All 12 functional test scenarios (A through L) passed on live org `carenest`:
- All validation rules block invalid inputs with exact business error messages.
- Discounts <= 10% proceed without approval.
- Discounts > 10% up to 20% submit to `Appointment_Discount_Approval` and update `Approval_Status__c` to `Pending`.
- Discounts > 20% are hard-blocked for unauthorized users by `Discount_Above_20_Not_Allowed`.
- Flow triggers properly create follow-up tasks upon confirmation.
- Phase 14 demo seed data (12 Doctors, 100 Patients, 36 Slots, 80 Appointments, 60 Payments) remains 100% intact (verified via `scripts/03_verify.sh`).
