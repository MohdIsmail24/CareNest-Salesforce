/**
 * @description Focused, idempotent seed script for CareNest 10-Patient Demo Cohort.
 * Links: Patient (Contact) -> Admission -> Ward -> Bed -> Doctor -> Encounter -> Vital.
 * Uses dedicated namespace 'CN-D10-' to guarantee isolation and zero impact on other records.
 */

// 1. Target Doctor Mapping (by Registration_No__c / Doctor_Id__c or Name)
Map<String, Id> docMap = new Map<String, Id>();
for (Doctor__c d : [SELECT Id, Name, Registration_No__c FROM Doctor__c]) {
    docMap.put(d.Name, d.Id);
}

// 2. Target Bed Mapping
Map<String, Bed__c> bedMap = new Map<String, Bed__c>();
for (Bed__c b : [
    SELECT Id, Name, Bed_Code__c, Status__c, Ward__c, Ward__r.Ward_Code__c, Ward__r.Name
    FROM Bed__c
    WHERE Bed_Code__c IN (
        'CN-BED-001', 'CN-BED-002',
        'CN-BED-018', 'CN-BED-020',
        'CN-BED-026', 'CN-BED-027',
        'CN-BED-033', 'CN-BED-034',
        'CN-BED-040', 'CN-BED-041'
    )
]) {
    bedMap.put(b.Bed_Code__c, b);
}

// 3. Define the 10 Synthetic Demo Cohort Data Structures
class DemoPatientDef {
    String patientCode;
    String firstName;
    String lastName;
    String email;
    String phone;
    String bedCode;
    String doctorName;
    String admissionCode;
    String admissionType;
    String reason;
    String encounterCode;
    String encounterType;
    String chiefComplaint;
    String assessment;
    String clinicalNotes;
    String vitalCode;
    Decimal tempC;
    Decimal pulse;
    Decimal sysBP;
    Decimal diaBP;
    Decimal respRate;
    Decimal spo2;
    Decimal painScore;

    DemoPatientDef(
        String pCode, String fName, String lName, String em, String ph,
        String bCode, String dName, String admCode, String admType, String rsn,
        String encCode, String encType, String cc, String asmt, String notes,
        String vCode, Decimal tc, Decimal p, Decimal sBP, Decimal dBP, Decimal rr, Decimal sp, Decimal pain
    ) {
        this.patientCode = pCode;
        this.firstName = fName;
        this.lastName = lName;
        this.email = em;
        this.phone = ph;
        this.bedCode = bCode;
        this.doctorName = dName;
        this.admissionCode = admCode;
        this.admissionType = admType;
        this.reason = rsn;
        this.encounterCode = encCode;
        this.encounterType = encType;
        this.chiefComplaint = cc;
        this.assessment = asmt;
        this.clinicalNotes = notes;
        this.vitalCode = vCode;
        this.tempC = tc;
        this.pulse = p;
        this.sysBP = sBP;
        this.diaBP = dBP;
        this.respRate = rr;
        this.spo2 = sp;
        this.painScore = pain;
    }
}

