// CareNest Seeder: Cancellations & Visit Records
// Strictly idempotent, validated against parent appointment status, all-or-none execution.

// -------------------------------------------------------------
// 1. SEED CANCELLATIONS (9 Records for Cancelled Appointments)
// -------------------------------------------------------------
List<Map<String, Object>> cancelData = new List<Map<String, Object>>{
    new Map<String, Object>{'code' => 'CN-APT-00005', 'hrs' => 30.0, 'fee' => 0.0,   'ref' => 650.0, 'reason' => 'Patient unwell'},
    new Map<String, Object>{'code' => 'CN-APT-00006', 'hrs' => 3.0,  'fee' => 665.0, 'ref' => 0.0,   'reason' => 'Doctor unavailable'},
    new Map<String, Object>{'code' => 'CN-APT-00034', 'hrs' => 20.0, 'fee' => 162.5, 'ref' => 487.5, 'reason' => 'Patient unwell'},
    new Map<String, Object>{'code' => 'CN-APT-00046', 'hrs' => 48.0, 'fee' => 0.0,   'ref' => 700.0, 'reason' => 'Booked by mistake'},
    new Map<String, Object>{'code' => 'CN-APT-00052', 'hrs' => 30.0, 'fee' => 0.0,   'ref' => 900.0, 'reason' => 'Schedule clash'},
    new Map<String, Object>{'code' => 'CN-APT-00060', 'hrs' => 72.0, 'fee' => 0.0,   'ref' => 650.0, 'reason' => 'Patient unwell'},
    new Map<String, Object>{'code' => 'CN-APT-00061', 'hrs' => 48.0, 'fee' => 0.0,   'ref' => 500.0, 'reason' => 'Schedule clash'},
    new Map<String, Object>{'code' => 'CN-APT-00062', 'hrs' => 72.0, 'fee' => 0.0,   'ref' => 700.0, 'reason' => 'Patient unwell'},
    new Map<String, Object>{'code' => 'CN-APT-00078', 'hrs' => 2.0,  'fee' => 650.0, 'ref' => 0.0,   'reason' => 'Booked by mistake'}
};

Set<String> cancelCodes = new Set<String>();
for (Map<String, Object> c : cancelData) {
    cancelCodes.add((String) c.get('code'));
}

Map<String, Appointment__c> cancelAppts = new Map<String, Appointment__c>();
for (Appointment__c a : [SELECT Id, Appointment_Code__c, Status__c FROM Appointment__c WHERE Appointment_Code__c IN :cancelCodes]) {
    cancelAppts.put(a.Appointment_Code__c, a);
}

Set<Id> existingCancelApptIds = new Set<Id>();
for (Cancellation__c c : [SELECT Id, Appointment__c FROM Cancellation__c WHERE Appointment__c IN :cancelAppts.values()]) {
    existingCancelApptIds.add(c.Appointment__c);
}

List<Cancellation__c> newCancellations = new List<Cancellation__c>();
for (Map<String, Object> item : cancelData) {
    String code = (String) item.get('code');
    if (!cancelAppts.containsKey(code)) {
        System.debug(LoggingLevel.ERROR, 'Appointment not found for code: ' + code);
        continue;
    }
    Appointment__c a = cancelAppts.get(code);
    if (a.Status__c != 'Cancelled') {
        System.debug(LoggingLevel.ERROR, 'Appointment status is not Cancelled for code: ' + code + ' (Status: ' + a.Status__c + ')');
        continue;
    }
    if (!existingCancelApptIds.contains(a.Id)) {
        newCancellations.add(new Cancellation__c(
            Appointment__c = a.Id,
            Hours_Before_Appointment__c = (Decimal) item.get('hrs'),
            Cancellation_Fee__c = (Decimal) item.get('fee'),
            Refund_Amount__c = (Decimal) item.get('ref'),
            Reason__c = (String) item.get('reason')
        ));
    } else {
        System.debug('Cancellation already exists for ' + code + ' - skipping.');
    }
}

if (!newCancellations.isEmpty()) {
    insert newCancellations;
    System.debug('Inserted ' + newCancellations.size() + ' Cancellation__c records.');
} else {
    System.debug('No new Cancellation__c records needed.');
}


