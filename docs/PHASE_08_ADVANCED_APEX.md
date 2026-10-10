# CareNest — Phase 08 Advanced Apex Documentation

## 1. Overview
Phase 08 implements the asynchronous processing, batch, and scheduling layer for CareNest. It provides automated background processing to manage appointment lifecycles without blocking synchronous user operations, enforces idempotency across all batch and queueable jobs, and prepares clean integration boundaries for Phase 10 SMS dispatch.

---

## 2. Asynchronous Architecture

```
Scheduled Triggers / Periodic Schedulers
       │
       ├─────────────────────────┬─────────────────────────┐
       ▼                         ▼                         ▼
CareNestReminderScheduler   NoShowBatch (Schedulable)  PendingExpiryBatch (Schedulable)
       │                         │                         │
       ▼                         ▼                         ▼
 ReminderSmsJob              Query Locator             Query Locator
 (Queueable, 50-chunking)    (Confirmed > 2h past,     (Pending > 30m old,
       │                     no Visit Record)          no successful payment)
       ▼                         │                         │
  Update Status &                ▼                         ▼
 Reminder_Sent__c = true    Status = 'No Show'        Status = 'Cancelled'
                                 │                         │
                                 └───────────┬─────────────┘
                                             ▼
                                 AppointmentTrigger
                                             ▼
                                 AppointmentService
                                 (Recalculates Slot Booked_Count__c)
```

---

## 3. Components Implemented

### 1. `ReminderSmsJob` (Queueable)
- **Role**: Dispatches SMS appointment reminders in chunks of 50 to respect governor limits.
- **Idempotency**: Strictly queries `Reminder_Sent__c = false` within the active chunk. Sets `Reminder_Sent__c = true` upon dispatch.
- **Governor Limit Protection**: Splits input into 50-record chunks. Enqueues subsequent chunks recursively when `Limits.getQueueableJobs() < Limits.getLimitQueueableJobs()` and outside test context.
- **Integration Boundary**: Encapsulates `dispatchReminder` as a stub boundary ready for Phase 10 outbound SMS callouts without introducing unauthorized HTTP callouts in Phase 08.

### 2. `NoShowBatch` (Batchable & Schedulable)
- **Role**: Nightly batch job identifying `Confirmed` appointments where the slot started more than 2 hours ago (`Slot__r.Slot_Start__c < :twoHoursAgo`) and no clinical visit occurred (`(SELECT Id FROM Visit_Records__r LIMIT 1)` is empty).
- **Status Transition**: Updates `Status__c = 'No Show'`.
- **Capacity Recovery**: Transition to `No Show` triggers `AppointmentService.updateBookedCounts` via `AppointmentTriggerHandler`, automatically decrementing the slot's `Booked_Count__c`.
- **Schedulable**: Implements `Schedulable` with default scope of 200, designed to be scheduled nightly at 23:00 (`0 0 23 * * ?`).

### 3. `PendingExpiryBatch` (Batchable & Schedulable)
- **Role**: Periodic batch job identifying unconfirmed `Pending` appointments older than 30 minutes (`CreatedDate <= :thirtyMinutesAgo`) with zero successful payments (`Amount_Paid__c = null OR Amount_Paid__c = 0`).
- **Status Transition**: Updates `Status__c = 'Cancelled'`.
- **Capacity Recovery**: Re-evaluates slot capacity via Phase 07 trigger synchronization, releasing the held slot for other patients.
- **Schedulable**: Implements `Schedulable` with default batch scope of 200, designed to run every 30 minutes.

### 4. `CareNestReminderScheduler` (Schedulable)
- **Role**: Orchestrates `ReminderSmsJob` execution on a cron schedule by querying up to 500 upcoming confirmed appointments where `Reminder_Sent__c = false` and enqueueing the queueable processor.

---

## 4. Idempotency & Error Handling Strategy
- **Idempotency**:
  - `ReminderSmsJob`: Only targets records where `Reminder_Sent__c = false`. Re-running the job on the same appointments results in a zero-record query and no DML operations.
  - `NoShowBatch`: Only queries `Status__c = 'Confirmed'`. Once updated to `'No Show'`, subsequent executions ignore them.
  - `PendingExpiryBatch`: Only queries `Status__c = 'Pending'`. Once cancelled, subsequent runs ignore them.
- **Safe DML Operations**:
  - All batch and queueable updates use `Database.update(records, false)` with save result inspection to ensure individual record validation or lock contention errors do not abort the entire batch chunk.

---

## 5. Security & Sharing
- Declared with `with sharing` to enforce organization-wide sharing settings and object permissions.
- Leverages existing custom fields and relationships without modifying Phase 03/04 security or permission sets.

---

## 6. Testing & Verification
- **Unit Test Class**: `AppointmentAsyncTest`
- **Total Test Methods**: 11 (22 total across `AppointmentAsyncTest` and `AppointmentCoreTest`)
- **Pass Rate**: 100% (22/22 passing)
- **Org Wide Code Coverage**: 92%
  - `CareNestReminderScheduler`: 100%
  - `AppointmentTriggerHandler`: 100%
  - `AppointmentTrigger`: 100%
  - `AppointmentService`: 99%
  - `CancellationService`: 94%
  - `PendingExpiryBatch`: 94%
  - `NoShowBatch`: 94%
  - `ReminderSmsJob`: 93%
  - `CancelAppointmentAction`: 93%
  - `TriggerHandler`: 74%
- **Phase 14 Regression Verification**:
  - `Doctor__c`: 12 / 12 (PASS)
  - `Contact`: 100 / 100 (PASS)
  - `Appointment_Slot__c`: 36 / 36 (PASS)
  - `Appointment__c`: 80 / 80 (PASS)
  - `Payment__c`: 60 / 60 (PASS)
  - Result: ALL CHECKS PASSED (5/5)
