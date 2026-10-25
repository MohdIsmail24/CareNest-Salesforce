// Phase 35 Live Verification Script
System.debug('=== STARTING PHASE 35 LIVE VERIFICATION ===');

// -------------------------------------------------------------
// 1. PATIENT REGISTRATION & DUPLICATE PREVENTION
// -------------------------------------------------------------
System.debug('--- 1. Testing Patient Registration & Duplicate Prevention ---');
String testPhone = '9991112223';
String testEmail = 'synthetic.patient.' + System.currentTimeMillis() + '@example.test';

CareNestAdmissionController.PatientRegistrationResultDto regRes = CareNestAdmissionController.registerPatient(
    'Synthetic', 'PatientPhase35', testPhone, testEmail, Date.newInstance(1990, 1, 1), false
);
System.assert(regRes.isSuccess, 'Synthetic patient registration must succeed');
System.assertNotEquals(null, regRes.contactId, 'Contact ID must be returned');
System.assert(regRes.patientCode.startsWith('CN-PAT-'), 'Patient Code must follow CN-PAT- format');

// Verify privacy architecture: AccountId = null
Contact createdContact = [SELECT Id, AccountId, MC_Is_Patient__c, Patient_Code__c FROM Contact WHERE Id = :regRes.contactId];
System.assertEquals(null, createdContact.AccountId, 'Patient Contact must NOT be linked to Account (AccountId == null)');
System.assertEquals(true, createdContact.MC_Is_Patient__c, 'MC_Is_Patient__c must be true');

// Verify Duplicate Detection
CareNestAdmissionController.PatientRegistrationResultDto dupRes = CareNestAdmissionController.registerPatient(
    'Duplicate', 'Attempt', testPhone, 'other@example.test', Date.newInstance(1990, 1, 1), false
);
System.assertEquals(false, dupRes.isSuccess, 'Duplicate phone should be blocked when forceRegister=false');
System.assertEquals(true, dupRes.isDuplicate, 'isDuplicate must be true');
System.assertNotEquals(null, dupRes.duplicateContactId, 'Must return duplicate contact ID');
System.debug('✓ Patient Registration and Duplicate Prevention verified successfully');

// -------------------------------------------------------------
// 2. FLEXIBLE APPOINTMENT SCHEDULING & CONCURRENCY
// -------------------------------------------------------------
System.debug('--- 2. Testing Flexible Appointment Scheduling & Concurrency ---');
CareNestAppointmentController.AppointmentInitDto initData = CareNestAppointmentController.getSchedulingInitData();
System.assert(initData.departments.size() > 0, 'Departments list populated');
System.assert(initData.doctors.size() > 0, 'Doctors list populated');

Doctor__c testDoc = [SELECT Id, Name, Department__c FROM Doctor__c WHERE Is_Active__c = true LIMIT 1];
Date bookingDate = Date.today().addDays(7);

// A. First manual booking (11:30)
CareNestAppointmentController.BookingResultDto b1 = CareNestAppointmentController.bookFlexibleAppointment(
    createdContact.Id, testDoc.Id, testDoc.Department__c, null, bookingDate, '11:30', 'OPD'
);
System.assertEquals(true, b1.isSuccess, 'First booking must succeed');
System.assertNotEquals(null, b1.appointmentId, 'First appointment ID generated');

// B. Concurrent overlapping booking on same doctor (11:40 -> rounds to 11:30)
CareNestAppointmentController.BookingResultDto b2 = CareNestAppointmentController.bookFlexibleAppointment(
    createdContact.Id, testDoc.Id, testDoc.Department__c, null, bookingDate, '11:40', 'OPD'
);
System.assertEquals(false, b2.isSuccess, 'Overlapping booking must fail');
System.assertEquals(true, b2.isConflict, 'Conflict flag must be set');
System.debug('✓ Concurrency double-booking rejection and conflict detection verified');

