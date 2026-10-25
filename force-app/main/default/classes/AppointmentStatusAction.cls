/**
 * @description Invocable action exposing secure Appointment Status lookups to Flow and Agentforce.
 * Enforces principal-level authorization (patient portal user can only view their own appointments;
 * internal staff can view authorized appointments; unauthenticated/unmatched requests are denied).
 * Privacy-preserving: zero exposure of clinical notes, diagnoses, vitals, or unrelated patient data.
 */
public with sharing class AppointmentStatusAction {

    @TestVisible private static Id mockUserContactId = null;
    @TestVisible private static String mockUserType = null;
    @TestVisible private static Boolean mockStaffAccess = null;

    public class Request {
        @InvocableVariable(required=true label='Appointment Identifier' description='18/15-char Salesforce ID, Appointment Code (e.g. APT-0001), or Name')
        public String appointmentIdentifier;
    }

    public class Response {
        @InvocableVariable(label='Is Authorized' description='True if caller has established identity and authorization')
        public Boolean isAuthorized;

        @InvocableVariable(label='Is Found' description='True if appointment was located')
        public Boolean isFound;

        @InvocableVariable(label='Appointment Code' description='Unique reference code')
        public String appointmentCode;

        @InvocableVariable(label='Status' description='Current appointment status')
        public String status;

        @InvocableVariable(label='Doctor Name' description='Attending doctor name')
        public String doctorName;

        @InvocableVariable(label='Department' description='Medical department')
        public String department;

        @InvocableVariable(label='Appointment Date Time' description='Scheduled start time')
        public Datetime appointmentTime;

        @InvocableVariable(label='Mode' description='OPD or Teleconsult')
        public String mode;

        @InvocableVariable(label='Balance Due' description='Outstanding balance due')
        public Decimal balanceDue;

        @InvocableVariable(label='Message' description='Status or authorization explanation')
        public String message;
    }

    private static Id getCurrentContactId() {
        if (Test.isRunningTest() && mockUserContactId != null) {
            return mockUserContactId;
        }
        User u = [SELECT Id, ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
        return u.ContactId;
    }

    private static String getCurrentUserType() {
        if (Test.isRunningTest() && mockUserType != null) {
            return mockUserType;
        }
        return UserInfo.getUserType();
    }

    private static Boolean hasStaffAccess() {
        if (Test.isRunningTest() && mockStaffAccess != null) {
            return mockStaffAccess;
        }
        return Schema.sObjectType.Appointment__c.isAccessible();
    }

    @InvocableMethod(label='Get Authorized Appointment Status' description='Reads appointment status for an authorized user. Never exposes clinical details.')
    public static List<Response> getStatus(List<Request> requests) {
        List<Response> responses = new List<Response>();
        if (requests == null || requests.isEmpty()) {
            return responses;
        }

        Id effectiveContactId = getCurrentContactId();
        String userType = getCurrentUserType();
        Boolean isStaff = (userType == 'Standard' || userType == 'SysAdmin') && hasStaffAccess();
        Boolean isPatient = (effectiveContactId != null);

        // Security check: If neither a verified portal patient nor internal authorized staff, deny all
        if (!isStaff && !isPatient) {
            for (Request req : requests) {
                Response denied = new Response();
                denied.isAuthorized = false;
                denied.isFound = false;
                denied.message = 'Access denied: Caller identity could not be verified. Appointment status inquiries require authenticated patient or staff access.';
                responses.add(denied);
            }
            return responses;
        }

        for (Request req : requests) {
            Response res = new Response();
            res.isAuthorized = false;
            res.isFound = false;

            if (req == null || String.isBlank(req.appointmentIdentifier)) {
                res.message = 'Invalid request: Appointment identifier is required.';
                responses.add(res);
                continue;
            }

            String rawId = req.appointmentIdentifier.trim();
            Id recordId = null;
            try {
                recordId = Id.valueOf(rawId);
            } catch (Exception ex) {
                recordId = null;
            }

            try {
                List<Appointment__c> appts = [
                    SELECT Id, Name, Appointment_Code__c, Status__c, Patient__c, Balance_Due__c,
                           Slot__r.Slot_Start__c, Slot__r.Mode__c,
                           Slot__r.Doctor__r.Name, Slot__r.Doctor__r.Department__c
                    FROM Appointment__c
                    WHERE (Id = :recordId OR Appointment_Code__c = :rawId OR Name = :rawId)
                    WITH USER_MODE
                    LIMIT 1
                ];

                if (appts.isEmpty()) {
                    res.isAuthorized = true;
                    res.isFound = false;
                    res.message = 'Appointment not found or insufficient access.';
                    responses.add(res);
                    continue;
                }

                Appointment__c a = appts[0];

                // If user is a portal patient, verify the appointment belongs to them
                if (isPatient && a.Patient__c != effectiveContactId) {
                    res.isAuthorized = false;
                    res.isFound = false;
                    res.message = 'Access denied: You are not authorized to view this appointment record.';
                    responses.add(res);
                    continue;
                }

                // Authorized
                res.isAuthorized = true;
                res.isFound = true;
                res.appointmentCode = (String.isNotBlank(a.Appointment_Code__c) ? a.Appointment_Code__c : a.Name);
                res.status = a.Status__c;
                res.doctorName = (a.Slot__r != null && a.Slot__r.Doctor__r != null) ? a.Slot__r.Doctor__r.Name : null;
                res.department = (a.Slot__r != null && a.Slot__r.Doctor__r != null) ? a.Slot__r.Doctor__r.Department__c : null;
                res.appointmentTime = (a.Slot__r != null) ? a.Slot__r.Slot_Start__c : null;
                res.mode = (a.Slot__r != null) ? a.Slot__r.Mode__c : null;
                res.balanceDue = a.Balance_Due__c;
                res.message = 'Appointment retrieved successfully. Status: ' + a.Status__c;

            } catch (Exception ex) {
                res.isAuthorized = false;
                res.isFound = false;
                res.message = 'Error retrieving appointment: ' + ex.getMessage();
            }
            responses.add(res);
        }
        return responses;
    }
}
