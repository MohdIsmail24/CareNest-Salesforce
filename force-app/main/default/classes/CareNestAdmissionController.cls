/**
 * @description Controller for the Patient Admission Workspace and Patient Registration (Module 3 & Phase 21).
 * Supports patient registration with auto-generated Patient_Code__c and duplicate detection,
 * patient search across code/name/phone/email, live ward and bed capacity rollups,
 * doctor availability resolution (checking open Appointment_Slot__c), atomic admission creation
 * with pessimistic row locking, and discharge processing via AdmissionService.
 * Enforces server-side authorization, input validation, and user mode execution.
 */
public with sharing class CareNestAdmissionController {

    public class AdmissionSummaryDto {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String admissionCode { get; set; }
        @AuraEnabled public Id patientId { get; set; }
        @AuraEnabled public String patientName { get; set; }
        @AuraEnabled public String patientPhone { get; set; }
        @AuraEnabled public String patientCode { get; set; }
        @AuraEnabled public Id bedId { get; set; }
        @AuraEnabled public String bedCode { get; set; }
        @AuraEnabled public Id wardId { get; set; }
        @AuraEnabled public String wardName { get; set; }
        @AuraEnabled public String wardType { get; set; }
        @AuraEnabled public String room { get; set; }
        @AuraEnabled public Id doctorId { get; set; }
        @AuraEnabled public String doctorName { get; set; }
        @AuraEnabled public String doctorDepartment { get; set; }
        @AuraEnabled public Datetime admissionDate { get; set; }
        @AuraEnabled public Datetime dischargeDate { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String admissionType { get; set; }
        @AuraEnabled public String reason { get; set; }
        @AuraEnabled public String dischargeSummary { get; set; }
        @AuraEnabled public String statusBadgeClass { get; set; }
    }

    public class SelectOptionDto {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }
        @AuraEnabled public String description { get; set; }
        @AuraEnabled public Id bedId { get; set; }
        @AuraEnabled public Id doctorId { get; set; }

        public SelectOptionDto(String label, String value) {
            this.label = label;
            this.value = value;
            this.description = '';
            try {
                Id recordId = (Id) value;
                if (recordId.getSObjectType() == Bed__c.sObjectType) {
                    this.bedId = recordId;
                } else if (recordId.getSObjectType() == Doctor__c.sObjectType) {
                    this.doctorId = recordId;
                }
            } catch (Exception e) {}
        }

        public SelectOptionDto(String label, String value, String description) {
            this(label, value);
            this.description = description;
        }
    }

    public class PatientLookupDto {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public Date birthdate { get; set; }
        @AuraEnabled public String patientCode { get; set; }
    }

    public class PatientDirectoryDto {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public Date birthdate { get; set; }
        @AuraEnabled public String patientCode { get; set; }
        @AuraEnabled public Datetime createdDate { get; set; }
        @AuraEnabled public Boolean isAdmitted { get; set; }
        @AuraEnabled public Id currentAdmissionId { get; set; }
        @AuraEnabled public String currentAdmissionNumber { get; set; }
        @AuraEnabled public String currentBedCode { get; set; }
        @AuraEnabled public String currentWardName { get; set; }
        @AuraEnabled public String admissionStatusBadge { get; set; }
    }

    public class PatientRegistrationResultDto {
        @AuraEnabled public Boolean isSuccess { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public Id contactId { get; set; }
        @AuraEnabled public Id accountId { get; set; }
        @AuraEnabled public String patientCode { get; set; }
        @AuraEnabled public String patientName { get; set; }
        @AuraEnabled public String phone { get; set; }
        @AuraEnabled public String email { get; set; }
        @AuraEnabled public Boolean isDuplicate { get; set; }
        @AuraEnabled public Id duplicateContactId { get; set; }
        @AuraEnabled public String duplicateContactName { get; set; }
        @AuraEnabled public String duplicatePatientCode { get; set; }
    }

    public class WardAvailabilityDto {
        @AuraEnabled public Id wardId { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String wardCode { get; set; }
        @AuraEnabled public String wardType { get; set; }
        @AuraEnabled public String floor { get; set; }
        @AuraEnabled public Integer plannedCapacity { get; set; }
        @AuraEnabled public Integer totalInstalledBeds { get; set; }
        @AuraEnabled public Integer availableBeds { get; set; }
        @AuraEnabled public Integer occupiedBeds { get; set; }
        @AuraEnabled public Decimal occupancyRate { get; set; }
        @AuraEnabled public Boolean isSelectable { get; set; }
    }

    public class BedDetailOptionDto {
        @AuraEnabled public Id bedId { get; set; }
        @AuraEnabled public String value { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String bedCode { get; set; }
        @AuraEnabled public String bedType { get; set; }
        @AuraEnabled public Decimal dailyCharge { get; set; }
        @AuraEnabled public String floor { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public Id wardId { get; set; }
        @AuraEnabled public String wardName { get; set; }
        @AuraEnabled public String wardType { get; set; }
    }

    public class DoctorAvailabilityDto {
        @AuraEnabled public Id doctorId { get; set; }
        @AuraEnabled public String value { get; set; }
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String department { get; set; }
        @AuraEnabled public String specialty { get; set; }
        @AuraEnabled public Decimal consultationFee { get; set; }
        @AuraEnabled public String availabilityStatus { get; set; }
        @AuraEnabled public Integer openSlotsCount { get; set; }
        @AuraEnabled public String nextSlotTime { get; set; }
        @AuraEnabled public String badgeClass { get; set; }
    }

    public class AdmissionActionResultDto {
        @AuraEnabled public Boolean isSuccess { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public Id admissionId { get; set; }
        @AuraEnabled public String admissionNumber { get; set; }
        @AuraEnabled public String patientName { get; set; }
        @AuraEnabled public String bedCode { get; set; }
        @AuraEnabled public String wardName { get; set; }
    }

    @TestVisible public static Id mockRegistryAccountId = null;
    @TestVisible public static Boolean forceMissingRegistryAccount = false;
    public static final String REGISTRY_ACCOUNT_NAME = 'CareNest Inpatient Registry';

    /**
     * @description Resolves the hospital registry Account Id for patient contact association.
     * Enforces fail-closed validation if the registry account is not configured in the org.
     */
    private static Id resolveRegistryAccountId() {
        if (Test.isRunningTest() && forceMissingRegistryAccount) {
            return null;
        }
        if (Test.isRunningTest() && mockRegistryAccountId != null) {
            return mockRegistryAccountId;
        }
        List<Account> accounts = [
            SELECT Id, Name
            FROM Account
            WHERE Name = :REGISTRY_ACCOUNT_NAME
            LIMIT 1
        ];
        if (!accounts.isEmpty()) {
            return accounts[0].Id;
        }
        return null;
    }

    // =========================================================================
    // 1. PATIENT REGISTRATION & LOOKUP
    // =========================================================================

    /**
     * @description Registers a new hospital patient. Validates required fields, checks for
     * duplicates by phone/email, auto-generates a unique Patient_Code__c (CN-PAT-XXXXX),
     * and inserts the Contact in USER_MODE.
     */
    @AuraEnabled
    public static PatientRegistrationResultDto registerPatient(
        String firstName,
        String lastName,
        String phone,
        String email,
        Date birthdate,
        Boolean allowDuplicate
    ) {
        PatientRegistrationResultDto result = new PatientRegistrationResultDto();
        try {
            if (String.isBlank(lastName)) {
                throw new AuraHandledException('Patient Last Name is required.');
            }

            String cleanFirst = String.isNotBlank(firstName) ? firstName.trim() : '';
            String cleanLast = lastName.trim();
            String cleanPhone = String.isNotBlank(phone) ? phone.trim() : null;
            String cleanEmail = String.isNotBlank(email) ? email.trim() : null;

            // Duplicate detection if allowDuplicate is not explicitly true
            if (allowDuplicate != true) {
                List<Contact> duplicates = new List<Contact>();
                if (cleanPhone != null) {
                    duplicates = [
                        SELECT Id, Name, Phone, Email, Patient_Code__c
                        FROM Contact
                        WHERE Phone = :cleanPhone
                        WITH USER_MODE
                        LIMIT 1
                    ];
                }
                if (duplicates.isEmpty() && cleanEmail != null) {
                    duplicates = [
                        SELECT Id, Name, Phone, Email, Patient_Code__c
                        FROM Contact
                        WHERE Email = :cleanEmail
                        WITH USER_MODE
                        LIMIT 1
                    ];
                }

                if (!duplicates.isEmpty()) {
                    Contact dup = duplicates[0];
                    result.isSuccess = false;
                    result.isDuplicate = true;
                    result.duplicateContactId = dup.Id;
                    result.duplicateContactName = dup.Name;
                    result.duplicatePatientCode = dup.Patient_Code__c;
                    result.message = 'A patient record already exists with matching contact details: ' + dup.Name +
                                     (String.isNotBlank(dup.Patient_Code__c) ? ' (' + dup.Patient_Code__c + ')' : '') +
                                     '. You can select this existing patient or confirm registration.';
                    return result;
                }
            }

            // Auto-generate next unique Patient_Code__c
            String newPatientCode = generateNextPatientCode();

            // Strict privacy architecture: Keep patient Contacts as unlinked private orphan Contacts (AccountId = null)
            // under ControlledByParent OWD to prevent broad Account ReadWrite demographic leakage to non-clinical users.
            Contact newPatient = new Contact(
                AccountId = null,
                FirstName = cleanFirst,
                LastName = cleanLast,
                Phone = cleanPhone,
                Email = cleanEmail,
                Birthdate = birthdate,
                Patient_Code__c = newPatientCode,
                MC_Is_Patient__c = true
            );

            // Insert with concurrency retry on duplicate code using USER_MODE and duplicate rule bypass if confirmed
            Boolean inserted = false;
            Integer insertAttempts = 0;
            while (!inserted && insertAttempts < 3) {
                try {
                    Database.DMLOptions dml = new Database.DMLOptions();
                    dml.DuplicateRuleHeader.AllowSave = true;
                    dml.DuplicateRuleHeader.RunAsCurrentUser = true;
                    Database.SaveResult sr = Database.insert(newPatient, dml, AccessLevel.USER_MODE);
                    if (sr.isSuccess()) {
                        inserted = true;
                    } else {
                        String errMsg = sr.getErrors()[0].getMessage();
                        if (errMsg.contains('DUPLICATE_VALUE') || errMsg.contains('Patient_Code__c')) {
                            insertAttempts++;
                            newPatient.Patient_Code__c = generateNextPatientCode();
                        } else {
                            throw new DmlException(errMsg);
                        }
                    }
                } catch (DmlException de) {
                    if (de.getMessage().contains('DUPLICATE_VALUE') || de.getMessage().contains('Patient_Code__c')) {
                        insertAttempts++;
                        newPatient.Patient_Code__c = generateNextPatientCode();
                    } else {
                        throw de;
                    }
                }
            }

            Contact created = [
                SELECT Id, Name, FirstName, LastName, Phone, Email, Birthdate, Patient_Code__c, AccountId
                FROM Contact
                WHERE Id = :newPatient.Id
                WITH USER_MODE
                LIMIT 1
            ];

            result.isSuccess = true;
            result.isDuplicate = false;
            result.contactId = created.Id;
            result.accountId = created.AccountId;
            result.patientCode = created.Patient_Code__c;
            result.patientName = created.Name;
            result.phone = created.Phone;
            result.email = created.Email;
            result.message = 'Patient registered successfully with Patient Code: ' + created.Patient_Code__c;

        } catch (AuraHandledException ahe) {
            result.isSuccess = false;
            result.message = ahe.getMessage();
            throw ahe;
        } catch (Exception e) {
            result.isSuccess = false;
            result.message = e.getMessage();
            AuraHandledException ahe = new AuraHandledException(e.getMessage());
            ahe.setMessage(e.getMessage());
            throw ahe;
        }
        return result;
    }

    /**
     * @description Generates the next sequential unique Patient Code (CN-PAT-XXXXX).
     */
    private static String generateNextPatientCode() {
        Integer nextNum = 101;
        List<Contact> maxCodeContacts = [
            SELECT Patient_Code__c
            FROM Contact
            WHERE Patient_Code__c LIKE 'CN-PAT-%'
            WITH USER_MODE
            ORDER BY Patient_Code__c DESC
            LIMIT 1
        ];

        if (!maxCodeContacts.isEmpty() && String.isNotBlank(maxCodeContacts[0].Patient_Code__c)) {
            String codeStr = maxCodeContacts[0].Patient_Code__c;
            String digits = codeStr.replaceAll('[^0-9]', '');
            if (String.isNotBlank(digits)) {
                try {
                    nextNum = Integer.valueOf(digits) + 1;
                } catch (Exception e) {
                    nextNum = 101;
                }
            }
        }

        // Loop to ensure uniqueness against concurrent inserts
        Boolean uniqueFound = false;
        String candidateCode = '';
        Integer attempts = 0;
        while (!uniqueFound && attempts < 20) {
            candidateCode = 'CN-PAT-' + String.valueOf(nextNum).leftPad(5, '0');
            Integer count = [SELECT count() FROM Contact WHERE Patient_Code__c = :candidateCode WITH USER_MODE];
            if (count == 0) {
                uniqueFound = true;
            } else {
                nextNum++;
                attempts++;
            }
        }

        if (!uniqueFound) {
            candidateCode = 'CN-PAT-' + String.valueOf(Crypto.getRandomInteger()).substring(1, 6);
        }
        return candidateCode;
    }

    /**
     * @description Enhanced patient search matching across Patient_Code__c, Name, Phone, and Email.
     */
    @AuraEnabled(cacheable=true)
    public static List<PatientLookupDto> searchPatients(String searchTerm) {
        return CareNestPatientAccessService.searchPatients(searchTerm);
    }

    /**
     * @description Retrieves the hospital patient directory with real-time admission status.
     * When searchTerm is provided, filters across name, code, phone, and email.
     * When searchTerm is blank, returns the most recently registered hospital patients.
     */
    @AuraEnabled(cacheable=true)
    public static List<PatientDirectoryDto> getPatientDirectory(String searchTerm) {
        return CareNestPatientAccessService.getPatientDirectory(searchTerm);
    }

    // =========================================================================
    // 2. LIVE WARD & BED INVENTORY
    // =========================================================================

    /**
     * @description Retrieves all active wards with real-time capacity and bed rollups.
     * Accurately distinguishes between planned max capacity and installed beds.
     */
    @AuraEnabled(cacheable=true)
    public static List<WardAvailabilityDto> getWardsWithAvailability() {
        List<WardAvailabilityDto> results = new List<WardAvailabilityDto>();
        try {
            List<Ward__c> wards = [
                SELECT Id, Name, Ward_Code__c, Ward_Type__c, Floor__c, Capacity__c,
                       Current_Bed_Count__c, Available_Bed_Count__c
                FROM Ward__c
                WHERE Is_Active__c = true
                WITH USER_MODE
                ORDER BY Floor__c ASC, Name ASC
            ];

            for (Ward__c w : wards) {
                WardAvailabilityDto dto = new WardAvailabilityDto();
                dto.wardId = w.Id;
                dto.name = w.Name;
                dto.wardCode = w.Ward_Code__c;
                dto.wardType = w.Ward_Type__c;
                dto.floor = w.Floor__c != null ? String.valueOf(w.Floor__c) : '1';
                dto.plannedCapacity = w.Capacity__c != null ? w.Capacity__c.intValue() : 0;
                dto.totalInstalledBeds = w.Current_Bed_Count__c != null ? w.Current_Bed_Count__c.intValue() : 0;
                dto.availableBeds = w.Available_Bed_Count__c != null ? w.Available_Bed_Count__c.intValue() : 0;
                dto.occupiedBeds = dto.totalInstalledBeds - dto.availableBeds;
                if (dto.occupiedBeds < 0) dto.occupiedBeds = 0;
                dto.occupancyRate = dto.totalInstalledBeds > 0
                    ? ((Decimal.valueOf(dto.occupiedBeds) / Decimal.valueOf(dto.totalInstalledBeds)) * 100).setScale(1)
                    : 0;
                dto.isSelectable = dto.availableBeds > 0;
                results.add(dto);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'CareNestAdmissionController.getWardsWithAvailability error: ' + e.getMessage());
        }
        return results;
    }

    /**
     * @description Queries available beds filtered by optional wardId.
     * Returns structured BedDetailOptionDto with pricing, type, floor, and ward context.
     */
    @AuraEnabled(cacheable=true)
    public static List<SelectOptionDto> getAvailableBeds(Id wardId) {
        List<SelectOptionDto> options = new List<SelectOptionDto>();
        try {
            String query = 'SELECT Id, Name, Bed_Code__c, Bed_Type__c, Daily_Charge__c, Floor__c, Ward__c, Ward__r.Name, Ward__r.Ward_Type__c ' +
                           'FROM Bed__c WHERE Status__c = \'Available\' ';
            if (wardId != null) {
                query += ' AND Ward__c = :wardId';
            }
            query += ' WITH USER_MODE ORDER BY Bed_Code__c ASC, Name ASC LIMIT 50';

            List<Bed__c> beds = Database.query(query);
            for (Bed__c b : beds) {
                String code = String.isNotBlank(b.Bed_Code__c) ? b.Bed_Code__c : b.Name;
                String wardName = b.Ward__r != null ? b.Ward__r.Name : 'General';
                String bedType = b.Bed_Type__c != null ? b.Bed_Type__c : 'Standard';
                String priceStr = b.Daily_Charge__c != null ? '₹' + String.valueOf(b.Daily_Charge__c.intValue()) + '/day' : '';
                String descStr = wardName + ' • ' + bedType + (String.isNotBlank(priceStr) ? ' • ' + priceStr : '');
                SelectOptionDto opt = new SelectOptionDto(code + ' (' + descStr + ')', b.Id, descStr);
                opt.bedId = b.Id;
                options.add(opt);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'CareNestAdmissionController.getAvailableBeds error: ' + e.getMessage());
        }
        return options;
    }

    /**
     * @description Extended available beds method returning full structured BedDetailOptionDto.
     */
    @AuraEnabled(cacheable=true)
    public static List<BedDetailOptionDto> getAvailableBedDetails(Id wardId) {
        List<BedDetailOptionDto> options = new List<BedDetailOptionDto>();
        try {
            String query = 'SELECT Id, Name, Bed_Code__c, Bed_Type__c, Daily_Charge__c, Floor__c, Status__c, Ward__c, Ward__r.Name, Ward__r.Ward_Type__c ' +
                           'FROM Bed__c WHERE Status__c = \'Available\' ';
            if (wardId != null) {
                query += ' AND Ward__c = :wardId';
            }
            query += ' WITH USER_MODE ORDER BY Bed_Code__c ASC, Name ASC LIMIT 50';

            List<Bed__c> beds = Database.query(query);
            for (Bed__c b : beds) {
                BedDetailOptionDto dto = new BedDetailOptionDto();
                dto.bedId = b.Id;
                dto.value = b.Id;
                dto.bedCode = String.isNotBlank(b.Bed_Code__c) ? b.Bed_Code__c : b.Name;
                dto.bedType = b.Bed_Type__c != null ? b.Bed_Type__c : 'Standard';
                dto.dailyCharge = b.Daily_Charge__c != null ? b.Daily_Charge__c : 0;
                dto.floor = b.Floor__c != null ? String.valueOf(b.Floor__c.intValue()) : '1';
                dto.status = b.Status__c;
                dto.wardId = b.Ward__c;
                dto.wardName = b.Ward__r != null ? b.Ward__r.Name : '';
                dto.wardType = b.Ward__r != null ? b.Ward__r.Ward_Type__c : '';
                dto.label = dto.bedCode + ' (' + dto.wardName + ' • ' + dto.bedType + ')';
                options.add(dto);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'CareNestAdmissionController.getAvailableBedDetails error: ' + e.getMessage());
        }
        return options;
    }

    // =========================================================================
    // 3. DOCTOR SELECTION & REAL AVAILABILITY
    // =========================================================================

    /**
     * @description Backward-compatible active doctors lookup.
     */
    @AuraEnabled(cacheable=true)
    public static List<SelectOptionDto> getActiveDoctors() {
        List<SelectOptionDto> options = new List<SelectOptionDto>();
        try {
            List<Doctor__c> doctors = [
                SELECT Id, Name, Department__c, Specialty__c
                FROM Doctor__c
                WHERE Is_Active__c = true
                WITH USER_MODE
                ORDER BY Name ASC
            ];
            for (Doctor__c doc : doctors) {
                String descStr = doc.Department__c + (String.isNotBlank(doc.Specialty__c) ? ' - ' + doc.Specialty__c : '');
                SelectOptionDto opt = new SelectOptionDto(doc.Name + ' (' + descStr + ')', doc.Id, descStr);
                opt.doctorId = doc.Id;
                options.add(opt);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'CareNestAdmissionController.getActiveDoctors error: ' + e.getMessage());
        }
        return options;
    }

    @AuraEnabled(cacheable=true)
    public static List<SelectOptionDto> getAvailableDoctors() {
        return getActiveDoctors();
    }

    /**
     * @description Resolves doctors with real-time schedule and slot availability data.
     * Distinguishes confirmed available doctors with open slots from active staff physicians.
     */
    @AuraEnabled(cacheable=true)
    public static List<DoctorAvailabilityDto> getDoctorsWithAvailability(String department, String searchKey) {
        List<DoctorAvailabilityDto> results = new List<DoctorAvailabilityDto>();
        try {
            String query = 'SELECT Id, Name, Department__c, Specialty__c, Consultation_Fee__c, Is_Active__c, ' +
                           '(SELECT Id, Slot_Start__c, Available__c, Mode__c FROM Slots__r WHERE Is_Open__c = true AND Available__c > 0 ORDER BY Slot_Start__c ASC) ' +
                           'FROM Doctor__c WHERE Is_Active__c = true ';

            if (String.isNotBlank(department) && department != 'All') {
                query += ' AND Department__c = :department';
            }
            if (String.isNotBlank(searchKey)) {
                String cleanKey = '%' + searchKey.trim() + '%';
                query += ' AND Name LIKE :cleanKey';
            }
            query += ' WITH USER_MODE ORDER BY Name ASC LIMIT 50';

            List<Doctor__c> doctors = Database.query(query);
            for (Doctor__c doc : doctors) {
                DoctorAvailabilityDto dto = new DoctorAvailabilityDto();
                dto.doctorId = doc.Id;
                dto.value = doc.Id;
                dto.name = doc.Name;
                dto.department = doc.Department__c;
                dto.specialty = doc.Specialty__c;
                dto.consultationFee = doc.Consultation_Fee__c != null ? doc.Consultation_Fee__c : 0;

                Integer openSlots = (doc.Slots__r != null) ? doc.Slots__r.size() : 0;
                dto.openSlotsCount = openSlots;

                if (openSlots > 0) {
                    dto.availabilityStatus = 'Verified OPD Schedule (' + openSlots + ' Open Slots)';
                    dto.nextSlotTime = doc.Slots__r[0].Slot_Start__c != null
                        ? doc.Slots__r[0].Slot_Start__c.format('MMM dd, hh:mm a')
                        : '';
                    dto.badgeClass = 'slds-theme_success';
                } else {
                    dto.availabilityStatus = 'Inpatient On-Call (Roster Unspecified)';
                    dto.nextSlotTime = 'On-Call / Ward Duty';
                    dto.badgeClass = 'slds-badge_lightest';
                }

                dto.label = doc.Name + ' (' + doc.Department__c + ' • ' + dto.availabilityStatus + ')';
                results.add(dto);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'CareNestAdmissionController.getDoctorsWithAvailability error: ' + e.getMessage());
        }
        return results;
    }

    // =========================================================================
    // 4. ADMISSIONS DIRECTORY & ATOMIC ADMISSION CREATION
    // =========================================================================

    @AuraEnabled(cacheable=true)
    public static List<AdmissionSummaryDto> getAdmissions(String statusFilter, String searchKey) {
        List<AdmissionSummaryDto> results = new List<AdmissionSummaryDto>();
        try {
            String query = 'SELECT Id, Name, Admission_Date__c, Discharge_Date__c, Status__c, Admission_Type__c, Reason__c, Discharge_Summary__c, ' +
                           'Contact__c, Contact__r.Name, Contact__r.Phone, Contact__r.Patient_Code__c, ' +
                           'Patient__c, Patient__r.Name, Patient__r.Phone, Patient__r.Patient_Code__c, ' +
                           'Bed__c, Bed__r.Name, Bed__r.Bed_Code__c, Bed__r.Floor__c, ' +
                           'Bed__r.Ward__c, Bed__r.Ward__r.Name, Bed__r.Ward__r.Ward_Type__c, ' +
                           'Attending_Doctor__c, Attending_Doctor__r.Name, Attending_Doctor__r.Department__c, Attending_Doctor__r.Specialty__c, ' +
                           'Doctor__c, Doctor__r.Name, Doctor__r.Department__c, Doctor__r.Specialty__c ' +
                           'FROM Admission__c WHERE Id != null ';

            if (String.isNotBlank(statusFilter) && statusFilter != 'All') {
                query += ' AND Status__c = :statusFilter';
            }
            if (String.isNotBlank(searchKey)) {
                String cleanKey = '%' + searchKey.trim() + '%';
                query += ' AND (Name LIKE :cleanKey OR Contact__r.Name LIKE :cleanKey OR Contact__r.Patient_Code__c LIKE :cleanKey OR Bed__r.Bed_Code__c LIKE :cleanKey)';
            }
            query += ' WITH USER_MODE ORDER BY Admission_Date__c DESC NULLS LAST LIMIT 100';

            List<Admission__c> admissions = Database.query(query);
            for (Admission__c adm : admissions) {
                AdmissionSummaryDto dto = new AdmissionSummaryDto();
                dto.id = adm.Id;
                dto.name = adm.Name;
                dto.admissionCode = adm.Name;
                dto.patientId = adm.Contact__c != null ? adm.Contact__c : adm.Patient__c;
                dto.patientName = adm.Contact__c != null ? adm.Contact__r.Name : (adm.Patient__c != null ? adm.Patient__r.Name : 'Unknown Patient');
                dto.patientPhone = adm.Contact__r != null ? adm.Contact__r.Phone : (adm.Patient__r != null ? adm.Patient__r.Phone : '');
                dto.patientCode = adm.Contact__r != null ? adm.Contact__r.Patient_Code__c : (adm.Patient__r != null ? adm.Patient__r.Patient_Code__c : '');

                dto.bedId = adm.Bed__c;
                dto.bedCode = adm.Bed__r != null ? (adm.Bed__r.Bed_Code__c != null ? adm.Bed__r.Bed_Code__c : adm.Bed__r.Name) : '';
                dto.room = (adm.Bed__r != null && adm.Bed__r.Floor__c != null) ? 'Floor ' + String.valueOf(adm.Bed__r.Floor__c.intValue()) : 'Floor 1';

                dto.wardId = adm.Bed__r != null ? adm.Bed__r.Ward__c : null;
                dto.wardName = (adm.Bed__r != null && adm.Bed__r.Ward__r != null) ? adm.Bed__r.Ward__r.Name : '';
                dto.wardType = (adm.Bed__r != null && adm.Bed__r.Ward__r != null) ? adm.Bed__r.Ward__r.Ward_Type__c : '';

                dto.doctorId = adm.Attending_Doctor__c != null ? adm.Attending_Doctor__c : adm.Doctor__c;
                dto.doctorName = adm.Attending_Doctor__c != null ? adm.Attending_Doctor__r.Name : (adm.Doctor__c != null ? adm.Doctor__r.Name : '');
                dto.doctorDepartment = adm.Attending_Doctor__c != null ? adm.Attending_Doctor__r.Department__c : (adm.Doctor__c != null ? adm.Doctor__r.Department__c : '');

                dto.admissionDate = adm.Admission_Date__c;
                dto.dischargeDate = adm.Discharge_Date__c;
                dto.status = adm.Status__c;
                dto.admissionType = adm.Admission_Type__c != null ? adm.Admission_Type__c : 'Emergency';
                dto.reason = adm.Reason__c;
                dto.dischargeSummary = adm.Discharge_Summary__c;

                if (adm.Status__c == 'Admitted') {
                    dto.statusBadgeClass = 'slds-theme_success';
                } else if (adm.Status__c == 'Discharged') {
                    dto.statusBadgeClass = 'slds-theme_default';
                } else {
                    dto.statusBadgeClass = 'slds-theme_warning';
                }

                results.add(dto);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'CareNestAdmissionController.getAdmissions error: ' + e.getMessage());
        }
        return results;
    }

    @AuraEnabled(cacheable=true)
    public static List<AdmissionSummaryDto> getActiveAdmissions(String searchTerm) {
        return getAdmissions('Admitted', searchTerm);
    }

    /**
     * @description Core transactional method to admit a patient to a hospital bed.
     * Enforces pessimistic row-level locking on Bed__c to prevent concurrency conflicts,
     * uses AdmissionService for atomic bed status transition, and returns real record values.
     */
    @AuraEnabled
    public static Map<String, Object> admitPatientRecord(Id patientId, Id bedId, Id doctorId, String reason, String admissionType) {
        Map<String, Object> response = new Map<String, Object>();
        try {
            if (patientId == null) {
                throw new AuraHandledException('Patient selection is required.');
            }
            if (bedId == null) {
                throw new AuraHandledException('Bed selection is required.');
            }
            if (doctorId == null) {
                throw new AuraHandledException('Attending Doctor selection is required.');
            }

            // Concurrency protection: Verify bed status with pessimistic row lock
            List<Bed__c> bedCheck = [
                SELECT Id, Status__c, Bed_Code__c, Ward__r.Name
                FROM Bed__c
                WHERE Id = :bedId
                FOR UPDATE
            ];

            if (bedCheck.isEmpty()) {
                throw new AuraHandledException('The selected bed does not exist.');
            }
            if (bedCheck[0].Status__c != 'Available') {
                throw new AuraHandledException('Bed ' + bedCheck[0].Bed_Code__c + ' is no longer available (Current Status: ' + bedCheck[0].Status__c + '). Please choose another bed.');
            }

            AdmissionService.AdmissionRequest req = new AdmissionService.AdmissionRequest();
            req.patientId = patientId;
            req.bedId = bedId;
            req.doctorId = doctorId;
            req.admissionDate = System.now();
            req.reason = String.isNotBlank(reason) ? reason : 'Inpatient Admission';

            Admission__c createdAdmission = AdmissionService.admitPatient(req);

            if (String.isNotBlank(admissionType)) {
                createdAdmission.Admission_Type__c = admissionType;
                update as user createdAdmission;
            }

            // Fetch auto-number Name and populated relationships
            Admission__c fullRecord = [
                SELECT Id, Name, Contact__r.Name, Bed__r.Bed_Code__c, Bed__r.Ward__r.Name
                FROM Admission__c
                WHERE Id = :createdAdmission.Id
                WITH USER_MODE
                LIMIT 1
            ];

            response.put('success', true);
            response.put('admissionId', fullRecord.Id);
            response.put('admissionNumber', fullRecord.Name);
            response.put('patientName', fullRecord.Contact__r.Name);
            response.put('bedCode', fullRecord.Bed__r.Bed_Code__c);
            response.put('wardName', fullRecord.Bed__r.Ward__r.Name);
            response.put('message', 'Patient ' + fullRecord.Contact__r.Name + ' admitted successfully under Admission #' + fullRecord.Name + ' in Bed ' + fullRecord.Bed__r.Bed_Code__c + '.');

        } catch (Exception e) {
            response.put('success', false);
            response.put('message', e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
        return response;
    }

    @AuraEnabled
    public static AdmissionActionResultDto admitPatient(Id patientId, Id bedId, Id doctorId, String admissionType, String reason) {
        AdmissionActionResultDto res = new AdmissionActionResultDto();
        try {
            Map<String, Object> r = admitPatientRecord(patientId, bedId, doctorId, reason, admissionType);
            res.isSuccess = (Boolean) r.get('success');
            res.message = (String) r.get('message');
            res.admissionId = (Id) r.get('admissionId');
            res.admissionNumber = (String) r.get('admissionNumber');
            res.patientName = (String) r.get('patientName');
            res.bedCode = (String) r.get('bedCode');
            res.wardName = (String) r.get('wardName');
        } catch (Exception e) {
            res.isSuccess = false;
            res.message = e.getMessage();
        }
        return res;
    }

    // =========================================================================
    // 5. INPATIENT DISCHARGE
    // =========================================================================

    @AuraEnabled
    public static Map<String, Object> dischargePatientRecord(Id admissionId, String dischargeSummary, String disposition) {
        Map<String, Object> response = new Map<String, Object>();
        try {
            if (admissionId == null) {
                throw new AuraHandledException('Admission ID is required for discharge.');
            }

            AdmissionService.DischargeRequest req = new AdmissionService.DischargeRequest();
            req.admissionId = admissionId;
            req.dischargeDate = System.now();
            req.dischargeSummary = String.isNotBlank(dischargeSummary) ? dischargeSummary : 'Routine discharge following clinical stabilization.';
            req.dischargeDisposition = String.isNotBlank(disposition) ? disposition : 'Home';

            Admission__c dischargedAdm = AdmissionService.dischargePatient(req);

            Admission__c fullRecord = [
                SELECT Id, Name, Contact__r.Name, Bed__r.Bed_Code__c
                FROM Admission__c
                WHERE Id = :dischargedAdm.Id
                WITH USER_MODE
                LIMIT 1
            ];

            response.put('success', true);
            response.put('admissionId', fullRecord.Id);
            response.put('admissionNumber', fullRecord.Name);
            response.put('message', 'Patient ' + fullRecord.Contact__r.Name + ' discharged successfully and Bed ' + fullRecord.Bed__r.Bed_Code__c + ' released to Available inventory.');

        } catch (Exception e) {
            response.put('success', false);
            response.put('message', e.getMessage());
            throw new AuraHandledException(e.getMessage());
        }
        return response;
    }

    @AuraEnabled
    public static AdmissionActionResultDto dischargePatient(Id admissionId, String summary, String disposition) {
        AdmissionActionResultDto res = new AdmissionActionResultDto();
        try {
            Map<String, Object> r = dischargePatientRecord(admissionId, summary, disposition);
            res.isSuccess = (Boolean) r.get('success');
            res.message = (String) r.get('message');
            res.admissionId = (Id) r.get('admissionId');
            res.admissionNumber = (String) r.get('admissionNumber');
        } catch (Exception e) {
            res.isSuccess = false;
            res.message = e.getMessage();
        }
        return res;
    }
}