// C. Reschedule Appointment
Appointment__c appt1 = [SELECT Id, Slot__c FROM Appointment__c WHERE Id = :b1.appointmentId];
Appointment_Slot__c altSlot = [SELECT Id FROM Appointment_Slot__c WHERE Is_Open__c = true AND Id != :appt1.Slot__c LIMIT 1];
CareNestAppointmentController.BookingResultDto resched = CareNestAppointmentController.rescheduleAppointment(b1.appointmentId, altSlot.Id);
System.assertEquals(true, resched.isSuccess, 'Rescheduling must succeed');

// D. Cancel Appointment
Boolean cancelled = CareNestAppointmentController.cancelAppointmentBooking(b1.appointmentId, 'Live verification cleanup');
System.assertEquals(true, cancelled, 'Cancellation must succeed');
System.debug('✓ Rescheduling and cancellation verified');

// -------------------------------------------------------------
// 3. CLINICAL VITALS ALERT LIFECYCLE & HISTORICAL PRESERVATION
// -------------------------------------------------------------
System.debug('--- 3. Testing Clinical Vitals Alert Lifecycle ---');

// Verify existing abnormal alerts count (17 expected)
Integer activeAlertsInitial = [
    SELECT count() 
    FROM Patient_Vital__c 
    WHERE Alert_Flag__c = true 
      AND (Alert_Status__c = null OR Alert_Status__c != 'Resolved')
];
System.assert(activeAlertsInitial >= 17, 'All 17 pre-existing alerts must be active: count=' + activeAlertsInitial);

// Create 1 synthetic abnormal vital for testing lifecycle
Admission__c adm = [SELECT Id FROM Admission__c WHERE Status__c = 'Admitted' LIMIT 1];
Patient_Vital__c synthVital = new Patient_Vital__c(
    Admission__c = adm.Id,
    Recorded_Date__c = System.now(),
    Systolic_BP__c = 190,
    Diastolic_BP__c = 115,
    Pulse_BPM__c = 130,
    Temperature_C__c = 39.2,
    SpO2_Percent__c = 84,
    Notes__c = 'Synthetic emergency vital for Phase 35 live test'
);
insert synthVital;

// Acknowledge Alert
CareNestClinicalController.PatientVitalDto ackDto = CareNestClinicalController.acknowledgeVitalAlert(
    synthVital.Id, 'Physician acknowledged hypertensive crisis'
);
System.assertEquals('Acknowledged', ackDto.alertStatus, 'Status must transition to Acknowledged');
System.assertNotEquals(null, ackDto.acknowledgedAt, 'Timestamp must be stamped');

// Resolve Alert with Mandatory Clinical Notes
CareNestClinicalController.PatientVitalDto resDto = CareNestClinicalController.resolveVitalAlert(
    synthVital.Id, 'Administered IV antihypertensive bolus. BP normalized to 125/80 mmHg. Patient stable.'
);
System.assertEquals('Resolved', resDto.alertStatus, 'Status must transition to Resolved');
System.assertNotEquals(null, resDto.resolvedAt, 'Resolved timestamp must be stamped');
System.assert(resDto.resolutionNotes.contains('antihypertensive'), 'Resolution notes must be stored');

// Verify active alert KPI count decrements back to initial count (excluding resolved alert)
Integer activeAlertsAfter = [
    SELECT count() 
    FROM Patient_Vital__c 
    WHERE Alert_Flag__c = true 
      AND (Alert_Status__c = null OR Alert_Status__c != 'Resolved')
];
System.assertEquals(activeAlertsInitial, activeAlertsAfter, 'Resolved alert must be excluded from active alerts count');
System.debug('✓ Alert lifecycle (Acknowledge -> Resolve with Notes) and KPI decrement verified');

// -------------------------------------------------------------
// 4. CLEANUP SYNTHETIC TEST DATA
// -------------------------------------------------------------
delete synthVital;
delete [SELECT Id FROM Appointment__c WHERE Id = :b1.appointmentId];
delete createdContact;
System.debug('=== PHASE 35 LIVE VERIFICATION PASSED WITH 100% SUCCESS ===');