List<DemoPatientDef> cohort = new List<DemoPatientDef>{
    // 1. General Ward - Aarav Sharma
    new DemoPatientDef(
        'CN-D10-P-001', 'Aarav', 'Sharma', 'aarav.sharma@example.carenest.demo', '+91 98765 00001',
        'CN-BED-001', 'Dr. Ayesha Khan', 'CN-D10-ADM-001', 'Planned', 'Acute gastroenteritis with mild dehydration',
        'CN-D10-ENC-001', 'Doctor Round', 'Nausea, abdominal cramping, and decreased oral intake.', 'Improving on IV fluid hydration and antiemetics.', 'Tolerating clear liquids; planned for step-down to oral rehydration.',
        'CN-D10-VIT-001', 37.1, 76, 120, 80, 18, 98, 2
    ),
    // 2. General Ward - Sana Khan
    new DemoPatientDef(
        'CN-D10-P-002', 'Sana', 'Khan', 'sana.khan@example.carenest.demo', '+91 98765 00002',
        'CN-BED-002', 'Dr. Imran Qureshi', 'CN-D10-ADM-002', 'Planned', 'Uncontrolled type 2 diabetes with mild ketosis',
        'CN-D10-ENC-002', 'Doctor Round', 'Fatigue, polyuria, and elevated home capillary blood glucose readings.', 'Metabolic stabilization achieved on basal-bolus insulin titration.', 'Endocrine consult complete; diabetes educator scheduled for discharge planning.',
        'CN-D10-VIT-002', 36.8, 82, 128, 84, 16, 97, 1
    ),
    // 3. Semi-Private - Rohan Patel
    new DemoPatientDef(
        'CN-D10-P-003', 'Rohan', 'Patel', 'rohan.patel@example.carenest.demo', '+91 98765 00003',
        'CN-BED-018', 'Dr. Kavita Rao', 'CN-D10-ADM-003', 'Planned', 'Community-acquired pneumonia under observation',
        'CN-D10-ENC-003', 'Doctor Round', 'Productive cough, low-grade pyrexia, and pleuritic chest discomfort.', 'Resolving right lower lobe consolidation with IV ceftriaxone.', 'Afebrile for 24 hours; chest auscultation shows improved air entry.',
        'CN-D10-VIT-003', 37.4, 88, 122, 78, 20, 95, 3
    ),
    // 4. Semi-Private - Meera Joshi
    new DemoPatientDef(
        'CN-D10-P-004', 'Meera', 'Joshi', 'meera.joshi@example.carenest.demo', '+91 98765 00004',
        'CN-BED-020', 'Dr. Faizan Ansari', 'CN-D10-ADM-004', 'Planned', 'Closed distal radius fracture, conservative management',
        'CN-D10-ENC-004', 'Doctor Round', 'Post-reduction pain and mild digit swelling.', 'Neurovascular bundle intact distal to plaster cast; compartment signs negative.', 'Pain well managed on oral analgesics; elevation protocol reinforced.',
        'CN-D10-VIT-004', 36.7, 74, 116, 74, 16, 99, 4
    ),
    // 5. Private Room - Kabir Mehta
    new DemoPatientDef(
        'CN-D10-P-005', 'Kabir', 'Mehta', 'kabir.mehta@example.carenest.demo', '+91 98765 00005',
        'CN-BED-026', 'Dr. Rajesh Pandey', 'CN-D10-ADM-005', 'Planned', 'Elective total knee arthroplasty preparation',
        'CN-D10-ENC-005', 'Doctor Round', 'Severe degenerative tricompartmental gonarthrosis.', 'Pre-operative cardiac and anaesthetic clearance completed.', 'Crossmatched PRBC on reserve; prophylactic antibiotics ordered.',
        'CN-D10-VIT-005', 36.6, 70, 124, 80, 15, 98, 2
    ),
    // 6. Private Room - Aisha Shaikh
    new DemoPatientDef(
        'CN-D10-P-006', 'Aisha', 'Shaikh', 'aisha.shaikh@example.carenest.demo', '+91 98765 00006',
        'CN-BED-027', 'Dr. Sanjay Reddy', 'CN-D10-ADM-006', 'Planned', 'Lumbar radiculopathy and pain management',
        'CN-D10-ENC-006', 'Doctor Round', 'L5-S1 nerve root compression with sharp lower extremity radiation.', 'Responding positively to epidural steroid injection and physical therapy review.', 'Mobilizing with assistive frame; discharge planning in progress.',
        'CN-D10-VIT-006', 36.9, 78, 118, 76, 17, 99, 5
    ),
    // 7. ICU - Dev Malhotra (Abnormal Vital Alert Case)
    new DemoPatientDef(
        'CN-D10-P-007', 'Dev', 'Malhotra', 'dev.malhotra@example.carenest.demo', '+91 98765 00007',
        'CN-BED-033', 'Dr. Kavita Rao', 'CN-D10-ADM-007', 'Emergency', 'Severe sepsis secondary to acute pyelonephritis',
        'CN-D10-ENC-007', 'Doctor Round', 'High-grade fever, chills, flank pain, and severe tachycardia in ICU.', 'Septic shock profile with tachycardia, hypoxemia, and hypertensive compensatory response.', 'Initiated broad-spectrum meropenem, aggressive fluid resus, continuous monitoring.',
        'CN-D10-VIT-007', 39.4, 128, 186, 102, 28, 89, 7
    ),
    // 8. ICU - Priya Nair (ICU Stable monitoring)
    new DemoPatientDef(
        'CN-D10-P-008', 'Priya', 'Nair', 'priya.nair@example.carenest.demo', '+91 98765 00008',
        'CN-BED-034', 'Dr. Ayesha Khan', 'CN-D10-ADM-008', 'Emergency', 'Acute exacerbation of COPD post-stabilization',
        'CN-D10-ENC-008', 'Doctor Round', 'Shortness of breath, expiratory wheeze, and respiratory fatigue.', 'Improving post-BiPAP ventilation; transitioning to low-flow nasal cannula.', 'Serial blood gas analysis stable; steroid and bronchodilator therapy continued.',
        'CN-D10-VIT-008', 37.0, 86, 132, 84, 21, 94, 3
    ),
    // 9. Post-Operative - Arjun Verma
    new DemoPatientDef(
        'CN-D10-P-009', 'Arjun', 'Verma', 'arjun.verma@example.carenest.demo', '+91 98765 00009',
        'CN-BED-040', 'Dr. Rajesh Pandey', 'CN-D10-ADM-009', 'Planned', 'Post-operative recovery following arthroscopic meniscectomy',
        'CN-D10-ENC-009', 'Doctor Round', 'Day 1 post-operative right knee arthroscopy review.', 'Surgical dressing clean and dry; minimal effusion; active ankle pumps confirmed.', 'Cryotherapy applied; partial weight-bearing with crutches cleared by physio.',
        'CN-D10-VIT-009', 36.8, 75, 120, 76, 16, 98, 3
    ),
    // 10. Post-Operative - Zoya Siddiqui
    new DemoPatientDef(
        'CN-D10-P-010', 'Zoya', 'Siddiqui', 'zoya.siddiqui@example.carenest.demo', '+91 98765 00010',
        'CN-BED-041', 'Dr. Sanjay Reddy', 'CN-D10-ADM-010', 'Planned', 'Post-operative observation after carpal tunnel decompression',
        'CN-D10-ENC-010', 'Doctor Round', 'Post-operative wound inspection and distal neurological assessment.', 'Median nerve distribution sensation intact; capillary refill < 2 seconds.', 'Hand elevation maintained; analgesia optimized for planned discharge tomorrow.',
        'CN-D10-VIT-010', 36.7, 72, 114, 72, 15, 99, 2
    )
};