// -------------------------------------------------------------
// 2. SEED VISIT RECORDS (21 Records for Completed Appointments)
// -------------------------------------------------------------
List<Map<String, Object>> visitData = new List<Map<String, Object>>{
    new Map<String, Object>{'code' => 'CN-APT-00008', 'complaint' => 'Sore throat',           'req' => true,  'dt' => Date.newInstance(2026, 9, 20)},
    new Map<String, Object>{'code' => 'CN-APT-00012', 'complaint' => 'Hearing check',          'req' => true,  'dt' => Date.newInstance(2026, 9, 21)},
    new Map<String, Object>{'code' => 'CN-APT-00013', 'complaint' => 'Itching and dryness',    'req' => true,  'dt' => Date.newInstance(2026, 9, 8)},
    new Map<String, Object>{'code' => 'CN-APT-00016', 'complaint' => 'Ear pain',              'req' => false, 'dt' => null},
    new Map<String, Object>{'code' => 'CN-APT-00020', 'complaint' => 'Child fever',            'req' => false, 'dt' => null},
    new Map<String, Object>{'code' => 'CN-APT-00028', 'complaint' => 'Itching and dryness',    'req' => false, 'dt' => null},
    new Map<String, Object>{'code' => 'CN-APT-00031', 'complaint' => 'Lower back pain',        'req' => true,  'dt' => Date.newInstance(2026, 9, 6)},
    new Map<String, Object>{'code' => 'CN-APT-00032', 'complaint' => 'Routine check-up',       'req' => false, 'dt' => null},
    new Map<String, Object>{'code' => 'CN-APT-00037', 'complaint' => 'Acne',                  'req' => false, 'dt' => null},
    new Map<String, Object>{'code' => 'CN-APT-00038', 'complaint' => 'Sore throat',           'req' => true,  'dt' => Date.newInstance(2026, 10, 25)},
    new Map<String, Object>{'code' => 'CN-APT-00039', 'complaint' => 'Child fever',            'req' => true,  'dt' => Date.newInstance(2026, 10, 26)},
    new Map<String, Object>{'code' => 'CN-APT-00044', 'complaint' => 'Lower back pain',        'req' => true,  'dt' => Date.newInstance(2026, 10, 9)},
    new Map<String, Object>{'code' => 'CN-APT-00054', 'complaint' => 'Shoulder stiffness',     'req' => true,  'dt' => Date.newInstance(2026, 9, 21)},
    new Map<String, Object>{'code' => 'CN-APT-00056', 'complaint' => 'Shoulder stiffness',     'req' => false, 'dt' => null},
    new Map<String, Object>{'code' => 'CN-APT-00065', 'complaint' => 'Hair fall',              'req' => false, 'dt' => null},
    new Map<String, Object>{'code' => 'CN-APT-00066', 'complaint' => 'Cough and cold',         'req' => false, 'dt' => null},
    new Map<String, Object>{'code' => 'CN-APT-00067', 'complaint' => 'Blood sugar follow-up',   'req' => false, 'dt' => null},
    new Map<String, Object>{'code' => 'CN-APT-00069', 'complaint' => 'Knee pain',              'req' => false, 'dt' => null},
    new Map<String, Object>{'code' => 'CN-APT-00073', 'complaint' => 'Poor appetite',          'req' => false, 'dt' => null},
    new Map<String, Object>{'code' => 'CN-APT-00074', 'complaint' => 'Knee pain',              'req' => false, 'dt' => null},
    new Map<String, Object>{'code' => 'CN-APT-00080', 'complaint' => 'Cold and cough',         'req' => true,  'dt' => Date.newInstance(2026, 9, 24)}
};

Set<String> visitCodes = new Set<String>();
for (Map<String, Object> v : visitData) {
    visitCodes.add((String) v.get('code'));
}

Map<String, Appointment__c> visitAppts = new Map<String, Appointment__c>();
for (Appointment__c a : [SELECT Id, Appointment_Code__c, Status__c FROM Appointment__c WHERE Appointment_Code__c IN :visitCodes]) {
    visitAppts.put(a.Appointment_Code__c, a);
}

Set<Id> existingVisitApptIds = new Set<Id>();
for (Visit_Record__c v : [SELECT Id, Appointment__c FROM Visit_Record__c WHERE Appointment__c IN :visitAppts.values()]) {
    existingVisitApptIds.add(v.Appointment__c);
}

List<Visit_Record__c> newVisits = new List<Visit_Record__c>();
for (Map<String, Object> item : visitData) {
    String code = (String) item.get('code');
    if (!visitAppts.containsKey(code)) {
        System.debug(LoggingLevel.ERROR, 'Appointment not found for code: ' + code);
        continue;
    }
    Appointment__c a = visitAppts.get(code);
    if (a.Status__c != 'Completed') {
        System.debug(LoggingLevel.ERROR, 'Appointment status is not Completed for code: ' + code + ' (Status: ' + a.Status__c + ')');
        continue;
    }
    if (!existingVisitApptIds.contains(a.Id)) {
        newVisits.add(new Visit_Record__c(
            Appointment__c = a.Id,
            Chief_Complaint__c = (String) item.get('complaint'),
            Follow_Up_Required__c = (Boolean) item.get('req'),
            Follow_Up_Date__c = (Date) item.get('dt')
        ));
    } else {
        System.debug('Visit_Record already exists for ' + code + ' - skipping.');
    }
}

if (!newVisits.isEmpty()) {
    insert newVisits;
    System.debug('Inserted ' + newVisits.size() + ' Visit_Record__c records.');
} else {
    System.debug('No new Visit_Record__c records needed.');
}

System.debug('AUDIT_STATUS: SUCCESS - Cancellations and Visit Records processed safely.');
