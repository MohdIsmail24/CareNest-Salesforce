/**
 * @description Invocable action exposing Ward and Bed availability to Flow and Agentforce.
 * Safe read-only lookup with aggregate capacity metrics. Zero patient data exposed.
 */
public with sharing class WardAvailabilityAction {

    public class Request {
        @InvocableVariable(label='Ward Name or Code' description='Name or code of the ward, e.g. General, ICU, W-ICU')
        public String wardNameOrCode;

        @InvocableVariable(label='Ward Type' description='Type of ward, e.g. General, Semi-Private, Private, ICU, Paediatric')
        public String wardType;
    }

    public class WardSummaryDto {
        public String id;
        public String name;
        public String wardCode;
        public String wardType;
        public String floor;
        public Decimal capacity;
        public Decimal currentBedCount;
        public Decimal availableBedCount;
        public Decimal occupancyRatePercent;
    }

    public class Response {
        @InvocableVariable(label='Is Success' description='True if lookup executed successfully')
        public Boolean isSuccess;

        @InvocableVariable(label='Total Capacity' description='Sum of capacity across matching wards')
        public Integer totalCapacity;

        @InvocableVariable(label='Available Beds' description='Sum of available beds across matching wards')
        public Integer availableBeds;

        @InvocableVariable(label='Occupied Beds' description='Number of currently occupied beds')
        public Integer occupiedBeds;

        @InvocableVariable(label='Message' description='Summary description of ward availability')
        public String message;

        @InvocableVariable(label='Ward Details JSON' description='JSON serialized list of ward capacity details')
        public String resultJson;
    }

    @InvocableMethod(label='Check CareNest Ward Availability' description='Returns ward capacity and available bed count without exposing patient identities.')
    public static List<Response> checkAvailability(List<Request> requests) {
        List<Response> responses = new List<Response>();
        if (requests == null || requests.isEmpty()) {
            return responses;
        }

        for (Request req : requests) {
            Response res = new Response();
            res.isSuccess = true;
            res.totalCapacity = 0;
            res.availableBeds = 0;
            res.occupiedBeds = 0;
            res.resultJson = '[]';

            String cleanNameOrCode = (req != null && String.isNotBlank(req.wardNameOrCode) && req.wardNameOrCode != 'All')
                ? req.wardNameOrCode.trim() : null;
            String cleanType = (req != null && String.isNotBlank(req.wardType) && req.wardType != 'All')
                ? req.wardType.trim() : null;

            try {
                List<Ward__c> wards;
                if (cleanNameOrCode != null && cleanType != null) {
                    String pattern = '%' + cleanNameOrCode + '%';
                    wards = [
                        SELECT Id, Name, Ward_Code__c, Ward_Type__c, Floor__c, Capacity__c,
                               Current_Bed_Count__c, Available_Bed_Count__c, Is_Active__c
                        FROM Ward__c
                        WHERE Is_Active__c = true
                          AND (Name LIKE :pattern OR Ward_Code__c = :cleanNameOrCode)
                          AND Ward_Type__c = :cleanType
                        WITH USER_MODE
                        ORDER BY Name ASC
                    ];
                } else if (cleanNameOrCode != null) {
                    String pattern = '%' + cleanNameOrCode + '%';
                    wards = [
                        SELECT Id, Name, Ward_Code__c, Ward_Type__c, Floor__c, Capacity__c,
                               Current_Bed_Count__c, Available_Bed_Count__c, Is_Active__c
                        FROM Ward__c
                        WHERE Is_Active__c = true
                          AND (Name LIKE :pattern OR Ward_Code__c = :cleanNameOrCode)
                        WITH USER_MODE
                        ORDER BY Name ASC
                    ];
                } else if (cleanType != null) {
                    wards = [
                        SELECT Id, Name, Ward_Code__c, Ward_Type__c, Floor__c, Capacity__c,
                               Current_Bed_Count__c, Available_Bed_Count__c, Is_Active__c
                        FROM Ward__c
                        WHERE Is_Active__c = true
                          AND Ward_Type__c = :cleanType
                        WITH USER_MODE
                        ORDER BY Name ASC
                    ];
                } else {
                    wards = [
                        SELECT Id, Name, Ward_Code__c, Ward_Type__c, Floor__c, Capacity__c,
                               Current_Bed_Count__c, Available_Bed_Count__c, Is_Active__c
                        FROM Ward__c
                        WHERE Is_Active__c = true
                        WITH USER_MODE
                        ORDER BY Name ASC
                    ];
                }

                Decimal sumCapacity = 0;
                Decimal sumAvailable = 0;
                Decimal sumCurrent = 0;

                List<WardSummaryDto> dtos = new List<WardSummaryDto>();
                for (Ward__c w : wards) {
                    WardSummaryDto d = new WardSummaryDto();
                    d.id = w.Id;
                    d.name = w.Name;
                    d.wardCode = w.Ward_Code__c;
                    d.wardType = w.Ward_Type__c;
                    d.floor = w.Floor__c;
                    d.capacity = w.Capacity__c != null ? w.Capacity__c : 0;
                    d.currentBedCount = w.Current_Bed_Count__c != null ? w.Current_Bed_Count__c : 0;
                    d.availableBedCount = w.Available_Bed_Count__c != null ? w.Available_Bed_Count__c : 0;

                    sumCapacity += d.capacity;
                    sumCurrent += d.currentBedCount;
                    sumAvailable += d.availableBedCount;

                    Decimal occupied = d.currentBedCount - d.availableBedCount;
                    d.occupancyRatePercent = (d.currentBedCount > 0)
                        ? ((occupied / d.currentBedCount) * 100).setScale(1) : 0;

                    dtos.add(d);
                }

                res.totalCapacity = (Integer) sumCapacity;
                res.availableBeds = (Integer) sumAvailable;
                res.occupiedBeds = (Integer) (sumCurrent - sumAvailable);
                res.resultJson = JSON.serialize(dtos);

                if (wards.isEmpty()) {
                    res.message = 'No active wards found matching the criteria.';
                } else {
                    res.message = String.format(
                        '{0} ward(s) found. Total Beds: {1}, Available: {2}, Occupied: {3}.',
                        new List<Object>{ wards.size(), sumCurrent, sumAvailable, res.occupiedBeds }
                    );
                }
            } catch (Exception ex) {
                res.isSuccess = false;
                res.message = 'Error checking ward availability: ' + ex.getMessage();
                res.resultJson = '[]';
            }
            responses.add(res);
        }
        return responses;
    }
}