System.debug('--- COMMENCING IDEMPOTENT 10-PATIENT DEMO DATA LOAD ---');

// STEP A: UPSERT CONTACTS BY Patient_Code__c
List<Contact> contactsToUpsert = new List<Contact>();
for (DemoPatientDef def : cohort) {
    contactsToUpsert.add(new Contact(
        Patient_Code__c = def.patientCode,
        FirstName = def.firstName,
        LastName = def.lastName,
        Email = def.email,
        Phone = def.phone
    ));
}
upsert contactsToUpsert Patient_Code__c;
System.debug('Successfully upserted ' + contactsToUpsert.size() + ' Contacts.');

Map<String, Id> patientCodeToContactId = new Map<String, Id>();
for (Contact c : [SELECT Id, Patient_Code__c FROM Contact WHERE Patient_Code__c IN :new Set<String>{
    'CN-D10-P-001', 'CN-D10-P-002', 'CN-D10-P-003', 'CN-D10-P-004', 'CN-D10-P-005',
    'CN-D10-P-006', 'CN-D10-P-007', 'CN-D10-P-008', 'CN-D10-P-009', 'CN-D10-P-010'
}]) {
    patientCodeToContactId.put(c.Patient_Code__c, c.Id);
}

// STEP B: UPSERT ADMISSIONS BY Admission_Code__c
List<Admission__c> admissionsToUpsert = new List<Admission__c>();
for (DemoPatientDef def : cohort) {
    Id contactId = patientCodeToContactId.get(def.patientCode);
    Bed__c bed = bedMap.get(def.bedCode);
    Id docId = docMap.get(def.doctorName);

    admissionsToUpsert.add(new Admission__c(
        Admission_Code__c = def.admissionCode,
        Contact__c = contactId,
        Patient__c = contactId,
        Bed__c = bed.Id,
        Attending_Doctor__c = docId,
        Doctor__c = docId,
        Admission_Type__c = def.admissionType,
        Status__c = 'Admitted',
        Admission_Date__c = System.now().addDays(-2),
        Expected_Discharge_Date__c = Date.today().addDays(3),
        Reason__c = def.reason
    ));
}
upsert admissionsToUpsert Admission_Code__c;
System.debug('Successfully upserted ' + admissionsToUpsert.size() + ' Admissions.');

