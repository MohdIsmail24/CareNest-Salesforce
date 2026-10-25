/**
 * @description Controller for the Ward and Bed Management Workspace (Module 2).
 * Exposes ward metrics, visual bed layouts, bed filtering, and occupancy rates.
 * Enforces WITH USER_MODE and strict read-only access.
 */
public with sharing class CareNestWardBedController {

    public class BedDto {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String bedCode { get; set; }
        @AuraEnabled public String bedType { get; set; }
        @AuraEnabled public String status { get; set; }
        @AuraEnabled public String room { get; set; }
        @AuraEnabled public Id wardId { get; set; }
        @AuraEnabled public String wardName { get; set; }
        @AuraEnabled public String wardCode { get; set; }
        @AuraEnabled public String patientName { get; set; }
        @AuraEnabled public Id admissionId { get; set; }
        @AuraEnabled public String attendingDoctorName { get; set; }
        @AuraEnabled public Datetime admissionDate { get; set; }
        @AuraEnabled public String statusBadgeClass { get; set; }
    }

    public class WardWithBedsDto {
        @AuraEnabled public Id id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String wardCode { get; set; }
        @AuraEnabled public String wardType { get; set; }
        @AuraEnabled public String floor { get; set; }
        @AuraEnabled public Integer capacity { get; set; }
        @AuraEnabled public Integer totalBeds { get; set; }
        @AuraEnabled public Integer occupiedBeds { get; set; }
        @AuraEnabled public Integer availableBeds { get; set; }
        @AuraEnabled public Integer maintenanceBeds { get; set; }
        @AuraEnabled public Decimal occupancyRate { get; set; }
        @AuraEnabled public List<BedDto> beds { get; set; }
    }

    @AuraEnabled(cacheable=true)
    public static List<WardWithBedsDto> getWardsWithBeds(String wardIdFilter, String statusFilter) {
        List<WardWithBedsDto> wardList = new List<WardWithBedsDto>();
        try {
            String wardQuery = 'SELECT Id, Name, Ward_Code__c, Ward_Type__c, Floor__c, Capacity__c FROM Ward__c';
            if (String.isNotBlank(wardIdFilter) && wardIdFilter != 'All') {
                wardQuery += ' WHERE Id = :wardIdFilter';
            }
            wardQuery += ' WITH USER_MODE ORDER BY Name ASC';

            List<Ward__c> wards = Database.query(wardQuery);
            Set<Id> wardIds = new Set<Id>();
            for (Ward__c w : wards) {
                wardIds.add(w.Id);
            }

            // Query beds for these wards
            String bedQuery = 'SELECT Id, Name, Bed_Code__c, Bed_Type__c, Status__c, Floor__c, Ward__c, Ward__r.Name, Ward__r.Ward_Code__c FROM Bed__c WHERE Ward__c IN :wardIds';
            if (String.isNotBlank(statusFilter) && statusFilter != 'All') {
                bedQuery += ' AND Status__c = :statusFilter';
            }
            bedQuery += ' WITH USER_MODE ORDER BY Bed_Code__c ASC, Name ASC';
            List<Bed__c> beds = Database.query(bedQuery);

            // Query active admissions to map current occupant info
            Map<Id, Admission__c> activeAdmissionsByBed = new Map<Id, Admission__c>();
            List<Admission__c> activeAdmissions = [
                SELECT Id, Name, Bed__c, Admission_Date__c, Status__c,
                       Patient__r.Name, Contact__r.Name,
                       Attending_Doctor__r.Name, Doctor__r.Name
                FROM Admission__c
                WHERE Status__c = 'Admitted' AND Bed__c IN :beds
                WITH USER_MODE
            ];
            for (Admission__c adm : activeAdmissions) {
                activeAdmissionsByBed.put(adm.Bed__c, adm);
            }

            // Map beds by ward
            Map<Id, List<BedDto>> bedsByWard = new Map<Id, List<BedDto>>();
            for (Bed__c b : beds) {
                BedDto dto = new BedDto();
                dto.id = b.Id;
                dto.name = b.Name;
                dto.bedCode = String.isNotBlank(b.Bed_Code__c) ? b.Bed_Code__c : b.Name;
                dto.bedType = String.isNotBlank(b.Bed_Type__c) ? b.Bed_Type__c : 'Standard';
                dto.status = String.isNotBlank(b.Status__c) ? b.Status__c : 'Available';
                dto.room = 'Floor ' + (b.Floor__c != null ? String.valueOf(b.Floor__c.intValue()) : '1');
                dto.wardId = b.Ward__c;
                dto.wardName = b.Ward__r != null ? b.Ward__r.Name : '';
                dto.wardCode = b.Ward__r != null ? b.Ward__r.Ward_Code__c : '';

                // Active admission mapping
                if (activeAdmissionsByBed.containsKey(b.Id)) {
                    Admission__c adm = activeAdmissionsByBed.get(b.Id);
                    dto.admissionId = adm.Id;
                    dto.patientName = adm.Contact__c != null ? adm.Contact__r.Name : (adm.Patient__c != null ? adm.Patient__r.Name : 'Patient');
                    dto.attendingDoctorName = adm.Attending_Doctor__c != null ? adm.Attending_Doctor__r.Name : (adm.Doctor__c != null ? adm.Doctor__r.Name : '');
                    dto.admissionDate = adm.Admission_Date__c;
                }

                if (dto.status == 'Available') {
                    dto.statusBadgeClass = 'slds-theme_success';
                } else if (dto.status == 'Occupied') {
                    dto.statusBadgeClass = 'slds-theme_error';
                } else {
                    dto.statusBadgeClass = 'slds-theme_warning';
                }

                if (!bedsByWard.containsKey(b.Ward__c)) {
                    bedsByWard.put(b.Ward__c, new List<BedDto>());
                }
                bedsByWard.get(b.Ward__c).add(dto);
            }

            for (Ward__c w : wards) {
                WardWithBedsDto wdto = new WardWithBedsDto();
                wdto.id = w.Id;
                wdto.name = w.Name;
                wdto.wardCode = w.Ward_Code__c;
                wdto.wardType = w.Ward_Type__c;
                wdto.floor = String.isNotBlank(w.Floor__c) ? w.Floor__c : '1';
                wdto.capacity = w.Capacity__c != null ? Integer.valueOf(w.Capacity__c) : 0;
                wdto.beds = bedsByWard.containsKey(w.Id) ? bedsByWard.get(w.Id) : new List<BedDto>();
                wdto.totalBeds = wdto.beds.size();
                wdto.occupiedBeds = 0;
                wdto.availableBeds = 0;
                wdto.maintenanceBeds = 0;

                for (BedDto bd : wdto.beds) {
                    if (bd.status == 'Occupied') {
                        wdto.occupiedBeds++;
                    } else if (bd.status == 'Available') {
                        wdto.availableBeds++;
                    } else {
                        wdto.maintenanceBeds++;
                    }
                }

                wdto.occupancyRate = (wdto.totalBeds > 0)
                    ? ((Decimal) wdto.occupiedBeds / (Decimal) wdto.totalBeds * 100).setScale(1)
                    : 0.0;

                wardList.add(wdto);
            }

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'CareNestWardBedController.getWardsWithBeds error: ' + e.getMessage());
        }
        return wardList;
    }

    @AuraEnabled(cacheable=true)
    public static List<WardWithBedsDto> getWardSummaries() {
        return getWardsWithBeds(null, null);
    }

    @AuraEnabled(cacheable=true)
    public static List<BedDto> getBeds(Id wardId, String statusFilter) {
        String wardFilter = wardId != null ? String.valueOf(wardId) : null;
        List<WardWithBedsDto> wards = getWardsWithBeds(wardFilter, statusFilter);
        List<BedDto> allBeds = new List<BedDto>();
        for (WardWithBedsDto w : wards) {
            if (w.beds != null) {
                allBeds.addAll(w.beds);
            }
        }
        return allBeds;
    }
}
