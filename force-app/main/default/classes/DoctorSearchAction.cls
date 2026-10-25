/**
 * @description Invocable action exposing Doctor Search capability to Flow and Agentforce.
 * Enforces WITH USER_MODE, input sanitization, and structured read-only response.
 */
public with sharing class DoctorSearchAction {

    public class Request {
        @InvocableVariable(label='Department' description='Medical department filter, e.g. Cardiology, Neurology, Pediatrics')
        public String department;

        @InvocableVariable(label='Specialty' description='Doctor specialty keyword')
        public String specialty;

        @InvocableVariable(label='Search Key' description='Doctor name keyword')
        public String searchKey;
    }

    public class DoctorDto {
        public String id;
        public String name;
        public String specialty;
        public String department;
        public Decimal consultationFee;
    }

    public class Response {
        @InvocableVariable(label='Is Success' description='True if search executed successfully')
        public Boolean isSuccess;

        @InvocableVariable(label='Doctor Count' description='Number of active doctors found')
        public Integer doctorCount;

        @InvocableVariable(label='Message' description='Status or summary message')
        public String message;

        @InvocableVariable(label='Doctor Details JSON' description='JSON serialized list of matching doctors')
        public String resultJson;
    }

    @InvocableMethod(label='Search CareNest Doctors' description='Searches active CareNest doctors by department, specialty, or name keyword. Safe read-only lookup.')
    public static List<Response> search(List<Request> requests) {
        List<Response> responses = new List<Response>();
        if (requests == null || requests.isEmpty()) {
            return responses;
        }

        for (Request req : requests) {
            Response res = new Response();
            res.isSuccess = true;
            res.doctorCount = 0;
            res.resultJson = '[]';

            String cleanDept = (req != null && String.isNotBlank(req.department) && req.department != 'All')
                ? req.department.trim() : null;
            String cleanSpec = (req != null && String.isNotBlank(req.specialty))
                ? '%' + req.specialty.trim() + '%' : null;
            String cleanKey = (req != null && String.isNotBlank(req.searchKey))
                ? '%' + req.searchKey.trim() + '%' : null;

            try {
                List<Doctor__c> doctors;
                if (cleanDept != null && cleanSpec != null && cleanKey != null) {
                    doctors = [
                        SELECT Id, Name, Specialty__c, Department__c, Consultation_Fee__c
                        FROM Doctor__c
                        WHERE Is_Active__c = true
                          AND Department__c = :cleanDept
                          AND Specialty__c LIKE :cleanSpec
                          AND Name LIKE :cleanKey
                        WITH USER_MODE
                        ORDER BY Name ASC
                        LIMIT 25
                    ];
                } else if (cleanDept != null && cleanSpec != null) {
                    doctors = [
                        SELECT Id, Name, Specialty__c, Department__c, Consultation_Fee__c
                        FROM Doctor__c
                        WHERE Is_Active__c = true
                          AND Department__c = :cleanDept
                          AND Specialty__c LIKE :cleanSpec
                        WITH USER_MODE
                        ORDER BY Name ASC
                        LIMIT 25
                    ];
                } else if (cleanDept != null && cleanKey != null) {
                    doctors = [
                        SELECT Id, Name, Specialty__c, Department__c, Consultation_Fee__c
                        FROM Doctor__c
                        WHERE Is_Active__c = true
                          AND Department__c = :cleanDept
                          AND Name LIKE :cleanKey
                        WITH USER_MODE
                        ORDER BY Name ASC
                        LIMIT 25
                    ];
                } else if (cleanSpec != null && cleanKey != null) {
                    doctors = [
                        SELECT Id, Name, Specialty__c, Department__c, Consultation_Fee__c
                        FROM Doctor__c
                        WHERE Is_Active__c = true
                          AND Specialty__c LIKE :cleanSpec
                          AND Name LIKE :cleanKey
                        WITH USER_MODE
                        ORDER BY Name ASC
                        LIMIT 25
                    ];
                } else if (cleanDept != null) {
                    doctors = [
                        SELECT Id, Name, Specialty__c, Department__c, Consultation_Fee__c
                        FROM Doctor__c
                        WHERE Is_Active__c = true
                          AND Department__c = :cleanDept
                        WITH USER_MODE
                        ORDER BY Name ASC
                        LIMIT 25
                    ];
                } else if (cleanSpec != null) {
                    doctors = [
                        SELECT Id, Name, Specialty__c, Department__c, Consultation_Fee__c
                        FROM Doctor__c
                        WHERE Is_Active__c = true
                          AND Specialty__c LIKE :cleanSpec
                        WITH USER_MODE
                        ORDER BY Name ASC
                        LIMIT 25
                    ];
                } else if (cleanKey != null) {
                    doctors = [
                        SELECT Id, Name, Specialty__c, Department__c, Consultation_Fee__c
                        FROM Doctor__c
                        WHERE Is_Active__c = true
                          AND Name LIKE :cleanKey
                        WITH USER_MODE
                        ORDER BY Name ASC
                        LIMIT 25
                    ];
                } else {
                    doctors = [
                        SELECT Id, Name, Specialty__c, Department__c, Consultation_Fee__c
                        FROM Doctor__c
                        WHERE Is_Active__c = true
                        WITH USER_MODE
                        ORDER BY Name ASC
                        LIMIT 25
                    ];
                }

                res.doctorCount = doctors.size();
                List<DoctorDto> dtos = new List<DoctorDto>();
                for (Doctor__c doc : doctors) {
                    DoctorDto d = new DoctorDto();
                    d.id = doc.Id;
                    d.name = doc.Name;
                    d.specialty = doc.Specialty__c;
                    d.department = doc.Department__c;
                    d.consultationFee = doc.Consultation_Fee__c;
                    dtos.add(d);
                }
                res.resultJson = JSON.serialize(dtos);
                res.message = doctors.isEmpty()
                    ? 'No active doctors found matching the search criteria.'
                    : 'Found ' + doctors.size() + ' active doctor(s).';
            } catch (Exception ex) {
                res.isSuccess = false;
                res.doctorCount = 0;
                res.message = 'Error searching doctors: ' + ex.getMessage();
                res.resultJson = '[]';
            }
            responses.add(res);
        }
        return responses;
    }
}
