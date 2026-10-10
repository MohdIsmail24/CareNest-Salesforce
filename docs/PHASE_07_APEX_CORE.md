# CareNest — Phase 07 Apex Core Documentation

## 1. Overview
Phase 07 implements the core domain and business logic architecture for CareNest. It provides concurrency-safe appointment booking, row-level locking (`FOR UPDATE`) to prevent double-booking, automatic fee copying and total calculation, slot booked-count maintenance, tiered cancellation policy evaluation from `Cancellation_Policy__mdt`, and exposes cancellation capabilities to declarative Flow and Agentforce via an Invocable Action.

---

## 2. Apex Architecture
The architecture follows separation of concerns:
```
AppointmentTrigger (Thin Trigger)
       ↓
AppointmentTriggerHandler (Trigger Routing & Bypass)
       ↓
AppointmentService / CancellationService (Domain & Business Logic)
       ↓
Salesforce Database (with FOR UPDATE Row Locks)
```

### Components
1. **`TriggerHandler`**: Virtual base class providing lifecycle routing (`beforeInsert`, `beforeUpdate`, `beforeDelete`, `afterInsert`, `afterUpdate`, `afterDelete`, `afterUndelete`) and bypass controls.
2. **`AppointmentTrigger`**: Thin trigger on `Appointment__c` delegating all operations to `AppointmentTriggerHandler`.
3. **`AppointmentTriggerHandler`**: Context router coordinating before/after operations with `AppointmentService`.
4. **`AppointmentService`**:
   - `validateAndReserve`: Locks `Appointment_Slot__c` rows using `FOR UPDATE`, checks requested slots against remaining capacity, and prevents double-booking.
   - `populateFeesAndTotals`: Copies consultation fee from `Doctor__c` if blank and computes `Total_Amount__c = Fee_Amount__c * (1 - Discount_Percent__c / 100)`.
   - `recalculateTotals`: Dynamically updates `Total_Amount__c` upon fee or discount adjustments.
   - `updateBookedCounts`: Aggregates active appointments (`Confirmed`, `Pending`) per slot and synchronizes `Appointment_Slot__c.Booked_Count__c`.
5. **`CancellationService`**:
   - Evaluates `Cancellation_Policy__mdt` custom metadata tiers (`More_Than_24_Hours`, `Between_4_And_24_Hours`, `Under_4_Hours`).
   - Calculates cancellation fee and refund amount based on hours remaining before slot start.
   - Creates `Cancellation__c` record and transitions appointment status to `Cancelled`.
   - Bulk-safe and provides row-locking (`FOR UPDATE`) on the cancelled appointment.
6. **`CancelAppointmentAction`**:
   - `@InvocableMethod(label='Cancel Appointment')`
   - Exposes `CancellationService.cancel` to Flow and external automation.
7. **`AppointmentCoreTest`**:
   - Comprehensive test suite covering valid booking, double-booking rejection, booked count recalculation, cancellation tiers, invocable actions, bulk processing, and trigger bypass.

---

## 3. Test Coverage & Verification
- **Total Tests**: 11
- **Passed**: 11 (100%)
- **Failed**: 0
- **Org Coverage**:
  - `AppointmentTrigger`: 100%
  - `AppointmentTriggerHandler`: 100%
  - `AppointmentService`: 97%
  - `CancellationService`: 94%
  - `CancelAppointmentAction`: 93%
  - `TriggerHandler`: 74%
  - **Overall Weighted Coverage**: >90%