Map<String, Id> admCodeToAdmId = new Map<String, Id>();
for (Admission__c adm : [SELECT Id, Admission_Code__c FROM Admission__c WHERE Admission_Code__c IN :new Set<String>{
    'CN-D10-ADM-001', 'CN-D10-ADM-002', 'CN-D10-ADM-003', 'CN-D10-ADM-004', 'CN-D10-ADM-005',
    'CN-D10-ADM-006', 'CN-D10-ADM-007', 'CN-D10-ADM-008', 'CN-D10-ADM-009', 'CN-D10-ADM-010'
}]) {
    admCodeToAdmId.put(adm.Admission_Code__c, adm.Id);
}

// STEP C: UPSERT INPATIENT ENCOUNTERS BY Encounter_Code__c
List<Inpatient_Encounter__c> encountersToUpsert = new List<Inpatient_Encounter__c>();
for (DemoPatientDef def : cohort) {
    Id admId = admCodeToAdmId.get(def.admissionCode);
    Id docId = docMap.get(def.doctorName);

    encountersToUpsert.add(new Inpatient_Encounter__c(
        Encounter_Code__c = def.encounterCode,
        Admission__c = admId,
        Attending_Doctor__c = docId,
        Doctor__c = docId,
        Encounter_Type__c = def.encounterType,
        Status__c = 'Completed',
        Encounter_Date__c = System.now().addHours(-6),
        Chief_Complaint__c = def.chiefComplaint,
        Assessment__c = def.assessment,
        Clinical_Notes__c = def.clinicalNotes,
        Notes__c = def.clinicalNotes.left(255)
    ));
}
upsert encountersToUpsert Encounter_Code__c;
System.debug('Successfully upserted ' + encountersToUpsert.size() + ' Inpatient Encounters.');

Map<String, Id> encCodeToEncId = new Map<String, Id>();
for (Inpatient_Encounter__c enc : [SELECT Id, Encounter_Code__c FROM Inpatient_Encounter__c WHERE Encounter_Code__c IN :new Set<String>{
    'CN-D10-ENC-001', 'CN-D10-ENC-002', 'CN-D10-ENC-003', 'CN-D10-ENC-004', 'CN-D10-ENC-005',
    'CN-D10-ENC-006', 'CN-D10-ENC-007', 'CN-D10-ENC-008', 'CN-D10-ENC-009', 'CN-D10-ENC-010'
}]) {
    encCodeToEncId.put(enc.Encounter_Code__c, enc.Id);
}

// STEP D: UPSERT PATIENT VITALS BY Vital_Code__c
List<Patient_Vital__c> vitalsToUpsert = new List<Patient_Vital__c>();
for (DemoPatientDef def : cohort) {
    Id admId = admCodeToAdmId.get(def.admissionCode);
    Id encId = encCodeToEncId.get(def.encounterCode);

    vitalsToUpsert.add(new Patient_Vital__c(
        Vital_Code__c = def.vitalCode,
        Admission__c = admId,
        Inpatient_Encounter__c = encId,
        Encounter__c = encId,
        Recorded_Date__c = System.now().addHours(-4),
        Recorded_At__c = System.now().addHours(-4),
        Temperature_C__c = def.tempC,
        Pulse_BPM__c = def.pulse,
        Systolic_BP__c = def.sysBP,
        Diastolic_BP__c = def.diaBP,
        Respiratory_Rate__c = def.respRate,
        SpO2_Percent__c = def.spo2,
        Pain_Score__c = def.painScore,
        Recorded_By__c = 'Staff Nurse'
    ));
}
upsert vitalsToUpsert Vital_Code__c;
System.debug('Successfully upserted ' + vitalsToUpsert.size() + ' Patient Vitals.');
System.debug('--- 10-PATIENT DEMO DATA LOAD COMPLETED SUCCESSFULLY ---');
