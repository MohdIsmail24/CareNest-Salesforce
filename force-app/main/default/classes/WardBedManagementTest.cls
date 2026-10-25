/**
 * @description Comprehensive unit tests for Ward and Bed Management foundation (Phase 12.2).
 * Validates capacity constraints, rollup summaries, status transitions, and validation rules.
 */
@isTest
private class WardBedManagementTest {

    @isTest
    static void testCreateWardAndBedsSuccess() {
        Ward__c ward = new Ward__c(
            Name = 'General Ward A',
            Ward_Code__c = 'WRD-GEN-A',
            Ward_Type__c = 'General',
            Floor__c = '1',
            Capacity__c = 5,
            Is_Active__c = true
        );
        insert ward;

        List<Bed__c> beds = new List<Bed__c>();
        for (Integer i = 1; i <= 5; i++) {
            beds.add(new Bed__c(
                Name = 'Bed G-0' + i,
                Bed_Code__c = 'WRD-GEN-A-B0' + i,
                Ward__c = ward.Id,
                Bed_Type__c = 'Standard',
                Status__c = 'Available'
            ));
        }
        insert beds;

        Ward__c queriedWard = [
            SELECT Id, Capacity__c, Current_Bed_Count__c, Available_Bed_Count__c
            FROM Ward__c
            WHERE Id = :ward.Id
        ];
        System.assertEquals(5, queriedWard.Current_Bed_Count__c, 'Should count all 5 registered beds');
        System.assertEquals(5, queriedWard.Available_Bed_Count__c, 'All 5 beds should be available');
    }

    @isTest
    static void testCapacityMustBePositive() {
        Ward__c wardZero = new Ward__c(
            Name = 'Invalid Ward Zero',
            Ward_Code__c = 'WRD-INV-0',
            Ward_Type__c = 'General',
            Floor__c = '1',
            Capacity__c = 0,
            Is_Active__c = true
        );

        Boolean threw = false;
        try {
            insert wardZero;
        } catch (DmlException e) {
            threw = true;
            System.assert(e.getMessage().contains('positive integer'), 'Should throw positive capacity validation error: ' + e.getMessage());
        }
        System.assert(threw, 'Expected DmlException for zero capacity');
    }

    @isTest
    static void testReduceCapacityBelowBedCountFails() {
        Ward__c ward = new Ward__c(
            Name = 'Pediatric Ward',
            Ward_Code__c = 'WRD-PED-01',
            Ward_Type__c = 'General',
            Floor__c = '2',
            Capacity__c = 4,
            Is_Active__c = true
        );
        insert ward;

        List<Bed__c> beds = new List<Bed__c>();
        for (Integer i = 1; i <= 3; i++) {
            beds.add(new Bed__c(
                Name = 'Bed P-0' + i,
                Bed_Code__c = 'WRD-PED-B0' + i,
                Ward__c = ward.Id,
                Bed_Type__c = 'Pediatric',
                Status__c = 'Available'
            ));
        }
        insert beds;

        // Attempt to reduce capacity to 2 (below current bed count of 3)
        ward.Capacity__c = 2;
        Boolean threw = false;
        try {
            update ward;
        } catch (DmlException e) {
            threw = true;
            System.assert(e.getMessage().contains('cannot be reduced below'), 'Should enforce capacity cannot be reduced below bed count: ' + e.getMessage());
        }
        System.assert(threw, 'Expected DmlException when reducing capacity below bed count');
    }

    @isTest
    static void testExceedWardCapacityFails() {
        Ward__c ward = new Ward__c(
            Name = 'ICU Isolation Ward',
            Ward_Code__c = 'WRD-ICU-ISO',
            Ward_Type__c = 'ICU',
            Floor__c = '3',
            Capacity__c = 2,
            Is_Active__c = true
        );
        insert ward;

        insert new List<Bed__c>{
            new Bed__c(Name = 'Bed ICU-01', Bed_Code__c = 'ICU-B01', Ward__c = ward.Id, Bed_Type__c = 'ICU', Status__c = 'Available'),
            new Bed__c(Name = 'Bed ICU-02', Bed_Code__c = 'ICU-B02', Ward__c = ward.Id, Bed_Type__c = 'ICU', Status__c = 'Available')
        };

        // Try adding a 3rd bed to ward with capacity 2
        Bed__c excessBed = new Bed__c(
            Name = 'Bed ICU-03',
            Bed_Code__c = 'ICU-B03',
            Ward__c = ward.Id,
            Bed_Type__c = 'ICU',
            Status__c = 'Available'
        );

        Boolean threw = false;
        try {
            insert excessBed;
        } catch (DmlException e) {
            threw = true;
            System.assert(e.getMessage().contains('capacity'), 'Should block exceeding ward capacity: ' + e.getMessage());
        }
        System.assert(threw, 'Expected DmlException when exceeding ward capacity');
    }

