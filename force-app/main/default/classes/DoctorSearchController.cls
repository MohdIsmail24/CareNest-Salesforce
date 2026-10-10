/**
 * @description Controller for CareNest Lightning Web Components:
 * Doctor Search, Slot Picker, Appointment Booking Wizard, and My Appointments.
 * Enforces server-side authorization, input validation, and user mode execution.
 */
public with sharing class DoctorSearchController {

    public class SlotOption {
        @AuraEnabled public Id id;
        @AuraEnabled public String label;
        @AuraEnabled public Decimal seatsLeft;
        @AuraEnabled public Decimal fee;
        @AuraEnabled public String mode;
        @AuraEnabled public Datetime slotStart;
        @AuraEnabled public String doctorName;
        @AuraEnabled public String department;

        public SlotOption() {}
        public SlotOption(Appointment_Slot__c slot) {
            this.id = slot.Id;
            this.label = (slot.Slot_Start__c != null ? slot.Slot_Start__c.format('MMM dd, yyyy - hh:mm a') : 'Slot')
                         + ' (' + (slot.Mode__c != null ? slot.Mode__c : 'OPD') + ')';
            this.seatsLeft = slot.Available__c != null ? slot.Available__c : 0;
            this.fee = (slot.Doctor__r != null && slot.Doctor__r.Consultation_Fee__c != null)
                       ? slot.Doctor__r.Consultation_Fee__c : 0;
            this.mode = slot.Mode__c;
            this.slotStart = slot.Slot_Start__c;
            this.doctorName = slot.Doctor__r != null ? slot.Doctor__r.Name : '';
            this.department = slot.Doctor__r != null ? slot.Doctor__r.Department__c : '';
        }
    }

    public class CancelResultDto {
        @AuraEnabled public Id appointmentId;
        @AuraEnabled public Id cancellationId;
        @AuraEnabled public Decimal fee;
        @AuraEnabled public Decimal refund;
        @AuraEnabled public Boolean isSuccess;
        @AuraEnabled public String errorMessage;

        public CancelResultDto() {}
        public CancelResultDto(CancellationService.CancellationResult res) {
            this.appointmentId = res.appointmentId;
            this.cancellationId = res.cancellationId;
            this.fee = res.fee;
            this.refund = res.refund;
            this.isSuccess = res.isSuccess;
            this.errorMessage = res.errorMessage;
        }
    }

    public class UserContextDto {
        @AuraEnabled public Boolean isPatient;
        @AuraEnabled public Id contactId;
        @AuraEnabled public String contactName;
    }

    @TestVisible private static Id mockContactId = null;

    /**
     * @description Resolves the ContactId of the current user session.
     * In unit test contexts, allows testing portal user behavior via mockContactId.
     * @return ContactId of current user if portal patient, otherwise null.
     */
    private static Id getCurrentUserContactId() {
        if (Test.isRunningTest() && mockContactId != null) {
            return mockContactId;
        }
        User u = [SELECT Id, ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        return u.ContactId;
    }

    /**
     * @description Returns the patient identity context of the current logged-in user.
     * @return UserContextDto containing Contact information if user is an authenticated patient portal user.
     */
    @AuraEnabled(cacheable=true)
    public static UserContextDto getUserContext() {
        UserContextDto ctx = new UserContextDto();
        Id effectiveContactId = getCurrentUserContactId();
        if (effectiveContactId != null) {
            ctx.isPatient = true;
            ctx.contactId = effectiveContactId;
            List<Contact> contacts = [
                SELECT Id, Name
                FROM Contact
                WHERE Id = :effectiveContactId
                WITH USER_MODE
                LIMIT 1
            ];
            ctx.contactName = !contacts.isEmpty() ? contacts[0].Name : null;
        } else {
            ctx.isPatient = false;
            ctx.contactId = null;
            ctx.contactName = null;
        }
        return ctx;
    }

    /**
     * @description Queries active doctors matching optional department and search key.
     * @param department Medical department filter.
     * @param searchKey Partial doctor name.
     * @return List of matching Doctor__c records.
     */
    @AuraEnabled(cacheable=true)
    public static List<Doctor__c> getDoctors(String department, String searchKey) {
        String cleanDept = String.isNotBlank(department) && department != 'All' ? department.trim() : null;
        String cleanSearch = String.isNotBlank(searchKey) ? '%' + searchKey.trim() + '%' : null;

        if (cleanDept != null && cleanSearch != null) {
            return [
                SELECT Id, Name, Department__c, Specialty__c, Consultation_Fee__c, Is_Active__c
                FROM Doctor__c
                WHERE Is_Active__c = true
                  AND Department__c = :cleanDept
                  AND Name LIKE :cleanSearch
                WITH USER_MODE
                ORDER BY Name ASC
                LIMIT 50
            ];
        } else if (cleanDept != null) {
            return [
                SELECT Id, Name, Department__c, Specialty__c, Consultation_Fee__c, Is_Active__c
                FROM Doctor__c
                WHERE Is_Active__c = true
                  AND Department__c = :cleanDept
                WITH USER_MODE
                ORDER BY Name ASC
                LIMIT 50
            ];
        } else if (cleanSearch != null) {
            return [
                SELECT Id, Name, Department__c, Specialty__c, Consultation_Fee__c, Is_Active__c
                FROM Doctor__c
                WHERE Is_Active__c = true
                  AND Name LIKE :cleanSearch
                WITH USER_MODE
                ORDER BY Name ASC
                LIMIT 50
            ];
        } else {
            return [
                SELECT Id, Name, Department__c, Specialty__c, Consultation_Fee__c, Is_Active__c
                FROM Doctor__c
                WHERE Is_Active__c = true
                WITH USER_MODE
                ORDER BY Name ASC
                LIMIT 50
            ];
        }
    }

    /**
     * @description Dynamic slot query with bind variables matching the CareNest Project Guide specification.
     * @param department Medical department filter.
     * @param mode OPD or Teleconsult filter.
     * @param onDate Target appointment date.
     * @return List of available SlotOption DTOs.
     */
    @AuraEnabled(cacheable=true)
    public static List<SlotOption> searchSlots(String department, String mode, Date onDate) {
        String cleanDept = String.isNotBlank(department) && department != 'All' ? department.trim() : null;
        String cleanMode = String.isNotBlank(mode) && mode != 'All' ? mode.trim() : null;

        Datetime startOfDay = null;
        Datetime endOfDay = null;
        if (onDate != null) {
            startOfDay = Datetime.newInstance(onDate, Time.newInstance(0, 0, 0, 0));
            endOfDay = Datetime.newInstance(onDate, Time.newInstance(23, 59, 59, 999));
        }

        List<Appointment_Slot__c> slots;
        if (cleanDept != null && cleanMode != null && onDate != null) {
            slots = [
                SELECT Id, Slot_Start__c, Mode__c, Available__c, Total_Capacity__c, Booked_Count__c,
                       Doctor__r.Name, Doctor__r.Department__c, Doctor__r.Consultation_Fee__c
                FROM Appointment_Slot__c
                WHERE Is_Open__c = true
                  AND Doctor__r.Department__c = :cleanDept
                  AND Mode__c = :cleanMode
                  AND Slot_Start__c >= :startOfDay
                  AND Slot_Start__c <= :endOfDay
                WITH USER_MODE
                ORDER BY Slot_Start__c ASC
                LIMIT 50
            ];
        } else if (cleanDept != null && cleanMode != null) {
            slots = [
                SELECT Id, Slot_Start__c, Mode__c, Available__c, Total_Capacity__c, Booked_Count__c,
                       Doctor__r.Name, Doctor__r.Department__c, Doctor__r.Consultation_Fee__c
                FROM Appointment_Slot__c
                WHERE Is_Open__c = true
                  AND Doctor__r.Department__c = :cleanDept
                  AND Mode__c = :cleanMode
                WITH USER_MODE
                ORDER BY Slot_Start__c ASC
                LIMIT 50
            ];
        } else if (cleanDept != null) {
            slots = [
                SELECT Id, Slot_Start__c, Mode__c, Available__c, Total_Capacity__c, Booked_Count__c,
                       Doctor__r.Name, Doctor__r.Department__c, Doctor__r.Consultation_Fee__c
                FROM Appointment_Slot__c
                WHERE Is_Open__c = true
                  AND Doctor__r.Department__c = :cleanDept
                WITH USER_MODE
                ORDER BY Slot_Start__c ASC
                LIMIT 50
            ];
        } else {
            slots = [
                SELECT Id, Slot_Start__c, Mode__c, Available__c, Total_Capacity__c, Booked_Count__c,
                       Doctor__r.Name, Doctor__r.Department__c, Doctor__r.Consultation_Fee__c
                FROM Appointment_Slot__c
                WHERE Is_Open__c = true
                WITH USER_MODE
                ORDER BY Slot_Start__c ASC
                LIMIT 50
            ];
        }

        List<SlotOption> options = new List<SlotOption>();
        for (Appointment_Slot__c s : slots) {
            options.add(new SlotOption(s));
        }
        return options;
    }

    /**
     * @description Retrieves open slots for a specific doctor.
     * @param doctorId Validated Doctor__c Record Id.
     * @param slotDate Optional date filter.
     * @return List of SlotOption DTOs.
     */
    @AuraEnabled(cacheable=true)
    public static List<SlotOption> getDoctorSlots(Id doctorId, Date slotDate) {
        if (doctorId == null || doctorId.getSObjectType() != Doctor__c.sObjectType) {
            throw new AuraHandledException('Invalid Doctor Id supplied.');
        }

        Datetime startOfDay = null;
        Datetime endOfDay = null;
        if (slotDate != null) {
            startOfDay = Datetime.newInstance(slotDate, Time.newInstance(0, 0, 0, 0));
            endOfDay = Datetime.newInstance(slotDate, Time.newInstance(23, 59, 59, 999));
        }

        List<Appointment_Slot__c> slots;
        if (slotDate != null) {
            slots = [
                SELECT Id, Slot_Start__c, Mode__c, Available__c, Total_Capacity__c, Booked_Count__c,
                       Doctor__r.Name, Doctor__r.Department__c, Doctor__r.Consultation_Fee__c
                FROM Appointment_Slot__c
                WHERE Doctor__c = :doctorId
                  AND Is_Open__c = true
                  AND Slot_Start__c >= :startOfDay
                  AND Slot_Start__c <= :endOfDay
                WITH USER_MODE
                ORDER BY Slot_Start__c ASC
                LIMIT 50
            ];
        } else {
            slots = [
                SELECT Id, Slot_Start__c, Mode__c, Available__c, Total_Capacity__c, Booked_Count__c,
                       Doctor__r.Name, Doctor__r.Department__c, Doctor__r.Consultation_Fee__c
                FROM Appointment_Slot__c
                WHERE Doctor__c = :doctorId
                  AND Is_Open__c = true
                WITH USER_MODE
                ORDER BY Slot_Start__c ASC
                LIMIT 50
            ];
        }

        List<SlotOption> options = new List<SlotOption>();
        for (Appointment_Slot__c s : slots) {
            options.add(new SlotOption(s));
        }
        return options;
    }

    /**
     * @description Searches patient Contacts by patient code, name, or phone.
     * Restricted to authenticated staff with minimum 2-character query.
     * @param searchKey Query term.
     * @return List of patient Contact records.
     */
    @AuraEnabled(cacheable=true)
    public static List<Contact> searchPatients(String searchKey) {
        Id contactId = getCurrentUserContactId();
        if (contactId != null) {
            throw new AuraHandledException('Patient search is restricted to internal healthcare staff.');
        }

        if (String.isBlank(searchKey) || searchKey.trim().length() < 2) {
            return new List<Contact>();
        }
        String cleanKey = '%' + searchKey.trim() + '%';
        String exactCode = searchKey.trim().toUpperCase();

        return [
            SELECT Id, Name, Email, Phone, Patient_Code__c
            FROM Contact
            WHERE Patient_Code__c != null
              AND (Patient_Code__c = :exactCode OR Name LIKE :cleanKey OR Phone LIKE :cleanKey)
            WITH USER_MODE
            ORDER BY Name ASC
            LIMIT 10
        ];
    }

    /**
     * @description Books an appointment. Validates IDs, enforces patient authorization,
     * copies consultation fee securely from the Doctor record, and delegates concurrency
     * locking and capacity enforcement to Phase 07 AppointmentService.
     * @param slotId Validated Appointment_Slot__c record ID.
     * @param patientId Validated Contact record ID.
     * @return Confirmed Appointment__c record.
     */
    @AuraEnabled
    public static Appointment__c bookAppointment(Id slotId, Id patientId) {
        if (slotId == null || slotId.getSObjectType() != Appointment_Slot__c.sObjectType) {
            throw new AuraHandledException('Invalid slot selected.');
        }

        // Verify slot is currently open and valid
        List<Appointment_Slot__c> openSlots = [
            SELECT Id, Is_Open__c, Doctor__c, Doctor__r.Consultation_Fee__c
            FROM Appointment_Slot__c
            WHERE Id = :slotId
            WITH USER_MODE
            LIMIT 1
        ];
        if (openSlots.isEmpty() || !openSlots[0].Is_Open__c) {
            throw new AuraHandledException('This slot is full or no longer available. Please choose another time.');
        }

        // Patient identity authorization:
        // If current user is a portal patient, enforce their own ContactId to prevent booking for others
        Id effectiveContactId = getCurrentUserContactId();
        Id effectivePatientId;
        if (effectiveContactId != null) {
            effectivePatientId = effectiveContactId;
        } else {
            if (patientId == null || patientId.getSObjectType() != Contact.sObjectType) {
                throw new AuraHandledException('Please select a valid patient.');
            }
            effectivePatientId = patientId;
        }

        // Create appointment in Confirmed status without trusting client-provided pricing
        // AppointmentService will automatically copy Fee_Amount__c and compute Total_Amount__c
        Appointment__c appt = new Appointment__c(
            Slot__c = slotId,
            Patient__c = effectivePatientId,
            Status__c = 'Confirmed'
        );

        try {
            Database.insert(appt, AccessLevel.USER_MODE);
        } catch (DmlException e) {
            throw new AuraHandledException(e.getDmlMessage(0));
        } catch (Exception e) {
            throw new AuraHandledException('Unable to complete booking: ' + e.getMessage());
        }

        return [
            SELECT Id, Name, Status__c, Fee_Amount__c, Total_Amount__c,
                   Slot__r.Slot_Start__c, Slot__r.Mode__c, Slot__r.Doctor__r.Name,
                   Patient__r.Name
            FROM Appointment__c
            WHERE Id = :appt.Id
            WITH USER_MODE
            LIMIT 1
        ];
    }

    /**
     * @description Retrieves appointments for the authenticated patient portal user.
     * Throws an exception if user has no mapped patient ContactId.
     * @return List of Appointment__c records.
     */
    @AuraEnabled(cacheable=true)
    public static List<Appointment__c> getMyAppointments() {
        Id effectiveContactId = getCurrentUserContactId();
        if (effectiveContactId == null) {
            throw new AuraHandledException('No associated patient profile found for the current user session. This view requires an authenticated patient portal user.');
        }

        return [
            SELECT Id, Name, Status__c, Fee_Amount__c, Discount_Percent__c,
                   Total_Amount__c, Amount_Paid__c, Balance_Due__c,
                   Slot__r.Slot_Start__c, Slot__r.Mode__c,
                   Slot__r.Doctor__r.Name, Slot__r.Doctor__r.Department__c
            FROM Appointment__c
            WHERE Patient__c = :effectiveContactId
            WITH USER_MODE
            ORDER BY Slot__r.Slot_Start__c DESC
            LIMIT 50
        ];
    }

    /**
     * @description Cancels an appointment delegating to Phase 07 CancellationService.
     * Verifies that portal patients can only cancel their own appointments.
     * @param appointmentId ID of appointment to cancel.
     * @param reason Reason for cancellation.
     * @return CancelResultDto with cancellation fee and refund amounts.
     */
    @AuraEnabled
    public static CancelResultDto cancelAppointment(Id appointmentId, String reason) {
        if (appointmentId == null || appointmentId.getSObjectType() != Appointment__c.sObjectType) {
            throw new AuraHandledException('Invalid appointment ID.');
        }

        Id effectiveContactId = getCurrentUserContactId();
        List<Appointment__c> appt = [
            SELECT Id, Patient__c, Status__c
            FROM Appointment__c
            WHERE Id = :appointmentId
            WITH USER_MODE
            LIMIT 1
        ];
        if (appt.isEmpty()) {
            throw new AuraHandledException('Appointment not found or insufficient access.');
        }

        // If portal user, verify patient ownership
        if (effectiveContactId != null && appt[0].Patient__c != effectiveContactId) {
            throw new AuraHandledException('You are not authorized to cancel this appointment.');
        }

        try {
            CancellationService.CancellationResult res = CancellationService.cancel(appointmentId, reason);
            return new CancelResultDto(res);
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /**
     * @description Retrieves billing and fee details for a specific appointment.
     * Enforces user mode and patient authorization (portal user can only access their own appointment).
     * @param appointmentId ID of the Appointment__c record.
     * @return Appointment__c record containing fee, discount, paid amount, balance due, doctor, and patient details.
     */
    @AuraEnabled(cacheable=true)
    public static Appointment__c getBillingDetails(Id appointmentId) {
        if (appointmentId == null || appointmentId.getSObjectType() != Appointment__c.sObjectType) {
            throw new AuraHandledException('Invalid appointment ID.');
        }

        Id effectiveContactId = getCurrentUserContactId();

        List<Appointment__c> appts = [
            SELECT Id, Name, Status__c, Fee_Amount__c, Discount_Percent__c,
                   Total_Amount__c, Amount_Paid__c, Balance_Due__c,
                   Patient__c, Patient__r.Name,
                   Slot__r.Slot_Start__c, Slot__r.Mode__c,
                   Slot__r.Doctor__r.Name, Slot__r.Doctor__r.Department__c
            FROM Appointment__c
            WHERE Id = :appointmentId
            WITH USER_MODE
            LIMIT 1
        ];

        if (appts.isEmpty()) {
            throw new AuraHandledException('Appointment not found or insufficient access.');
        }

        if (effectiveContactId != null && appts[0].Patient__c != effectiveContactId) {
            throw new AuraHandledException('You are not authorized to view billing details for this appointment.');
        }

        return appts[0];
    }
}
