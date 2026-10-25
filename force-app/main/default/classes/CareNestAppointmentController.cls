/**
 * @description Controller for flexible receptionist appointment scheduling.
 * Supports patient selection/registration integration, "Any Available Doctor" matching,
 * specialty filters, manual date/time booking with working-hour checks, atomic row locking (FOR UPDATE)
 * to prevent double-booking, conflict alternative suggestions, and rescheduling.
 */
public with sharing class CareNestAppointmentController {

    public class AppointmentInitDto {
        @AuraEnabled public List<String> departments { get; set; }
        @AuraEnabled public List<DoctorSummaryDto> doctors { get; set; }
    }

    public class DoctorSummaryDto {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String department { get; set; }
        @AuraEnabled public String specialty { get; set; }
        @AuraEnabled public Decimal consultationFee { get; set; }
    }

    public class FlexibleSlotDto {
        @AuraEnabled public Id slotId { get; set; }
        @AuraEnabled public Id doctorId { get; set; }
        @AuraEnabled public String doctorName { get; set; }
        @AuraEnabled public String department { get; set; }
        @AuraEnabled public Datetime slotStart { get; set; }
        @AuraEnabled public String slotStartFormatted { get; set; }
        @AuraEnabled public String mode { get; set; }
        @AuraEnabled public Decimal availableSeats { get; set; }
        @AuraEnabled public Decimal fee { get; set; }
    }

    public class BookingResultDto {
        @AuraEnabled public Boolean isSuccess { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public Id appointmentId { get; set; }
        @AuraEnabled public String appointmentCode { get; set; }
        @AuraEnabled public String doctorName { get; set; }
        @AuraEnabled public String department { get; set; }
        @AuraEnabled public String patientName { get; set; }
        @AuraEnabled public Datetime slotStart { get; set; }
        @AuraEnabled public Decimal feeAmount { get; set; }
        @AuraEnabled public Decimal totalAmount { get; set; }
        @AuraEnabled public Boolean isConflict { get; set; }
        @AuraEnabled public List<FlexibleSlotDto> alternativeSlots { get; set; }
    }

    /**
     * @description Returns available departments and active doctors for initial wizard setup.
     */
    @AuraEnabled(cacheable=true)
    public static AppointmentInitDto getSchedulingInitData() {
        AppointmentInitDto dto = new AppointmentInitDto();
        dto.departments = new List<String>{
            'Cardiology', 'Internal Medicine', 'Neurology', 'Orthopedics', 'Pediatrics', 'General Surgery'
        };

        List<Doctor__c> docs = [
            SELECT Id, Name, Department__c, Specialty__c, Consultation_Fee__c
            FROM Doctor__c
            WHERE Is_Active__c = true
            WITH USER_MODE
            ORDER BY Name ASC
            LIMIT 100
        ];

        dto.doctors = new List<DoctorSummaryDto>();
        for (Doctor__c d : docs) {
            DoctorSummaryDto s = new DoctorSummaryDto();
            s.id = d.Id;
            s.name = d.Name;
            s.department = d.Department__c;
            s.specialty = d.Specialty__c;
            s.consultationFee = d.Consultation_Fee__c != null ? d.Consultation_Fee__c : 0;
            dto.doctors.add(s);
        }
        return dto;
    }

    /**
     * @description Flexible slot query supporting specific doctor OR "Any Doctor" across department/hospital.
     */
    @AuraEnabled(cacheable=true)
    public static List<FlexibleSlotDto> findAvailableSlots(Id doctorId, String department, Date targetDate, String mode) {
        Datetime startOfDay = null;
        Datetime endOfDay = null;
        if (targetDate != null) {
            startOfDay = Datetime.newInstance(targetDate, Time.newInstance(0, 0, 0, 0));
            endOfDay = Datetime.newInstance(targetDate, Time.newInstance(23, 59, 59, 999));
        }

        String cleanDept = (String.isNotBlank(department) && department != 'All') ? department.trim() : null;
        String cleanMode = (String.isNotBlank(mode) && mode != 'All') ? mode.trim() : null;

        String query = 'SELECT Id, Slot_Start__c, Mode__c, Available__c, Total_Capacity__c, Booked_Count__c, ' +
                       'Doctor__r.Id, Doctor__r.Name, Doctor__r.Department__c, Doctor__r.Consultation_Fee__c ' +
                       'FROM Appointment_Slot__c ' +
                       'WHERE Is_Open__c = true ';

        if (doctorId != null) {
            query += 'AND Doctor__c = :doctorId ';
        } else if (cleanDept != null) {
            query += 'AND Doctor__r.Department__c = :cleanDept ';
        }

        if (cleanMode != null) {
            query += 'AND Mode__c = :cleanMode ';
        }

        if (startOfDay != null && endOfDay != null) {
            query += 'AND Slot_Start__c >= :startOfDay AND Slot_Start__c <= :endOfDay ';
        } else {
            Datetime nowDt = Datetime.now();
            query += 'AND Slot_Start__c >= :nowDt ';
        }

        query += 'WITH USER_MODE ORDER BY Slot_Start__c ASC LIMIT 40';

        List<Appointment_Slot__c> slots = Database.query(query);
        List<FlexibleSlotDto> results = new List<FlexibleSlotDto>();
        for (Appointment_Slot__c s : slots) {
            results.add(mapSlotDto(s));
        }
        return results;
    }

    /**
     * @description Books an appointment atomically with row-level locking (FOR UPDATE).
     * Supports slot reservation OR manual requested time with automatic slot creation within working hours.
     */
    @AuraEnabled
    public static BookingResultDto bookFlexibleAppointment(
        Id patientId,
        Id doctorId,
        String department,
        Id slotId,
        Date manualDate,
        String manualTimeStr,
        String mode
    ) {
        BookingResultDto res = new BookingResultDto();
        res.isSuccess = false;
        res.isConflict = false;
        res.alternativeSlots = new List<FlexibleSlotDto>();

        if (patientId == null) {
            throw new AuraHandledException('Patient must be selected or registered before booking.');
        }

        Id effectiveSlotId = slotId;

        // Manual Time Entry Mode: Generate or resolve slot for doctor within working hours
        if (effectiveSlotId == null) {
            if (manualDate == null || String.isBlank(manualTimeStr)) {
                throw new AuraHandledException('Please select an available slot or provide a requested date and time.');
            }

            // Resolve target doctor
            Id targetDoctorId = doctorId;
            if (targetDoctorId == null) {
                targetDoctorId = findFirstAvailableDoctorInDept(department);
                if (targetDoctorId == null) {
                    throw new AuraHandledException('No active doctor found for the requested department.');
                }
            }

            Datetime requestedDt = parseDateTime(manualDate, manualTimeStr);
            if (requestedDt == null) {
                throw new AuraHandledException('Invalid requested time format. Please use HH:mm (e.g. 10:30).');
            }

            // Validate Doctor Working Hours (08:00 to 19:00)
            Integer hour = requestedDt.hour();
            if (hour < 8 || hour >= 19) {
                res.message = 'Requested time is outside hospital clinic operating hours (08:00 AM - 07:00 PM).';
                res.isConflict = true;
                res.alternativeSlots = getSuggestedAlternatives(targetDoctorId, department, manualDate);
                return res;
            }

            effectiveSlotId = resolveOrCreateSlot(targetDoctorId, requestedDt, mode);
        }

        // Pessimistic Row Lock: Prevents simultaneous double-booking of the slot
        List<Appointment_Slot__c> lockedSlots = [
            SELECT Id, Doctor__c, Doctor__r.Name, Doctor__r.Department__c, Doctor__r.Consultation_Fee__c,
                   Slot_Start__c, Total_Capacity__c, Booked_Count__c, Is_Open__c, Mode__c
            FROM Appointment_Slot__c
            WHERE Id = :effectiveSlotId
            FOR UPDATE
        ];

        if (lockedSlots.isEmpty() || !lockedSlots[0].Is_Open__c || (lockedSlots[0].Booked_Count__c >= lockedSlots[0].Total_Capacity__c)) {
            // Slot is full or closed — Return intelligent alternative open slots
            Appointment_Slot__c fullSlot = !lockedSlots.isEmpty() ? lockedSlots[0] : null;
            Id conflictDocId = fullSlot != null ? fullSlot.Doctor__c : doctorId;
            String conflictDept = fullSlot != null ? fullSlot.Doctor__r.Department__c : department;
            Date conflictDate = fullSlot != null ? fullSlot.Slot_Start__c.date() : (manualDate != null ? manualDate : Date.today());

            res.isConflict = true;
            res.message = 'The requested appointment slot is already fully booked. Please choose an alternative slot below.';
            res.alternativeSlots = getSuggestedAlternatives(conflictDocId, conflictDept, conflictDate);
            return res;
        }

        Appointment_Slot__c chosenSlot = lockedSlots[0];

        // Create confirmed appointment record
        Appointment__c appt = new Appointment__c(
            Patient__c = patientId,
            Slot__c = chosenSlot.Id,
            Status__c = 'Confirmed'
        );

        try {
            Database.insert(appt, AccessLevel.USER_MODE);
        } catch (DmlException e) {
            res.message = e.getDmlMessage(0);
            res.isConflict = true;
            res.alternativeSlots = getSuggestedAlternatives(chosenSlot.Doctor__c, chosenSlot.Doctor__r.Department__c, chosenSlot.Slot_Start__c.date());
            return res;
        }

        // Query confirmed details
        Appointment__c created = [
            SELECT Id, Name, Fee_Amount__c, Total_Amount__c, Slot__r.Slot_Start__c,
                   Slot__r.Doctor__r.Name, Slot__r.Doctor__r.Department__c, Patient__r.Name
            FROM Appointment__c
            WHERE Id = :appt.Id
            WITH USER_MODE
            LIMIT 1
        ];

        res.isSuccess = true;
        res.appointmentId = created.Id;
        res.appointmentCode = created.Name;
        res.doctorName = created.Slot__r.Doctor__r.Name;
        res.department = created.Slot__r.Doctor__r.Department__c;
        res.patientName = created.Patient__r.Name;
        res.slotStart = created.Slot__r.Slot_Start__c;
        res.feeAmount = created.Fee_Amount__c;
        res.totalAmount = created.Total_Amount__c;
        res.message = 'Appointment confirmed successfully for ' + created.Patient__r.Name + ' with ' + created.Slot__r.Doctor__r.Name + '.';
        return res;
    }

    /**
     * @description Reschedules an appointment to a new slot atomically with concurrency check.
     */
    @AuraEnabled
    public static BookingResultDto rescheduleAppointment(Id appointmentId, Id newSlotId) {
        BookingResultDto res = new BookingResultDto();
        res.isSuccess = false;
        res.isConflict = false;

        if (appointmentId == null || newSlotId == null) {
            throw new AuraHandledException('Appointment ID and new slot ID are required.');
        }

        // Lock new slot FOR UPDATE
        List<Appointment_Slot__c> newSlots = [
            SELECT Id, Doctor__c, Doctor__r.Name, Doctor__r.Department__c,
                   Total_Capacity__c, Booked_Count__c, Is_Open__c, Slot_Start__c
            FROM Appointment_Slot__c
            WHERE Id = :newSlotId
            FOR UPDATE
        ];

        if (newSlots.isEmpty() || !newSlots[0].Is_Open__c || (newSlots[0].Booked_Count__c >= newSlots[0].Total_Capacity__c)) {
            res.isConflict = true;
            res.message = 'The target slot for rescheduling is no longer available.';
            res.alternativeSlots = getSuggestedAlternatives(newSlots[0].Doctor__c, newSlots[0].Doctor__r.Department__c, newSlots[0].Slot_Start__c.date());
            return res;
        }

        Appointment__c appt = [
            SELECT Id, Slot__c, Status__c
            FROM Appointment__c
            WHERE Id = :appointmentId
            WITH USER_MODE
            LIMIT 1
        ];

        appt.Slot__c = newSlotId;
        appt.Status__c = 'Confirmed';
        update appt;

        res.isSuccess = true;
        res.appointmentId = appt.Id;
        res.message = 'Appointment successfully rescheduled to ' + newSlots[0].Slot_Start__c.format('MMM dd, yyyy - hh:mm a') + '.';
        return res;
    }

    /**
     * @description Cancels an existing appointment.
     */
    @AuraEnabled
    public static Boolean cancelAppointmentBooking(Id appointmentId, String reason) {
        if (appointmentId == null) {
            throw new AuraHandledException('Appointment ID is required.');
        }
        Appointment__c appt = [
            SELECT Id, Status__c
            FROM Appointment__c
            WHERE Id = :appointmentId
            WITH USER_MODE
            LIMIT 1
        ];
        appt.Status__c = 'Cancelled';
        update appt;
        return true;
    }

    private static List<FlexibleSlotDto> getSuggestedAlternatives(Id doctorId, String department, Date refDate) {
        List<FlexibleSlotDto> alternatives = new List<FlexibleSlotDto>();
        Date fromDate = refDate != null ? refDate : Date.today();
        Date toDate = fromDate.addDays(3);

        Datetime startDt = Datetime.newInstance(fromDate, Time.newInstance(0, 0, 0, 0));
        Datetime endDt = Datetime.newInstance(toDate, Time.newInstance(23, 59, 59, 999));

        List<Appointment_Slot__c> slots = [
            SELECT Id, Slot_Start__c, Mode__c, Available__c, Total_Capacity__c, Booked_Count__c,
                   Doctor__r.Id, Doctor__r.Name, Doctor__r.Department__c, Doctor__r.Consultation_Fee__c
            FROM Appointment_Slot__c
            WHERE Is_Open__c = true
              AND Slot_Start__c >= :startDt
              AND Slot_Start__c <= :endDt
              AND (Doctor__c = :doctorId OR Doctor__r.Department__c = :department)
            WITH USER_MODE
            ORDER BY Slot_Start__c ASC
            LIMIT 5
        ];

        for (Appointment_Slot__c s : slots) {
            alternatives.add(mapSlotDto(s));
        }
        return alternatives;
    }

    private static Id findFirstAvailableDoctorInDept(String department) {
        String cleanDept = String.isNotBlank(department) ? department.trim() : null;
        if (cleanDept != null) {
            List<Doctor__c> docs = [
                SELECT Id
                FROM Doctor__c
                WHERE Is_Active__c = true
                  AND Department__c = :cleanDept
                WITH USER_MODE
                ORDER BY Name ASC
                LIMIT 1
            ];
            return !docs.isEmpty() ? docs[0].Id : null;
        } else {
            List<Doctor__c> docs = [
                SELECT Id
                FROM Doctor__c
                WHERE Is_Active__c = true
                WITH USER_MODE
                ORDER BY Name ASC
                LIMIT 1
            ];
            return !docs.isEmpty() ? docs[0].Id : null;
        }
    }

    private static Id resolveOrCreateSlot(Id docId, Datetime slotDt, String mode) {
        // Round to nearest 30 mins
        Integer mins = slotDt.minute();
        Integer roundedMins = (mins < 30) ? 0 : 30;
        Datetime normalizedStart = Datetime.newInstance(
            slotDt.year(), slotDt.month(), slotDt.day(),
            slotDt.hour(), roundedMins, 0
        );

        List<Appointment_Slot__c> existing = [
            SELECT Id
            FROM Appointment_Slot__c
            WHERE Doctor__c = :docId
              AND Slot_Start__c = :normalizedStart
            WITH USER_MODE
            LIMIT 1
        ];

        if (!existing.isEmpty()) {
            return existing[0].Id;
        }

        Appointment_Slot__c newSlot = new Appointment_Slot__c(
            Doctor__c = docId,
            Slot_Start__c = normalizedStart,
            Total_Capacity__c = 1,
            Booked_Count__c = 0,
            Mode__c = String.isNotBlank(mode) ? mode : 'OPD'
        );
        insert newSlot;
        return newSlot.Id;
    }

    private static Datetime parseDateTime(Date d, String timeStr) {
        try {
            String[] parts = timeStr.trim().split(':');
            Integer h = Integer.valueOf(parts[0]);
            Integer m = Integer.valueOf(parts[1]);
            return Datetime.newInstance(d, Time.newInstance(h, m, 0, 0));
        } catch (Exception e) {
            return null;
        }
    }

    private static FlexibleSlotDto mapSlotDto(Appointment_Slot__c s) {
        FlexibleSlotDto dto = new FlexibleSlotDto();
        dto.slotId = s.Id;
        dto.doctorId = s.Doctor__r != null ? s.Doctor__r.Id : null;
        dto.doctorName = s.Doctor__r != null ? s.Doctor__r.Name : '';
        dto.department = s.Doctor__r != null ? s.Doctor__r.Department__c : '';
        dto.slotStart = s.Slot_Start__c;
        dto.slotStartFormatted = s.Slot_Start__c != null ? s.Slot_Start__c.format('MMM dd, yyyy - hh:mm a') : '';
        dto.mode = s.Mode__c != null ? s.Mode__c : 'OPD';
        dto.availableSeats = s.Available__c != null ? s.Available__c : 0;
        dto.fee = (s.Doctor__r != null && s.Doctor__r.Consultation_Fee__c != null) ? s.Doctor__r.Consultation_Fee__c : 0;
        return dto;
    }
}