    @isTest
    static void testCannotAddBedToInactiveWard() {
        Ward__c ward = new Ward__c(
            Name = 'Closed Ward',
            Ward_Code__c = 'WRD-CLOSED-01',
            Ward_Type__c = 'General',
            Floor__c = 'B1',
            Capacity__c = 5,
            Is_Active__c = false
        );
        insert ward;

        Bed__c bed = new Bed__c(
            Name = 'Bed C-01',
            Bed_Code__c = 'WRD-CLS-B01',
            Ward__c = ward.Id,
            Bed_Type__c = 'Standard',
            Status__c = 'Available'
        );

        Boolean threw = false;
        try {
            insert bed;
        } catch (DmlException e) {
            threw = true;
            System.assert(e.getMessage().contains('inactive ward'), 'Should block bed in inactive ward: ' + e.getMessage());
        }
        System.assert(threw, 'Expected DmlException for inactive ward');
    }

    @isTest
    static void testBedStatusTransitionsAndRollupCounts() {
        Ward__c ward = new Ward__c(
            Name = 'Surgical Ward',
            Ward_Code__c = 'WRD-SURG-01',
            Ward_Type__c = 'Post-Operative',
            Floor__c = '2',
            Capacity__c = 4,
            Is_Active__c = true
        );
        insert ward;

        List<Bed__c> beds = new List<Bed__c>{
            new Bed__c(Name = 'Bed S-01', Bed_Code__c = 'SURG-B01', Ward__c = ward.Id, Bed_Type__c = 'Electric', Status__c = 'Available'),
            new Bed__c(Name = 'Bed S-02', Bed_Code__c = 'SURG-B02', Ward__c = ward.Id, Bed_Type__c = 'Electric', Status__c = 'Available'),
            new Bed__c(Name = 'Bed S-03', Bed_Code__c = 'SURG-B03', Ward__c = ward.Id, Bed_Type__c = 'Electric', Status__c = 'Available'),
            new Bed__c(Name = 'Bed S-04', Bed_Code__c = 'SURG-B04', Ward__c = ward.Id, Bed_Type__c = 'Electric', Status__c = 'Available')
        };
        insert beds;

        // Transition bed statuses
        beds[0].Status__c = 'Occupied';
        beds[1].Status__c = 'Cleaning';
        beds[2].Status__c = 'Out of Service';
        update new List<Bed__c>{ beds[0], beds[1], beds[2] };

        Ward__c queried = [
            SELECT Id, Current_Bed_Count__c, Available_Bed_Count__c
            FROM Ward__c
            WHERE Id = :ward.Id
        ];
        System.assertEquals(4, queried.Current_Bed_Count__c, 'Total bed count must still be 4');
        System.assertEquals(1, queried.Available_Bed_Count__c, 'Only 1 bed should remain Available');
    }

    @isTest
    static void testUniqueWardAndBedCode() {
        Ward__c ward1 = new Ward__c(
            Name = 'Cardiac Ward 1',
            Ward_Code__c = 'WRD-CARD-01',
            Ward_Type__c = 'General',
            Floor__c = '1',
            Capacity__c = 5,
            Is_Active__c = true
        );
        insert ward1;

        Ward__c wardDup = new Ward__c(
            Name = 'Cardiac Ward Duplicate',
            Ward_Code__c = 'WRD-CARD-01',
            Ward_Type__c = 'Private',
            Floor__c = '2',
            Capacity__c = 3,
            Is_Active__c = true
        );

        Boolean threw = false;
        try {
            insert wardDup;
        } catch (DmlException e) {
            threw = true;
        }
        System.assert(threw, 'Expected DmlException for duplicate Ward Code');
    }
}
