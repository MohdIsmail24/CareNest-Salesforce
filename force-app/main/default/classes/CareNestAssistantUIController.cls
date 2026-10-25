/**
 * @description Controller for the CareNest AI Assistant UI Widget (Module 8).
 * Bridges the internal Lightning UI directly to the CareNest Agentforce actions
 * (DoctorSearchAction, WardAvailabilityAction, AppointmentStatusAction, and Safety Guardrails).
 */
public with sharing class CareNestAssistantUIController {

    public class AgentQueryResponseDto {
        @AuraEnabled public String userPrompt { get; set; }
        @AuraEnabled public String topic { get; set; }
        @AuraEnabled public String actionInvoked { get; set; }
        @AuraEnabled public String message { get; set; }
        @AuraEnabled public String payloadJson { get; set; }
        @AuraEnabled public Boolean isSuccess { get; set; }
        @AuraEnabled public Boolean isEmergency { get; set; }
        @AuraEnabled public Datetime timestamp { get; set; }
    }

    @AuraEnabled
    public static AgentQueryResponseDto processQuery(String promptText) {
        AgentQueryResponseDto dto = new AgentQueryResponseDto();
        dto.userPrompt = promptText;
        dto.timestamp = System.now();
        dto.isSuccess = true;
        dto.isEmergency = false;

        if (String.isBlank(promptText)) {
            dto.topic = 'General';
            dto.actionInvoked = 'None';
            dto.message = 'Please enter a query or select one of the suggested topics.';
            return dto;
        }

        String lower = promptText.toLowerCase().trim();

        // 1. Clinical Emergency / Medical Advice Safety Guardrail
        if (lower.contains('chest pain') || lower.contains('trouble breathing') || lower.contains('prescribe') || 
            lower.contains('treatment') || lower.contains('diagnosis') || lower.contains('emergency') || 
            lower.contains('heart attack') || lower.contains('stroke')) {
            dto.topic = 'Hospital_Information_and_Safe_Escalation';
            dto.actionInvoked = 'Clinical Safety Guardrail (Refusal & Escalation)';
            dto.isEmergency = true;
            dto.message = 'CareNest Assistant does not provide clinical diagnosis or treatment prescriptions. For symptoms such as acute chest pain, trouble breathing, or clinical emergencies, immediately alert the attending on-duty medical team, call emergency services, or report to the Emergency Department.';
            return dto;
        }

        // 2. Appointment Status
        if (lower.contains('appointment') || lower.contains('booking') || lower.contains('status of my') || lower.contains('apt-') || lower.contains('cn-apt')) {
            dto.topic = 'Appointment_Assistance';
            dto.actionInvoked = 'AppointmentStatusAction';

            // Extract potential identifier or default to user appointment lookup
            AppointmentStatusAction.Request req = new AppointmentStatusAction.Request();
            Pattern p = Pattern.compile('(AP-\\d+|CN-APT-\\d+|a0A[a-zA-Z0-9]{12,15})');
            Matcher m = p.matcher(promptText);
            if (m.find()) {
                req.appointmentIdentifier = m.group(1);
            } else {
                List<Appointment__c> userAppts = [SELECT Id, Name FROM Appointment__c ORDER BY CreatedDate DESC LIMIT 1];
                if (!userAppts.isEmpty()) {
                    req.appointmentIdentifier = userAppts[0].Name;
                } else {
                    req.appointmentIdentifier = 'CURRENT_USER';
                }
            }

            try {
                List<AppointmentStatusAction.Response> resList = AppointmentStatusAction.getStatus(new List<AppointmentStatusAction.Request>{ req });
                if (!resList.isEmpty()) {
                    AppointmentStatusAction.Response r = resList[0];
                    dto.message = r.message;
                    dto.payloadJson = JSON.serialize(r);
                    dto.isSuccess = r.isFound && r.isAuthorized;
                }
            } catch (Exception e) {
                dto.isSuccess = false;
                dto.message = 'Error retrieving appointment: ' + e.getMessage();
            }
            return dto;
        }

        // 3. Doctor Discovery
        Boolean isEnt = lower.contains(' ent ') || lower.startsWith('ent ') || lower.endsWith(' ent') || lower == 'ent' || lower.contains('ent specialist') || lower.contains('ent department');
        if (lower.contains('doctor') || lower.contains('physician') || lower.contains('specialist') || 
            lower.contains('medicine') || lower.contains('orthopaedic') || lower.contains('orthopedic') ||
            lower.contains('paediatric') || lower.contains('pediatric') || 
            lower.contains('dermatolog') || isEnt) {
            dto.topic = 'Doctor_Discovery';
            dto.actionInvoked = 'DoctorSearchAction';

            DoctorSearchAction.Request req = new DoctorSearchAction.Request();
            if (lower.contains('orthopaedics') || lower.contains('orthopedic') || lower.contains('orthopaedic')) {
                req.department = 'Orthopaedics';
            } else if (lower.contains('general medicine') || lower.contains('medicine')) {
                req.department = 'General Medicine';
            } else if (lower.contains('paediatric') || lower.contains('pediatric')) {
                req.department = 'Paediatrics';
            } else if (lower.contains('dermatolog')) {
                req.department = 'Dermatology';
            } else if (isEnt) {
                req.department = 'ENT';
            }

            try {
                List<DoctorSearchAction.Response> resList = DoctorSearchAction.search(new List<DoctorSearchAction.Request>{ req });
                if (!resList.isEmpty()) {
                    dto.message = resList[0].message;
                    dto.payloadJson = resList[0].resultJson;
                    dto.isSuccess = resList[0].isSuccess;
                }
            } catch (Exception e) {
                dto.isSuccess = false;
                dto.message = 'Error searching doctors: ' + e.getMessage();
            }
            return dto;
        }

        // 4. Ward and Bed Availability
        if (lower.contains('ward') || lower.contains('bed') || lower.contains('icu') || 
            lower.contains('capacity') || lower.contains('occupancy') || lower.contains('available beds')) {
            dto.topic = 'Ward_Availability';
            dto.actionInvoked = 'WardAvailabilityAction';

            WardAvailabilityAction.Request req = new WardAvailabilityAction.Request();
            if (lower.contains('icu')) {
                req.wardType = 'ICU';
            } else if (lower.contains('general')) {
                req.wardNameOrCode = 'General Ward';
            } else if (lower.contains('semi-private') || lower.contains('semi private')) {
                req.wardType = 'Semi-Private';
            } else if (lower.contains('private')) {
                req.wardType = 'Private';
            } else if (lower.contains('paediatric') || lower.contains('pediatric')) {
                req.wardType = 'General';
            }

            try {
                List<WardAvailabilityAction.Response> resList = WardAvailabilityAction.checkAvailability(new List<WardAvailabilityAction.Request>{ req });
                if (!resList.isEmpty()) {
                    dto.message = resList[0].message;
                    dto.payloadJson = resList[0].resultJson;
                    dto.isSuccess = resList[0].isSuccess;
                }
            } catch (Exception e) {
                dto.isSuccess = false;
                dto.message = 'Error checking ward availability: ' + e.getMessage();
            }
            return dto;
        }

        // 5. Default General Hospital Information
        dto.topic = 'Hospital_Information_and_Safe_Escalation';
        dto.actionInvoked = 'CareNest Hospital Knowledge';
        dto.message = 'Welcome to CareNest Hospital Management System. Visiting hours are 10:00 AM – 12:00 PM and 4:00 PM – 7:00 PM daily. For outpatient appointments, ward capacity, or doctor inquiries, please select an option or ask a specific question.';
        return dto;
    }
}
